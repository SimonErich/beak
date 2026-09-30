const fs = require('node:fs');

// Flutter's semantics observer may lag the worker paint. Flush the PNG, then
// require two identical observer frames before publishing measurement bounds.
async function stableScreenshot({page, screenshotPath, boundsPath, readBounds}) {
  const samples = [];
  const signature = bounds => JSON.stringify(bounds, (_, value) =>
    typeof value === 'number' ? Math.round(value * 10) / 10 : value);
  for (let attempt = 0; attempt < 6; attempt++) {
    const before = await readBounds();
    await page.screenshot({path: screenshotPath});
    const after = await readBounds();
    await page.evaluate(() => new Promise(resolve =>
      requestAnimationFrame(() => requestAnimationFrame(resolve))));
    const confirmed = await readBounds();
    const matched = signature(before) === signature(after) &&
      signature(after) === signature(confirmed);
    samples.push({attempt, matched, before, after, confirmed});
    if (matched) {
      fs.writeFileSync(boundsPath, JSON.stringify(confirmed, null, 2));
      fs.writeFileSync(`${boundsPath}.observer.json`, JSON.stringify(samples, null, 2));
      return confirmed;
    }
    await page.waitForTimeout(100);
  }
  fs.writeFileSync(`${boundsPath}.observer.json`, JSON.stringify(samples, null, 2));
  throw new Error(`Screenshot semantics did not stabilize: ${boundsPath}`);
}
module.exports = {stableScreenshot};
