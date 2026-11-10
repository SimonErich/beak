---
name: beak-frontend-theme
description: Set a Beak panel's look with BeakTheme, a built-in theme such as Gabel, or a small token override. Use when the panel should match a brand or switch between light and dark.
---

# Theme a panel

A panel takes one `BeakTheme`: a light `OiThemeData`, a dark one, and the
licences its fonts register.

## Steps

1. The built-in Gabel theme is one line, and its fonts stay opt-in:

   ```dart
   BeakPanelConfig(
     theme: GabelTheme(),
     // ...
   )
   ```

2. A host theme starts from the standard one and overrides tokens:

   ```dart
   BeakTheme(
     light: BeakTheme.standard().light.copyWith(
       colors: BeakTheme.standard().light.colors.copyWith(primary: brand),
     ),
     dark: BeakTheme.standard().dark,
   )
   ```

3. For a generated panel, set `theme.preset: gabel` in `beak.yaml` and run
   `beak prepare`; the generated config selects it.
4. Never copy a theme into the app. A one-off adjustment belongs in the theme
   file, and a reusable one belongs in a package.
5. Tests load bundled fonts explicitly: `loadGabelFonts()` from
   `package:beak_theme_gabel/testing.dart`.

## Gate

`flutter analyze`, the theme tests (goldens and font resolution), and a visual
check at 375 and 1440 pixels.

## Example prompt

> Use the beak-frontend-theme skill: give the panel the Gabel theme and make the brand colour the primary token in light mode.
