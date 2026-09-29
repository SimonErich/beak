# Theming and formatting

> Style the panel with one theme, resolve semantic colors, set type and icons, and choose how numbers, money, dates and built-in text are written.

A panel has two looks to get right. One is how it is drawn: colors, type, icons, dark mode. The other is how it writes: `1.234,50 €` or `€1,234.50`, `29.09.2026` or `Tue 29 Sep`, `Speichern` or `Save`. This section shows where each is set, so you can tell which knob to turn without reading the widget code.

Beak has no design system of its own. Every table, form, card and dialog is an `obers_ui` widget, and none of Beak's widgets import `package:flutter/material.dart` or `cupertino.dart`. They read colors, spacing, radii and text styles from one `OiThemeData`, so you style a panel by handing it a theme, not by overriding widgets one at a time.

Colors are roles, not values. A column or an action names `BeakColor.success`, and `beak_frontend` resolves it against the active theme, so the same schema draws its badges in a light theme and in a dark one.

Formatting is a separate axis. A theme never changes how a number looks, and a format policy never changes a color. They meet in one place, the panel's configuration.

## Which page to read

| You want to... | Read | For that |
| --- | --- | --- |
| Give the panel a light and a dark theme from one brand color, and pick the starting mode | [Theming basics](theming-basics.md) | The first theme, wired into a generated or an authored panel |
| Know which theme color a `BeakColor` becomes, or build a full palette from a design system | [Colors and tokens](colors-and-tokens.md) | The mapping on badges, buttons and charts, and Foodio's palette |
| Load a font, set the text styles, or replace every icon | [Typography and icons](typography-and-icons.md) | The type ramp, the variable-font trap and the icon map |
| Set the locale, currency and date patterns, or switch Beak's own text to German | [Formatting and localization](formatting-and-localization.md) | `BeakFormatting`, the export policy and what is translated |

## Where the knobs live

Two objects carry nearly everything: `BeakPanelConfig`, the declarative surface an app sets, and `OiThemeData`, the theme value it hands over. The `BeakPanel(...)` shorthand takes some of the config's fields, and a generated panel sets the rest in `lib/panel.dart` and `lib/theme.dart`.

| Knob | Set on | Page |
| --- | --- | --- |
| `theme`, `darkTheme` | `BeakPanel`, `BeakPanelConfig`, or `lib/theme.dart` in a generated panel | [Theming basics](theming-basics.md) |
| `initialThemeMode` | `BeakPanelConfig` | [Theming basics](theming-basics.md) |
| The theme toggle | `BeakNavigation.showThemeToggle` | [Theming basics](theming-basics.md) |
| `sidebarCollapsible`, `sidebarDefaultCollapsed` | `BeakPanelConfig`, or `theme.sidebar` in `beak.yaml` | [Theming basics](theming-basics.md) |
| A swatch, a surface, a text or a border color | the theme's `OiColorScheme` | [Colors and tokens](colors-and-tokens.md) |
| Font family, text styles | `OiThemeData.light(fontFamily:)`, `textTheme` | [Typography and icons](typography-and-icons.md) |
| Icons | `BeakIconToken` on a destination, `components.icon` on the theme | [Typography and icons](typography-and-icons.md) |
| Numbers, money, dates, empty cells | `formatting:` | [Formatting and localization](formatting-and-localization.md) |
| Language of Beak's controls | `locale:`, `supportedLocales`, `localizationsDelegates` | [Formatting and localization](formatting-and-localization.md) |

Start with [Theming basics](theming-basics.md), which is short and covers the everyday case. Formatting is worth reading before the first release: the tables, the forms and the CSV export take their time zone from it, and the defaults do not all agree.

## Continue reading

- [Theming basics](theming-basics.md) start here to theme a panel from one color.
- [Formatting and localization](formatting-and-localization.md) the other half of how a panel looks.
- [Foodio](../examples/foodio.md) a complete custom theme, type ramp and icon set in a real panel.
- [Panel options](../reference/panel-options.md) every field of `BeakPanelConfig` and `BeakFormatting`.
