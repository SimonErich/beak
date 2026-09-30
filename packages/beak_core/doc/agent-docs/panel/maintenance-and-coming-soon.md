# Maintenance and coming soon

> Mount /maintenance and /coming-soon pages with countdowns, and redirect every route to one of them. They are presentation only and do not block the API.

You are about to migrate a database, or launch a panel next month, and you want a page that says so. `BeakMaintenanceConfig` gives the panel two ready-made pages for that, and one switch, `redirectTo`, that sends every visitor to one of them. Neither page stops a request: the API keeps answering.

## At a glance

| | |
| --- | --- |
| Config | `BeakPanelConfig.maintenance`, a `BeakMaintenanceConfig?`. `null` mounts neither page |
| Routes | `/maintenance` and `/coming-soon`, outside the shell, so no sidebar |
| Rendered by | obers_ui `OiMaintenancePage` |
| Countdown | Only when `estimatedReturn` (maintenance) or `launchAt` (coming soon) is set |
| Redirect to them | Only with `redirectTo`. Without it you send people there |
| Stops API traffic | No |
| Signed out | Reachable. Both are public paths for the auth redirect |
| Where you can set it | `BeakPanelConfig.maintenance`, or `maintenance:` on the `BeakPanel(...)` shorthand |

## Mount the pages

**Generated panel**

The generated panel builds its `BeakPanelConfig` for you, and `lib/panel.dart` has the last word on it. `beak eject panel` writes that file, returning the config unchanged:

```console
$ beak eject panel
  created lib/panel.dart

  run `beak prepare` to wire it up
```

Add the pages with `copyWith`:

```dart title="lib/panel.dart"
import 'package:beak/panel.dart';

/// The last word on this panel's configuration.
///
/// [defaults] is everything `beak.yaml`, the models, the resource classes and
/// `lib/screens/` produced. Return it to change nothing, or `copyWith` the
/// parts you want different: the resources list, the notification source.
BeakPanelConfig beakPanel(BeakPanelConfig defaults) => defaults.copyWith(
  maintenance: BeakMaintenanceConfig(
    maintenanceDescription: 'We are upgrading the database.',
    estimatedReturn: DateTime.utc(2026, 10, 3, 6),
    launchAt: DateTime.utc(2026, 11, 1, 8),
  ),
);
```

`beak prepare` finds the file and ends `buildBeakPanel()` with `return panel.beakPanel(config);`.

**Authored panel**

Give `BeakPanel` a `maintenance:` argument, or put it on the `BeakPanelConfig` you pass as `config:`. From the package's own routing test:

```dart title="packages/beak_frontend/test/src/panel/beak_screen_routing_test.dart"
maintenance: const BeakMaintenanceConfig(
  maintenanceTitle: 'Back soon',
  comingSoonTitle: 'Launching',
),
```

A shared configuration can turn the pages on for one environment. Illustrative, with the real `copyWith`:

```dart
final staging = config.copyWith(
  title: 'Acme staging',
  maintenance: const BeakMaintenanceConfig(),
);
```

That is the whole setup. Open `/maintenance` or `/coming-soon` and the page is there, with its default English title if you set none.

## What the pages show

The constructor has seven optional named arguments, three per page and the redirect:

```dart title="packages/beak_frontend/lib/src/panel/beak_maintenance_config.dart"
const BeakMaintenanceConfig({
  this.maintenanceTitle = 'Under maintenance',
  this.maintenanceDescription,
  this.estimatedReturn,
  this.comingSoonTitle = 'Coming soon',
  this.comingSoonDescription,
  this.launchAt,
  this.redirectTo,
});
```

| Page | Title | Text | Countdown |
| --- | --- | --- | --- |
| `/maintenance` | `maintenanceTitle`, default `Under maintenance` | `maintenanceDescription` | `estimatedReturn` |
| `/coming-soon` | `comingSoonTitle`, default `Coming soon` | `comingSoonDescription` | `launchAt` |

Each page is an `OiMaintenancePage` built by the router:

```dart title="packages/beak_frontend/lib/src/panel/beak_router.dart"
List<RouteBase> _maintenanceRoutes(BeakMaintenanceConfig? maintenance) {
  if (maintenance == null) {
    return const [];
  }
  return [
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
  ];
}
```

With `estimatedReturn` five and a half hours away, `/maintenance` reads `Returning in 5h 29m` a moment later. With `launchAt` thirty days away, `/coming-soon` reads `Returning in 719h 59m`.

The countdown counts against the browser's clock and ticks every second. Under an hour it shows minutes and seconds (`Returning in 12m 30s`). Once the moment has passed it reads `Back any moment now...`. Hours never roll over into days, so a launch a month away reads `719h`. If a countdown like that reads badly, leave `launchAt` out and put the date in the description. The countdown text is English, whatever the panel locale.

Neither page has a retry button or a status link. `OiMaintenancePage` supports both, and Beak passes neither.

## Send people there

The pages are a sign on the door, not the lock. `redirectTo` puts every visitor in front of one of them:

