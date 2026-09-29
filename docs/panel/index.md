---
title: The panel
description: Compose resource screens, workflows and custom pages.
type: index
audience: [beginner, expert]
status: stable
---

# The panel

`BeakPanel` accepts resources, custom pages, themes, formatting and an API origin. Resource configuration supplies conventional routes, navigation, typed search and filters. Forms and wizards use one draft runtime and have their own section: [Forms and records](../forms/index.md).

```dart title="examples/clean_beak_config/lib/main.dart"
--8<-- "examples/clean_beak_config/lib/main.dart"
```

## Which page to read

| You want to… | Read | For |
| --- | --- | --- |
| Configure navigation, search and conventional screens around a shared model | [Resources](resources.md) | Guide for beginners |
| Build navigation from resources and custom pages | [Navigation](navigation.md) | Guide for beginners and experts |
| Configure typed list projections, permanent scopes and interactive filters | [Tables and filters](tables-and-filters.md) | Guide for beginners |
| Share one typed query across list presets, filters, summaries, saved views and exports | [Composed lists and query state](composed-lists.md) | Guide for experts |
| Keep shared model behavior while choosing a task-specific presentation | [View modes](view-modes.md) | Guide for beginners and experts |
| Expose model transitions and typed bulk edits with automatic validation and persistence | [Actions](actions.md) | Guide for beginners and experts |
| Open confirmations, modals, dialogs, side sheets and toasts from an action context | [Overlays](overlays.md) | Guide for experts |
| Compose dashboards and complete custom application screens from Beak blocks and widgets | [Custom screens](custom-screens.md) | Guide for beginners and experts |
| Combine live queries, aggregates and custom widgets on a page | [Dashboards](dashboards.md) | Guide for beginners |
| Configure Beak-owned login, registration and password recovery over one backend session authority | [Auth and idle-lock](auth-and-idle-lock.md) | Guide for beginners and experts |
| Use dedicated presentation states while controlling service access separately | [Maintenance and coming soon](maintenance-and-coming-soon.md) | Guide for beginners |

## Continue reading

- [Resources](resources.md): Configure navigation, search and conventional screens around a shared model.
- [Navigation](navigation.md): Build navigation from resources and custom pages.
- [Tables and filters](tables-and-filters.md): Configure typed list projections, permanent scopes and interactive filters.
