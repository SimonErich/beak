/**
 * Real Chrome edit regression over ORD-24817. Adds a €4.50 soup and changes
 * delivery to noon, then removes the soup and restores the original slot.
 * Retains the corrected contact phone and audit trail; verifies atomic edit notes
 * and standalone inline notes with immediate refresh and a hard reload.
 * No external provider is contacted.
 * Run: npm exec --yes --package=playwright -- node tool/verify_edit.cjs
 */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {performance} = require('node:perf_hooks');
const {createHash} = require('node:crypto');
const cli = process.env.PATH.split(path.delimiter).map(p => path.join(p, 'playwright')).find(fs.existsSync);
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const base = (process.env.FOODIO_URL || 'http://127.0.0.1:59389').replace(/\/$/, '').replace(/#.*$/, '');
const artifacts = process.env.FOODIO_ARTIFACTS || path.join(__dirname, '../.artifacts', `foodio-edit-${Date.now()}`);
fs.mkdirSync(artifacts, {recursive: true});
const id = 'ord_3f9c24817b';
const soup = 'Pumpkin soup with seed oil';
const restoreOnly = process.env.FOODIO_EDIT_RESTORE_ONLY === '1';
const noteOnly = process.env.FOODIO_EDIT_NOTE_ONLY === '1';
const report = {url: base, passes: [], errors: [], requests: []};

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const page = await browser.newPage({viewport: {width: 1440, height: 1720}, timezoneId: 'Europe/Vienna'});
  if (process.env.FOODIO_API_OVERRIDE) {
    const apiOrigin = new URL(process.env.FOODIO_API_OVERRIDE).origin;
    await page.route('http://127.0.0.1:8081/**', route => {
      const url = new URL(route.request().url());
      return route.continue({url: apiOrigin + url.pathname + url.search});
    });
  }
  page.setDefaultTimeout(20000);
  const active = new Map();
  page.on('pageerror', error => report.errors.push(String(error)));
  page.on('request', request => {
    const url = new URL(request.url());
    if (!url.pathname.includes('/api/')) return;
    const requestSignature = createHash('sha256').update(request.method() + '\n' + request.url() + '\n' + (request.postData() || '')).digest('hex');
    const entry = {path: url.pathname, method: request.method(), requestSignature, start: performance.now()};
    active.set(request, entry); report.requests.push(entry);
  });
  page.on('response', response => {const entry = active.get(response.request()); if (entry) entry.status = response.status();});
  page.on('requestfinished', request => {const entry = active.get(request); if (entry) {entry.durationMs = Math.round(performance.now() - entry.start); active.delete(request);}});
  page.on('requestfailed', request => {const entry = active.get(request); if (entry) {entry.failure = request.failure()?.errorText; active.delete(request);}});
  const button = name => page.getByRole('button', {name: new RegExp(`^${name}(?:\\s+${name})?$`)});
  const disclosure = name => page.getByRole('button', {name: new RegExp(`^(?:(?:Expand|Collapse) )?${name}(?: ${name})?$`)});
  async function settle() {
    const deadline = performance.now() + 15000;
    let quiet = performance.now();
    while (performance.now() < deadline) {
      if (active.size) quiet = performance.now();
      if (!active.size && performance.now() - quiet > 400) return;
      await page.waitForTimeout(50);
    }
    throw new Error('Requests did not settle');
  }
  async function open(edit = false) {
    const target = `${base}/#/orders/${id}${edit ? '/edit' : ''}`;
    if (page.url() === target) await page.reload(); else await page.goto(target);
    await page.waitForFunction(() => document.querySelector('flt-semantics-placeholder') || document.querySelector('flt-semantics[role]'));
    await page.locator('flt-semantics-placeholder').evaluateAll(elements => elements.forEach(element => element.click()));
    await button(edit ? 'Save changes' : 'Edit(?: order)?').waitFor(); await settle();
  }
  async function enter(input, value) {
    // Accessibility text fields are the active browser editors in this Flutter
    // build; tapping their painted surface does not necessarily focus the DOM.
    await input.focus();
    await input.evaluate(editor => {
      if (document.activeElement !== editor) throw new Error('Editor did not receive browser focus');
    });
    await input.fill(value);
    await input.blur();
    await settle();
    assert.equal(await input.inputValue(), value, 'Text replacement survives the Flutter semantics refresh');
  }
  async function capture(name) {
    await settle();
    await page.mouse.move(800, 450); await page.mouse.wheel(0, -4000);
    await page.mouse.move(4, 4);
    await page.waitForTimeout(150);
    await page.screenshot({path: path.join(artifacts, name + '.png')});
    fs.writeFileSync(path.join(artifacts, name + '.txt'), await page.locator('body').ariaSnapshot());
  }
  async function selectSlot(label) {
    await page.getByRole('button', {name: /^Slot(?:\s|$)/}).click();
    await page.getByText(label, {exact: true}).click(); await settle();
  }
  async function save(expectedCents, expectedNote) {
    const started = performance.now();
    const [response] = await Promise.all([
      page.waitForResponse(response => response.url().endsWith('/commits'), {timeout: 45000}),
      button('Save changes').first().click(),
    ]);
    const submitted = response.request().postDataJSON();
    assert.equal(submitted.action, 'amend', 'Edits use one atomic domain command');
    if (expectedNote) assert.equal(submitted.arguments.values.body, expectedNote);
    const payload = await response.json();
    assert.ok(payload.outcomes.every(outcome => outcome.status === 'applied'), JSON.stringify(payload));
    const root = payload.outcomes.find(outcome => outcome.id === payload.rootOperationId);
    assert.equal(root.record.values.gross_cents, expectedCents);
    assert.equal(root.record.values.contact_phone, '+436642184471');
    // The applied HTTP receipt precedes client-side authoritative hydration.
    // Wait for the completed read state before navigating or measuring completion.
    await button('Edit(?: order)?').waitFor({timeout: 45000});
    await settle();
    return {durationMs: Math.round(performance.now() - started), payload};
  }
  try {
    let started = performance.now();
    if (!restoreOnly && !noteOnly) {
      await open(true);
      const readyMs = Math.round(performance.now() - started);
      assert.equal(await page.getByRole('button', {name: `Remove ${soup}`, exact: true}).count(), 0, 'Run against the reference baseline');
      await capture('cold-baseline');
      await page.getByRole('button', {name: /^(?:Options for Beetroot|(?:Expand|Collapse) Options)/}).first().click();
      await disclosure('Preparation note').first().click();
      const note = page.getByRole('textbox', {name: 'Note', exact: true}).first();
      await note.click(); await page.waitForTimeout(100);
      const originalNote = await note.inputValue();
      await enter(note, 'THIS CANCELLED EDIT MUST NOT BE SAVED');
      await button('Cancel').click();
      await button('Discard changes').click();
      await open(true);
      await page.getByRole('button', {name: /^(?:Options for Beetroot|(?:Expand|Collapse) Options)/}).first().click();
      await disclosure('Preparation note').first().click();
      assert.equal(await note.inputValue(), originalNote, 'Cancelling the owner form discards inline row changes');
      await page.getByRole('button', {name: /^(?:Options for Beetroot|(?:Expand|Collapse) Options)/}).first().click();
      // New-row dialogs retain their own checkpoint and may be cancelled without
      // leaving the owner form or retaining a blank collection row.
      await page.getByRole('button', {name: /^Add a dish(?:\s|$)/}).click();
      await page.getByRole('button', {name: /^Dish(?:\s|$)/}).click();
      await page.getByText(soup, {exact: true}).click();
      await button('Cancel').last().click();
      await button('Apply').waitFor({state: 'hidden'});
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      await page.getByRole('button', {name: `Remove ${soup}`, exact: true}).waitFor({state: 'hidden'});
      await settle();
      assert.equal(await page.getByRole('button', {name: `Remove ${soup}`, exact: true}).isVisible(), false);
      assert.match(await page.locator('body').innerText(), /€31\.40/, 'Cancelling a new row restores the original basket total');
      await enter(page.getByRole('textbox', {name: 'Contact phone on arrival', exact: true}), '+436642184471');
      await page.getByRole('button', {name: /^Add a dish(?:\s|$)/}).click();
      await page.getByRole('button', {name: /^Dish(?:\s|$)/}).click();
      await page.getByText(soup, {exact: true}).click();
      await page.getByRole('button', {name: /^Size(?:\s|$)/}).last().click();
      await page.getByText(/^Cup(?: \(\d+ g\))?$/).click();
      await page.getByRole('button', {name: 'Increase quantity', exact: true}).last().click();
      await page.getByRole('button', {name: 'Decrease quantity', exact: true}).last().click();
      await button('Apply').click(); await settle();
      await selectSlot('12:00–12:30');
      assert.match(await page.locator('body').innerText(), /€35\.90/);
      assert.match(await page.locator('body').innerText(), /€52\.10/);
      const editNote = `Atomic edit verification ${Date.now()}: soup and slot changed together.`;
      await enter(page.getByRole('textbox', {name: 'New internal note', exact: true}), editNote);
      await capture('cold-preview');
      if (process.env.FOODIO_EDIT_PREVIEW_ONLY === '1') {
        assert.equal(report.requests.filter(request => request.path.endsWith('/commits')).length, 0);
        report.preview = {cancelledOwnerEdit: true, cancelledNewRow: true, stagedOnly: true};
        return;
      }
      const added = await save(3590, editNote);
      fs.writeFileSync(path.join(artifacts, 'cold-commit.json'), JSON.stringify(added.payload, null, 2));
      await open();
      assert.match(await page.locator('body').innerText(), /€35\.90/);
      assert.match(await page.locator('body').innerText(), /€52\.10/);
      assert.ok((await page.locator('body').innerText()).includes(editNote), 'Amend saves the inline note with the order');
      await capture('cold-saved');
      report.passes.push({pass: 'cold-add', readyMs, saveMs: added.durationMs, totalCents: 3590, budgetLeftCents: 5210, inlineOwnerCancel: true, newRowCancel: true, quantityStepper: true, atomicInlineNote: true});
    }

    if (!noteOnly) {
      started = performance.now(); await open(true);
      const warmReadyMs = Math.round(performance.now() - started);
      await page.getByRole('button', {name: `Remove ${soup}`, exact: true}).click(); await settle();
      await selectSlot('11:30–12:00');
      const removed = await save(3140);
      fs.writeFileSync(path.join(artifacts, 'warm-commit.json'), JSON.stringify(removed.payload, null, 2));
      await open();
      assert.match(await page.locator('body').innerText(), /€31\.40/);
      assert.match(await page.locator('body').innerText(), /€56\.60/);
      await capture('warm-restored');
      report.passes.push({pass: 'warm-remove', readyMs: warmReadyMs, saveMs: removed.durationMs, totalCents: 3140, budgetLeftCents: 5660});
    } else { await open(); }
    const internalNote = process.env.FOODIO_EDIT_NOTE || 'Chrome verification: delivery slot and soup edit checked; original basket restored.';
    await enter(page.getByRole('textbox', {name: 'New internal note', exact: true}), internalNote);
    started = performance.now();
    const [noteResponse] = await Promise.all([
      page.waitForResponse(response => response.url().endsWith('/commits'), {timeout: 45000}),
      button('Add note').click(),
    ]);
    assert.equal(noteResponse.request().postDataJSON().action, 'addNote');
    const noteResult = await noteResponse.json();
    assert.ok(noteResult.outcomes.every(outcome => outcome.status === 'applied'), JSON.stringify(noteResult));
    const noteMs = Math.round(performance.now() - started);
    await settle();
    assert.ok((await page.locator('body').innerText()).includes(internalNote), 'In-place commands refresh their visible relationship data');
    await capture('warm-note-immediate');
    await open();
    assert.ok((await page.locator('body').innerText()).includes(internalNote), 'Server-authored note survives navigation/reload');
    await capture('warm-note');
    report.note = {saved: true, immediateRefresh: true, hardReload: true, durationMs: noteMs};
    await capture('final-detail');
    await open(true); await capture('final-edit');
    assert.deepEqual(report.errors, []);
    assert.deepEqual(report.requests.filter(request => request.failure || request.status >= 400), []);
  } catch (error) {
    report.failure = String(error);
    await capture('failure').catch(() => {});
    throw error;
  } finally {
    report.requests = report.requests.map(({start, ...request}) => request);
    fs.writeFileSync(path.join(artifacts, 'report.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify({artifacts, passes: report.passes, note: report.note, failure: report.failure}, null, 2));
    await browser.close();
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