```dart
BeakMaintenanceConfig(
  maintenanceDescription: 'We are upgrading the database.',
  estimatedReturn: DateTime.utc(2026, 10, 3, 6),
  redirectTo: BeakMaintenancePage.maintenance,
)
```

With that set, every route except the two pages redirects to `/maintenance` (or `/coming-soon` for `BeakMaintenancePage.comingSoon`), a signed-out visitor included: the redirect runs ahead of the sign-in wall. The other page stays reachable, so you can preview a launch page during a maintenance window. It is a client-side redirect in the panel build the visitor has already loaded. It never checks the server's health and never redirects on a failed request, so to switch it on you ship a build (or a config) with `redirectTo` set. Without `redirectTo` a visitor sees `/maintenance` only when a link, a script or a proxy sends them there. From inside the app, `context.go('/maintenance')` (go_router) is the whole trip.

For a real outage the mechanics belong to your deployment:

- The panel is static files and the API is a separate process. Stopping the API leaves the panel files in place, and each request then fails inside the panel.
- What takes traffic away is your proxy or your platform. Answer API paths with a 503, or stop the server, and point page requests at `/maintenance`. Not shipped and not tested here.
- The repo's `deploy/nginx.conf` falls back to `index.html` for any unknown path, so `/maintenance` resolves on a hard refresh, which is what a proxy redirect relies on.
- The server's `/readyz` answers 503 when the data source does not respond. That probe is for your orchestrator. The panel does not read it.

[Going to production](../shipping/going-to-production.md) is the page for the deployment side, and [Middleware](../backend/middleware.md) for the server side.

A launch page has one more limit: `BeakPanelConfig.home` must be one of the panel's own resources or screens, so `/coming-soon` cannot be the landing page. The panel opens on your first destination and the coming-soon page waits behind a link.

## Rules and limits

| Rule | What it means |
| --- | --- |
| Presentation only | The pages change what a visitor sees. The API keeps answering |
| One trigger | `redirectTo`. Not a failed request, not a date, not a server flag |
| `maintenance: null` mounts neither | The routes then fall through to the not-found page |
| `copyWith` can add, not remove | `copyWith(maintenance: null)` keeps the old value, because `null` means "unchanged" |
| Signed-out visitors can open them | With `auth:` set, `/maintenance` and `/coming-soon` are public paths. Every other guest path redirects to `/login` |
| Outside the shell | No sidebar, no top bar, no theme toggle |
| `home:` cannot point at them | `home` must name a declared resource or screen, or the panel throws a `BeakConfigurationException` at startup. Use `redirectTo` to land on them |
| Default titles are English | `Under maintenance` and `Coming soon` are plain strings, not localized. Pass your own for another language |

## Verify it

The package tests mount both routes, read their titles and check both redirects. From `packages/beak_frontend`:

```console
$ flutter test test/src/panel/beak_screen_routing_test.dart --plain-name maintenance
error + maintenance routes 403 and 500 render typed error pages
error + maintenance routes maintenance + coming-soon mount when configured
error + maintenance routes redirectTo sends every other route to the chosen page
error + maintenance routes a coming-soon redirect wins over the sign-in wall
All tests passed!
```

The generated path, in a scratch project made with `beak create demo --no-pub --beak-path <repo>` after `beak eject panel`, the edit above and `beak prepare`:

```console
$ beak prepare
1 model · 0 resource classes · 0 screens · 1 override
$ grep -n "as panel\|beakPanel" lib/beak/panel.g.dart
8:import '../panel.dart' as panel;
31:  return panel.beakPanel(config);
$ flutter analyze lib
No issues found!
```

The two countdown lines, the redirect for a guest and the public paths come from a scratch widget test in the same project. It mounts a panel with `auth:` set to a guest adapter and visits three paths:

```console
START path=/login
AT /maintenance -> /maintenance [Under maintenance, We are upgrading the database., Returning in 5h 29m]
AT /coming-soon -> /coming-soon [Coming soon, Returning in 719h 59m]
AT /notes -> /login [Demo, Sign in, Username or email, Password]
```

A guest reaches both pages and is sent to `/login` for everything else.

## Reference

Import `package:beak/panel.dart`.

| Member | Type | Default | Meaning |
| --- | --- | --- | --- |
| `maintenanceTitle` | `String` | `Under maintenance` | Heading of `/maintenance` |
| `maintenanceDescription` | `String?` | `null` | Text under the heading |
| `estimatedReturn` | `DateTime?` | `null` | Return time. Turns the countdown on |
| `comingSoonTitle` | `String` | `Coming soon` | Heading of `/coming-soon` |
| `comingSoonDescription` | `String?` | `null` | Text under the heading |
| `launchAt` | `DateTime?` | `null` | Launch time. Turns the countdown on |

`BeakPanelConfig.maintenance` is the only place the object attaches. Its other options are on [Panel and resource options](../reference/panel-options.md).

## Continue reading

- [Auth and idle-lock](auth-and-idle-lock.md): what a guest may reach, and the lock screen that sits beside these pages.
- [Custom screens](custom-screens.md): a page of your own at a route of your own.
- [Going to production](../shipping/going-to-production.md): the proxy, the probes and the checklist that decide whether these pages ever show.
