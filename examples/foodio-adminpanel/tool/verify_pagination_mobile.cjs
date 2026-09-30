/** Checks a bookmarked middle page and visible pagination at narrow widths. */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const cli = process.env.PATH.split(path.delimiter).map(p => path.join(p, 'playwright')).find(p => fs.existsSync(p));
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const base = process.env.FOODIO_URL || 'http://127.0.0.1:59389';
const artifacts = process.env.FOODIO_ARTIFACTS || path.join(__dirname, '../.artifacts', `foodio-pagination-${Date.now()}`);
fs.mkdirSync(artifacts, {recursive: true});
(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const page = await browser.newPage({timezoneId: 'Europe/Vienna'});
  const errors = [], failures = [], passes = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('response', response => {
    if (response.url().includes('/api/') && response.status() >= 400) failures.push(response.status());
  });
  try {
    for (const width of [320, 390]) {
      await page.setViewportSize({width, height: 844});
      const state = {version: 1, preset: 'all', filters: {}, search: '', sorts: [], page: 21, perPage: 15, showHeader: false};
      // Match BeakQueryController's padded base64Url wire representation.
      const encoded = Buffer.from(JSON.stringify(state)).toString('base64').replaceAll('+', '-').replaceAll('/', '_');
      await page.goto(`${base}/?beak_qa=pager-${width}#/orders?list=${encoded}`);
      const placeholder = page.locator('flt-semantics-placeholder');
      await placeholder.waitFor({state: 'attached'});
      await placeholder.evaluateAll(elements => elements.forEach(element => element.click()));
      const next = page.getByRole('button', {name: 'Next page', exact: true});
      await page.waitForTimeout(2500);
      await page.screenshot({path: path.join(artifacts, `initial-${width}.png`)});
      fs.writeFileSync(path.join(artifacts, `initial-${width}.txt`), await page.locator('body').ariaSnapshot());
      await next.waitFor();
      // Scroll the actual Flutter page, not just its accessibility DOM proxy.
      for (let attempt = 0; attempt < 8; attempt++) {
        const box = await next.boundingBox();
        if (box && box.y >= 64 && box.y + box.height <= 820) break;
        await page.mouse.move(18, 740);
        await page.mouse.wheel(0, 700);
        await page.waitForTimeout(180);
      }
      await page.getByRole('button', {name: /^Page 21(?: 21)?$/}).waitFor();
      await page.screenshot({path: path.join(artifacts, `orders-${width}.png`)});
      fs.writeFileSync(path.join(artifacts, `orders-${width}.txt`), await page.locator('body').ariaSnapshot());
      const bounds = await next.boundingBox();
      assert(bounds && bounds.x >= 0 && bounds.x + bounds.width <= width + 1 && bounds.y >= 64 && bounds.y + bounds.height <= 844, 'Next page fits the viewport');
      const hitStack = await page.evaluate(({x,y}) => document.elementsFromPoint(x,y).slice(0,5).map(element=>({tag:element.tagName,id:element.id,role:element.getAttribute('role'),label:element.getAttribute('aria-label'),text:element.textContent,rect:element.getBoundingClientRect().toJSON()})), {x:bounds.x+bounds.width/2,y:bounds.y+bounds.height/2});
      fs.writeFileSync(path.join(artifacts, `hit-stack-${width}.json`), JSON.stringify({bounds,hitStack},null,2));
      // A transparent Flutter semantics proxy can cover the DOM node. Verify
      // the real pointer route at the observed button centre, without force.
      await page.mouse.click(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2);
      await page.waitForURL(url => {
        const list = new URLSearchParams(url.hash.split('?')[1]).get('list');
        return list && JSON.parse(Buffer.from(list, 'base64url').toString()).page === 22;
      });
      passes.push({width, pageBefore: 21, pageAfter: 22, nextButtonBounds: bounds});
    }
    assert.deepEqual(errors, []);
    assert.deepEqual(failures, []);
  } finally {
    fs.writeFileSync(path.join(artifacts, 'report.json'), JSON.stringify({passes, errors, failures}, null, 2));
    console.log(JSON.stringify({artifacts, passes, errors, failures}, null, 2));
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
