# Colors and tokens

> How the seven BeakColor names resolve to theme colors on badges, buttons, boards and charts, and how Gabel builds a full palette from a design system.

Beak has two color vocabularies. Your schema and your blocks speak in seven semantic names, `BeakColor`. The theme speaks in tokens: swatches, surfaces, text and border colors. This page shows how a name becomes a token on each surface, so a badge does not come out the wrong color in a theme you built by hand, and how the Gabel theme builds a complete palette from a design system's tokens.

## At a glance

```dart title="packages/beak_core/lib/src/common/beak_color.dart"
enum BeakColor {
  /// The theme's primary accent color.
  primary,

  /// The theme's secondary accent color.
  secondary,

  /// Positive/confirming states (published, paid, active).
  success,

  /// Cautionary states (pending, low stock).
  warning,

  /// Destructive or failing states (rejected, out of stock).
  error,

  /// Neutral informational states.
  info,

  /// De-emphasized/disabled states.
  muted,
}

```

`beak_core` never imports `dart:ui`, so a column or an action names a role and never a color value. `beak_frontend` resolves the role against the active theme, in three places that agree on the mapping:

| `BeakColor` | Badge (`OiBadgeColor`) | Direct color (`context.colors`) | Action button |
| --- | --- | --- | --- |
| `primary` | `primary` | `primary.base` | primary button |
| `secondary` | `accent` | `accent.base` | secondary button |
| `success` | `success` | `success.base` | secondary button |
| `warning` | `warning` | `warning.base` | secondary button |
| `error` | `error` | `error.base` | destructive button |
| `info` | `info` | `info.base` | secondary button |
| `muted` | `neutral` | `textMuted` | secondary button |

`secondary` is the one name that differs: it means the theme's `accent` swatch. The badge column is this function, and the direct column is the function under it:

```dart title="packages/beak_frontend/lib/src/table/column_cell_renderer.dart"
OiBadgeColor oiBadgeColorFor(BeakColor color) => switch (color) {
  BeakColor.primary => OiBadgeColor.primary,
  BeakColor.secondary => OiBadgeColor.accent,
  BeakColor.success => OiBadgeColor.success,
  BeakColor.warning => OiBadgeColor.warning,
  BeakColor.error => OiBadgeColor.error,
  BeakColor.info => OiBadgeColor.info,
  BeakColor.muted => OiBadgeColor.neutral,
};
```

```dart title="packages/beak_frontend/lib/src/blocks/views/beak_record_readers.dart"
Color? _resolveBeakColor(BuildContext context, BeakColor? color) {
  final colors = context.colors;
  return switch (color) {
    null => null,
    BeakColor.primary => colors.primary.base,
    BeakColor.secondary => colors.accent.base,
    BeakColor.success => colors.success.base,
    BeakColor.warning => colors.warning.base,
    BeakColor.error => colors.error.base,
    BeakColor.info => colors.info.base,
    BeakColor.muted => colors.textMuted,
  };
}
```

Action buttons only distinguish `primary` and `error`. An action declared with `BeakColor.success` renders as a secondary button, not a green one.

## Where a color name comes from

An enum field gets its badge colors from the schema, once, and every surface that shows the field agrees: the table cell, the detail value, a kanban column, a calendar event:

```dart title="examples/showcase/lib/resources/tasks/models/task.dart"
@Column(defaultValue: TaskStatus.todo, filterable: true)
@Badges<TaskStatus>({
  TaskStatus.todo: BeakColor.muted,
  TaskStatus.doing: BeakColor.info,
  TaskStatus.done: BeakColor.success,
})
late final TaskStatus status;
```

A value with no entry gets `neutral`. The board and the calendar reuse the same mapping for column and event colors, which is why the Aviary's Planner needs no color argument at all. Blocks take a `BeakColor` where they need one directly: `BeakBadgeBlock(color:)`, `BeakSummaryValue(iconColor:)`, and the `color` of an action. The Aviary's content page renders every value in a loop, which is the quickest look at what your theme does to all seven:

```dart title="examples/showcase/lib/pages/content_blocks.dart"
BeakBlock _badges() => BeakCardBlock(
  title: 'Badges',
  child: BeakRowBlock(
    gapInPixels: 8,
    children: [
      for (final color in BeakColor.values)
        BeakBadgeBlock(color.name, color: color),
    ],
  ),
);
```

## What a swatch holds

