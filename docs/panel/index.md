---
title: The panel
description: BeakPanel and BeakPanelConfig, the single declarative object that stands up a whole admin app, plus the pages that break it down.
---

# The panel

After this page you can boot a complete admin app from one config object: hand a
`BeakPanelConfig` to a `BeakPanel`, call `runApp`, and the navigation, routing,
generated CRUD pages, and dashboard all come from that one value.

## One widget, one config

A Beak app has exactly two moving parts at the top. `BeakPanel` is the root
widget you give to `runApp`. `BeakPanelConfig` is the plain, `const`-friendly
object that describes the whole panel. You compose the config once, usually in a
builder so tests can vary the API origin, and Beak wires everything from it.

```dart title="examples/superdashboard/lib/main.dart"
/// The superdashboard demo app: one [BeakPanel] over the shared models,
/// reproducing a full admin theme entirely from seeded data.
final class SuperdashboardApp extends StatelessWidget {
  /// Creates the app; [dataSource] injects a fake in widget tests.
  const SuperdashboardApp({this.dataSource, super.key});

  /// Test seam replacing the HTTP-backed data source.
  final BeakDataSource? dataSource;

  @override
  Widget build(BuildContext context) =>
      BeakPanel(config: buildSuperdashboardConfig(), dataSource: dataSource);
}

/// Boots the Flutter superdashboard against the default local backend.
void main() => runApp(const SuperdashboardApp());
```

That is the whole app shell. `SuperdashboardApp` is a `StatelessWidget` wrapper
so a widget test can pass a fake `dataSource`; production leaves it null and the
panel talks HTTP to `config.apiBaseUrl`.

!!! note "What just happened"
    - `BeakPanel` took a config and became the root of a Flutter app.
    - `buildSuperdashboardConfig()` returned a `BeakPanelConfig` describing the
      panel. It is a builder so its `apiBaseUrl` can be overridden.
    - Nothing here mentions routes, tables, or forms. Those are generated from
      the resources in the config.

## What BeakPanel does on first build

`BeakPanel` is a `HookWidget`. On its first build it does three things, all
memoized on `config`:

1. Registers the panel's dependencies in the package-scoped GetIt locator
   (`beakLocator`): the data source (HTTP by default, or the injected fake), the
   model registry, the theme controller.
2. Builds a `go_router` over every resource and page in the config.
3. Wraps the router in `OiApp.router` with the config's light and dark themes,
   driven by a live `BeakThemeController`.

```dart title="packages/beak_frontend/lib/src/panel/beak_panel.dart"
class BeakPanel extends HookWidget {
  /// Creates the panel for [config].
  ///
  /// [dataSource] and [httpClient] inject fakes in tests; production
  /// panels leave both null and talk HTTP to `config.apiBaseUrl`.
  const BeakPanel({
    required this.config,
    this.dataSource,
    this.httpClient,
    super.key,
  });
```

You almost never touch the router, the locator, or the theme controller
directly. They are wired from config. That is the deal Beak makes: you configure,
Beak plumbs.

## The config object

`BeakPanelConfig` is the single declarative entry point. Here is the top of the
superdashboard's, which runs against the showcase server on port 8180:

```dart title="examples/superdashboard/lib/panel/config.dart"
BeakPanelConfig buildSuperdashboardConfig({
  String apiBaseUrl = 'http://localhost:8180',
}) => BeakPanelConfig(
  title: 'Beak Superdashboard',
  apiBaseUrl: apiBaseUrl,
  initialThemeMode: OiThemeMode.light,
  resources: buildResources(),
  notifications: const BeakNotificationSource(
    model: NotificationModel(),
    titleField: NotificationColumns.title,
    bodyField: NotificationColumns.body,
    timeField: NotificationColumns.createdAt,
    readField: NotificationColumns.isRead,
    categoryField: NotificationColumns.level,
  ),
  pages: [
    buildDashboardScreen(),
    buildEmailScreen(),
    // …
  ],
  auth: BeakAuthConfig(/* … */),
  maintenance: BeakMaintenanceConfig(/* … */),
);
```

