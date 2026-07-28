---
title: The navigation shell
description: The chrome around every panel page: a section-grouped sidebar, a Ctrl/Cmd-K command bar, a notification bell, and a theme toggle, all generated from config.
---

# The navigation shell

After this page you can drive the frame that wraps every panel page: the sidebar
that lists your resources and screens, the command bar that jumps anywhere with two
keystrokes, the notification bell, and the light/dark toggle. All four come from
config. You configure; Beak wires the shell.

Every routed page renders inside one `OiAppShell`: a sidebar on the left, a top bar
with actions on the right, and your page in the middle. The shell is preserved
across navigations, so switching pages never rebuilds the frame.

## The sidebar and sections

The sidebar is generated from your config. Beak walks the resources and the in-nav
screens and emits one `OiNavItem` each, grouped by an optional `section` heading.

```dart title="packages/beak_frontend/lib/src/panel/beak_router.dart"
navigation: [
  if (!_hasHomePage(config))
    const OiNavItem(
      label: 'Dashboard',
      icon: OiIcons.layoutDashboard,
      route: '/',
    ),
  for (final resource in config.resources)
    OiNavItem(
      label: resource.effectiveLabel,
      icon: resource.icon.icon,
      route: resource.route,
      section: resource.section,
    ),
  for (final screen in config.pages)
    if (screen.showInNav)
      OiNavItem(
        label: screen.effectiveLabel,
        icon: screen.icon.icon,
        route: screen.path,
        section: screen.section,
      ),
],
```

Three things fall out of this:

- A "Dashboard" entry points at `/`, unless a custom page already claims that route
  (see [Custom screens](custom-screens.md)).
- Resources and screens with the same `section` string cluster under one heading.
  Leave `section` null and the item sits ungrouped at the top.
- A screen with `showInNav: false` gets a route but no sidebar entry.

Two config flags shape the sidebar itself: `sidebarCollapsible` lets the user
collapse it, and `sidebarDefaultCollapsed` decides its starting state. Both live on
`BeakPanelConfig`.

## The command bar (Ctrl/Cmd-K)

The shell binds Ctrl-K and Cmd-K to open a fuzzy-searchable palette that jumps to
any resource or screen. The keybinding is registered on the shell with
`CallbackShortcuts`, so it works from anywhere inside the panel.

```dart title="packages/beak_frontend/lib/src/panel/beak_router.dart"
bindings: {
  const SingleActivator(LogicalKeyboardKey.keyK, control: true):
      openCommandBar,
  const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
      openCommandBar,
},
```

`openBeakCommandBar` opens the palette as a dialog over an `OiCommandBar`, and the
commands come straight from your config, so every navigable destination is
reachable without per-app wiring.

```dart title="packages/beak_frontend/lib/src/panel/beak_command_bar.dart"
--8<-- "packages/beak_frontend/lib/src/panel/beak_command_bar.dart:openBeakCommandBar"
```

`beakNavigationCommands` builds one command per resource and in-nav screen, plus a
Dashboard command when no page claims `/`. Commands carry the same section as the
sidebar, so the palette groups the same way.

```dart title="packages/beak_frontend/lib/src/panel/beak_command_bar.dart"
--8<-- "packages/beak_frontend/lib/src/panel/beak_command_bar.dart:beakNavigationCommands"
```

!!! note "What just happened"
    - The command bar is purely client-side navigation. It does not hit the backend.
      For record-level search across models, see
      [Search and export](../backend/search-and-export.md).
    - `keywords: const ['open', 'go to']` widen the fuzzy match, so typing "open
      orders" finds the Orders resource.

## The notification bell

Bind a model's rows to the bell and Beak drops a badge into the top bar with the
unread count. The binding is a `BeakNotificationSource`: which columns carry the
title, body, timestamp, read flag, and category.

```dart title="packages/beak_frontend/lib/src/panel/beak_notifications.dart"
const BeakNotificationSource({
  required this.model,
  required this.titleField,
  this.bodyField,
  this.timeField,
  this.readField,
  this.categoryField,
});
```

Set it on `BeakPanelConfig.notifications` and the bell appears with no widget code
on your side.

```dart title="examples/superdashboard/lib/panel.dart"
notifications: const BeakNotificationSource(
  model: NotificationModel(),
  titleField: NotificationColumns.title,
  bodyField: NotificationColumns.body,
  timeField: NotificationColumns.createdAt,
  readField: NotificationColumns.isRead,
  categoryField: NotificationColumns.level,
),
```

Clicking the bell opens a side sheet listing the source's rows on
`OiNotificationCenter`, newest first when `timeField` is set. When `readField` is
set, the badge counts unread rows and "mark as read" writes `true` back through the
data source. Leave `notifications` null and the bell does not render.

## The theme toggle

The top bar carries a light/dark/system toggle. It is driven by a
`BeakThemeController`, a `ValueNotifier<OiThemeMode>` held in the panel's DI
container so the toggle can flip the mode and the root `BeakPanel` rebuilds with it.

```dart title="packages/beak_frontend/lib/src/panel/beak_theme_controller.dart"
--8<-- "packages/beak_frontend/lib/src/panel/beak_theme_controller.dart:BeakThemeController"
```

You rarely touch the controller directly. What you set is the starting mode on the
config:

```dart title="examples/superdashboard/lib/panel.dart"
initialThemeMode: OiThemeMode.light,
```

The look of each mode comes from `theme` and `darkTheme` on the config. Those are
covered in [The shell](../theming/the-shell.md).

## Reference

The shell reads these `BeakPanelConfig` fields:

| Field | Effect on the shell |
| --- | --- |
| `title` | The shell label and title. |
| `resources` / `pages` | The sidebar entries and command-bar destinations. |
| `sidebarCollapsible` | Whether the user can collapse the sidebar. |
| `sidebarDefaultCollapsed` | The sidebar's starting state. |
| `notifications` | A `BeakNotificationSource`, or null for no bell. |
| `initialThemeMode` | The theme mode the toggle starts in. |
| `theme` / `darkTheme` | The `OiThemeData` for each mode. |

The command-bar entry points are `openBeakCommandBar(context, config)` and
`beakNavigationCommands(config, go)`; both are exported from `beak_frontend`.

## Continue reading

- [Custom screens](custom-screens.md) how screens and sections you add show up in the sidebar and command bar.
- [Auth and idle-lock](auth-and-idle-lock.md) the login, register, recover, and lock routes that live outside the shell.
- [The shell](../theming/the-shell.md) theming the shell, `theme` and `darkTheme`, and the toggle's look.
- [Resources](resources.md) how each resource earns its sidebar entry and generated pages.
