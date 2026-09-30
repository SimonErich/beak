/**
 * Real Chrome list/filter/export verification, without altering application data.
 * Run: npm exec --yes --package=playwright -- node tool/verify_list.cjs
 * FOODIO_URL defaults to http://127.0.0.1:59389; FOODIO_ARTIFACTS controls output.
 * FOODIO_EXPECT_FILTER_COUNT optionally asserts the seeded fixture count (214).
 */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {performance} = require('node:perf_hooks');
const cli = process.env.PATH.split(path.delimiter)
  .map(p => path.join(p, 'playwright')).find(p => fs.existsSync(p));
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const base = (process.env.FOODIO_URL || 'http://127.0.0.1:59389').replace(/\/$/, '').replace(/#.*$/, '');
const artifacts = process.env.FOODIO_ARTIFACTS || path.join(__dirname, '../.artifacts', `foodio-list-${Date.now()}`);
fs.mkdirSync(artifacts, {recursive: true});
const report = {url: base, passes: []};
const escapeRegex = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const page = await browser.newPage({viewport: {width: 1440, height: 1720}, timezoneId: 'Europe/Vienna', acceptDownloads: true});
  let requests = [], inFlight = new Map(), errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('request', request => {
    if (request.resourceType() !== 'fetch' && request.resourceType() !== 'xhr') return;
    const url = new URL(request.url());
    if (!url.pathname.includes('/api/')) return;
    const entry = {method: request.method(), path: url.pathname, start: performance.now()};
    requests.push(entry); inFlight.set(request, entry);
  });
  page.on('requestfinished', request => {
    const entry = inFlight.get(request); if (!entry) return;
    entry.durationMs = Math.round((performance.now() - entry.start) * 10) / 10;
    inFlight.delete(request);
  });
  page.on('requestfailed', request => {
    const entry = inFlight.get(request); if (!entry) return;
    entry.failure = request.failure()?.errorText; inFlight.delete(request);
  });
  page.on('response', response => {
    const entry = inFlight.get(response.request()); if (entry) entry.status = response.status();
  });
  const button = label => page.getByRole('button', {name: new RegExp(`^${escapeRegex(label)}(?:\\s+${escapeRegex(label)})?$`)});
  const prefix = label => page.getByRole('button', {name: new RegExp(`^${escapeRegex(label)}`)});
  async function checkbox(name, checked) {
    const control = page.getByRole('checkbox', {name, exact: true});
    if (await control.isChecked() !== checked) await control.click();
    await page.getByRole('checkbox', {name, exact: true, checked}).waitFor();
  }
  async function settle() {
    const deadline = performance.now() + 15000;
    let quietAt = performance.now();
    while (performance.now() < deadline) {
      if (inFlight.size) quietAt = performance.now();
      if (!inFlight.size && performance.now() - quietAt > 250) return;
      await page.waitForTimeout(50);
    }
    throw new Error('API requests did not settle within 15 seconds');
  }
  async function semantics() {
    const placeholder = page.locator('flt-semantics-placeholder');
    await placeholder.waitFor({state: 'attached'});
    await placeholder.evaluateAll(elements => elements.forEach(element => element.click()));
  }
  async function waitTable() {
    await prefix('Today · ').waitFor();
    await page.getByRole('button', {name: 'More actions', exact: true}).first().waitFor();
  }
  try {
    for (const pass of ['cold', 'warm']) {
      requests = []; inFlight = new Map(); errors = [];
      await page.setViewportSize({width: 1440, height: 1720});
      const started = performance.now();
      await page.goto(`${base}/?beak_qa=${pass}#/orders`);
      await semantics();
      await waitTable();
      const readyMs = Math.round(performance.now() - started);
      await settle();
      const initialRequests = requests.length;
      const today = await prefix('Today · ').innerText();
      await page.screenshot({path: path.join(artifacts, `${pass}-list.png`)});
      fs.writeFileSync(path.join(artifacts, `${pass}-list.txt`), await page.locator('body').ariaSnapshot());
      await prefix('Needs attention · ').click();
      await settle();
      await page.getByRole('group', {name: 'Show charts', exact: true}).getByRole('button').click();
      await settle();
      const firstRow = page.getByRole('checkbox', {name: 'Select row 1', exact: true});
      const secondRow = page.getByRole('checkbox', {name: 'Select row 2', exact: true});
      await firstRow.focus();
      await page.keyboard.press('Space');
      await page.getByRole('checkbox', {name: 'Select row 1', exact: true, checked: true}).waitFor();
      assert.equal(await firstRow.isChecked(), true, 'Space selects a focused row');
      await secondRow.focus();
      await page.keyboard.press('Enter');
      await page.getByRole('checkbox', {name: 'Select row 2', exact: true, checked: true}).waitFor();
      assert.equal(await secondRow.isChecked(), true, 'Enter selects a focused row');
      await button('Confirm with kitchen').waitFor();
      await button('Accept requested changes').waitFor();
      await page.getByRole('button', {name: 'More actions', exact: true}).nth(2).click();
      await button('View order').waitFor();
      await button('Edit delivery address').waitFor();
      assert.equal(await button('Save changes').count(), 0);
      await page.setViewportSize({width: 1440, height: 1240});
      fs.writeFileSync(path.join(artifacts, `${pass}-attention.txt`), await page.locator('body').ariaSnapshot());
      await page.screenshot({path: path.join(artifacts, `${pass}-attention.png`)});
      const attention = await prefix('Needs attention · ').innerText();
      await page.keyboard.press('Escape');
      const selectedDownload = page.waitForEvent('download');
      await page.getByRole('button', {name: 'Export', exact: true}).last().click();
      const selectedFile = await selectedDownload;
      const selectedPath = path.join(artifacts, `${pass}-selected-orders.csv`);
      await selectedFile.saveAs(selectedPath);
      const selectedCsv = fs.readFileSync(selectedPath, 'utf8');
      assert.equal(selectedCsv.trim().split(/\r?\n/).length, 3, 'Selection export contains only its two selected records plus the header');
      assert.match(selectedCsv, /ORD-24814/);
      assert.match(selectedCsv, /ORD-24810/);
      await checkbox('Select row 1', false);
      await checkbox('Select row 2', false);
      await prefix('Today · ').click();
      await settle();
      await prefix('All filters').click();
      await page.setViewportSize({width: 1440, height: 1000});
      await prefix('Delivery date ≤').click();
      await page.getByRole('button', {name: '29', exact: true}).click();
      await page.getByRole('button', {name: 'OK', exact: true}).click();
      for (const label of ['Confirmed', 'In kitchen', 'Needs attention', 'Company invoice', 'Subsidy + card']) {
        await checkbox(label, true);
      }
      await page.getByRole('radio', {name: 'Company profiles', exact: true}).click();
      await page.getByRole('button', {name: /^Organization/}).last().click();
      // The select search mounts asynchronously after the overlay animation.
      // Waiting for its own textbox avoids filling the underlying table search.
      await page.getByRole('textbox', {name: 'Search…', exact: true}).waitFor();
      // The placeholder label disappears while typing. After the overlay's
      // own input mounts it remains the final textbox, after both shell and
      // table searches; never target a pre-existing input by a fixed index.
      const organization = page.getByRole('textbox').last();
      for (const label of ['Nordlicht Energie GmbH', 'Kessler Logistik GmbH']) {
        await organization.fill(label);
        await page.getByText(label, {exact: true}).last().click();
      }
      await page.keyboard.press('Escape');
      assert.equal(await page.getByRole('textbox', {
        name: /Search by order, customer, company or phone/,
      }).inputValue(), '', 'Organization lookup does not alter table search');
      for (const label of ['11:30–12:00', '12:00–12:30']) {
        await button(label).click();
      }
      await settle();
      const apply = page.getByRole('button').filter({hasText: /^Show \d+ orders/});
      const count = Number((await apply.innerText()).match(/Show (\d+) orders/)[1]);
      if (process.env.FOODIO_EXPECT_FILTER_COUNT) assert.equal(count, Number(process.env.FOODIO_EXPECT_FILTER_COUNT));
      await page.screenshot({path: path.join(artifacts, `${pass}-filters.png`)});
      await page.getByRole('button', {name: 'Remove Nordlicht Energie GmbH', exact: true}).click();
      await page.getByRole('button', {name: 'Remove Kessler Logistik GmbH', exact: true}).waitFor();
      assert.equal(await page.getByRole('textbox', {name: 'Search…', exact: true}).count(), 0, 'Removing a tag does not open the lookup');
      await page.getByRole('button', {name: 'Add organization', exact: true}).click();
      await page.getByRole('textbox', {name: 'Search…', exact: true}).waitFor();
      await page.getByRole('textbox').last().fill('Nordlicht Energie GmbH');
      await page.getByRole('textbox').last().press('ArrowDown');
      await page.getByRole('textbox').last().press('ArrowUp');
      await page.getByRole('textbox').last().press('Enter');
      await settle();
      await page.keyboard.press('Escape');
      await page.getByRole('textbox', {name: 'Search…', exact: true}).waitFor({state: 'hidden'});
      await prefix('More filters').click();
      // Flutter's scroll container must reveal the actual editor before a
      // semantic-input click; browser DOM scrolling cannot move its canvas.
      await page.mouse.move(1320, 800);
      await page.mouse.wheel(0, 400);
      await page.waitForTimeout(250);
      const amount = page.getByRole('textbox', {name: /^Order value from/});
      await amount.click();
      await page.waitForTimeout(150);
      await page.keyboard.press('ControlOrMeta+A');
      await page.keyboard.type('40.25');
      await page.keyboard.press('Tab');
      assert.equal(await amount.inputValue(), '40.25', 'Currency input retains its committed amount');
      await settle();
      await page.screenshot({path: path.join(artifacts, `${pass}-advanced-filters.png`)});
      await amount.click();
      await page.waitForTimeout(150);
      await page.keyboard.press('ControlOrMeta+A');
      await page.keyboard.press('Backspace');
      await page.keyboard.press('Tab');
      assert.equal(await amount.inputValue(), '', 'Clearing the visible editor removes the amount');
      await prefix('More filters').click();
      await settle();
      assert.match(await apply.innerText(), new RegExp(`Show ${count} orders`), 'Clearing the amount restores the staged population');
      await apply.click();
      await settle();
      assert.match(page.url(), /list=/, 'Applied filters persist in the URL');
      await prefix('All filters').click();
      await settle();
      assert.match(await page.getByRole('button').filter({hasText: /^Show \d+ orders/}).innerText(), new RegExp(`Show ${count} orders`));
      await page.getByRole('button', {name: 'Close', exact: true}).click();
      const download = page.waitForEvent('download');
      await button('Export').click();
      const file = await download;
      const csvPath = path.join(artifacts, `${pass}-orders.csv`);
      await file.saveAs(csvPath);
      assert.equal(await file.failure(), null);
      const csv = fs.readFileSync(csvPath, 'utf8');
      assert.match(csv, /^Reference,/);
      assert.match(csv, /€\d/, 'Currency projection formats minor units');
      await settle();
      assert.deepEqual(errors, [], 'No browser runtime errors');
      assert.deepEqual(requests.filter(request => request.failure || request.status >= 400), [], 'No failed API requests');
      report.passes.push({pass, readyMs, initialRequests, requestCount: requests.length, today, attention, filterCount: count,
        requests: requests.map(({start, ...entry}) => entry)});
      await page.setViewportSize({width: 1440, height: 1720});
    }
  } catch (error) {
    fs.writeFileSync(path.join(artifacts, 'failure.txt'), await page.locator('body').ariaSnapshot());
    await page.screenshot({path: path.join(artifacts, 'failure.png')});
    throw error;
  } finally {
    fs.writeFileSync(path.join(artifacts, 'report.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify({artifacts, passes: report.passes.map(({requests, ...pass}) => pass)}, null, 2));
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
