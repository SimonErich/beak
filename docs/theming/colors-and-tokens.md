---
title: Colors and tokens
description: The BeakColor semantic role enum, badge colors on enum columns, hex color columns, and how obers_ui tokens resolve per theme.
---

# Colors and tokens

After this page you can color a status badge by meaning rather than by hex,
understand why those colors change with the theme, and know when to reach for a
literal color instead.

Beak has two very different notions of "color", and keeping them straight saves
confusion. One is a **semantic role** (this badge means success). The other is a
**literal value** stored on a record (this event is `#663399`). Roles resolve
against the theme; literals are plain data.

## Semantic colors: `BeakColor`

`beak_core` is pure Dart. It never imports `dart:ui`, so it cannot name an actual
color. Instead it names roles, and `beak_frontend` resolves each role against the
active obers_ui theme. The full set is small on purpose:

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

Seven roles cover the states an admin panel actually shows. Because a column
names the role and the frontend resolves it, the same status badge reads
correctly in light mode, in dark mode, and under a branded theme, with no
per-column color work. A `BeakColor` is declared once and re-resolved everywhere
the value appears.

| Role | Typical use |
| --- | --- |
| `primary` | Brand accent, primary actions. |
| `secondary` | Secondary accent. |
| `success` | Published, paid, active, in stock. |
| `warning` | Pending, low stock, needs attention. |
| `error` | Rejected, failed, out of stock. |
| `info` | Neutral informational states. |
| `muted` | Draft, disabled, de-emphasized. |

## Badge colors on enum columns

The place you set roles most often is a `BeakEnumColumn`. Its `badgeColors` map
pairs each enum value with a `BeakColor`, and the column renders as a colored
badge in tables and a select control in forms. Here is the products model from
the tutorial store, quoted verbatim:

```dart
/// Lifecycle states of a product.
enum ProductStatus {
  /// Being drafted, not on sale.
  draft,

  /// Live in the catalog.
  published,

  /// Withdrawn from the catalog.
  archived,
}

/// Lifecycle state, rendered as a colored badge.
static const status = BeakEnumColumn<ProductStatus>(
  key: 'status',
  label: 'Status',
  values: ProductStatus.values,
  defaultValue: ProductStatus.draft,
  filterable: true,
  badgeColors: {
    ProductStatus.draft: BeakColor.muted,
    ProductStatus.published: BeakColor.success,
    ProductStatus.archived: BeakColor.warning,
  },
);
```

The generic parameter keeps the whole thing type-safe. `values`, `defaultValue`,
`badgeColors`, and the optional `labelOf` all speak in `ProductStatus`, so there
is no stringly-typed state anywhere. The column exposes typed lookups over the
map:

```dart title="packages/beak_core/lib/src/columns/beak_enum_column.dart"
/// The badge color configured for [value], or `null` when unmapped.
BeakColor? badgeColorFor(T value) => badgeColors[value];

/// The display label of [value]: [labelOf] when set, else `value.name`.
String labelFor(T value) => labelOf?.call(value) ?? value.name;
```

Any value you leave out of `badgeColors` falls back to the theme default, so you
only map the states you want to stand out.

!!! note "What just happened"
    One `const` column declaration gave the products table a colored status
    badge, gave the form a select control over the same three values, and made
    the column filterable. No color was hardcoded; `muted`, `success`, and
    `warning` all resolve against whichever theme is active.

## Literal colors: `BeakColorColumn`

Sometimes the color is the data. A calendar event stores its own color; a brand
row stores a swatch. That is a `BeakColorColumn`, which holds a hex string and
renders as a swatch with a color picker in forms:

```dart title="packages/beak_core/lib/src/columns/beak_color_column.dart"
/// A color column holding hex strings (e.g. `#663399`), rendered as a
/// swatch with a color picker in forms.
final class BeakColorColumn extends BeakColumn {
  /// Creates a color column.
  const BeakColorColumn({
    required super.key,
    required super.label,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.rules,
  });

  /// Values are hex color strings.
  @override
  Type get valueType => String;
}
```

The superdashboard's calendar events use one so an organizer can override a
category's color per event:

```dart title="examples/superdashboard/lib/models/calendar/calendar_event.dart"
/// Event color (overrides the category color when set).
static const color = BeakColorColumn(
  key: 'color',
  label: 'Color',
  visibleOn: {BeakContext.form, BeakContext.detail},
);
```

The difference is worth holding onto. A `BeakColor` role does not change when the
data changes; it changes when the theme changes. A `BeakColorColumn` value does
not change when the theme changes; it changes when a user edits the record.

## obers_ui design tokens

Underneath the roles sits the theme's full token set. `OiThemeData` aggregates
colors, typography, spacing, radii, shadows, animations, and effects into one
immutable object, and every obers_ui widget reads from it. When `beak_frontend`
resolves a `BeakColor`, it is reading `context.colors` off that theme, which is
why the same role looks right under `OiThemeData.light()`, `OiThemeData.dark()`,
and a branded `OiThemeData.fromBrand(...)`. You set the theme once
([Theming basics](theming-basics.md)); the tokens do the rest.

## Continue reading

- [Column types](../models/column-types.md) the enum and color columns among all thirteen.
- [Typography and icons](typography-and-icons.md) the other half of the visual vocabulary.
- [Rendering per surface](../concepts/rendering-per-surface.md) how one column renders as a badge here and a select there.
- [Theming basics](theming-basics.md) the theme these tokens resolve against.
