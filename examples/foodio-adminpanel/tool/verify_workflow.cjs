/**
 * Runs the seeded order scenario twice in real Chrome, then cancels each order
 * through the UI to release its budget/capacity reservation. Audit history and
 * local demo messages remain visible. No real payment or email is sent.
 * Run: npm exec --yes --package=playwright -- node tool/verify_workflow.cjs
 * FOODIO_URL and FOODIO_ARTIFACTS configure the app and evidence directory.
 */
const fs = require('node:fs');
const {stableScreenshot} = require('./capture_observer.cjs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {performance} = require('node:perf_hooks');
const {createHash} = require('node:crypto');
const cli = process.env.PATH.split(path.delimiter).map(p => path.join(p, 'playwright')).find(fs.existsSync);
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const base = (process.env.FOODIO_URL || 'http://127.0.0.1:59389').replace(/\/$/, '').replace(/#.*$/, '');
const artifacts = process.env.FOODIO_ARTIFACTS || path.join(__dirname, '../.artifacts', `foodio-workflow-${Date.now()}`);
fs.mkdirSync(artifacts, {recursive: true});
const report = {url: base, passes: []};

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const context = await browser.newContext({viewport: {width: 1440, height: 1024}, timezoneId: 'Europe/Vienna'});
  if (process.env.FOODIO_API_OVERRIDE) {
    const override = new URL(process.env.FOODIO_API_OVERRIDE).origin;
    await context.route('http://127.0.0.1:8081/**', route => {
      const url = new URL(route.request().url());
      return route.continue({url: `${override}${url.pathname}${url.search}`});
    });
  }
  const page = await context.newPage();
  page.setDefaultTimeout(20000);
  let errors = [], requests = [], active = new Map();
  page.on('pageerror', error => errors.push(String(error)));
  page.on('request', request => {
    const url = new URL(request.url());
    if (!url.pathname.includes('/api/')) return;
    const requestSignature = createHash('sha256').update(request.method() + '\n' + request.url() + '\n' + (request.postData() || '')).digest('hex');
    const entry = {path: url.pathname, method: request.method(), requestSignature, start: performance.now()};
    if (request.method() === 'POST' && url.pathname.endsWith('/query')) { try {
      const query = request.postDataJSON();
      entry.searchTerm = query?.search?.term;
      entry.perPage = query?.pagination?.perPage;
    } catch (_) {} }
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
    await input.click(); await page.waitForTimeout(100);
    // Real editing keys keep Flutter's engine selection and semantics proxy in
    // sync even when browser select-all does not reach the engine.
    const length = (await input.inputValue()).length;
    for (let i = 0; i < length; i++) await page.keyboard.press('Backspace');
    for (let i = 0; i < length; i++) await page.keyboard.press('Delete');
    if (value) await page.keyboard.type(value, {delay: 15});
    await page.waitForTimeout(100);
    assert.equal(await input.inputValue(), value);
  }
  async function capture(pass, name) {
    const heading = page.getByRole('heading').first();
    if (await heading.count()) await heading.click();
    await page.locator('input:focus, textarea:focus').evaluateAll(editors => editors.forEach(editor => editor.blur()));
    await page.mouse.move(800, 450);
    await page.mouse.wheel(0, -5000);
    await page.mouse.move(4, 4);
    await settle();
    await page.waitForTimeout(300);
    await settle();
    const readBounds = () => page.locator('flt-semantics').evaluateAll(elements =>
      elements.map(element => {
        const r = element.getBoundingClientRect();
        return {text: element.getAttribute('aria-label') || element.innerText,
          role: element.getAttribute('role'), x:r.x, y:r.y, width:r.width, height:r.height};
      }).filter(element => element.text && element.width && element.height));
    await stableScreenshot({page, readBounds,
      boundsPath: path.join(artifacts, `${pass}-${name}-bounds.json`),
      screenshotPath: path.join(artifacts, `${pass}-${name}.png`)});
  }
  async function advance(title) {
    await page.getByRole('button').filter({hasText: /^Continue/}).click();
    await page.getByText(title, {exact: true}).waitFor(); await settle();
  }
  async function commit(label) {
    const response = page.waitForResponse(response => response.url().endsWith('/commits'));
    const start = performance.now();
    await button(label).click();
    const payload = await (await response).json();
    const root = payload.outcomes.find(outcome => outcome.id === payload.rootOperationId);
    assert.equal(root?.status, 'applied', JSON.stringify(payload));
    assert.ok(payload.outcomes.every(outcome => outcome.status === 'applied'), 'Atomic graph applied completely');
    return {payload, root, durationMs: Math.round(performance.now() - start)};
  }
  try {
    for (const pass of ['cold', 'warm']) {
      errors = []; requests = []; active = new Map();
      const started = performance.now();
      await page.setViewportSize({width: 1440, height: 1024});
      await open('/orders/create');
      await page.getByText('Who is this order for?', {exact: true}).waitFor();
      if (await button('Discard saved draft').count()) {
        await button('Discard saved draft').click();
        await settle();
      }
      const readyMs = Math.round(performance.now() - started);
      await enter(page.getByRole('textbox').first(), 'Lena');
      await page.getByRole('button').filter({hasText: /^Lena Hofer/}).click();
      await settle();
      await capture(pass, 'customer');
      await advance('When and where should it arrive?');
      await page.getByRole('button').filter({hasText: /^12:00–12:30/}).click();
      await enter(page.getByRole('textbox', {name: /^Delivery note$/i}),
        'Team meeting in room 3.14 – please bring cutlery for four.');
      await capture(pass, 'delivery');
      await advance('Choose dishes');
      for (const [term, quantity, dish] of [['risotto', 2, 'Beetroot risotto with goat’s cheese'], ['lentil', 1, 'Red lentil dal with basmati rice'], ['schnitzel', 1, 'Pork schnitzel with parsley potatoes']]) {
        await enter(page.getByRole('textbox').first(), term);
        await page.waitForTimeout(250); await settle();
        await page.getByText(dish, {exact: true}).waitFor();
        const increase = page.getByRole('button', {name: /Increase .*Regular/});
        assert.equal(await increase.count(), 1, `${term} searches the related dish identity`);
        for (let i = 0; i < quantity; i++) { await increase.click(); await settle(); }
      }
      await enter(page.getByRole('textbox').first(), '');
      const optionLink = page.getByRole('button', {name: /^Options for Beetroot/});
      await optionLink.last().waitFor({state: 'visible'});
      await optionLink.last().click(); await settle();
      await page.getByRole('checkbox', {name: /Extra goat’s cheese/i}).first().waitFor({state: 'visible'});
      await capture(pass, 'dishes');
      assert.match(await page.locator('body').innerText(), /€48\.60/);
      // These facets hide catalog choices, while selected dishes remain in the
      // separate summary. Check interactive catalog controls rather than names
      // that intentionally still appear in the summary.
      await page.getByRole('button', {name: 'All dishes', exact: true}).click(); await settle();
      assert.ok((await page.getByRole('button', {name: /Increase /}).count()) >= 6, 'All dishes removes the menu-plan filter');
      await page.getByRole('button', {name: 'Menu plan', exact: true}).click(); await settle();
      const regularVariants = page.getByRole('button', {name: /Increase .*Regular/});
      assert.equal(await regularVariants.count(), 3);
      const catalogBeforeFacets = requests.filter(request => request.path.endsWith('/dish_variants/query') && request.perPage === 200);
      const catalogQueries = catalogBeforeFacets.length;
      const catalogSignature = catalogBeforeFacets.at(-1)?.requestSignature;
      assert.ok(catalogQueries > 0, 'Bounded catalog query was observed before local facet checks');
      async function facet(name, checked) {
        await page.getByRole('button', {name, exact: true}).click();
        await settle();
      }
      await facet('Without A · gluten', true);
      assert.equal(await regularVariants.count(), 2, 'Gluten facet hides schnitzel while preserving risotto and dal');
      await facet('Without G · milk', true);
      assert.equal(await regularVariants.count(), 1, 'Milk facet also hides risotto while preserving dal');
      await capture(pass, 'dishes-filtered');
      assert.match(await page.locator('body').innerText(), /€48\.60/, 'Hiding choices preserves staged dishes and quantities');
      await facet('Without A · gluten', false);
      await facet('Without G · milk', false);
      assert.equal(await regularVariants.count(), 3);
      const extraCatalogQueries = requests.filter(request => request.path.endsWith('/dish_variants/query') && request.perPage === 200).slice(catalogQueries);
      for (const query of extraCatalogQueries) {
        const refreshResources = new Set(requests.filter(request =>
          Math.abs(request.start - query.start) < 1500 &&
          /\/(?:customers|delivery_profiles|delivery_slots|delivery_locations)\/query$/.test(request.path)
        ).map(request => request.path));
        assert.ok(query.requestSignature === catalogSignature && refreshResources.size >= 3,
          'Local facets cannot fetch a changed catalog; an identical query is allowed only in a proven scheduled multi-resource refresh wave');
        query.classification = 'scheduled form refresh';
      }
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
      await button('Back').click(); await settle();
      assert.match(await page.locator('body').innerText(), /€41\.31/, 'Going back keeps the same staged graph');
      await advance('How is it paid?');
      await advance('Check and place the order');
      const preview = await page.locator('body').innerText();
      for (const amount of ['€48.60', '-€7.29', '€37.55', '€3.76', '€41.31']) assert.ok(preview.includes(amount), amount);
      await capture(pass, 'review');
      if (process.env.FOODIO_PREVIEW_ONLY === '1') {
        assert.deepEqual(errors, [], 'No browser runtime errors');
        assert.equal(requests.filter(request => request.path.endsWith('/commits')).length, 0);
        report.passes.push({pass, readyMs, previewOnly: true, requests: requests.map(({start, ...request}) => request)});
        await page.goto('about:blank');
        continue;
      }
      await page.getByRole('button', {name: /^Edit Customer & profile/}).click();
      await page.getByText('Who is this order for?', {exact:true}).waitFor();
      for (const title of ['When and where should it arrive?', 'Choose dishes', 'How is it paid?', 'Check and place the order']) await advance(title);
      assert.match(await page.locator('body').innerText(), /€41\.31/, 'Review Edit preserves the complete draft');
      const place = await commit('Place order');
      const stored = place.root.record.values;
      assert.equal(stored.gross_cents, 4131);
      assert.equal(stored.net_cents, 3755);
      assert.equal(stored.approval_status, 'pending');
      assert.equal(requests.filter(request => request.path.endsWith('/commits')).length, 1, 'One final save for every step');
      const id = place.root.resolvedId;
      fs.writeFileSync(path.join(artifacts, `${pass}-created.json`), JSON.stringify({id, reference: stored.reference, totalCents: stored.gross_cents}, null, 2));
      await open(`/orders/${id}`);
      await button('Edit(?: order)?').waitFor(); await settle();
      await page.setViewportSize({width: 1440, height: 1720});
      await capture(pass, 'placed');
      await page.getByRole('button').filter({hasText: /^More actions/}).click();
      await button('Cancel order').click();
      await page.getByText('Apply this action to the record?', {exact: true}).waitFor();
      const cancel = await commit('Cancel order');
      assert.equal(cancel.root.record.values.status, 'cancelled');
      await settle();
      await capture(pass, 'cancelled');
      assert.deepEqual(errors, [], 'No browser runtime errors');
      assert.deepEqual(requests.filter(request => request.failure), [], 'No network failures');
      assert.deepEqual(requests.filter(request => request.status >= 400), [], 'No failed API responses');
      report.passes.push({pass, readyMs, placeMs: place.durationMs, cancelMs: cancel.durationMs, orderId: id,
        reference: stored.reference, totalCents: stored.gross_cents, requestCount: requests.length,
        requests: requests.map(({start, ...request}) => request)});
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
