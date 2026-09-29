# Theming and formatting

> Style the panel: themes, colors, type, icons, and how values are formatted.

By the end of this section you will know exactly which knob controls the panel's
look: the theme it boots with, the semantic colors your badges resolve to, the
type ramp and icon set your screens draw from, and how dates, numbers and
currency are formatted.

Beak does not ship its own design system. Every visible pixel comes from
`obers_ui`, the same widget kit Beak's blocks are built on. That has one large
consequence worth stating up front.

## No Material, ever

A Beak panel never imports `package:flutter/material.dart` or `cupertino.dart`.
Buttons, cards, tables, inputs, and the app shell are all obers_ui widgets, and
they read their colors, spacing, radii, and typography from a single
`OiThemeData` object. You style the panel by handing Beak a theme, not by
sprinkling widget-level overrides. One theme in, a consistent panel out.

That also means colors are semantic, not literal. A `beak_core` column never
names a hex value for a status badge. It names a role (`BeakColor.success`), and
`beak_frontend` resolves that role against the active theme. Flip to dark mode
and every badge, action, and status dot re-resolves without you touching a
column. A `BeakColor` is declared once and read everywhere.

## Which page to read

| You want to… | Read | For |
| --- | --- | --- |
| Set light and dark themes once at the panel boundary | [Theming basics](theming-basics.md) | Guide for beginners |
| Apply semantic colors consistently across built-in and custom content | [Colors and tokens](colors-and-tokens.md) | Guide for experts |
| Use the theme type scale and typed navigation icons | [Typography and icons](typography-and-icons.md) | Guide for experts |
| Set the locale, currency and date patterns a panel formats with | [Formatting and localization](formatting-and-localization.md) | Guide for beginners and experts |

## Where the knobs live

Two objects hold nearly all of it:

- **`BeakPanelConfig`** carries `theme`, `darkTheme`, `initialThemeMode`,
  `sidebarCollapsible`, and `sidebarDefaultCollapsed`. This is the declarative
  surface app authors set.
- **`OiThemeData`** (from obers_ui) is the theme itself: colors, typography,
  spacing, radii, shadows. You hand one to the config, or let Beak default to
  `OiThemeData.light()` and `OiThemeData.dark()`.

Start with [Theming basics](theming-basics.md) to see both wired together, then
follow the section down into colors, type, icons and formatting.

## Continue reading

- [Theming basics](theming-basics.md): Set light and dark themes once at the panel boundary.
- [Colors and tokens](colors-and-tokens.md): Apply semantic colors consistently across built-in and custom content.
- [Typography and icons](typography-and-icons.md): Use the theme type scale and typed navigation icons.
