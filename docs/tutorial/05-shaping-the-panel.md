---
title: Shaping the panel
description: Arrange resources, forms and custom content without rebuilding data plumbing.
type: tutorial
audience: [beginner]
status: draft
---

# Shaping the panel

Keep navigation and search in resource definitions. Keep the input arrangement in screen files. Register those resources and any custom pages in the panel.

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart"
```

## Forms and tables

Generated fields provide input, formatting and filter helpers. Use cards, columns, sections and tabs to group related work. Wizard steps share the same draft runtime as ordinary forms; changing presentation does not change persistence.

`BeakFormSections` projects reusable sections into tabs, a plain layout or wizard steps. Group conditions can disable a complete section. Read mode displays values in the same structure.

## Custom content

The shop overview and Operations page combine live data blocks with custom widgets. `BeakScreen` supplies standalone pages; `BeakCustomResourceScreen` replaces selected resource routes. `BeakWidgetBlock` embeds a widget inside a block layout.

Custom widgets obtain the active panel's services through `beakDependencies(context)`. Reuse its repository, formatting and mutation notifications so custom content stays consistent with generated screens. Ordinary forms need no such access.

## Search and filtering

A resource declares global search sources and table filters with typed fields. Related paths request the necessary joins or loads. Standard controls expose loading, errors and retry while queries run.

## Continue reading

- [Testing and shipping](06-auth-tests-and-shipping.md)
- [Custom screens](../panel/custom-screens.md)