Every field is optional except the three that a panel cannot do without.

| Field | Type | Default | What it does |
| --- | --- | --- | --- |
| `title` | `String` | required | Shown in the shell and on the login screen. |
| `resources` | `List<BeakResource>` | required | The models the panel exposes, in navigation order. |
| `apiBaseUrl` | `String` | required | Origin of the `beak_backend` server (match the port to your app). |
| `pages` | `List<BeakScreen>` | `[]` | Custom, non-resource screens, in navigation order. |
| `auth` | `BeakAuthConfig?` | `null` | Auth routes; `null` mounts only a default `/login`. |
| `maintenance` | `BeakMaintenanceConfig?` | `null` | Maintenance / coming-soon routes; `null` mounts neither. |
| `theme` / `darkTheme` | `OiThemeData?` | `OiThemeData.light()` / `.dark()` | The light and dark themes. |
| `initialThemeMode` | `OiThemeMode` | `system` | The mode the panel starts in; toggled live from the shell. |
| `sidebarCollapsible` | `bool` | `true` | Whether the sidebar can collapse to an icon rail. |
| `sidebarDefaultCollapsed` | `bool` | `false` | Whether the sidebar starts collapsed. |
| `dashboardStats` | `List<BeakStat>` | `[]` | The dashboard's metric cards, in order. |
| `dashboardCharts` | `List<BeakChart>` | `[]` | The dashboard's charts, in order. |
| `notifications` | `BeakNotificationSource?` | `null` | Binds a model's rows to the shell's notification bell. |

!!! warning "Match the port to the app"
    Beak ships two demo apps. The tutorial store (`store`) talks to a
    server on `http://localhost:8080`; the showcase (`superdashboard`) talks
    to one on `http://localhost:8180`. Point `apiBaseUrl` at the server your app
    actually runs, or the panel loads and every query returns connection-refused.

### The registry falls out of the resources

Config is the source of truth for the data layer too. `buildRegistry()` walks the
resources once at startup and registers every model, so the data layer can map a
table name back to its model (primary key, relations) without you maintaining a
second list.

```dart title="packages/beak_frontend/lib/src/panel/beak_panel_config.dart"
BeakModelRegistry buildRegistry() {
  final registry = BeakModelRegistry();
  for (final resource in resources) {
    registry.register(resource.model);
  }
  return registry;
}
```

Register the same table twice and the registry throws a configuration error. One
resource, one model, one registration.

## Where to go from here

This section takes the config apart, field by field:

- [Resources](resources.md) the anatomy of a `BeakResource`: model, icon, label,
  section, actions, filters, view modes, detail, and form layout.
- [Tables and filters](tables-and-filters.md) how the generated list renders,
  sorts, filters, and paginates server-side, plus the typed filter bar.
- [View modes](view-modes.md) giving a list a calendar or a board alongside the
  table.
- [Forms](forms.md) and [Multi-step forms](multi-step-forms.md) the generated
  create/edit surfaces.
- [Detail views and dual-mode blocks](detail-and-dual-mode.md) the show page and
  the one block tree that renders read-only and editable.
- [Actions](actions.md) and [Overlays](overlays.md) the typed action family and
  the confirm/modal/toast handles it reaches for.
- [Dashboards](dashboards.md) the stats and charts on `/`.
- [Custom screens](custom-screens.md), [The navigation shell](the-navigation-shell.md),
  [Auth and idle-lock](auth-and-idle-lock.md), and
  [Maintenance and coming soon](maintenance-and-coming-soon.md).

## Continue reading

- [Resources](resources.md) turn a registered model into a full CRUD surface.
- [Quickstart](../start-here/quickstart.md) the shortest path from zero to a
  running panel.
- [Configuration options](../reference/configuration-options.md) every config
  field in one reference table.
