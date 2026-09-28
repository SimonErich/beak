/**
 * Verifies the persisted delivery-note document twice in real Chrome. Read only.
 * Run: npm exec --yes --package=playwright -- node tool/verify_documents.cjs
 * Native print is intercepted in headless Chrome; its call and printable HTML,
 * PDF output, authorization query and absence of mutations are all verified.
 */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {performance} = require('node:perf_hooks');
const cli = process.env.PATH.split(path.delimiter)
  .map(p => path.join(p, 'playwright')).find(p => fs.existsSync(p));
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const base = (process.env.FOODIO_URL || 'http://127.0.0.1:59389').replace(/\/$/, '').replace(/#.*$/, '');
const artifacts = process.env.FOODIO_ARTIFACTS || path.join(__dirname, '../.artifacts', `foodio-documents-${Date.now()}`);
fs.mkdirSync(artifacts, {recursive: true});
const report = {url: base, passes: []};

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const context = await browser.newContext({viewport: {width: 1440, height: 1720}, timezoneId: 'Europe/Vienna'});
  await context.addInitScript(() => { window.print = () => { window.__printRequested = true; }; });
  const page = await context.newPage();
  const errors = [];
  const requests = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('request', request => {
    const url = new URL(request.url());
    if (url.pathname.includes('/api/')) requests.push({path: url.pathname, method: request.method()});
  });
  try {
    for (const pass of ['cold', 'warm']) {
      await page.goto(`${base}/?document_qa=${pass}#/orders/ord_3f9c24817b`);
      await page.locator('flt-semantics-placeholder').waitFor({state: 'attached'});
      await page.locator('flt-semantics-placeholder').evaluateAll(elements => elements.forEach(element => element.click()));
      const action = page.getByRole('button').filter({hasText: /^Print delivery note(?:\nPrint delivery note)?$/});
      await action.waitFor();
      await page.getByRole('banner', {name: /^ORD-24817/}).waitFor();
      await page.getByText('Customer and profile', {exact: false}).last().waitFor();
      await page.screenshot({path: path.join(artifacts, `${pass}-order-overview.png`)});
      fs.writeFileSync(path.join(artifacts, `${pass}-order-overview.txt`), await page.locator('body').ariaSnapshot());
      const before = requests.length;
      const started = performance.now();
      const opened = page.waitForEvent('popup');
      await action.click();
      const popup = await opened;
      await popup.waitForFunction(() => window.__printRequested === true);
      await popup.getByRole('heading', {name: 'ORD-24817', exact: true}).waitFor();
      const readyMs = Math.round(performance.now() - started);
      const text = await popup.locator('body').innerText();
      fs.writeFileSync(path.join(artifacts, `${pass}-text.txt`), text);
      for (const value of ['Lena Hofer', 'Delivery', 'Dishes', 'Kitchen notes', '€31.40', 'Mon 28 Sep']) {
        assert.ok(text.includes(value), `Delivery note includes ${value}`);
      }
      for (const allergens of ['G,L,O', 'L,M', 'A,C,G,H']) {
        assert.ok(text.includes(allergens), `Delivery note preserves saved allergen snapshot ${allergens}`);
      }
      assert.equal(await popup.evaluate(() => window.opener), null);
      assert.equal(await popup.locator('script').count(), 0);
      assert.match(await popup.locator('meta[http-equiv="Content-Security-Policy"]').getAttribute('content'), /default-src 'none'/);
      const documentRequests = requests.slice(before);
      assert.equal(documentRequests.filter(request => request.path.endsWith('/query')).length, 1, 'One authorized query loads the complete snapshot');
      assert.equal(documentRequests.filter(request => !request.path.endsWith('/query') && request.method !== 'GET').length, 0, 'Printing does not save or execute a command');
      await popup.screenshot({path: path.join(artifacts, `${pass}-delivery-note.png`), fullPage: true});
      await popup.pdf({path: path.join(artifacts, `${pass}-delivery-note.pdf`), format: 'A4', printBackground: true});
      fs.writeFileSync(path.join(artifacts, `${pass}-delivery-note.html`), await popup.content());
      await popup.close();
      await page.getByRole('button', {name: 'Payment & invoice', exact: true}).click();
      await page.getByText('INV-2026-0412', {exact: false}).first().waitFor();
      await page.screenshot({path: path.join(artifacts, `${pass}-order-payment.png`)});
      await page.getByRole('button', {name: 'Overview', exact: true}).click();
      assert.deepEqual(errors, []);
      report.passes.push({pass, readyMs, queryCount: documentRequests.filter(request => request.path.endsWith('/query')).length});
    }
    await page.evaluate(() => { window.open = () => null; });
    const downloadReady = page.waitForEvent('download');
    await page.getByRole('button').filter({hasText: /^Print delivery note(?:\nPrint delivery note)?$/}).click();
    const download = await downloadReady;
    const fallback = path.join(artifacts, 'blocked-popup-delivery-note.html');
    await download.saveAs(fallback);
    assert.equal(await download.failure(), null);
    assert.match(fs.readFileSync(fallback, 'utf8'), /ORD-24817/);
    assert.match(fs.readFileSync(fallback, 'utf8'), /€31\.40/);
    report.popupBlockedFallback = true;
  } finally {
    await page.screenshot({path: path.join(artifacts, 'page.png')}).catch(() => {});
    fs.writeFileSync(path.join(artifacts, 'page.txt'), await page.locator('body').ariaSnapshot().catch(() => ''));
    fs.writeFileSync(path.join(artifacts, 'report.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify({artifacts, ...report}, null, 2));
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
