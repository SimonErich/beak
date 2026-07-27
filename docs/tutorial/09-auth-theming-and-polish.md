---
title: 9. Auth, theming, and polish
description: Add a login screen, a live theme toggle, a notification bell, the command bar, and maintenance pages, mostly by declaring config.
---

# 9. Auth, theming, and polish

By the end of this chapter the roastery admin looks and behaves like a finished
product: a login screen with register and recover, a light/dark toggle in the top
bar, a notification bell, a keyboard command bar, and maintenance and coming-soon
pages. Most of it is config on the `BeakPanelConfig` you already have. Two features
(the command bar and the theme toggle) are already in the shell, waiting.

## Guarding the shell with auth

Set `auth` on the panel config and Beak mounts `/login`, plus `/register` and
`/recover` when enabled, each rendered with obers_ui's auth page. The callbacks
return `true` on success. In a real store you wire them to your backend; for the
demo they accept anyone. Add this to your store's `buildReferencePanelConfig`:

```dart
auth: BeakAuthConfig(
  // Demo sign-in accepts anyone; wire these to your backend for real guards.
  onLogin: (email, password) async => true,
  onRegister: (name, email, password) async => true,
  onRecover: (email) async => true,
  // Auto-lock the shell after inactivity; /lock is always available too.
  idleLockTimeout: const Duration(minutes: 10),
  lockUserName: 'Barista',
  onUnlock: (password) async => true,
),
```

`register` and `recover` default to `true`, so those routes appear unless you turn
them off. `idleLockTimeout` sends the shell to `/lock` after that much inactivity;
`onUnlock` validates the password to return. Leave the lock fields out and the panel
never auto-locks.

## Theming: one setting, a live toggle

The panel starts in whichever mode you pick and carries a light/dark toggle in the
top bar for free. You do not build the toggle; the shell already wires one to the
theme controller. Choose the starting mode with `initialThemeMode`:

```dart
initialThemeMode: OiThemeMode.light,
```

That is the whole change. Load the panel and a sun/moon toggle sits in the top bar
beside the search icon; clicking it switches the whole app between light and dark
without a reload. To ship your own palette, pass `theme` and `darkTheme`
(`OiThemeData`) as well; the defaults are sensible, so this one line is enough to
start.

## A notification bell

Point the shell at a table of notifications and a bell with an unread badge appears
in the top bar, opening a side sheet of the rows, with mark-as-read writing back
through the data source. It binds a model's columns to the bell: which column is the
title, the body, the timestamp, the read flag, and the category.

The reference store has no notifications table yet, so add a small one. Create
`examples/store/lib/models/store_notification.dart`:

```dart
import 'package:beak_core/beak_core.dart';

/// Typed columns of a minimal notifications table for the store.
abstract final class StoreNotificationColumns {
  /// Primary key.
  static const id = BeakStringColumn(
    key: 'id',
    label: 'Id',
    visibleOn: {BeakContext.detail},
  );

  /// The headline shown in the bell.
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    rules: [BeakRequired()],
  );

  /// The longer body text.
  static const body = BeakTextColumn(key: 'body', label: 'Body');

  /// A grouping label (e.g. "orders", "stock").
  static const level = BeakStringColumn(key: 'level', label: 'Level');

  /// Whether the notification has been read.
  static const isRead = BeakBoolColumn(key: 'is_read', label: 'Read');

  /// When it was raised; used to order newest-first.
  static const createdAt = BeakDateTimeColumn(
    key: 'created_at',
    label: 'Created',
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    id,
    title,
    body,
    level,
    isRead,
    createdAt,
  ];
}

/// The notifications model behind the shell's bell.
final class StoreNotificationModel extends BeakModel {
  /// Creates the notifications model.
  const StoreNotificationModel();

  @override
  String get table => 'notifications';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => StoreNotificationColumns.values;
}
```

Then bind it in the panel config with `notifications`:

```dart
notifications: const BeakNotificationSource(
  model: StoreNotificationModel(),
  titleField: StoreNotificationColumns.title,
  bodyField: StoreNotificationColumns.body,
  timeField: StoreNotificationColumns.createdAt,
  readField: StoreNotificationColumns.isRead,
  categoryField: StoreNotificationColumns.level,
),
```

The `readField` is what turns on the unread badge and mark-as-read; the `timeField`
orders the list. There is no bell widget to write.

!!! question "What this skipped"
    A new model needs a table and some rows. This chapter added the model and the
    binding only; give it a migration (chapter 2) and a seeder (chapter 5), or
    register it as a full `BeakResource` if you also want a CRUD page for it. See
    [Migrations](../backend/migrations.md) and [Seeding](../backend/seeding.md).

## The command bar comes free

Press Ctrl-K (or Cmd-K) anywhere in the shell and a fuzzy-searchable palette opens
that jumps to any resource or page. You configure nothing: the commands are derived
from the resources and pages already on your config, grouped by their sidebar
section. The same palette is behind the search icon in the top bar. Two keystrokes
reach any destination in the store.

## Maintenance and coming-soon pages

Set `maintenance` and Beak mounts `/maintenance` and `/coming-soon`, each with a
live countdown when you give it a target time. Handy for a scheduled restock or a
storefront that has not opened yet. Add it to the config:

```dart
maintenance: BeakMaintenanceConfig(
  maintenanceTitle: 'Back in a moment',
  maintenanceDescription:
      'We are restocking the roastery and will be right back.',
  estimatedReturn: DateTime.utc(2026, 8, 1, 9),
  comingSoonTitle: 'Opening soon',
  comingSoonDescription: 'The roastery storefront is on its way.',
  launchAt: DateTime.utc(2026, 9, 1),
),
```

`estimatedReturn` drives the maintenance countdown; `launchAt` drives the
coming-soon one. Navigate to either route to see the page.

## Run it

With the backend up on port 8080, launch the panel:

```bash
cd examples/store
flutter run -d chrome
```

Chrome now opens on `/login` (the demo accepts any email and password). Once inside,
the top bar carries a search icon, a bell, and a light/dark toggle: click the toggle
and the whole panel switches theme; press Ctrl-K to open the command bar and jump to
Products by name. Visit `/maintenance` in the address bar to see the countdown page.
Leave the tab idle for ten minutes and the shell locks to `/lock`.

!!! note "What just happened"
    - `BeakAuthConfig` mounts login, register, recover, and an idle lock, all from
      callbacks you point at your backend.
    - `initialThemeMode` picks the starting theme; the shell's live toggle is already
      wired, no widget code.
    - `BeakNotificationSource` binds a model's columns to the bell and its read/write
      behaviour.
    - The Ctrl/Cmd-K command bar and the search button are derived from your config
      with no wiring.
    - `BeakMaintenanceConfig` mounts maintenance and coming-soon pages with
      countdowns.

## Continue reading

- [10. Wrap-up and where to fly next](10-wrap-up.md) take stock and pick a direction.
- [Auth and idle-lock](../panel/auth-and-idle-lock.md) the login flow and lock behaviour in depth.
- [Theming basics](../theming/theming-basics.md) light, dark, and your own palette.
- [The navigation shell](../panel/the-navigation-shell.md) the command bar, bell, and toggle.
- [Auth and policies](../backend/auth-and-policies.md) guarding the API itself, not only the panel.
