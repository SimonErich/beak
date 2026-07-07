# obers_ui — generic widgets added for the superdashboard

Design record for four **generic** obers_ui widgets the superdashboard needs.
Each is a plain admin-UI widget any app would want, so it belongs in obers_ui
(not Beak). All four are **built and gated green** in `~/Flutters/obers_ui`
but **left uncommitted** (that repo has unrelated in-flight doc edits) — this
file records what to commit and why.

Genericity rationale: maps, carousels, radial inputs, and lock screens are
domain-agnostic UI. Nothing Beak-specific leaked in.

## 1. OiVectorMap — `packages/obers_ui_charts`
A choropleth + bubble world map with bundled geometry.
- `OiVectorMap({required label, List<OiMapRegion>? regions, Map<String,num>? values, List<OiMapMarker> markers, OiMapProjection projection, OiColorScale? colorScale, num? minValue/maxValue, bool showLegend/showTooltip/enableZoom, ValueChanged<OiMapRegion>? onRegionTap, ...})`
- `OiMapRegion`, `OiMapMarker`, `OiMapProjection`/`OiEquirectangularProjection`,
  `OiWorldMap` (bundled regions + 243-country centroids, lazily decoded).
- CustomPainter with cached paths; hit-test via `Path.contains`.
- 22 tests. Exported from the charts barrel.

## 2. OiCarousel — main package (`components/display`)
`OiCarousel({required label, required List<Widget> items, int initialPage, double? height, bool autoplay/pauseOnHover/loop/showArrows/showIndicator, Duration autoplayInterval, double viewportFraction, ValueChanged<int>? onPageChanged})`. 11 tests.

## 3. OiRadialSlider — main package (`components/inputs`)
`OiRadialSlider({required double value/min/max, double? step/size, ValueChanged<double>? onChanged, String? label, double startAngle/sweepAngle, bool showValue/enabled, String Function(double)? valueFormatter})` + a pure, unit-tested `OiRadialSliderGeometry`. 9 tests.

## 4. OiAuthMode.lock — additive on `OiAuthPage`
New `OiAuthMode.lock` value + `OiAuthPage.lock({required label, Future<bool> Function(String password)? onUnlock, String? userName, Widget? avatar, ...})` and matching fields on the default ctor. Existing modes untouched. 4 tests.

## Gate status (in ~/Flutters/obers_ui)
- charts: `flutter analyze` 0 issues, `flutter test` 770 passing (22 new).
- main: touched files analyze clean; 46 new tests pass. (Pre-existing 55
  missing-Linux-golden failures and 12 pre-existing analyze infos are in
  unrelated widgets and were not introduced here.)

## To do (yours)
Commit these in `~/Flutters/obers_ui` and add docs-site entries under
`doc/documentation/docs/charts/specialized.md` (map),
`widgets/display.md` (carousel), `widgets/selection-controls.md` (radial) —
skipped here to avoid touching that repo's in-flight doc branch.
