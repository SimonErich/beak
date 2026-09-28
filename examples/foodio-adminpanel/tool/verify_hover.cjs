/** Real-pointer contrast regression for dark navigation rails with light selected indicators. */
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const cli = process.env.PATH.split(path.delimiter)
  .map((p) => path.join(p, "playwright"))
  .find((p) => fs.existsSync(p));
const { chromium } = cli
  ? require(path.dirname(fs.realpathSync(cli)))
  : require("playwright");
const base = process.env.FOODIO_URL || "http://127.0.0.1:59389";
const artifacts =
  process.env.FOODIO_ARTIFACTS ||
  path.join(__dirname, "../.artifacts", `foodio-hover-${Date.now()}`);
fs.mkdirSync(artifacts, { recursive: true });
// Screenshots exercise the pixels users see. A visible semantics node alone
// would miss the original dark-foreground-on-dark-rail regression.
function visibleIconPixels(file) {
  const result = spawnSync(
    "python3",
    [
      "-c",
      `
from PIL import Image
import sys
image = Image.open(sys.argv[1]).convert('RGB')
bg = image.getpixel((3, 3))
cx, cy = image.width // 2, image.height // 2
pixels = image.crop((cx - 10, cy - 10, cx + 10, cy + 10)).getdata()
print(sum(min(abs(pixel[i] - bg[i]) for i in range(3)) >= 45 for pixel in pixels))
`,
      file,
    ],
    { encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
  return Number(result.stdout.trim());
}

function changedBorderPixels(before, after) {
  const result = spawnSync(
    "python3",
    [
      "-c",
      `
from PIL import Image
import sys
before = Image.open(sys.argv[1]).convert('RGB')
after = Image.open(sys.argv[2]).convert('RGB')
count = 0
for y in range(before.height):
  for x in range(before.width):
    if min(x, y, before.width - x - 1, before.height - y - 1) < 4:
      a, b = before.getpixel((x, y)), after.getpixel((x, y))
      if max(abs(a[i] - b[i]) for i in range(3)) >= 20:
        count += 1
print(count)
`,
      before,
      after,
    ],
    { encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
  return Number(result.stdout.trim());
}

// Measure the complete interior, rather than assuming every action has a
// centered icon. Re-estimate the dominant fill at each animation frame so a
// correctly recolored foreground remains comparable during hover transitions.
function visibleActionPixels(file) {
  const result = spawnSync("python3", ["-c", `
from PIL import Image
from collections import Counter
import sys, json
image = Image.open(sys.argv[1]).convert('RGB')
inside = image.crop((4, 4, image.width - 4, image.height - 4))
pixels = list(inside.getdata())
background = Counter(pixels).most_common(1)[0][0]
count = sum(max(abs(pixel[i] - background[i]) for i in range(3)) >= 45 for pixel in pixels)
print(json.dumps({'visible': count, 'background': background}))
`, file], {encoding: "utf8"});
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout.trim());
}

(async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  const page = await browser.newPage({
    viewport: { width: 1440, height: 1000 },
    timezoneId: "Europe/Vienna",
  });
  const errors = [],
    passes = [],
    samples = [],
    keyboard = [],
    actions = [],
    blockedWrites = [],
    failedRequests = [], activeRequests = new Set(), requestEvents = [];
  page.on("request", request => {
    if (request.url().includes('/api/')) {
      activeRequests.add(request);
      requestEvents.push({url: request.url(), start: Date.now()});
    }
  });
  page.on("requestfinished", request => activeRequests.delete(request));
  page.on("requestfailed", request => activeRequests.delete(request));
  async function quiet() {
    const deadline = Date.now() + 15000;
    let quietSince = Date.now();
    while (Date.now() < deadline) {
      if (activeRequests.size) quietSince = Date.now();
      if (!activeRequests.size && Date.now() - quietSince >= 350) return;
      await page.waitForTimeout(100);
    }
    assert.equal(activeRequests.size, 0, "API requests settle before hover baseline");
  }
  page.on("pageerror", (error) => errors.push(String(error)));
  page.on("console", (message) => { if (message.type() === "error") errors.push(message.text()); });
  page.on("response", (response) => { if (response.status() >= 400) failedRequests.push({url: response.url(), status: response.status()}); });
  await page.route("**/api/commits", route => { blockedWrites.push(route.request().url()); return route.abort(); });
  try {
    for (const pass of ["cold", "warm"]) {
      await page.goto(`${base}/?beak_qa=hover-${pass}#/orders`);
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
      await page.waitForTimeout(500);
      for (const mode of ["Light", "Dark"]) {
        // The example follows the system appearance; the prototype's header
        // contains help, notifications and account actions only.
        await page.emulateMedia({ colorScheme: mode.toLowerCase() });
        await page.mouse.move(1436, 996);
        await page.waitForTimeout(450);
        await quiet();
        await page.evaluate(() => document.fonts.ready);
        const prefix = `${pass}-${mode.toLowerCase()}`;
        const selected = page
          .getByRole("button", { name: /^Orders(?: Orders)?$/ })
          .first();
        const selectedBounds = await selected.boundingBox();
        assert(selectedBounds, "Selected rail destination is visible");
        const selectedClip = {
          x: Math.floor(selectedBounds.x),
          y: Math.floor(selectedBounds.y),
          width: Math.ceil(selectedBounds.width),
          height: Math.ceil(selectedBounds.height),
        };
        const unfocused = path.join(artifacts, `${prefix}-keyboard-before.png`);
        await page.screenshot({ path: unfocused, clip: selectedClip });
        let reachedRail = false;
        for (let attempt = 0; attempt < 80; attempt++) {
          await page.keyboard.press("Shift+Tab");
          await page.waitForTimeout(120);
          reachedRail = await page.evaluate(
            () =>
              document.activeElement
                ?.getAttribute("aria-label")
                ?.includes("primary navigation") ?? false,
          );
          if (reachedRail) break;
        }
        assert(reachedRail, "Keyboard reaches the primary navigation");
        await page.waitForTimeout(120);
        const focused = path.join(artifacts, `${prefix}-keyboard-focused.png`);
        await page.screenshot({ path: focused, clip: selectedClip });
        const paintedRingPixels = changedBorderPixels(unfocused, focused);
        assert(
          paintedRingPixels >= 30,
          `Focus must paint a visible ring, saw ${paintedRingPixels} changed border pixels`,
        );
        await page.screenshot({
          path: path.join(artifacts, `${prefix}-keyboard-page.png`),
        });
        await page.keyboard.press("Tab");
        await page.waitForTimeout(120);
        const left = path.join(artifacts, `${prefix}-keyboard-left.png`);
        await page.screenshot({ path: left, clip: selectedClip });
        const remainingRingPixels = changedBorderPixels(unfocused, left);
        assert(
          remainingRingPixels < 10,
          `Focus ring clears on exit, saw ${remainingRingPixels} changed border pixels`,
        );
        keyboard.push({
          run: pass,
          mode,
          paintedRingPixels,
          remainingRingPixels,
        });
        for (const name of [
          "Home",
          "Orders",
          "People",
          "Kitchen",
          "Finance",
          "Workspace settings",
        ]) {
          const button = page
            .getByRole("button", {
              name: new RegExp(`^${name}(?: ${name})?(?: Settings)*$`),
            })
            .first();
          const bounds = await button.boundingBox();
          assert(bounds, `${name} has a visible pointer target`);
          const clip = {
            x: Math.floor(bounds.x),
            y: Math.floor(bounds.y),
            width: Math.ceil(bounds.width),
            height: Math.ceil(bounds.height),
          };
          const slug = name.toLowerCase().replaceAll(" ", "-");
          await page.mouse.move(1436, 996);
          await page.waitForTimeout(500);
          const before = path.join(artifacts, `${prefix}-${slug}-before.png`);
          await page.screenshot({ path: before, clip });
          const baseline = visibleIconPixels(before);
          assert(
            baseline >= 20,
            `${name} baseline icon is visibly contrasted (${baseline} pixels)`,
          );
          await page.mouse.move(
            bounds.x + bounds.width / 2,
            bounds.y + bounds.height / 2,
          );
          let elapsed = 0;
          for (const time of [0, 100, 250, 500]) {
            await page.waitForTimeout(time - elapsed);
            elapsed = time;
            const file = path.join(artifacts, `${prefix}-${slug}-${time}.png`);
            await page.screenshot({ path: file, clip });
            const visible = visibleIconPixels(file);
            const sample = {
              run: pass,
              mode,
              name,
              time,
              baseline,
              visible,
              passed: visible >= baseline * 0.7,
            };
            samples.push(sample);
            assert(
              sample.passed,
              `${name} at ${time}ms: ${visible} visible pixels < 70% of baseline ${baseline}`,
            );
          }
        }

        for (const [name, kind, role] of [
          ["New order", "primary", "button"], ["Export", "outline", "button"],
          ["All filters", "ghost", "button"], ["Show charts", "switch", "group"],
        ]) {
          const button = page.getByRole(role, {name, exact: true}).first();
          await button.waitFor({state: "visible"});
          const pointer = role === "group" ? button.getByRole("button").first() : button;
          const chartViews = page.getByRole("button", {name: "Chart view", exact: true});
          const initialChartsShown = role === "group" ? await chartViews.count() > 0 : null;
          for (let state = 0; state < (role === "group" ? 2 : 1); state++) {
            const chartsShown = role === "group" ? await chartViews.count() > 0 : null;
            const slug = name.toLowerCase().replaceAll(" ", "-") + (chartsShown == null ? "" : `-${chartsShown ? "on" : "off"}`);
            await page.mouse.move(1436, 996);
            await page.waitForTimeout(500);
            await quiet();
            const bounds = await button.boundingBox();
            await page.waitForTimeout(200);
            const settledBounds = await button.boundingBox();
            assert(bounds && settledBounds, `${name} has a visible action target`);
            for (const axis of ['x', 'y', 'width', 'height']) assert(Math.abs(bounds[axis] - settledBounds[axis]) <= .1, `${name} baseline geometry settles`);
            const target = await pointer.boundingBox();
            assert(target, `${name} pointer target is visible`);
            const clip = {x: Math.floor(bounds.x), y: Math.floor(bounds.y),
              width: Math.ceil(bounds.width), height: Math.ceil(bounds.height)};
            const before = path.join(artifacts, `${prefix}-action-${slug}-before.png`);
            await page.screenshot({path: before, clip});
            const baseline = visibleActionPixels(before);
            assert(baseline.visible >= 40, `${name} baseline content must remain visible`);
            const started = Date.now();
            await page.mouse.move(target.x + target.width / 2, target.y + target.height / 2);
            let elapsed = 0;
            for (const time of [0, 100, 250, 500]) {
              await page.waitForTimeout(time - elapsed);
              elapsed = time;
              const file = path.join(artifacts, `${prefix}-action-${slug}-${time}.png`);
              const currentBounds = await button.boundingBox();
              assert(currentBounds, `${name} remains mounted during hover`);
              const geometry = Object.fromEntries(['x','y','width','height'].map(axis => [axis, currentBounds[axis] - bounds[axis]]));
              await page.screenshot({path: file, clip});
              const pixels = visibleActionPixels(file);
              const sample = {run: pass, mode, name, kind, role, chartsShown, time, geometry,
                apiActive: activeRequests.size, apiSinceBaseline: requestEvents.filter(request => request.start >= started),
                baseline: baseline.visible, visible: pixels.visible,
                background: pixels.background, passed: pixels.visible >= baseline.visible * .7};
              actions.push(sample);
              if (!sample.passed || Object.values(geometry).some(delta => Math.abs(delta) > .1)) await page.screenshot({path: path.join(artifacts, `${prefix}-action-${slug}-${time}-page.png`)});
              assert(Object.values(geometry).every(delta => Math.abs(delta) <= .1), `${name} geometry remains stable during hover: ${JSON.stringify(geometry)}`);
              assert(sample.passed, `${name} ${mode} at ${time}ms: visible content ${pixels.visible} <70% of ${baseline.visible}`);
              assert(await button.isVisible(), `${name} semantics remain mounted during hover`);
            }
            if (role === "group") {
              await pointer.click();
              await page.waitForTimeout(500);
              assert.equal(await chartViews.count() > 0, !chartsShown, "Chart switch changes the actual chart region");
            }
          }
          if (role === "group") assert.equal(await chartViews.count() > 0, initialChartsShown, "Chart switch restores the initial display");
        }
        await page.mouse.move(1436, 996);
        await page.screenshot({
          path: path.join(artifacts, `${prefix}-page.png`),
        });
        passes.push(prefix);
      }
    }
    assert.deepEqual(errors, []);
    assert.deepEqual(failedRequests, []);
    assert.deepEqual(blockedWrites, []);
  } finally {
    fs.writeFileSync(
      path.join(artifacts, "report.json"),
      JSON.stringify({ passes, samples, actions, keyboard, errors, failedRequests, blockedWrites }, null, 2),
    );
    console.log(
      JSON.stringify(
        { artifacts, passes, samples: samples.length, actions: actions.length, keyboard, errors, failedRequests, blockedWrites },
        null,
        2,
      ),
    );
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
