/** Read-only checks for narrow/short pages and reduced-motion wizard surfaces.
 * npm exec --yes --package=playwright -- node tool/verify_compact_surfaces.cjs
 */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const cli = process.env.PATH.split(path.delimiter).map(p => path.join(p, 'playwright')).find(fs.existsSync);
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const base = process.env.FOODIO_URL || 'http://127.0.0.1:59389';
const artifacts = process.env.FOODIO_ARTIFACTS || path.join(__dirname, '../.artifacts', `foodio-compact-surfaces-${Date.now()}`);
fs.mkdirSync(artifacts, {recursive: true});
const report = {passes: [], errors: [], failedRequests: [], writes: []};
(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  try {
    for (const viewport of [{width: 375, height: 812}, {width: 812, height: 375}]) {
      const context = await browser.newContext({viewport, reducedMotion: 'reduce', timezoneId: 'Europe/Vienna'});
      for (const route of ['overview', 'orders', 'orders/create']) {
        const page = await context.newPage();
        page.setDefaultTimeout(20000);
        page.on('pageerror', error => report.errors.push(String(error)));
        page.on('response', response => {
          if (response.url().includes('/api/') && response.status() >= 400) report.failedRequests.push({url: response.url(), status: response.status()});
        });
        await page.route('**/api/commits', request => {
          report.writes.push(request.request().url());
          return request.abort('blockedbyclient');
        });
        try {
          await page.goto(`${base}/#/${route}`);
          await page.waitForFunction(() => document.querySelector('flt-semantics-placeholder') || document.querySelector('flt-semantics[role]'));
          await page.locator('flt-semantics-placeholder').evaluateAll(elements => elements.forEach(element => element.click()));
          if (route === 'overview') await page.getByText('Good morning, Marie', {exact: true}).waitFor();
          else if (route === 'orders') await page.getByRole('button', {name: 'New order', exact: true}).waitFor();
          else await page.getByText('Who is this order for?', {exact: true}).waitFor();
          await page.waitForTimeout(600);
          assert(await page.evaluate(() => matchMedia('(prefers-reduced-motion: reduce)').matches));
          const name = `${viewport.width}x${viewport.height}-${route.replace('/', '-')}`;
          await page.mouse.move(2, 2);
          await page.screenshot({path: path.join(artifacts, `${name}.png`)});
          fs.writeFileSync(path.join(artifacts, `${name}.txt`), await page.locator('body').ariaSnapshot());
          if (route === 'orders/create') {
            const next = page.getByRole('button', {name: /^Continue to delivery/});
            const bounds = await next.boundingBox();
            assert(bounds && bounds.x >= 0 && bounds.x + bounds.width <= viewport.width + 1 && bounds.y >= 0 && bounds.y + bounds.height <= viewport.height,
              `Wizard footer remains reachable at ${viewport.width}x${viewport.height}`);
            const summary = page.getByRole('button', {name: 'Summary', exact: true});
            await summary.click();
            const close = page.getByRole('button', {name: 'Close Summary', exact: true});
            await close.waitFor();
            const closeBounds = await close.boundingBox();
            assert(closeBounds && closeBounds.y >= 0 && closeBounds.y + closeBounds.height <= viewport.height,
              'Summary close action stays inside the short viewport');
            await page.screenshot({path: path.join(artifacts, `${name}-summary.png`)});
            await close.click();
            await close.waitFor({state: 'hidden'});
            if (viewport.height < 500) {
              const customer = page.getByRole('textbox').first();
              for (let attempt = 0; attempt < 8; attempt++) {
                const inputBounds = await customer.boundingBox();
                if (inputBounds && inputBounds.y >= 108 && inputBounds.y + inputBounds.height < bounds.y) break;
                await page.mouse.move(viewport.width - 180, 210);
                await page.mouse.wheel(0, 120);
                await page.waitForTimeout(100);
              }
              const inputBounds = await customer.boundingBox();
              assert(inputBounds && inputBounds.y >= 108 && inputBounds.y + inputBounds.height < bounds.y,
                'The short wizard scrolls inputs into its editable region');
              await customer.click();
              await page.waitForTimeout(150);
              assert(await customer.evaluate(element => document.activeElement === element),
                'The real editor owns focus before typing');
              await page.keyboard.type('Lena', {delay: 60});
              assert.equal(await customer.inputValue(), 'Lena');
              await page.getByRole('button').filter({hasText: /^Lena Hofer/}).waitFor();
              await page.waitForTimeout(200);
              await page.mouse.move(2, 2);
              await page.screenshot({path: path.join(artifacts, `${name}-scrolled.png`)});
            }

          }
          report.passes.push({viewport, route, reducedMotion: true});
        } finally { await page.close(); }
      }
      await context.close();
    }
    assert.deepEqual(report.errors, []);
    assert.deepEqual(report.failedRequests, []);
    assert.deepEqual(report.writes, []);
  } finally {
    await browser.close();
    fs.writeFileSync(path.join(artifacts, 'report.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify({artifacts, ...report}, null, 2));
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
