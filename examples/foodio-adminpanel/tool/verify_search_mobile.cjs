/** Verifies the visible compact header search button at both phone widths. */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const cli = process.env.PATH.split(path.delimiter).map(p => path.join(p, 'playwright')).find(p => fs.existsSync(p));
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const base = process.env.FOODIO_URL || 'http://127.0.0.1:59389';
const artifacts = process.env.FOODIO_ARTIFACTS || path.join(__dirname, '../.artifacts', `foodio-search-mobile-${Date.now()}`);
fs.mkdirSync(artifacts, {recursive: true});
(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const page = await browser.newPage({timezoneId: 'Europe/Vienna'});
  const passes = [], errors = [], failures = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('response', response => {
    if (response.url().includes('/api/') && response.status() >= 400) failures.push(response.status());
  });
  try {
    for (const width of [320, 390]) {
      await page.setViewportSize({width, height: 844});
      await page.goto(`${base}/?beak_qa=search-${width}#/orders`);
      const placeholder = page.locator('flt-semantics-placeholder');
      await placeholder.waitFor({state: 'attached'});
      await placeholder.evaluateAll(elements => elements.forEach(element => element.click()));
      await page.waitForTimeout(1500);
      await page.screenshot({path: path.join(artifacts, `initial-${width}.png`)});
      fs.writeFileSync(path.join(artifacts, `initial-${width}.txt`), await page.locator('body').ariaSnapshot());
      await page.getByRole('button', {name: 'Toggle theme', exact: true}).waitFor();
      await page.getByRole('button', {name: 'Marie Novak account menu', exact: true}).waitFor();
      const search = page.getByRole('button', {name: /^Search orders, customers, invoices/});
      await search.waitFor();
      const bounds = await search.boundingBox();
      assert(bounds && bounds.width >= 32 && bounds.height >= 32 && bounds.x + bounds.width <= width, 'Visible search target fits the header');
      await page.screenshot({path: path.join(artifacts, `header-${width}.png`)});
      // Use the real pointer route; Flutter's transparent semantics layer can
      // obscure a locator without preventing actual pointer hit testing.
      await page.mouse.click(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2);
      await page.getByText('Go to', {exact: true}).waitFor();
      const input = page.getByRole('textbox').last();
      await input.fill('ORD-24817');
      const result = page.getByRole('button').filter({hasText: 'ORD-24817'}).first();
      await result.waitFor();
      await page.screenshot({path: path.join(artifacts, `search-${width}.png`)});
      fs.writeFileSync(path.join(artifacts, `search-${width}.txt`), await page.locator('body').ariaSnapshot());
      await page.keyboard.press('Escape');
      await search.waitFor();
      passes.push({width, searchButtonBounds: bounds, query: 'ORD-24817', resultVisible: true});
    }
    assert.deepEqual(errors, []);
    assert.deepEqual(failures, []);
  } finally {
    await page.screenshot({path: path.join(artifacts, 'last-page.png')}).catch(() => {});
    fs.writeFileSync(path.join(artifacts, 'last-page.txt'), await page.locator('body').ariaSnapshot().catch(() => ''));
    fs.writeFileSync(path.join(artifacts, 'report.json'), JSON.stringify({passes, errors, failures}, null, 2));
    console.log(JSON.stringify({artifacts, passes, errors, failures}, null, 2));
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
