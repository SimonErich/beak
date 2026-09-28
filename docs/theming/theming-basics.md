---
title: Theming basics
description: Set light and dark themes once at the panel boundary.
---

# Theming basics

Pass `theme` and `darkTheme` to `BeakPanel`, or configure them through `BeakPanelConfig`. Beak uses Obers UI widgets and tokens throughout the shell, forms and blocks. The theme controller exposes the current mode to custom widgets.

Use semantic colors and typography from the nearest theme rather than hardcoded values. Set data formatting separately through `BeakFormatting`; a color theme should not alter currency or date meaning.

```dart title="examples/clean_beak_config/lib/main.dart"
--8<-- "examples/clean_beak_config/lib/main.dart"
```

## Continue reading

- [Colors and tokens](colors-and-tokens.md)
- [Typography and icons](typography-and-icons.md)