`OiColorScheme` has six swatches (`primary`, `accent`, `success`, `warning`, `error`, `info`), and each is an `OiColorSwatch` with five slots: `base`, `light`, `dark`, `muted` and `foreground`. Around them sit the surfaces (`background`, `surface`, `surfaceSubtle`, `surfaceHover`, `surfaceActive`, `overlay`), the text colors (`text`, `textSubtle`, `textMuted`, `textInverse`, `textOnPrimary`), the borders (`border`, `borderSubtle`, `borderFocus`, `borderError`) and `chart`, a list of series colors.

Which slot a widget reads matters when you build a swatch by hand. The soft badge, the one Beak uses for every enum value, has two recipes:

| `OiBadgeThemeData.useSwatchColors` | Background | Text |
| --- | --- | --- |
| `false` (default) | `base` at 20% opacity | `dark` |
| `true` | `muted` (neutral: `surfaceSubtle`) | `dark` (neutral: `textMuted`) |

So a status badge is drawn in `dark` on either a tinted `base` or `muted`. A swatch whose `dark` is too light to read on its `muted` produces an unreadable badge, and `OiColorSwatch.from(base)` derives `dark` by lowering the lightness of `base` by 20 points. A hand-built swatch has to keep that contrast itself, because Beak does not check it.

## A full palette from a design system

The Gabel theme (`beak_theme_gabel`, selected by Foodio, see [Built-in themes](built-in-themes.md)) comes from a design file whose tokens have names like `canvas`, `sheet`, `ink` and `primary-soft`. The tokens live in two classes of named constants, one for light and one for dark:

```dart title="packages/beak_theme_gabel/lib/src/tokens/gabel_light.dart"
abstract final class GabelLight {
  /// Page background, panel, recessed well and popover surfaces.
  static const canvas = Color(0xFFF3F3F7),
      sheet = Color(0xFFFEFEFF),
      well = Color(0xFFF6F7FA),
      overlay = Color(0xFFFFFFFF);
  // ...
}
```

`GabelPalette(dark:)` picks one class by brightness, and `gabelColors` maps its tokens onto the obers_ui slots. First a helper that turns a design's three colors into a swatch, with `dark` deliberately set to the ink color so soft badges read well:

```dart title="packages/beak_theme_gabel/lib/src/gabel_colors.dart"
OiColorSwatch _swatch(Color value, Color soft, Color foreground) =>
    OiColorSwatch(
      base: value,
      light: soft,
      dark: value,
      muted: soft,
      foreground: foreground,
    );
```

Then the whole `OiColorScheme`, copied from the stock theme and overridden slot by slot:

```dart title="packages/beak_theme_gabel/lib/src/gabel_colors.dart"
OiColorScheme gabelColors(OiColorScheme base, GabelPalette p) {
  final pick = p.pick;
  return base.copyWith(
    background: p.canvas,
    surface: p.sheet,
    surfaceSubtle: p.well,
    surfaceHover: pick(GabelLight.fillHover, GabelDark.fillHover),
    surfaceActive: pick(GabelLight.fillPress, GabelDark.fillPress),
    overlay: pick(GabelLight.scrim, GabelDark.scrim),
    text: p.ink,
    textSubtle: p.subtle,
    textMuted: p.muted,
    textInverse: pick(GabelLight.onInverse, GabelDark.onInverse),
    textOnPrimary: p.onPrimary,
    border: p.border,
    borderSubtle: p.line,
    borderFocus: p.primaryInk,
    borderError: p.dangerInk,
    primary: _swatch(
      p.primary,
      p.primarySoft,
      p.onPrimary,
    ).copyWith(dark: p.primaryInk),
    accent: _swatch(
      pick(GabelLight.secondary, GabelDark.secondary),
      pick(GabelLight.secondarySoft, GabelDark.secondarySoft),
      pick(GabelLight.onSecondary, GabelDark.onSecondary),
    ),
    success: _swatch(
      pick(GabelLight.successInk, GabelDark.successInk),
      pick(GabelLight.successSoft, GabelDark.successSoft),
      pick(GabelLight.onSuccess, GabelDark.onSuccess),
    ),
    warning: _swatch(
      pick(GabelLight.warningInk, GabelDark.warningInk),
      pick(GabelLight.warningSoft, GabelDark.warningSoft),
      pick(GabelLight.onWarning, GabelDark.onWarning),
    ),
    error: _swatch(
      p.dangerInk,
      p.dangerSoft,
      pick(GabelLight.onDanger, GabelDark.onDanger),
    ),
    info: _swatch(
      pick(GabelLight.secondaryInk, GabelDark.secondaryInk),
      pick(GabelLight.secondarySoft, GabelDark.secondarySoft),
      pick(GabelLight.onSecondary, GabelDark.onSecondary),
    ),
    chart: p.dark
        ? const [
            GabelDark.chart1,
            GabelDark.chart2,
            GabelDark.chart3,
            GabelDark.chart4,
            GabelDark.chart5,
            GabelDark.chart6,
          ]
        : const [
            GabelLight.chart1,
            GabelLight.chart2,
            GabelLight.chart3,
            GabelLight.chart4,
            GabelLight.chart5,
            GabelLight.chart6,
          ],
  );
}
```

