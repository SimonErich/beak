---
title: The shell
description: Customize shared navigation and actions while preserving responsive layout.
---

# The shell

The panel shell combines resource navigation, custom pages, global search, authentication actions and a theme switch. Panel configuration supplies titles, themes and optional shell actions.

The shell uses available panel width, so an embedded panel can switch to compact navigation independently of the surrounding window. Custom page content should use responsive grids or constraints as well. Use a custom screen when changing one task; replace the host shell only when the application needs a distinct navigation model.

## Workspace headers and search

A `BeakNavigation` workspace uses the shared `OiSidebarHeader`. Its title and
create action come from the configured workspace and its first visible resource
that permits creation. Set `showCreateAction: false` to omit that action. A
`headerBuilder` remains an escape hatch for genuinely different composition.
`OiSidebarThemeData.headerHeight`, `headerPadding` and `headerTextStyle` control
its design without an application widget.

Desktop global search is an `OiSearchTrigger`, a button that opens the command
bar. It never acquires an editable text connection or opens the mobile keyboard.
`BeakNavigation.searchShortcut` controls the visible hint; the existing Ctrl+K
and Meta+K shortcuts open the actual search overlay. The default hint is
`['meta', 'K']`; set `['⌘', 'K']` for a fixed Mac-style presentation or `[]` to
omit it. `components.searchTrigger` controls height, padding, decoration,
label typography and icon spacing. `OiKbd(combineKeys: true)` renders the hint
as one capsule.

The shell reserves the actual search width before placing trailing actions;
there is no leftover flexible allocation after the account menu. Use
`OiAppShellThemeData.actionSpacing` and `titleStyle` for the shared header.
Unread notifications use the independent `OiBadge.counter` role, so a large
status-pill theme cannot enlarge or obscure the bell. `OiBadgeThemeData.counter`
and `.token` accept `OiBadgeMetrics` for counts and short codes respectively.

## Continue reading

- [Navigation shell](../panel/the-navigation-shell.md)
- [Custom screens](../panel/custom-screens.md)
