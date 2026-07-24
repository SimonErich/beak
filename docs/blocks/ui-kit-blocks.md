---
title: UI-kit blocks
description: The small stateful widgets as blocks: alert banners, colored badges, progress bars, star ratings, and the radial slider.
---

# UI-kit blocks

After this page you can drop the small pieces of UI onto any screen: an alert
banner at one of four severities, a colored status badge, a labelled progress
bar, a star rating, and a draggable radial slider. These are leaf blocks. They
take values, not children.

| Block | Renders onto | Key parameters |
| --- | --- | --- |
| `BeakAlertBlock` | `OiBanner` | `message`, `level` |
| `BeakBadgeBlock` | `OiBadge` | `label`, `color` |
| `BeakProgressBlock` | `OiProgress` (linear) | `value`, `label` |
| `BeakRatingBlock` | `OiStarRating` | `value`, `maxStars`, `readOnly` |
| `BeakRadialSliderBlock` | `OiRadialSlider` | `label`, `min`, `max`, `initialValue` |

The showcase's UI Elements screen puts all of these on one page. The snippets
below are lifted from it and from the block tests.

## Alert

`BeakAlertBlock` is an inline banner. The first argument is the `message`; the
`level` picks the severity and defaults to `info`.

```dart title="packages/beak_frontend/lib/src/blocks/beak_alert_block.dart"
const BeakAlertBlock(
  this.message, {
  this.level = BeakAlertLevel.info,
  super.span,
});
```

The level maps one-to-one onto an `OiBanner` constructor:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
Widget _alert(BeakAlertBlock block) => switch (block.level) {
  BeakAlertLevel.info => OiBanner.info(message: block.message),
  BeakAlertLevel.success => OiBanner.success(message: block.message),
  BeakAlertLevel.warning => OiBanner.warning(message: block.message),
  BeakAlertLevel.error => OiBanner.error(message: block.message),
};
```

| Level | Use for |
| --- | --- |
| `info` | Neutral, informational notices (the default) |
| `success` | Confirmation that something worked |
| `warning` | Something the reader should be careful about |
| `error` | Something that failed |

```dart title="packages/beak_frontend/test/src/blocks/beak_uikit_blocks_test.dart"
BeakAlertBlock('Saved', level: BeakAlertLevel.success),
```

## Badge

`BeakBadgeBlock` is a colored status pill. It takes a `label` and a `BeakColor`,
which defaults to `primary`.

```dart title="packages/beak_frontend/lib/src/blocks/beak_badge_block.dart"
const BeakBadgeBlock(
  this.label, {
  this.color = BeakColor.primary,
  super.span,
});
```

```dart title="packages/beak_frontend/test/src/blocks/beak_uikit_blocks_test.dart"
BeakBadgeBlock('Active', color: BeakColor.success),
```

`BeakColor` is the shared semantic palette (`primary`, `secondary`, `success`,
`warning`, `error`, `info`, `muted`). The host maps each one to an obers_ui
badge color, so a badge stays on the theme:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
OiBadgeColor _badgeColor(BeakColor color) => switch (color) {
  BeakColor.primary => OiBadgeColor.primary,
  BeakColor.secondary => OiBadgeColor.accent,
  BeakColor.success => OiBadgeColor.success,
  BeakColor.warning => OiBadgeColor.warning,
  BeakColor.error => OiBadgeColor.error,
  BeakColor.info => OiBadgeColor.info,
  BeakColor.muted => OiBadgeColor.neutral,
};
```

Because `BeakColor` is an enum, you can loop over `BeakColor.values` to show the
whole palette, exactly as the UI-kit page does:

```dart title="apps/beak_superdashboard/lib/screens/ui_kit_screen.dart"
BeakRowBlock(
  gapInPixels: 8,
  children: [
    for (final color in BeakColor.values)
      BeakBadgeBlock(color.name, color: color),
  ],
),
```

## Progress

`BeakProgressBlock` is a linear progress bar. `value` is the fill fraction in the
range 0 to 1, and `label` is an optional caption above the bar.

```dart title="packages/beak_frontend/lib/src/blocks/beak_progress_block.dart"
const BeakProgressBlock({required this.value, this.label, super.span});
```

```dart title="apps/beak_superdashboard/lib/screens/ui_kit_screen.dart"
BeakColumnBlock(
  gapInPixels: 12,
  children: [
    BeakProgressBlock(value: 0.25, label: 'Design'),
    BeakProgressBlock(value: 0.6, label: 'Development'),
    BeakProgressBlock(value: 0.9, label: 'Launch'),
  ],
),
```

## Rating

`BeakRatingBlock` shows a star rating. It is display-only by default
(`readOnly: true`) and supports half-stars.

```dart title="packages/beak_frontend/lib/src/blocks/beak_rating_block.dart"
const BeakRatingBlock({
  required this.value,
  this.maxStars = 5,
  this.readOnly = true,
  super.span,
});
```

```dart title="apps/beak_superdashboard/lib/screens/ui_kit_screen.dart"
BeakRatingBlock(value: 3.5),
```

The host always renders it with half-star precision:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
Widget _rating(BeakRatingBlock block) => OiStarRating(
  value: block.value,
  maxStars: block.maxStars,
  readOnly: block.readOnly,
  allowHalf: true,
);
```

## Radial slider

`BeakRadialSliderBlock` is a knob you drag around an arc to pick a value. Unlike
the others it is interactive: it owns its value locally with no binding, which
makes it a self-contained showcase control.

```dart title="packages/beak_frontend/lib/src/blocks/beak_radial_slider_block.dart"
const BeakRadialSliderBlock({
  required this.label,
  this.min = 0,
  this.max = 100,
  this.initialValue = 40,
  this.sizeInPixels = 200,
  super.span,
});
```

```dart title="apps/beak_superdashboard/lib/screens/ui_kit_screen.dart"
BeakCardBlock(
  title: 'Round slider',
  child: BeakRadialSliderBlock(label: 'Volume', initialValue: 65),
),
```

!!! note "Display versus data"
    These blocks take literal values you already have. To show a live number
    from your database (an aggregate, a metric), reach for a data block: a
    [KPI or metric](data-blocks.md) reads a `BeakQuerySpec` instead of a
    hard-coded `value`.

## Continue reading

- [Data blocks](data-blocks.md) KPIs, charts, and tables that read live data.
- [Layout blocks](layout-blocks.md) the cards and grids these leaves sit inside.
- [Colors and tokens](../theming/colors-and-tokens.md) how `BeakColor` maps to
  the theme's palette.
- [Blocks overview](index.md) the sealed family and its one renderer.
