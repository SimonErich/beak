/** Capture a rendered Flutter route and its accessible structure for visual QA.
 * npm exec --yes --package=playwright -- node tool/capture_screen.cjs /orders/id/edit
 */
const fs = require('node:fs');
const path = require('node:path');
const cli = process.env.PATH.split(path.delimiter).map(p => path.join(p, 'playwright')).find(fs.existsSync);
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const route = process.argv[2] || '/orders';
const name = route.replace(/[^a-z0-9_-]/gi, '_');
const output = process.env.FOODIO_ARTIFACTS || path.join(__dirname, '../.artifacts/captures');
fs.mkdirSync(output, {recursive: true});
(async () => {
  const browser = await chromium.launch({channel:'chrome', headless:true});
  try {
    const page = await browser.newPage({viewport:{width:1440, height:1720}, timezoneId:'Europe/Vienna'});
    await page.goto(`${process.env.FOODIO_URL || 'http://127.0.0.1:59389'}/#${route}`);
    await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
    await page.locator('flt-semantics-placeholder').evaluateAll(elements => elements.forEach(element => element.click()));
    if (/^\/orders\/[^/]+\/edit$/.test(route)) {
      await page.getByRole('button', {name:/^Save changes(?:\s+Save changes)?$/}).waitFor({timeout:30000});
    } else if (/^\/orders\/[^/]+$/.test(route) && route !== '/orders/create') {
      await page.getByRole('button', {name:/^Edit(?: order)?(?:\s+Edit(?: order)?)?$/}).waitFor({timeout:30000});
    }
    await page.getByText('Loading…', {exact:true}).waitFor({state:'hidden'});
    await page.waitForTimeout(1200);
    await page.screenshot({path:path.join(output, name+'.png')});
    fs.writeFileSync(path.join(output, name+'.txt'), await page.locator('body').ariaSnapshot());
    console.log(path.join(output,name+'.png'));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode=1; });
