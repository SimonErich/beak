/**
 * Real Chrome supporting-resource smoke checks. No order writes.
 * Run: npm exec --yes --package=playwright -- node tool/verify_supporting.cjs
 */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {performance} = require('node:perf_hooks');
const cli = process.env.PATH.split(path.delimiter)
  .map(p => path.join(p, 'playwright')).find(p => fs.existsSync(p));
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const base = process.env.FOODIO_URL || 'http://127.0.0.1:59389';
const artifacts = process.env.FOODIO_ARTIFACTS || path.join(__dirname, '../.artifacts', `foodio-supporting-${Date.now()}`);
fs.mkdirSync(artifacts, {recursive: true});
const report = {url: base, passes: [], failures: [], requests: []};
const resources = ['customers', 'organizations', 'delivery_profiles', 'staff_members',
  'delivery_locations', 'dishes', 'menu_plans', 'delivery_slots', 'complaints',
  'invoices', 'vouchers', 'budget_accounts', 'app_settings', 'notifications'];

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const page = await browser.newPage({viewport: {width: 1440, height: 1200}, timezoneId: 'Europe/Vienna'});
  page.setDefaultTimeout(10000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('response', response => {
    const url = new URL(response.url());
    if (url.pathname.includes('/api/')) report.requests.push({path: url.pathname, query: Object.fromEntries(url.searchParams), status: response.status()});
  });
  const button = text => page.getByRole('button').filter({hasText: new RegExp(`^${text}(?:\\n${text})?$`)});
  async function semantics() {
    if (await page.locator('flt-semantics').count()) return;
    const placeholder = page.locator('flt-semantics-placeholder');
    await placeholder.waitFor({state: 'attached'});
    await placeholder.evaluateAll(elements => elements.forEach(element => element.click()));
  }
  async function screenshot(name) {
    await page.screenshot({path: path.join(artifacts, `${name}.png`)});
    fs.writeFileSync(path.join(artifacts, `${name}.txt`), await page.locator('body').ariaSnapshot());
  }
  try {
    for (const resource of resources) {
      const started = performance.now();
      try {
        await page.goto(`${base}/#/${resource}`);
        await semantics();
        await page.getByRole('button', {name: 'View', exact: true}).first().waitFor();
        const listReadyMs = Math.round(performance.now() - started);
        await screenshot(`${resource}-list`);
        const detailStarted = performance.now();
        await page.getByRole('button', {name: 'View', exact: true}).first().click();
        await button('Back').waitFor();
        await page.getByText('Loading…', {exact: true}).waitFor({state: 'hidden'});
        await screenshot(`${resource}-detail`);
        assert(!/Invalid default|Something went wrong|Failed to load/.test(await page.locator('body').ariaSnapshot()));
        assert.equal(errors.length, 0, errors.join('\n'));
        report.passes.push({resource, listReadyMs, detailReadyMs: Math.round(performance.now() - detailStarted)});
      } catch (error) {
        report.failures.push({resource, message: String(error)});
        await screenshot(`${resource}-failure`).catch(() => {});
      }
    }
    await page.setViewportSize({width: 390, height: 844});
    await page.goto(`${base}/#/customers`);
    await semantics();
    await button('Create').waitFor();
    await screenshot('customers-mobile');
    assert.equal(errors.length, 0, errors.join('\n'));
    assert.deepEqual(report.requests.filter(request => request.status >= 400), []);
  } finally {
    fs.writeFileSync(path.join(artifacts, 'report.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify({artifacts, passes: report.passes, failures: report.failures}, null, 2));
    await browser.close();
  }
  if (report.failures.length) process.exitCode = 1;
})().catch(error => {console.error(error); process.exitCode = 1;});
