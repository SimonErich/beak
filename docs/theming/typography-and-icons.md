---
title: Typography and icons
description: The BeakTextVariant type ramp, BeakTextBlock, typed icon tokens over OiIcons, and the icon gallery.
---

# Typography and icons

After this page you can drop themed text at any size onto a screen, reference an
icon in a resource or screen without touching raw icon plumbing, and build a
labelled icon reference grid.

Both text and icons follow the same rule as colors: you name the intent, not the
pixels. Text names a variant in a ramp; icons name a token over the obers_ui
`OiIcons` set. The theme decides how each one actually looks.

## The type ramp

`BeakTextVariant` is the whole type scale, from a hero display size down to a
caption:

```dart title="packages/beak_frontend/lib/src/blocks/beak_text_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_text_block.dart:BeakTextVariant"
```

You render a variant with a `BeakTextBlock`. It takes the text and a variant, and
paints onto the matching obers_ui `OiLabel`:

```dart title="packages/beak_frontend/lib/src/blocks/beak_text_block.dart"
/// A run of themed text.
///
/// Renders onto the matching `OiLabel` variant.
final class BeakTextBlock extends BeakBlock {
  /// Creates a text block showing [text].
  const BeakTextBlock(
    this.text, {
    this.variant = BeakTextVariant.body,
    super.span,
  });

  /// The text to show.
  final String text;

  /// The typographic variant.
  final BeakTextVariant variant;
}
```

The variant defaults to `body`, so plain paragraph text is
`BeakTextBlock('some copy')`. The superdashboard's typography screen shows the
whole ramp in one card:

```dart title="examples/superdashboard/lib/screens/typography_screen.dart"
--8<-- "examples/superdashboard/lib/screens/typography_screen.dart:buildTypographyScreen"
```

Every line inherits the theme's font family and sizes. Change the theme's
`fontFamily` and the whole ramp shifts together, because there is one
`OiTextTheme` behind all nine variants.

| Variant | Role |
| --- | --- |
| `display` | Hero display text. |
| `h1` to `h4` | Page, section, sub-section, and minor headings. |
| `body` | Regular paragraph copy (the default). |
| `bodyStrong` | Emphasized paragraph copy. |
| `small` | De-emphasized secondary text. |
| `caption` | The smallest label or hint. |

## Icons: `BeakIconToken` over `OiIcons`

Every icon in a Beak panel is an `OiIcons` value (the Lucide set) wrapped in a
`BeakIconToken`. The token is a zero-cost wrapper so resource and screen
declarations stay expressive without leaking raw icon plumbing into the config
surface:

```dart title="packages/beak_frontend/lib/src/panel/beak_panel_config.dart"
/// A typed icon reference for panel navigation.
///
/// A zero-cost wrapper over [IconData] so resource declarations stay
/// expressive (`BeakIconToken(OiIcons.package)`) without leaking raw icon
/// plumbing into Beak's config surface. Wrap any obers_ui `OiIcons` value.
extension type const BeakIconToken(IconData icon) {}
```

You have already seen it in use. A resource takes one for its sidebar entry
(`icon: BeakIconToken(OiIcons.package)`), and so does a custom screen. It is the
one type you use wherever Beak asks for an icon.

## The icon gallery

To document or preview the icon set on a screen, pair `BeakIconGalleryBlock` with
`BeakIconGalleryItem`. Each item ties a token to a label, and the block lays them
out in a grid:

```dart title="packages/beak_frontend/lib/src/blocks/beak_icon_gallery_block.dart"
/// One labelled icon in a [BeakIconGalleryBlock].
final class BeakIconGalleryItem {
  /// Creates an entry pairing [icon] with its [label].
  const BeakIconGalleryItem({required this.icon, required this.label});

  /// The icon to display.
  final BeakIconToken icon;

  /// The name shown beneath the icon.
  final String label;
}

/// A reference grid of named icons — a design-system cheat-sheet. Each entry
/// renders onto `OiIcon` with its label beneath.
final class BeakIconGalleryBlock extends BeakBlock {
  /// Creates a gallery of [items] laid out in [columns] columns.
  const BeakIconGalleryBlock({
    required this.items,
    this.columns = 6,
    super.span,
  });

  /// The icons to display.
  final List<BeakIconGalleryItem> items;

  /// The number of grid columns.
  final int columns;
}
```

The superdashboard's icons screen builds a curated slice of the set from a list
of token/label pairs:

```dart title="examples/superdashboard/lib/screens/icons_screen.dart"
--8<-- "examples/superdashboard/lib/screens/icons_screen.dart:buildIconsScreen"
```

Where `_icons` is a plain list of pairs, each one a
`(BeakIconToken(OiIcons.home), 'home')` and so on. Every entry renders onto an
`OiIcon`, so the icons pick up the theme's sizing and color like everything else.

!!! tip "Finding an icon name"
    `OiIcons` mirrors the Lucide set, so the name you want is usually the Lucide
    name in camelCase (`layoutDashboard`, `creditCard`, `messageCircle`). The
    icons screen above is a live gallery of the common ones.

## Continue reading

- [Display blocks](../blocks/display-blocks.md) `BeakTextBlock` and the icon gallery among the display blocks.
- [Colors and tokens](colors-and-tokens.md) the color side of the visual vocabulary.
- [Custom screens](../panel/custom-screens.md) how the typography and icon screens are registered.
- [The shell](the-shell.md) where these screens sit in the navigation.
