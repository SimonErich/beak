---
title: Maintenance and coming soon
description: Mount a maintenance screen and a coming-soon screen from config with BeakMaintenanceConfig, each with an optional live countdown.
---

# Maintenance and coming soon

After this page you can give the panel two holding pages: a maintenance screen for
when the service is down, and a coming-soon screen for a feature that has not
launched. You declare both with one `BeakMaintenanceConfig`, and each can show a
live countdown.

## Turning it on

Set `maintenance` on the config. Beak mounts `/maintenance` and `/coming-soon`, each
rendered with obers_ui's `OiMaintenancePage`.

```dart title="packages/beak_frontend/lib/src/panel/beak_maintenance_config.dart"
const BeakMaintenanceConfig({
  this.maintenanceTitle = 'Under maintenance',
  this.maintenanceDescription,
  this.estimatedReturn,
  this.comingSoonTitle = 'Coming soon',
  this.comingSoonDescription,
  this.launchAt,
});
```

The two screens share one config object but read different fields. The maintenance
screen uses `maintenanceTitle`, `maintenanceDescription`, and `estimatedReturn`; the
coming-soon screen uses `comingSoonTitle`, `comingSoonDescription`, and `launchAt`.

```dart title="apps/beak_superdashboard/lib/panel/config.dart"
maintenance: BeakMaintenanceConfig(
  maintenanceTitle: 'Under maintenance',
  maintenanceDescription:
      'We are performing scheduled maintenance and will be back shortly.',
  estimatedReturn: DateTime.utc(2026, 7, 8, 12),
  comingSoonTitle: 'Coming soon',
  comingSoonDescription: 'Something great is on the way.',
  launchAt: DateTime.utc(2026, 8, 1),
),
```

## The countdown

A `DateTime` in `estimatedReturn` (maintenance) or `launchAt` (coming-soon) turns on
a live countdown on that screen. Leave the date null and the screen renders without
one. Beak decides `showCountdown` from whether the date is present:

```dart title="packages/beak_frontend/lib/src/panel/beak_router.dart"
GoRoute(
  path: '/maintenance',
  builder: (context, state) => OiMaintenancePage(
    label: maintenance.maintenanceTitle,
    title: maintenance.maintenanceTitle,
    description: maintenance.maintenanceDescription,
    estimatedReturn: maintenance.estimatedReturn,
    showCountdown: maintenance.estimatedReturn != null,
  ),
),
GoRoute(
  path: '/coming-soon',
  builder: (context, state) => OiMaintenancePage(
    label: maintenance.comingSoonTitle,
    title: maintenance.comingSoonTitle,
    description: maintenance.comingSoonDescription,
    estimatedReturn: maintenance.launchAt,
    showCountdown: maintenance.launchAt != null,
  ),
),
```

!!! note "What just happened"
    - `launchAt` maps onto the same `estimatedReturn` slot of `OiMaintenancePage`; it
      is the coming-soon screen's countdown target, named for its role.
    - Both dates are UTC in the demo (`DateTime.utc(...)`), which keeps the countdown
      stable regardless of where the panel runs.

## Sending users there

Like the [auth screens](auth-and-idle-lock.md), these routes live outside the shell,
so they render full-page with no sidebar. Beak does not redirect traffic to them on
its own; it gives you the screens and the routes. You decide when a user lands on
`/maintenance` or `/coming-soon`, whether that is a feature flag in your app, a build
that ships with the flag on, or a redirect at your reverse proxy.

Leave `maintenance` null on the config and neither route exists.

## Reference

`BeakMaintenanceConfig` fields and defaults:

| Field | Type | Default | Purpose |
| --- | --- | --- | --- |
| `maintenanceTitle` | `String` | `'Under maintenance'` | Heading of `/maintenance`. |
| `maintenanceDescription` | `String?` | `null` | Supporting copy of `/maintenance`. |
| `estimatedReturn` | `DateTime?` | `null` | Maintenance countdown target; null hides it. |
| `comingSoonTitle` | `String` | `'Coming soon'` | Heading of `/coming-soon`. |
| `comingSoonDescription` | `String?` | `null` | Supporting copy of `/coming-soon`. |
| `launchAt` | `DateTime?` | `null` | Coming-soon countdown target; null hides it. |

## Continue reading

- [Auth and idle-lock](auth-and-idle-lock.md) the other config-mounted routes that live outside the shell.
- [The navigation shell](the-navigation-shell.md) the shell these holding pages sit outside of.
- [The panel](index.md) the full picture of what `BeakPanelConfig` assembles.
- [Configuration options](../reference/configuration-options.md) every `BeakPanelConfig` field in one table.
