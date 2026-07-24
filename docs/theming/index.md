---
title: Styling and theming
description: How a Beak panel gets its look, from the light/dark theme to colors, type, icons, and the shell layout.
---

# Styling and theming

By the end of this section you will know exactly which knob controls the panel's
look: the theme it boots with, the semantic colors your badges resolve to, the
type ramp and icon set your screens draw from, and the shape of the shell around
them.

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

## What lives where

| Page | What it covers |
| --- | --- |
| [Theming basics](theming-basics.md) | The light and dark `OiThemeData`, the `theme` / `darkTheme` / `initialThemeMode` config fields, and the live `BeakThemeController` toggle. |
| [Colors and tokens](colors-and-tokens.md) | The `BeakColor` role enum, badge colors on enum columns, hex color columns, and how obers_ui design tokens resolve per theme. |
| [Typography and icons](typography-and-icons.md) | The `BeakTextVariant` type ramp, `BeakTextBlock`, `BeakIconToken` over `OiIcons`, and the icon gallery. |
| [The shell](the-shell.md) | The collapsible sidebar, framed versus full-bleed screens, and how the app shell wraps every route. |

## Where the knobs live

Two objects hold nearly all of it:

- **`BeakPanelConfig`** carries `theme`, `darkTheme`, `initialThemeMode`,
  `sidebarCollapsible`, and `sidebarDefaultCollapsed`. This is the declarative
  surface app authors set.
- **`OiThemeData`** (from obers_ui) is the theme itself: colors, typography,
  spacing, radii, shadows. You hand one to the config, or let Beak default to
  `OiThemeData.light()` and `OiThemeData.dark()`.

Start with [Theming basics](theming-basics.md) to see both wired together, then
follow the section down into colors, type, and the shell.

## Continue reading

- [Theming basics](theming-basics.md) the theme objects and the live light/dark toggle.
- [Colors and tokens](colors-and-tokens.md) semantic colors, badge colors, and design tokens.
- [Typography and icons](typography-and-icons.md) the text ramp and the icon set.
- [The shell](the-shell.md) the sidebar and page framing around your screens.
