/**
 * Verifies real local draft resume/discard at 390px and 320px in Chrome.
 * Saves only the browser-local draft; no order or server commit is made.
 * Run: npm exec --yes --package=playwright -- node tool/verify_drafts_mobile.cjs
 * FOODIO_URL and FOODIO_ARTIFACTS configure the app and evidence directory.
 */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {performance} = require('node:perf_hooks');
const cli = process.env.PATH.split(path.delimiter).map(p => path.join(p, 'playwright')).find(fs.existsSync);
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const base = (process.env.FOODIO_URL || 'http://127.0.0.1:59389').replace(/\/$/, '').replace(/#.*$/, '');
const artifacts = process.env.FOODIO_ARTIFACTS || path.join(__dirname, '../.artifacts', `foodio-mobile-drafts-${Date.now()}`);
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
  async function closeSummary() {
    const close = page.getByRole('button', {name: 'Close Summary', exact: true});
    const bounds = await close.boundingBox();
    assert.ok(bounds && bounds.y >= 0 && bounds.y + bounds.height <= 844,
      'The summary exposes its close action inside the mobile viewport');
    await close.click();
    await close.waitFor({state: 'hidden'});
  }
  try {
    await open('/orders/create');
    await page.getByText('Who is this order for?', {exact: true}).waitFor();
    await enter(page.getByRole('textbox').first(), 'Lena');
    await page.getByRole('button').filter({hasText: /^Lena Hofer/}).click();
    await settle();
    await page.getByRole('button', {name:'Save draft', exact:true}).click();
    await settle();
    for (const [width, action] of [[390, 'Resume draft'], [320, 'Discard saved draft']]) {
      await page.setViewportSize({width, height:844});
      const started = performance.now();
      await page.goto('about:blank');
      await open('/orders/create');
      await page.getByText('An unfinished draft is available', {exact:true}).waitFor();
      await settle();
      const bounds = {};
      for (const label of ['Resume draft', 'Discard saved draft']) {
        const button = page.getByRole('button', {name:label, exact:true});
        bounds[label] = await button.boundingBox();
        assert.ok(bounds[label] && bounds[label].x >= 0 &&
          bounds[label].x + bounds[label].width <= width - 24,
          `${label} stays inside the narrow form`);
      }
      assert.ok(bounds['Discard saved draft'].y >=
        bounds['Resume draft'].y + bounds['Resume draft'].height,
        'The two draft actions wrap instead of clipping their labels');
      await capture(String(width), 'prompt');
      await page.getByRole('button', {name:action, exact:true}).click();
      await settle();
      await page.getByText('An unfinished draft is available', {exact:true}).waitFor({state:'hidden'});
      if (action === 'Resume draft') {
        assert.match(await page.locator('body').innerText(), /Lena Hofer/);
        await page.getByRole('button', {name:'Summary', exact:true}).click();
        await settle();
        await capture(String(width), 'resumed-summary');
        await closeSummary();
        await page.getByRole('button', {name:'Save draft', exact:true}).click();
        await settle();
      } else {
        await page.goto('about:blank');
        await open('/orders/create');
        await page.getByText('Who is this order for?', {exact:true}).waitFor();
        await settle();
        assert.equal(await page.getByText('An unfinished draft is available', {exact:true}).count(), 0,
          'Discard removes the persisted local draft across reloads');
      }
      await capture(String(width), 'completed');
      report.passes.push({width, action, durationMs: Math.round(performance.now()-started), bounds});
    }
    assert.deepEqual(errors, [], 'No browser runtime errors');
    assert.deepEqual(requests.filter(request => request.failure), [], 'No network failures');
    assert.deepEqual(requests.filter(request => request.status >= 400), [], 'No failed API responses');
    assert.equal(requests.filter(request => request.path.endsWith('/commits')).length, 0,
      'Draft verification performs no server commits');
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
