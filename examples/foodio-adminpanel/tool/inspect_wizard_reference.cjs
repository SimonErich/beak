/** Measure the prototype's wizard typography and spacing at its design size. */
const fs = require('node:fs');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const cli = process.env.PATH.split(path.delimiter)
  .map(p => path.join(p, 'playwright')).find(p => fs.existsSync(p));
const {chromium} = cli ? require(path.dirname(fs.realpathSync(cli))) : require('playwright');
const directory = path.join(__dirname, '../.artifacts/reference');
(async () => {
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  try {
    const page = await browser.newPage({viewport: {width: 1440, height: 1024}});
    const report = [];
    for (const state of [8, 9]) {
      await page.goto(pathToFileURL(path.join(directory, `reference-${state}.html`)).href);
      await page.evaluate(() => document.fonts.ready);
      const elements = await page.evaluate(() => {
        const text = /^(How is it paid\?|Payment method|Company invoice \(monthly\)|Company invoice · monthly collective|Lena Hofer|Customer and profile|Delivery|Dishes|Total and budget|Subtotal · 4 dishes|€41\.31|Total|Voucher|Review|Check and place the order|Budget after this order)$/;
        return [...document.querySelectorAll('body *')]
          .filter(e => e.children.length === 0 && text.test(e.textContent.trim()) && e.getBoundingClientRect().width)
          .map(e => {
            const s = getComputedStyle(e), r = e.getBoundingClientRect();
            return {text:e.textContent, tag:e.tagName, x:r.x, y:r.y, width:r.width, height:r.height,
              font:s.fontFamily, size:s.fontSize, weight:s.fontWeight, variations:s.fontVariationSettings,
              lineHeight:s.lineHeight, color:s.color, spacing:s.letterSpacing,
              parent: e.parentElement.getAttribute('style')};
          });
      });
      report.push({state, elements});
    }
    fs.writeFileSync(path.join(directory, 'wizard-computed-layout.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify(report, null, 2));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
