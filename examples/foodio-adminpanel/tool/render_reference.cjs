/**
 * Renders extracted prototype states with their embedded fonts in real Chrome.
 * Run extract_reference.py first, then:
 * npm exec --yes --package=playwright -- node tool/render_reference.cjs
 * FOODIO_REFERENCE selects a folder containing reference-0.html through -9.html.
 */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {pathToFileURL} = require('node:url');
const cli = process.env.PATH.split(path.delimiter)
  .map(p => path.join(p, 'playwright')).find(p => fs.existsSync(p));
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const directory = process.env.FOODIO_REFERENCE || path.join(__dirname, '../.artifacts/reference');

(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const page = await browser.newPage({timezoneId: 'Europe/Vienna'});
  const report = [];
  try {
    for (let state = 0; state < 10; state++) {
      const height = [0, 3, 4].includes(state) ? 1720 : state === 1 ? 1240 : state === 2 ? 1000 : 1024;
      await page.setViewportSize({width: 1440, height});
      await page.goto(pathToFileURL(path.join(directory, `reference-${state}.html`)).href);
      assert.equal(await page.locator('sc-if, sc-raw-table, sc-raw-select').count(), 0, 'Bundler elements are restored before capture');
      const fonts = await page.evaluate(async () => {
        await document.fonts.ready;
        return {status: document.fonts.status, faces: Array.from(document.fonts, face => ({family: face.family, status: face.status}))};
      });
      assert.equal(fonts.status, 'loaded');
      assert.ok(fonts.faces.some(face => /Mona/i.test(face.family) && face.status === 'loaded'), `State ${state} loads Mona Sans`);
      assert.ok(fonts.faces.every(face => face.status !== 'error'), `State ${state} has no failed fonts`);
      await page.screenshot({path: path.join(directory, `reference-${state}.png`)});
      report.push({state, viewport: {width: 1440, height}, fonts});
    }
  } finally {
    fs.writeFileSync(path.join(directory, 'render-report.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify({directory, states: report.length}, null, 2));
    await browser.close();
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
