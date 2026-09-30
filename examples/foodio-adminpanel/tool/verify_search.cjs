/**
 * Cross-resource global search and keyboard activation in real Chrome, twice.
 * Run: npm exec --yes --package=playwright -- node tool/verify_search.cjs
 * Read-only; FOODIO_URL and FOODIO_ARTIFACTS select the app and evidence folder.
 */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {performance} = require('node:perf_hooks');
const cli = process.env.PATH.split(path.delimiter)
  .map(p => path.join(p, 'playwright')).find(p => fs.existsSync(p));
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const base = (process.env.FOODIO_URL || 'http://127.0.0.1:59389').replace(/\/$/, '').replace(/#.*$/, '');
const artifacts = process.env.FOODIO_ARTIFACTS || path.join(__dirname, '../.artifacts', `foodio-search-${Date.now()}`);
fs.mkdirSync(artifacts, {recursive: true});
const report = {url: base, passes: []};

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const page = await browser.newPage({viewport: {width: 1440, height: 1024}, timezoneId: 'Europe/Vienna'});
  const errors = [], failed = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('response', response => {
    if (response.url().includes('/api/') && response.status() >= 400) failed.push({url: response.url(), status: response.status()});
  });
  try {
    for (const pass of ['cold', 'warm']) {
      await page.goto(`${base}/?search_qa=${pass}#/orders`);
      await page.locator('flt-semantics-placeholder').waitFor({state: 'attached'});
      await page.locator('flt-semantics-placeholder').evaluateAll(elements => elements.forEach(element => element.click()));
      await page.getByRole('button', {name: /^Today · \d+$/}).waitFor();
      const searches = [];
      for (const scenario of [
        {term: 'ORD-24817', result: /ORD-24817.*Orders/, route: '/orders/ord_3f9c24817b', keyboard: true},
        {term: 'lena.hofer@nordlicht-energie.at', result: /Lena Hofer.*Customers/, route: '/customers/customer-lena'},
        {term: 'Beetroot risotto', result: /Beetroot risotto.*Dishes/, route: '/dishes/dish-risotto'},
        {term: 'INV-2026-0412', result: /INV-2026-0412.*Invoices/, route: '/invoices/invoice-2026-0412'},
      ]) {
        const started = performance.now();
        await page.keyboard.press('Control+k');
        await page.getByText('Go to', {exact: true}).waitFor();
        const input = page.getByRole('textbox').last();
        await input.click();
        await page.keyboard.type(scenario.term, {delay: 8});
        const result = page.getByRole('button').filter({hasText: scenario.result}).first();
        await result.waitFor();
        const readyMs = Math.round(performance.now() - started);
        const name = scenario.route.split('/')[1];
        await page.screenshot({path: path.join(artifacts, `${pass}-${name}-search.png`)});
        if (scenario.keyboard) await page.keyboard.press('Enter'); else await result.click();
        await page.waitForURL(url => decodeURIComponent(url.hash).split('?')[0] === `#${scenario.route}`);
        await page.getByRole('button', {name: /^Edit(?: order)?(?:\s+Edit(?: order)?)?$/}).waitFor();
        searches.push({resource: name, term: scenario.term, readyMs, route: scenario.route, keyboard: !!scenario.keyboard});
      }
      assert.deepEqual(errors, [], 'No browser errors');
      assert.deepEqual(failed, [], 'No failed API responses');
      report.passes.push({pass, searches});
    }
  } finally {
    await page.screenshot({path: path.join(artifacts, 'last-page.png')}).catch(() => {});
    fs.writeFileSync(path.join(artifacts, 'last-page.txt'), await page.locator('body').ariaSnapshot().catch(() => ''));
    fs.writeFileSync(path.join(artifacts, 'report.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify({artifacts, ...report}, null, 2));
    await browser.close();
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
