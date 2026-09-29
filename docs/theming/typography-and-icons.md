---
title: Typography and icons
description: Set the panel's fonts and type ramp, know which text styles Beak's blocks use, and re-skin every icon the framework draws through one theme entry.
type: guide
audience: [expert]
status: stable
---

# Typography and icons

Text and icons come from the theme like colors do, so a panel changes its whole voice with a font family, a type ramp and an icon map. After this page you can load a font, set the 14 text styles, keep a variable font from fighting your components, and replace the icon set without touching a screen.

## At a glance

| You want to change | Where |
| --- | --- |
| The font of the whole panel | `OiThemeData.light(fontFamily:, monoFontFamily:)` and the dark twin |
| One text style, or all of them | `theme.copyWith(textTheme: base.textTheme.copyWith(...))` |
| What a `BeakTextBlock` looks like | its `BeakTextVariant`, resolved by the type ramp |
| An icon in navigation | `BeakIconToken(OiIcons.name)` on a resource or a screen |
| Every drawing of an icon | `components.icon`: `OiIconThemeData(sources: {...})` |

## The type ramp

`OiTextTheme` holds 14 named styles: `display`, `h1` to `h4`, `body`, `bodyStrong`, `small`, `smallStrong`, `tiny`, `caption`, `code`, `overline` and `link`. Widgets never build a `TextStyle`; they render an `OiLabel` variant and the theme supplies the style. Beak's own text does the same, so changing `body` changes table cells, form labels and dialog copy together.

A `BeakTextBlock` reaches nine of the 14:

```dart title="packages/beak_frontend/lib/src/blocks/beak_text_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_text_block.dart:BeakTextVariant"
```

For `smallStrong`, `tiny`, `code`, `overline` or `link`, put an `OiLabel` in a `BeakWidgetBlock`. In `display`, `h1` and `h2`, obers_ui scales sizes up on wide screens (a factor of 1.0 on compact widths, 1.1 on medium and 1.2 beyond) unless the theme pins them with `headingScale`. A design with an exact type scale pins it, as Foodio does.

## A full type ramp: Foodio

Foodio's design is set in Mona Sans with JetBrains Mono for code. The fonts are declared as assets like any Flutter font:

```yaml title="examples/foodio-adminpanel/pubspec.yaml"
  fonts:
    - family: Mona Sans
      fonts:
        - asset: assets/fonts/MonaSans.ttf
    - family: Mona Sans Extended
      fonts:
        - asset: assets/fonts/MonaSansExtended.ttf
    - family: JetBrains Mono
      fonts:
        - asset: assets/fonts/JetBrainsMono.ttf
    - family: JetBrains Mono Extended
      fonts:
        - asset: assets/fonts/JetBrainsMonoExtended.ttf
```

The theme starts from a stock light or dark theme and hands it the two families, which sets them across the ramp:

```dart title="examples/foodio-adminpanel/lib/theme/gabel_theme.dart"
--8<-- "examples/foodio-adminpanel/lib/theme/gabel_theme.dart:gabelBase"
```

Then a small helper builds every style the design specifies, from its size, its line height in pixels, a weight and a width:

```dart title="examples/foodio-adminpanel/lib/theme/gabel_theme.dart"
--8<-- "examples/foodio-adminpanel/lib/theme/gabel_theme.dart:gabelTextHelper"
```

And the ramp itself replaces the stock one, with `headingScale` pinned to 1 so `display`, `h1` and `h2` do not grow on a wide screen:

```dart title="examples/foodio-adminpanel/lib/theme/gabel_theme.dart"
--8<-- "examples/foodio-adminpanel/lib/theme/gabel_theme.dart:gabelTextTheme"
```

### The variable-font trap

