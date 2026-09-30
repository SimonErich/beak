/**
 * Traverses all five order steps twice at a 390px mobile viewport in Chrome.
 * Exercises catalog filters, voucher validation, draft retention and summary
 * sheet access without placing an order. Any commit request fails the check.
 * Run: npm exec --yes --package=playwright -- node tool/verify_wizard_mobile.cjs
 * FOODIO_URL and FOODIO_ARTIFACTS configure the app and evidence directory.
 */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {performance} = require('node:perf_hooks');
const cli = process.env.PATH.split(path.delimiter).map(p => path.join(p, 'playwright')).find(fs.existsSync);
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const base = (process.env.FOODIO_URL || 'http://127.0.0.1:59389').replace(/\/$/, '').replace(/#.*$/, '');
const artifacts = process.env.FOODIO_ARTIFACTS || path.join(__dirname, '../.artifacts', `foodio-mobile-wizard-${Date.now()}`);
fs.mkdirSync(artifacts, {recursive: true});
const report = {url: base, passes: []};

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const context = await browser.newContext({viewport: {width: 390, height: 844}, timezoneId: 'Europe/Vienna'});
  const page = await context.newPage();
  page.setDefaultTimeout(20000);
  await page.route('**/api/commits', route => route.abort('blockedbyclient'));
  let errors = [], requests = [], active = new Map();
  page.on('pageerror', error => errors.push(String(error)));
  page.on('request', request => {
    const url = new URL(request.url());
    if (!url.pathname.includes('/api/')) return;
    const entry = {path: url.pathname, method: request.method(), start: performance.now()};
    if (request.method() === 'POST' && url.pathname.endsWith('/query')) { try { entry.searchTerm = request.postDataJSON()?.search?.term; } catch (_) {} }
    active.set(request, entry); requests.push(entry);
  });
  page.on('response', response => { const entry = active.get(response.request()); if (entry) entry.status = response.status(); });
  page.on('requestfinished', request => {
    const entry = active.get(request);
    if (entry) { entry.durationMs = Math.round(performance.now() - entry.start); active.delete(request); }
  });
  page.on('requestfailed', request => {
    const entry = active.get(request);
    if (entry) { entry.failure = request.failure()?.errorText; active.delete(request); }
  });
  const button = name => page.getByRole('button').filter({hasText: new RegExp(`^${name}(?:\\n${name})?$`)});
  async function settle() {
    const deadline = performance.now() + 15000;
    let quiet = performance.now();
    while (performance.now() < deadline) {
      if (active.size) quiet = performance.now();
      if (!active.size && performance.now() - quiet > 350) return;
      await page.waitForTimeout(50);
    }
    throw new Error('Requests did not settle');
  }
  async function open(route) {
    await page.goto(`${base}/#${route}`);
    const placeholder = page.locator('flt-semantics-placeholder');
    await page.waitForFunction(() => document.querySelector('flt-semantics-placeholder') || document.querySelector('flt-semantics[role]'));
    await placeholder.evaluateAll(elements => elements.forEach(element => element.click()));
  }
  async function enter(input, value) {
    await settle();
    await input.click(); await page.waitForTimeout(250);
    assert.ok(await input.evaluate(element => document.activeElement === element),
      'The requested editor owns focus before changing its value');
    // Use editing keys so the Flutter engine and its semantic input agree on
    // selection. Clear both sides of the caret without mutating the DOM value.
    const length = (await input.inputValue()).length;
    for (let i = 0; i < length; i++) await page.keyboard.press('Backspace', {delay: 10});
    for (let i = 0; i < length; i++) await page.keyboard.press('Delete', {delay: 10});
    await page.waitForTimeout(100);
    assert.equal(await input.inputValue(), '', 'The editor is empty before replacing its value');
    if (value) await page.keyboard.type(value, {delay: 60});
    await page.waitForTimeout(100);
    assert.equal(await input.inputValue(), value, 'The real editor retains the complete input');
  }

  async function capture(pass, name) {
    await page.mouse.move(4, 4);
    await settle();
    await page.screenshot({path: path.join(artifacts, `${pass}-${name}.png`)});
    fs.writeFileSync(path.join(artifacts, `${pass}-${name}.txt`), await page.locator('body').ariaSnapshot());
  }
  async function captureScrolled(pass, name, delta) {
    await page.mouse.move(190, 350);
    await page.mouse.wheel(0, delta);
    await settle();
    await capture(pass, name);
  }
  async function closeSummary() {
    const close = page.getByRole('button', {name: 'Close Summary', exact: true});
    const bounds = await close.boundingBox();
    assert.ok(bounds && bounds.y >= 0 && bounds.y + bounds.height <= 844,
      'The summary exposes its close action inside the mobile viewport');
    await close.click();
    await close.waitFor({state: 'hidden'});
  }
  async function advance(title) {
    await page.getByRole('button').filter({hasText: /^Continue/}).click();
    await page.getByText(title, {exact: true}).waitFor(); await settle();
  }
  try {
    for (const pass of ['cold', 'warm']) {
      errors = []; requests = []; active = new Map();
      const started = performance.now();
      await page.setViewportSize({width: 390, height: 844});
      await open('/orders/create');
      await page.getByText('Who is this order for?', {exact: true}).waitFor();
      const readyMs = Math.round(performance.now() - started);
      await enter(page.getByRole('textbox').first(), 'Lena');
      await page.getByRole('button').filter({hasText: /^Lena Hofer/}).click();
      await settle();
      await capture(pass, 'customer');
      await captureScrolled(pass, 'customer-profiles', 1200);
      await advance('When and where should it arrive?');
      await page.getByRole('button').filter({hasText: /^12:00–12:30/}).click();
      await enter(page.getByRole('textbox', {name: 'Delivery note', exact: true}),
        'Team meeting in room 3.14 – please bring cutlery for four.');
      await capture(pass, 'delivery');
      await captureScrolled(pass, 'delivery-top', -2000);
      await advance('Choose dishes');
      for (const [term, quantity, dish] of [['risotto', 2, 'Beetroot risotto with goat’s cheese'], ['schnitzel', 1, 'Pork schnitzel with parsley potatoes'], ['lentil', 1, 'Red lentil dal with basmati rice']]) {
        await enter(page.getByRole('textbox').first(), term);
        await page.waitForTimeout(250); await settle();
        await page.getByText(dish, {exact: true}).waitFor();
        const increase = page.getByRole('button', {name: /Increase .*Regular/});
        assert.equal(await increase.count(), 1, `${term} searches the related dish identity`);
        for (let i = 0; i < quantity; i++) { await increase.click(); await settle(); }
      }
      await enter(page.getByRole('textbox').first(), '');
      await capture(pass, 'dishes');
      assert.match(await page.locator('body').innerText(), /€48\.60/);
      // These facets hide catalog choices, while selected dishes remain in the
      // separate summary. Check interactive catalog controls rather than names
      // that intentionally still appear in the summary.
      const regularVariants = page.getByRole('button', {name: /Increase .*Regular/});
      assert.equal(await regularVariants.count(), 3);
      const catalogQueries = requests.filter(request => request.path.endsWith('/dish_variants/query')).length;
      async function facet(name) {
        await page.getByRole('button', {name, exact: true}).click();
        await settle();
      }
      await facet('Without A · gluten');
      assert.equal(await regularVariants.count(), 2, 'Gluten facet hides schnitzel while preserving risotto and dal');
      await facet('Without G · milk');
      assert.equal(await regularVariants.count(), 1, 'Milk facet also hides risotto while preserving dal');
      await capture(pass, 'dishes-filtered');
      assert.match(await page.locator('body').innerText(), /€48\.60/, 'Hiding choices preserves staged dishes and quantities');
      await facet('Without A · gluten');
      await facet('Without G · milk');
      assert.equal(await regularVariants.count(), 3);
      assert.equal(requests.filter(request => request.path.endsWith('/dish_variants/query')).length, catalogQueries,
        'Bounded local facets do not fetch the catalog again');
      await advance('How is it paid?');
      const voucherInput = page.getByRole('textbox', {name: /^Voucher code/});
      await enter(voucherInput, 'MISSING');
      await button('Apply').click();
      await page.waitForFunction(() => {
        const message = 'No available record matches this code.';
        return document.body.innerText.includes(message) ||
          [...document.querySelectorAll('[aria-label]')].some(
            element => element.getAttribute('aria-label').includes(message),
          );
      });
      await enter(voucherInput, 'lunch15');
      await button('Apply').click(); await settle();
      await button('Remove').waitFor();
      await capture(pass, 'payment');
      await captureScrolled(pass, 'payment-top', -2000);
      await button('Back').click(); await settle();
      await page.getByRole('button', {name: 'Summary', exact: true}).click();
      await settle();
      assert.match(await page.locator('body').innerText(), /€41\.31/,
        'Going back keeps the same staged graph in the mobile summary');
      await capture(pass, 'retained-summary-sheet');
      await closeSummary();
      await settle();
      await advance('How is it paid?');
      await advance('Check and place the order');
      const preview = await page.locator('body').innerText();
      for (const amount of ['€48.60', '-€7.29', '€37.55', '€3.76', '€41.31']) assert.ok(preview.includes(amount), amount);
      await capture(pass, 'review');
      await captureScrolled(pass, 'review-top', -2000);
      await captureScrolled(pass, 'review-totals', 2000);
      await page.getByRole('button', {name: 'Summary', exact: true}).click();
      await settle();
      await capture(pass, 'summary-sheet');
      assert.ok((await page.locator('body').innerText()).includes('€41.31'));
      await closeSummary(); await settle();
      await page.getByRole('button', {name: 'Place order', exact: true}).waitFor();
      const placeBounds = await page.getByRole('button', {name: 'Place order', exact: true}).boundingBox();
      assert.ok(placeBounds && placeBounds.y >= 0 && placeBounds.y + placeBounds.height <= 844,
        'Final submission stays reachable inside the mobile viewport');
      assert.deepEqual(errors, [], 'No browser runtime errors');
      assert.deepEqual(requests.filter(request => request.failure), [], 'No network failures');
      assert.deepEqual(requests.filter(request => request.status >= 400), [], 'No failed API responses');
      assert.equal(requests.filter(request => request.path.endsWith('/commits')).length, 0,
        'Mobile previews never persist the staged order');
      report.passes.push({pass, readyMs, viewport: '390x844', totalCents: 4131,
        previewOnly: true, requestCount: requests.length,
        requests: requests.map(({start, ...request}) => request)});
      await page.goto('about:blank');
    }
  } catch (error) {
    await page.screenshot({path:path.join(artifacts, 'failure.png')}).catch(() => {});
    fs.writeFileSync(path.join(artifacts, 'failure.txt'), await page.locator('body').ariaSnapshot());
    throw error;
  } finally {
    fs.writeFileSync(path.join(artifacts, 'last-requests.json'), JSON.stringify(requests.map(({start, ...request}) => request), null, 2));
    fs.writeFileSync(path.join(artifacts, 'report.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify({artifacts, passes: report.passes.map(({requests, ...pass}) => pass)}, null, 2));
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
