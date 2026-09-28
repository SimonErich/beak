/**
 * Real Chrome delivery configuration checks, cold and warm. This harness edits
 * only a local new-order draft: it never places an order or calls /commits.
 * Run: npm exec --yes --package=playwright -- node tool/verify_delivery.cjs
 * FOODIO_URL / FOODIO_ARTIFACTS configure the app and retained evidence.
 */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {performance} = require('node:perf_hooks');
const cli = process.env.PATH.split(path.delimiter).map(p => path.join(p, 'playwright')).find(fs.existsSync);
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const base = (process.env.FOODIO_URL || 'http://127.0.0.1:59389').replace(/\/$/, '').replace(/#.*$/, '');
const artifacts = process.env.FOODIO_ARTIFACTS || path.join(__dirname, '../.artifacts', `foodio-delivery-${Date.now()}`);
fs.mkdirSync(artifacts, {recursive: true});
const report = {url: base, passes: [], errors: [], requests: []};
const originalLocation = 'HQ Wieden';
const overrideStreet = 'Karlsgasse 9, side entrance';
const note = 'Please use the side entrance.\nCall reception on arrival.';

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const context = await browser.newContext({viewport: {width: 1440, height: 1024}, timezoneId: 'Europe/Vienna'});
  const page = await context.newPage();
  page.setDefaultTimeout(20000);
  await page.route('**/api/commits', async route => {
    report.errors.push('Unexpected order commit attempted by preview-only harness');
    await route.abort('blockedbyclient');
  });
  const active = new Map();
  page.on('pageerror', error => report.errors.push(String(error)));
  page.on('request', request => {
    const url = new URL(request.url());
    if (!url.pathname.includes('/api/')) return;
    const entry = {path: url.pathname, method: request.method(), start: performance.now()};
    if (url.pathname.endsWith('/query')) {
      try { entry.query = request.postDataJSON(); } catch (_) {}
    }
    active.set(request, entry); report.requests.push(entry);
  });
  page.on('response', response => {const entry = active.get(response.request()); if (entry) entry.status = response.status();});
  page.on('requestfinished', request => {const entry = active.get(request); if (entry) {entry.durationMs = Math.round(performance.now() - entry.start); active.delete(request);}});
  page.on('requestfailed', request => {const entry = active.get(request); if (entry) {entry.failure = request.failure()?.errorText; active.delete(request);}});
  const button = name => page.getByRole('button', {name: new RegExp(`^${name}(?:\\s+${name})?$`)});
  const slot = () => page.getByRole('button').filter({hasText: /^12:00–12:30/});
  const body = () => page.locator('body').innerText();
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
  async function readInput(input) {
    await input.click(); await page.waitForTimeout(250);
    return input.inputValue();
  }
  async function enter(input, value) {
    await settle();
    await input.click(); await page.waitForTimeout(250);
    assert.ok(await input.evaluate(element => document.activeElement === element),
      'The requested editor owns focus before changing its value');
    for (let attempt = 0; attempt < 3; attempt++) {
      const length = (await input.inputValue()).length;
      if (!length) break;
      await page.keyboard.press('End'); await page.waitForTimeout(80);
      for (let i = 0; i < length + 4; i++) await page.keyboard.press('Backspace', {delay: 10});
      for (let i = 0; i < length + 4; i++) await page.keyboard.press('Delete', {delay: 10});
      await page.waitForTimeout(100);
    }
    assert.equal(await input.inputValue(), '', 'The editor is empty before replacing its value');
    // A transient validation caption once reordered the web semantics subtree
    // on the first key. Assert real focus and record any focus loss while typing
    // at normal speed; do not repair lost text with retries or DOM value writes.
    if (value === 'No extra salt') {
      assert.ok(await input.evaluate(element => document.activeElement === element),
        'The disclosed Note editor owns focus before typing');
      await input.evaluate(element => {
        window.foodioNoteFocusLosses = [];
        element.addEventListener('focusout', () => {
          window.foodioNoteFocusLosses.push({value: element.value, at: performance.now()});
        }, {once: true});
      });
    }
    if (value) await page.keyboard.type(value, {delay: 60});
    await page.waitForTimeout(100);
    assert.equal(await input.inputValue(), value, 'The real editor retains the complete input');
    if (value === 'No extra salt') {
      const losses = await page.evaluate(() => window.foodioNoteFocusLosses);
      (report.noteTyping ||= []).push({delayMs: 60, value: await input.inputValue(), focusLosses: losses});
      assert.deepEqual(losses, [], 'Validation retains browser focus throughout note typing');
    }
  }
  async function capture(pass, name) {
    await settle();
    await page.mouse.move(8, 8); await page.waitForTimeout(80);
    await page.screenshot({path: path.join(artifacts, `${pass}-${name}.png`)});
    fs.writeFileSync(path.join(artifacts, `${pass}-${name}.txt`), await page.locator('body').ariaSnapshot());
  }
  async function advance(title) {
    await page.getByRole('button').filter({hasText: /^Continue/}).click();
    await page.getByText(title, {exact: true}).waitFor(); await settle();
  }
  async function back(title) {
    await button('Back').click();
    await page.getByText(title, {exact: true}).waitFor(); await settle();
  }
  async function toggleAddress() {
    const label = 'Use a one-time delivery address';
    await settle();
    const grouped = page.getByRole('group', {name: label, exact: true}).getByRole('button');
    if (await grouped.count()) {await grouped.click(); await settle(); return;}
    for (const role of ['switch', 'checkbox', 'button']) {
      const control = page.getByRole(role, {name: label, exact: true});
      if (await control.count()) {await control.click(); await settle(); return;}
    }
    await page.getByText(label, {exact: true}).click(); await settle();
  }
  async function hasText(text, message = text) {
    assert.ok((await body()).includes(text), message);
  }
  try {
    for (const pass of ['cold', 'warm']) {
      const started = performance.now();
      await page.setViewportSize({width: 1440, height: 1024});
      await page.goto(`${base}/#/orders/create`);
      await page.waitForFunction(() => document.querySelector('flt-semantics-placeholder') || document.querySelector('flt-semantics[role]'));
      await page.locator('flt-semantics-placeholder').evaluateAll(elements => elements.forEach(element => element.click()));
      await page.getByText('Who is this order for?', {exact: true}).waitFor();
      const readyMs = Math.round(performance.now() - started);
      await enter(page.getByRole('textbox').first(), 'Lena');
      await page.getByRole('button').filter({hasText: /^Lena Hofer/}).click(); await settle();
      await page.getByRole('button').filter({hasText: /^Private/}).click(); await settle();
      await advance('When and where should it arrive?');
      await hasText('Lena’s home'); await hasText('Kaiserstraße 12/5');
      assert.equal(await page.getByRole('button').filter({hasText: /^HQ Wieden/}).count(), 0);
      assert.equal(await page.getByRole('button').filter({hasText: /^Gabel kitchen/}).count(), 0,
        'Private profiles expose their own location, not every unassigned address');
      await capture(pass, 'private-location');
      await back('Who is this order for?');
      await page.getByRole('button').filter({hasText: /^Nordlicht/}).click(); await settle();
      await advance('When and where should it arrive?');
      await page.getByRole('button').filter({hasText: /^HQ Wieden/}).waitFor();
      await button('Today').click(); await settle();
      await hasText('28 Sep 2026');
      await button('Wednesday').click(); await settle();
      await hasText('30 Sep 2026');
      await slot().click(); await settle();
      await button('Next week').click(); await settle();
      await hasText('5 Oct 2026');
      await hasText('No matching options.');
      await hasText('Delivery not set', 'Changing dates invalidates a previous date’s selected slot');
      await capture(pass, 'next-week');
      await button('Tomorrow').click(); await settle();
      await hasText('29 Sep 2026');
      await slot().click(); await settle();
      await capture(pass, 'company-delivery');
      await page.setViewportSize({width: 1440, height: 1600});
      await page.getByRole('button', {name: 'Expand Deliver to a different address this once', exact: true}).click();
      await toggleAddress();
      const street = page.getByRole('textbox', {name: 'Street and house number', exact: true});
      await street.waitFor();
      assert.equal(await readInput(page.getByRole('textbox', {name: 'Postal code', exact: true})), '1040');
      assert.equal(await readInput(page.getByRole('textbox', {name: 'City', exact: true})), 'Wien');
      await enter(street, overrideStreet);
      const instructions = page.getByRole('textbox', {name: 'Delivery note', exact: true});
      await readInput(instructions);
      assert.equal(await instructions.evaluate(element => element.tagName.toLowerCase()), 'textarea');
      await enter(instructions, note);
      await capture(pass, 'one-time-address');
      await advance('Choose dishes');
      await hasText(overrideStreet, 'The summary previews the explicit shipment address');
      await capture(pass, 'override-preview');
      await back('When and where should it arrive?');
      // The disclosure keeps its state through wizard navigation.
      if (!(await page.getByRole('textbox', {name: 'Street and house number', exact: true}).count())) {
        await page.getByRole('button', {name: 'Expand Deliver to a different address this once', exact: true}).click();
      }
      await toggleAddress();
      assert.equal(await page.getByRole('textbox', {name: 'Street and house number', exact: true}).count(), 0);
      assert.equal(await readInput(instructions), note, 'Turning off the address override preserves the delivery note');
      await advance('Choose dishes');
      await hasText(originalLocation, 'Turning off the override restores the selected location in the summary');
      assert.ok(!(await body()).includes(overrideStreet), 'The disabled override is absent from the shipment preview');
      await page.setViewportSize({width: 1440, height: 1024});
      await capture(pass, 'restored-preview');
      const catalogSearch = page.getByRole('textbox').first();
      await enter(catalogSearch, 'risotto');
      await page.getByText('Beetroot risotto with goat’s cheese', {exact: true}).waitFor();
      const increaseRisotto = page.getByRole('button', {name: /^Increase /});
      await increaseRisotto.waitFor();
      assert.equal(await increaseRisotto.count(), 1, 'The filtered catalog has exactly the requested dish');
      await increaseRisotto.click(); await settle();
      await increaseRisotto.click(); await settle();
      await button('Options').click(); await settle();
      const cheese = page.getByRole('checkbox', {name: /^Extra goat/});
      await cheese.waitFor(); await cheese.click(); await settle();
      assert.equal(await cheese.getAttribute('aria-checked'), 'true');
      await page.getByRole('button', {name: 'Expand Preparation note', exact: true}).click();
      await settle();
      await enter(page.getByRole('textbox', {name: 'Note', exact: true}), 'No extra salt');
      await button('Options').click(); await settle();
      assert.equal(await cheese.count(), 0, 'Collapsed options leave accessibility traversal');
      await button('Options').click(); await settle();
      assert.equal(await cheese.getAttribute('aria-checked'), 'true', 'Extra selection survives collapsing');
      assert.equal(await readInput(page.getByRole('textbox', {name: 'Note', exact: true})), 'No extra salt');
      await hasText('€26.80', 'Two portions include the selected per-portion extra in the shared total');
      await enter(catalogSearch, ''); await settle();
      await capture(pass, 'inline-extras');
      assert.deepEqual(report.errors, []);
      assert.deepEqual(report.requests.filter(request => request.failure || request.status >= 400), []);
      assert.equal(report.requests.filter(request => request.path.endsWith('/commits')).length, 0);
      report.passes.push({pass, readyMs, durationMs: Math.round(performance.now() - started),
        privateLocation: true, dateShortcuts: true, dateInvalidatesSlot: true,
        multilineNote: true, addressOverridePreview: true, addressRestorePreview: true,
        inlineExtrasStaged: true, inlineNoteRetained: true, commits: 0});
      // This disposable browser context owns these local drafts. Clear them so
      // the warm pass begins a new draft while retaining cached web resources.
      await page.evaluate(() => localStorage.clear());
      await page.goto('about:blank');
    }
  } catch (error) {
    report.failure = String(error);
    await capture('failure', 'delivery').catch(() => {});
    throw error;
  } finally {
    report.requests = report.requests.map(({start, ...request}) => request);
    fs.writeFileSync(path.join(artifacts, 'report.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify({artifacts, passes: report.passes, errors: report.errors, failure: report.failure}, null, 2));
    await browser.close();
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