Read the mapping as a table of your own: the design's `canvas` is `background`, `sheet` is `surface`, `well` is `surfaceSubtle`, `fill-hover` and `fill-press` are `surfaceHover` and `surfaceActive`, `scrim` is `overlay`, `ink` is `text`, `line` is `borderSubtle`, and each status swatch takes the color's `-ink` token as `base` and `dark`, and its `-soft` token as `light` and `muted`. The six `chart` colors are a list in series order. Everything the design does not name (`glassBackground`, `glassBorder`) keeps the stock value, because the code starts from `base.copyWith(...)`.

`GabelTheme` builds the two results with `buildGabelTheme(dark:)` and the panel receives them as one value, `theme: GabelTheme()`:

```dart title="examples/foodio-adminpanel/lib/main.dart"
theme: GabelTheme(),
```

## Rules and limits

- Names are fixed. `BeakColor` has seven values and you cannot add one. A hue the theme lacks, such as purple, is a theme decision: pick the closest role and put the hue in that swatch.
- Only `BeakColor` follows the mode. `BeakSummaryValue.color` and `BeakSummaryGroupStyle.color` take a plain `Color`, so they keep their value in dark mode. Foodio passes its `GabelLight` chart tokens there and accepts that.
- Charts have their own palette. `BeakChartBlock` series come from the theme's `chart` list. Summary bars and donuts cycle `primary`, `warning`, `info`, `success` and `error` unless you give a color ([Charts](../blocks/charts.md), [Population summaries](../blocks/summaries.md)).
- Status is not only color. Give every state a label, as badges do, and use the non-color cues Beak already has: a metric's change carries a sign and an arrow, and summary bars and legends take `hatched` for forecast values.
- Contrast is yours. Beak resolves names to tokens and never measures contrast. Check swatches in both modes.
- Formatting is separate. A number, date or currency looks the same in every theme. That is set by [BeakFormatting](formatting-and-localization.md).

## Verify it

Open the Aviary's Content blocks page, look at the Badges card, and press the theme toggle. All seven badges should change with the mode. The mapping itself has a unit test:

```console
$ cd packages/beak_frontend
$ flutter test --no-pub test/src/table/column_cell_renderer_test.dart --plain-name "BeakColor"
enum badges use the configured BeakColor and label
every BeakColor maps onto an obers badge color
All tests passed!
```

The Gabel package keeps a golden of a small showcase in each mode (`packages/beak_theme_gabel/test/goldens`), which catches a palette that drifts. It does not measure contrast, so run Foodio, switch to dark, and look at a status badge and a chart.

## Reference

| Symbol | Notes |
| --- | --- |
| `BeakColor` | `primary`, `secondary`, `success`, `warning`, `error`, `info`, `muted`. |
| `Badges<T>` | Schema annotation: `Map<T, BeakColor>` for an enum field. |
| `oiBadgeColorFor(BeakColor)` | The badge mapping, exported by `beak_frontend`. |
| `OiColorSwatch` | `base`, `light`, `dark`, `muted`, `foreground`; `OiColorSwatch.from(base)` derives the rest. |
| `OiColorScheme.copyWith` | Every slot listed above, plus `chart`. |
| `OiBadgeThemeData(useSwatchColors:)` | Chooses the soft-badge recipe. |
| `OiChartThemeData` | `components.chart`: palette, axis, grid, legend, density. |

## Continue reading

- [Typography and icons](typography-and-icons.md) the type ramp and the icon set, themed the same way.
- [Built-in themes](built-in-themes.md) select the Gabel design instead of rebuilding it.
- [Theming basics](theming-basics.md) where the theme goes and how the toggle works.
- [Charts](../blocks/charts.md) the chart palette in use.
- [Semantic fields](../models/semantic-fields.md) money, percentages and units, which format independently of color.