The comment inside the helper is the lesson. A variable font has axes, and `fontVariations: [FontVariation('wght', 500)]` sets one. A component that wants emphasis calls `style.copyWith(fontWeight: FontWeight.w600)`, and if the style also carries a fixed `wght` variation, the variation wins and the emphasis silently does nothing. So the helper sets the `wght` variation only for weights that are not a multiple of 100 (the design's 560 and 580) and leaves the 400, 500 and 600 to `fontWeight`, where components can still override them.

Foodio keeps a test for exactly this. It rasterizes the body style at four weights, once through `fontWeight` and once through the axis, and asserts the glyphs are identical and that each weight differs from the previous:

```console
$ cd examples/foodio-adminpanel
$ flutter test --no-pub test/gabel_typography_test.dart
00:00 +0: native hundred weights rasterize exactly as their variable font axes
...
00:00 +5: All tests passed!
```

The same test file pins tabular figures. Money that changes digits should not jitter, so Foodio's numeric styles switch on `FontFeature.tabularFigures()`.

## Icons

Icons are `IconData` tokens from `OiIcons`, the Lucide set that ships inside obers_ui: over 1,950 glyphs, named in camelCase (`OiIcons.layoutDashboard`, `OiIcons.receiptText`). A typo is a compile error. Beak asks for an icon in two spellings:

- Navigation destinations take a `BeakIconToken`, a zero-cost wrapper: `BeakResource(icon: BeakIconToken(OiIcons.users))` and `BeakScreen(icon: ...)`.
- Blocks, actions and summary values take a plain `IconData`: `BeakMetricBlock(icon: OiIcons.bird)`, `BeakAction(icon:)`, `BeakSummaryValue(icon:)`.

```dart title="packages/beak_frontend/lib/src/panel/beak_resource.dart"
--8<-- "packages/beak_frontend/lib/src/panel/beak_resource.dart:BeakIconToken"
```

A generated panel takes icons from `beak.yaml` by name (`icon: fileText` under a resource), and `beak prepare` writes `BeakIconToken(OiIcons.fileText)`. It does not check that the name exists. A wrong name stops at the analyzer, as an undefined getter on `OiIcons` in `lib/beak/panel.g.dart`. The Aviary's icon gallery block is the quickest way to find a name:

```dart title="examples/showcase/lib/pages/content_blocks.dart"
--8<-- "examples/showcase/lib/pages/content_blocks.dart:icons"
```

### Replace the icon set

A theme can redraw any token. `OiIconThemeData.sources` maps a token to a different source, and every widget that draws that token, Beak's controls included, uses the new drawing. Tokens you do not map keep their Lucide glyph, so a partial set is fine. Foodio maps the 26 icons its design draws and sets the default size:

```dart title="examples/foodio-adminpanel/lib/theme/gabel_theme.dart"
--8<-- "examples/foodio-adminpanel/lib/theme/gabel_theme.dart:gabelIconTheme"
```

Each entry is a token and an SVG string:

```dart title="examples/foodio-adminpanel/lib/theme/gabel_icons.dart"
--8<-- "examples/foodio-adminpanel/lib/theme/gabel_icons.dart:gabelIconEntry"
```

The `stroke="currentColor"` in the markup is what makes it themable: the icon takes the color and size of whichever widget draws it, and follows the theme mode. An SVG with a fixed color would not.

## Rules and limits

- **Nine of 14 text variants in blocks.** The rest exist in the theme and are reachable through `OiLabel`.
- **Declare fonts as assets.** A family that is not in `pubspec.yaml` falls back to the platform font without a warning, and web builds also need the font files served.
- **Keep the `wght` variation off hundred weights.** See the trap above.
- **Text is `OiLabel`, not `Text`.** A raw `Text` ignores the ramp and the mode's text color.
- **Icons are tokens.** Swapping the set needs no screen change, and adding a new token to the design needs a `sources` entry only if the design draws it.
- **Two spellings, one token.** `BeakIconToken(x)` and `x` are the same `IconData`. There is no conversion; use whichever the parameter's type asks for.
- **Formatting is separate.** Number and date style comes from `BeakFormatting`, not from the type ramp ([Formatting and localization](formatting-and-localization.md)).

## Verify it

Change `body` in your theme and run the panel: table cells, form labels and block text change together. For icons, map one token, say `OiIcons.search`, to any SVG and reload. The search button in the top bar and in the command bar both change. Foodio's typography tests cover the weight behavior, as shown above.

## Reference

| Symbol | Notes |
| --- | --- |
| `OiTextTheme` | `display`, `h1` to `h4`, `body`, `bodyStrong`, `small`, `smallStrong`, `tiny`, `caption`, `code`, `overline`, `link`, and `headingScale`. |
| `OiLabel` | One named constructor per variant; `OiLabel.variant(text, variant:)` picks at runtime. |
| `BeakTextVariant` | The nine variants a `BeakTextBlock` takes. |
| `OiIcons` | The Lucide tokens. |
| `BeakIconToken` | `extension type const BeakIconToken(IconData icon)`. |
| `OiIconThemeData` | `sources` (`Map<IconData, OiIconSource>`), `size`, `color`. |
| `OiIconSource.svg(String)` | An SVG drawn in the current color. |

## Continue reading

- [Colors and tokens](colors-and-tokens.md) the color half of the same theme.
- [Formatting and localization](formatting-and-localization.md) numbers, dates, currency and the UI language.
- [Content blocks](../blocks/content-blocks.md) the text, badge and icon blocks that read this theme.
- [Navigation](../panel/navigation.md) where icons show up in the shell.
