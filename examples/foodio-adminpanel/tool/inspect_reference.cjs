/** Captures computed prototype geometry and typography for repeatable review. */
const fs = require('node:fs');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const cli = process.env.PATH.split(path.delimiter)
  .map(p => path.join(p, 'playwright')).find(p => fs.existsSync(p));
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const directory = process.env.FOODIO_REFERENCE || path.join(__dirname, '../.artifacts/reference');
(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  try {
    const page = await browser.newPage();
    const report = [];
    for (const state of [0, 1, 2]) {
      await page.setViewportSize({width: 1440, height: [1720, 1240, 1000][state]});
      await page.goto(pathToFileURL(path.join(directory, `reference-${state}.html`)).href);
      await page.evaluate(() => document.fonts.ready);
      const elements = await page.evaluate(() => {
        const names = /^(Orders|412|2|Today|All filters|Delivery date|Status|Delivery slot|Payment method|Rows per page|Showing 1–15 of 412|Showing 1–7 of 7|Confirmed|Company profiles|Custom|Clear all|15)$/;
        function measure(element) {
          const style = getComputedStyle(element), bounds = element.getBoundingClientRect();
          return {
            tag: element.tagName, text: element.textContent.trim().replace(/\s+/g, ' ').slice(0, 90),
            bounds: {x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height},
            font: {family: style.fontFamily, size: style.fontSize, weight: style.fontWeight, lineHeight: style.lineHeight, spacing: style.letterSpacing},
            color: style.color, background: style.backgroundColor, border: style.border,
            radius: style.borderRadius, padding: style.padding, gap: style.gap,
          };
        }
        return [...document.querySelectorAll('body *')]
          .filter(e => e.children.length === 0 && names.test(e.textContent.trim()) && e.getBoundingClientRect().width)
          .map(e => ({element: measure(e), parent: measure(e.parentElement)}));
      });
      report.push({state, elements});
    }
    fs.writeFileSync(path.join(directory, 'computed-layout.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify(report, null, 2));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
