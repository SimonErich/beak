---
title: The navigation shell
description: Build navigation from resources and custom pages.
---

# The navigation shell

Resource titles, icons, groups and ranks define navigation. Custom pages supply their own paths and optional navigation entries. A page at `/` replaces the default dashboard. Conventional resource paths are built by `BeakRoutes`.

The shell supplies global search, theme controls and optional authentication actions. It resolves responsive navigation against the panel's available width, including embedded and split-view layouts. Custom shell actions can be supplied through panel configuration. Resource visibility is presentation; enforce access through server policies.

```dart title="examples/clean_beak_config/lib/main.dart"
--8<-- "examples/clean_beak_config/lib/main.dart"
```

## Contextual navigation

`BeakNavigation` adds a primary workspace rail and contextual resource destinations. `BeakNavigationSection` supplies its icon, label and items; `bottom: true` anchors utility sections below the main destinations. Resource items can open a named list preset, while page items target registered custom screens. Each section lands on its first visible item. Existing resource permissions determine visibility.

`headerBuilder` can supply a workspace heading, `leading` a rail brand, `userMenu` an account menu, and `searchPlaceholder` a command-search hint. These slots reuse the shell routing and search lifecycle. `showThemeToggle` controls the shared theme action; application help actions belong in `shellActions`. A `BeakNotificationSource` binds the built-in bell to normal model fields and refreshes after source invalidation. The sidebar wrapper follows the sidebar theme, including its header and footer.

Header search becomes an icon button on compact screens, retaining the configured
search hint as its accessible name and opening the same global command search.
Beak wires this Obers shell fallback automatically; no compact-screen callback or
application widget is needed.

Set `showCount: true` on a resource navigation item to show its live result count. Beak applies that resource's permanent list query and the destination's explicit or initial preset, using the same authorized data source as the list. Only visible destinations in the active workspace are queried. Counts refresh after mutations and invalidations; loading or unavailable counts show an em dash. No application count request or state controller is needed.

`OiSidebarThemeData.plainBadges` and `badgeTextStyle` style navigation counts
independently of status badges. `labelGap`, `itemSpacing`, `selectedIconColor`
and `selectedBorderColor` refine navigation density and selection. Selection
outlines do not shift labels. These options also apply to ordinary Obers sidebars.

Workspace headers can include ordinary routed actions, such as an `OiButton.icon` that opens `BeakRoutes.create(model.table)`. `OiUserMenu.avatar` accepts a themed `OiAvatar` when the account trigger needs a different size or palette; the menu continues to own its interactions and accessibility.

The shell can include the current record, using the model display field rather than the raw identity. Generated links retain the originating list query; the shared Back action restores it. Set `sidebarCollapsible: false` to keep a fixed contextual sidebar. Full-screen form routes replace shell presentation while preserving the route's authentication checks.

## Continue reading

- [Declarative resources](../concepts/declarative-resources.md)
- [Custom screens](../extending/custom-screens-and-pages.md)

- [Composed lists and query state](composed-lists.md)
