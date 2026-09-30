/** Real-browser coverage for narrow headings, hover geometry and model-backed sorts. */
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const cli = process.env.PATH.split(path.delimiter)
  .map((p) => path.join(p, "playwright"))
  .find((p) => fs.existsSync(p));
const { chromium } = cli
  ? require(path.dirname(fs.realpathSync(cli)))
  : require("playwright");
const base = process.env.FOODIO_URL || "http://127.0.0.1:59389";
const artifacts =
  process.env.FOODIO_ARTIFACTS ||
  path.join(__dirname, "../.artifacts", `foodio-table-headers-${Date.now()}`);
fs.mkdirSync(artifacts, { recursive: true });
(async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  const page = await browser.newPage({
    viewport: { width: 1440, height: 1720 },
    timezoneId: "Europe/Vienna",
  });
  const errors = [],
    sorts = [];
  page.on("pageerror", (error) => errors.push(String(error)));
  try {
    await page.goto(`${base}/?beak_qa=table-headers#/orders`);
    await page
      .locator("flt-semantics-placeholder")
      .waitFor({ state: "attached" });
    await page
      .locator("flt-semantics-placeholder")
      .evaluateAll((elements) =>
        elements.forEach((element) => element.click()),
      );
    await page
      .getByRole("button", { name: "New order", exact: true })
      .waitFor();
    await page.waitForTimeout(600);
    assert.equal(
      await page
        .getByRole("button", { name: "Chart view", exact: true })
        .count(),
      3,
    );
    assert.equal(
      await page
        .getByRole("button", { name: "Table view", exact: true })
        .count(),
      3,
    );
    for (const [label, column] of [
      ["Items", "item_count"],
      ["Total", "gross_cents"],
    ]) {
      const header = page.getByRole("button", { name: label, exact: true });
      const bounds = await header.boundingBox();
      const clip = {
        x: Math.floor(bounds.x) - 4,
        y: Math.floor(bounds.y) - 4,
        width: Math.ceil(bounds.width) + 8,
        height: 220,
      };
      await page.mouse.move(1435, 1715);
      await page.waitForTimeout(180);
      await page.screenshot({
        path: path.join(artifacts, `${column}-neutral.png`),
        clip,
      });
      await header.hover();
      await page.waitForTimeout(250);
      assert.deepEqual(
        await header.boundingBox(),
        bounds,
        `${label} hover preserves geometry`,
      );
      await page.screenshot({
        path: path.join(artifacts, `${column}-hover.png`),
        clip,
      });
      for (const descending of [false, true]) {
        const responseReady = page.waitForResponse(
          (response) =>
            response.url().endsWith("/api/orders/query") &&
            response.request().method() === "POST",
        );
        await header.click();
        const response = await responseReady;
        assert.equal(response.status(), 200);
        const request = response.request().postDataJSON();
        assert.deepEqual(request.sorts, [{ column, descending }]);
        const result = await response.json();
        const values = result.items.map((row) => row.values[column]);
        assert.equal(values.length, 15);
        assert(values.every(Number.isFinite));
        assert.deepEqual(
          values,
          [...values].sort((a, b) => (descending ? b - a : a - b)),
        );
        await page.waitForTimeout(250);
        await page.screenshot({
          path: path.join(
            artifacts,
            `${column}-${descending ? "descending" : "ascending"}-hover.png`,
          ),
          clip,
        });
        await page.mouse.move(1435, 1715);
        await page.waitForTimeout(180);
        await page.screenshot({
          path: path.join(
            artifacts,
            `${column}-${descending ? "descending" : "ascending"}.png`,
          ),
          clip,
        });
        sorts.push({
          column,
          descending,
          values,
          status: response.status(),
          bounds,
        });
      }
    }
    await page.screenshot({ path: path.join(artifacts, "list.png") });
    assert.deepEqual(errors, []);
    fs.writeFileSync(
      path.join(artifacts, "report.json"),
      JSON.stringify({ sorts, errors, namedChartButtons: 6 }, null, 2),
    );
    console.log(
      JSON.stringify(
        { artifacts, sorts, errors, namedChartButtons: 6 },
        null,
        2,
      ),
    );
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
