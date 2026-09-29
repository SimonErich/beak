---
title: Panel and resource options
description: Every option of BeakPanel, BeakPanelConfig, BeakResource, navigation, auth, maintenance, notifications, refresh and formatting, with defaults.
type: reference
audience: [expert, agent]
status: stable
search: {boost: 2}
---

# Panel and resource options

A panel is one `BeakPanelConfig`: a list of `BeakResource` objects, optional custom `BeakScreen` pages and a handful of shell options. This page lists every option with its type and default, and says which bootstrap can set it. The guides in [The panel](../panel/index.md) teach the same options with worked examples.

## Import

```dart
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
```

`package:beak/panel.dart` exports everything on this page and pulls in Flutter. `package:beak/ui.dart` adds the obers_ui widgets you need for `OiIcons` and `OiThemeData`. Server code never imports either.

## Summary

| Type | What it configures | Passed to |
| --- | --- | --- |
| [`BeakPanel`](#beakpanel) | The root widget: a config or the everyday arguments, plus two data seams | `runApp` |
| [`BeakPanelConfig`](#beakpanelconfig) | The whole panel: resources, pages, auth, maintenance, themes, locale, formatting, sidebar, home, navigation, notifications, refresh, shell actions, exception mapping | `BeakPanel(config:)` |
| [`BeakResource`](#beakresource) | One model in the panel: navigation entry, screens, filters, actions, capability switches, uploads, duplication | `BeakPanelConfig.resources` |
| [`BeakScreen`](#beakscreen) | A custom page made of blocks | `BeakPanelConfig.pages` |
| [`BeakDestination`](#beakdestination) | A typed place to send the user: a resource or a screen | `BeakPanelConfig.home` |
| [`BeakNavigation`](#beaknavigation) | A two-level rail and its contextual items | `BeakPanelConfig.navigation` |
| [`BeakAuthConfig`](#beakauthconfig) | Sign-in routes, registration, recovery, idle lock | `BeakPanelConfig.auth` |
| [`BeakMaintenanceConfig`](#beakmaintenanceconfig) | The `/maintenance` and `/coming-soon` pages | `BeakPanelConfig.maintenance` |
| [`BeakNotificationSource`](#beaknotificationsource) | The shell's notification bell | `BeakPanelConfig.notifications` |
| [`BeakRefreshPolicy`](#beakrefreshpolicy) | Periodic and foreground refetch | `BeakPanelConfig.refreshPolicy` |
| [`BeakFormatting`](#beakformatting) | Date, number and currency display | `BeakPanelConfig.formatting` |

Resource screens (`BeakTableScreen`, `BeakFormScreen`, `BeakWizardScreen`, `BeakCustomResourceScreen`) are listed in [Screens and form layouts](screens-and-layouts.md). Actions and duplication are in [Behavior and actions](behavior-and-actions.md), list filters in [Filter builders](filter-builders.md).

## Where each option can be set

Beak boots a panel two ways. An authored `lib/main.dart` calls `BeakPanel` itself, and a generated one runs `BeakApp` from `lib/beak/app.g.dart`, which builds the same `BeakPanel(config: ...)` from `beak.yaml`, discovery and the override files. [Two ways to boot a panel](../start-here/generated-or-authored.md) explains the choice. The `BeakPanel` shorthand takes only the everyday options; anything else goes through `config:`.

| `BeakPanelConfig` option | `BeakPanel(...)` shorthand | Generated `BeakApp` |
| --- | --- | --- |
| `title` | `title` | `name` in [beak.yaml](beak-yaml.md) |
| `resources` | `resources` | every discovered model, replaced by the `BeakResource` class written for it |
| `apiBaseUrl` | `apiBaseUrl` | `api.baseUrl` in beak.yaml |
| `pages` | `pages` | every screen discovered under `lib/screens/` |
| `auth` | `auth` | `beakAuth()` in `lib/auth.dart` |
| `theme`, `darkTheme` | `theme`, `darkTheme` | `beakLightTheme()`, `beakDarkTheme()` in `lib/theme.dart` |
| `sidebarCollapsible`, `sidebarDefaultCollapsed` | none | `theme.sidebar.collapsible`, `theme.sidebar.startCollapsed` in beak.yaml |
| `locale`, `formatting`, `home`, `navigation`, `refreshPolicy` | same names | `beakPanel(defaults)` in `lib/panel.dart` |
| `maintenance`, `mapException` | same names | `beakPanel(defaults)` in `lib/panel.dart` |
| `initialThemeMode`, `supportedLocales`, `localizationsDelegates`, `notifications`, `shellActions` | none, use `config:` | `beakPanel(defaults)` in `lib/panel.dart` |

`lib/panel.dart` declares `BeakPanelConfig beakPanel(BeakPanelConfig defaults)`, and the generated code returns whatever it returns. `defaults.copyWith(...)` is the usual body. [Configuration and environment](configuration.md) lists the override files and the environment variables.

## BeakPanel

The root widget. It builds its own dependency container and router from the config, memoized on the config, so pass a config object that lives as long as the app.

```dart title="packages/beak_frontend/lib/src/panel/beak_panel.dart"
  const BeakPanel({
    BeakPanelConfig? config,
    List<BeakResource>? resources,
    this.title,
    this.theme,
    this.darkTheme,
    this.apiBaseUrl,
    this.pages = const [],
    this.auth,
    this.locale,
    this.formatting,
    this.navigation,
    this.refreshPolicy,
    this.home,
    this.maintenance,
    this.mapException,
    this.dataSource,
    this.httpClient,
    super.key,
  }) : assert(config == null || resources == null),
       _config = config,
       resources = resources ?? const [];
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `config` | `BeakPanelConfig?` | `null` | A complete configuration. Exclusive with `resources`; the constructor asserts. |
| `resources` | `List<BeakResource>?` | `[]` | The resources of a directly configured panel. |
| `title` | `String?` | `null` | Application title; `Beak` when null. |
| `theme` | `OiThemeData?` | `null` | Light theme, `OiThemeData.light()` when null. |
| `darkTheme` | `OiThemeData?` | `null` | Dark theme, `OiThemeData.dark()` when null. |
| `apiBaseUrl` | `String?` | `null` | Backend origin; when null the `BEAK_API_BASE_URL` `--dart-define`, else `http://localhost:8080`. `BeakPanelConfig` does not read the `--dart-define`. |
| `pages` | `List<BeakScreen>` | `[]` | Custom pages. |
| `auth` | `BeakAuthConfig?` | `null` | Authentication configuration. |
| `locale` | `Locale?` | `null` | Application locale; the platform's when null. |
| `formatting` | `BeakFormatting?` | `null` | Shared display policy. |
| `navigation` | `BeakNavigation?` | `null` | Primary rail and contextual navigation. |
| `refreshPolicy` | `BeakRefreshPolicy?` | `null` | Periodic and foreground refetch. |
| `home` | `BeakDestination?` | `null` | Where `/` goes when no screen claims it. |
| `maintenance` | `BeakMaintenanceConfig?` | `null` | The `/maintenance` and `/coming-soon` pages, and optionally a redirect to one of them. |
| `mapException` | `BeakException? Function(Exception, StackTrace)?` | `null` | Maps a host exception, such as a Serverpod protocol error, to a `BeakException`. |
| `dataSource` | `BeakDataSource?` | `null` | Replaces the HTTP-backed source for every model, including a model bound to its own source. |
| `httpClient` | `http.Client?` | `null` | Replaces only the HTTP transport under the typed `BeakClient`. |

`dataSource` and `httpClient` work with `resources:` and with `config:`. A widget test passes a fake source (no HTTP). A host with its own transport passes one in production: the Serverpod admin app does, with `serverpodBeakDataSource(dispatch)`:

```dart title="examples/serverpod/bookshop_admin/lib/src/bookshop_admin.dart"
--8<-- "examples/serverpod/bookshop_admin/lib/src/bookshop_admin.dart:bookshopAdminPanel"
```

The everyday authored form is a title, a formatting policy, pages and resources:

```dart title="examples/clean_beak_config/lib/main.dart"
--8<-- "examples/clean_beak_config/lib/main.dart:shopMain"
```

The generated `BeakApp` is `BeakPanel(config: beakPanelConfig, dataSource: dataSource)` and exposes only `dataSource`. Its config comes from `buildBeakPanel()`:

```dart title="examples/quickstart/lib/beak/panel.g.dart"
BeakPanelConfig buildBeakPanel() {
  final config = BeakPanelConfig(
    title: 'Quickstart',
    apiBaseUrl: const String.fromEnvironment(
      'BEAK_API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
    sidebarCollapsible: true,
    sidebarDefaultCollapsed: false,
    resources: [
      BeakResource(
        model: const NoteModel(),
        icon: BeakIconToken(OiIcons.fileText),
        navigationGroup: 'Content',
      ),
    ],
  );
  return config;
}
```

## BeakPanelConfig

```dart title="packages/beak_frontend/lib/src/panel/beak_panel_config.dart"
const BeakPanelConfig({
  required this.title,
  required this.resources,
  this.apiBaseUrl = 'http://localhost:8080',
  this.pages = const [],
  this.auth,
  this.maintenance,
  this.theme,
  this.darkTheme,
  this.initialThemeMode = OiThemeMode.system,
  this.locale,
  this.formatting,
  this.supportedLocales = BeakLocalizations.supportedLocales,
  this.localizationsDelegates = const [],
  this.sidebarCollapsible = true,
  this.sidebarDefaultCollapsed = false,
  this.home,
  this.notifications,
  this.navigation,
  this.refreshPolicy,
  this.shellActions,
  this.mapException,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | The panel title, shown in the shell and the login screen. |
| `resources` | `List<BeakResource>` | required | The resources the panel exposes, in navigation order. |
| `apiBaseUrl` | `String` | `'http://localhost:8080'` | Origin of the `beak_backend` server (e.g. `http://localhost:8080`). |
| `pages` | `List<BeakScreen>` | `const []` | Custom, non-resource screens, in navigation order. |
| `auth` | `BeakAuthConfig?` | `null` | Authentication routes; `null` mounts only a default `/login`. |
| `maintenance` | `BeakMaintenanceConfig?` | `null` | Maintenance / coming-soon routes; `null` mounts neither. |
| `theme` | `OiThemeData?` | `null` | The light theme (defaults to `OiThemeData.light()`). |
| `darkTheme` | `OiThemeData?` | `null` | The dark theme (defaults to `OiThemeData.dark()`). |
| `initialThemeMode` | `OiThemeMode` | `OiThemeMode.system` | The theme mode the panel starts in; toggled live from the shell. |
| `locale` | `Locale?` | `null` | Explicit app locale; `null` follows the platform's supported locale. |
| `formatting` | `BeakFormatting?` | `null` | Shared date, number and currency display policy. |
| `supportedLocales` | `Iterable<Locale>` | `BeakLocalizations.supportedLocales` | Locales supported by the panel and its application-owned labels. |
| `localizationsDelegates` | `Iterable<LocalizationsDelegate<Object?>>` | `const []` | Application translation delegates, installed before Beak's default. Beak always appends its delegate. A custom delegate for `BeakLocalizations` may override that default when translating framework text into another language; application resource labels use their own delegate. |
| `sidebarCollapsible` | `bool` | `true` | Whether the sidebar can collapse to an icon rail. |
| `sidebarDefaultCollapsed` | `bool` | `false` | Whether the sidebar starts collapsed (an icon-only rail). |
| `home` | `BeakDestination?` | `null` | Where `/` sends the user when no `BeakScreen` claims it, for example a resource's list page or an overview screen. Sign-in and the error pages' back actions land here. `null` picks the first visible navigation destination. Ignored while its resource is not visible. |
| `notifications` | `BeakNotificationSource?` | `null` | Binds a model's rows to the shell's notification bell; `null` shows no bell. |
| `navigation` | `BeakNavigation?` | `null` | Optional primary rail and contextual navigation. |
| `refreshPolicy` | `BeakRefreshPolicy?` | `null` | Shared opt-in periodic and foreground refresh for remote changes. |
| `shellActions` | `List<Widget> Function(BuildContext context)?` | `null` | Host-owned shell controls, such as sign out or a locale selector. |
| `mapException` | `BeakException? Function(Exception exception, StackTrace stackTrace)?` | `null` | Maps known host transport/domain failures for every bound resource. Unknown exceptions propagate so programming failures are not hidden. |

| Member | Returns | Meaning |
| --- | --- | --- |
| `navigationResources` | `List<BeakResource>` | `resources` sorted by `navigationRank`, ties in declaration order |
| `copyWith(...)` | `BeakPanelConfig` | A copy with the named parts replaced. Every parameter of the constructor is accepted. A `null` argument keeps the current value, so `copyWith` cannot clear an option. |
| `buildRegistry()` | `BeakModelRegistry` | Validates the configuration and registers every resource model plus every model they relate to. Called once by `registerBeakDependencies`. |

`buildRegistry()` throws a `BeakConfigurationException` for each of these, at the first build of the panel:

| Condition | Message starts with |
| --- | --- |
| No resources and no pages | `A panel needs at least one resource or page to show.` |
| `home` is not one of the panel's resources or pages | `The home destination "..." must be one of the panel's resources or pages.` |
| `home` is not `/` and a screen already claims `/` | `The home destination "..." is unreachable` |
| A resource has two screens for one role | `Resource "..." defines more than one ... screen.` |
| A `globalSearchSources` entry is not a scalar field of the resource's own model | `Global search for "..." requires scalar fields rooted at that model.` |
| A `BeakTableScreen.query` targets another table | `Table screen query must target "...".` |
| A `BeakFormScreen` serves the `list` role | `A form screen cannot serve the list route.` |
| Two different model classes claim one related table | `Conflicting models for related table "...".` |
| Registering one table twice | raised by `BeakModelRegistry` |

## BeakResource

One model presented in the panel. Declaring one gives the list, create, show and edit routes; the built-in view, edit, delete and create actions are always present and the lists below add to them. A resource is usually a `final class ... extends BeakResource` in `lib/resources/<table>/`, which the generated bootstrap discovers and uses in place of the default resource for that model. The schema annotation `@Resource` is a different thing: it declares the model, see [Annotations](annotations.md#resource).

```dart title="packages/beak_frontend/lib/src/panel/beak_resource.dart"
const BeakResource({
  required this.model,
  this.icon = const BeakIconToken(OiIcons.database),
  this.title,
  this.navigationTitle,
  this.navigationGroup,
  this.navigationRank = 0,
  this.screens = const [],
  this.globalSearchSources = const [],
  this.recordActions = const [],
  this.bulkActions = const [],
  this.globalActions = const [],
  this.filters = const [],
  this.canCreate = true,
  this.canEdit = true,
  this.canDelete = true,
  this.deleteAction = const BeakDeleteAction(),
  this.onActionError,
  this.filePicker,
  this.uploader,
  this.duplication,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `model` | `BeakModel` | required | The model this resource exposes. |
| `icon` | `BeakIconToken` | `const BeakIconToken(OiIcons.database)` | The sidebar icon. |
| `title` | `String?` | `null` | Page title; defaults to the model's human-readable table name. |
| `navigationTitle` | `String?` | `null` | Sidebar title; defaults to `title` and then the inferred model name. |
| `navigationGroup` | `String?` | `null` | Sidebar group heading this resource is filed under. |
| `navigationRank` | `int` | `0` | Navigation order within the resource list. Ties retain declaration order. |
| `screens` | `List<BeakResourceScreen>` | `const []` | Screen definitions inheriting this resource's model and data source. |
| `globalSearchSources` | `List<BeakFieldRef<Object>>` | `const []` | Typed fields searched by the panel command bar; empty uses model defaults. |
| `recordActions` | `List<BeakRecordAction>` | `const []` | Extra per-row actions on the list page (view/edit/delete are built in). |
| `bulkActions` | `List<BeakBulkAction>` | `const []` | Actions over the list page's selection. |
| `globalActions` | `List<BeakGlobalAction>` | `const []` | Extra page-level list actions (create is built in). |
| `filters` | `List<BeakFilterDef>` | `const []` | The list page's filter controls. |
| `canCreate` | `bool` | `true` | Whether this resource exposes the corresponding write operation. These presentation capabilities do not replace server authorization; account-dependent checks belong on `BeakModel.permissions`. |
| `canEdit` | `bool` | `true` | Whether the edit action and route are available. |
| `canDelete` | `bool` | `true` | Whether the delete action is available. |
| `deleteAction` | `BeakRecordAction` | `const BeakDeleteAction()` | Domain-specific deletion semantics, such as confirmed archival. |
| `onActionError` | `void Function(BeakException error)?` | `null` | Host notification boundary for custom-action failures. |
| `filePicker` | `BeakFilePicker?` | `null` | Optional platform file chooser shared by the resource forms. |
| `uploader` | `BeakUploadClient?` | `null` | Optional upload transport; defaults to the resource data source. |
| `duplication` | `BeakDuplicationSpec?` | `null` | Enables the standard Duplicate action with explicit owned-child copying. |

```dart title="examples/clean_beak_config/lib/resources/categories/category_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/categories/category_resource.dart:CategoryResource"
```

| Member | Returns | Meaning |
| --- | --- | --- |
| `route` | `String` | The list route, `/<table>` |
| `location` | `String` | Same as `route`; the `BeakDestination` contract |
| `effectiveLabel` | `String` | `title`, else the table name in title case (`order_items` becomes `Order Items`) |
| `effectiveNavigationTitle` | `String` | `navigationTitle`, else `effectiveLabel` |
| `effectiveFilters` | `List<BeakFilterDef>` | `filters` when declared, else the controls the model's `filterable` columns imply |
| `screenFor(BeakScreenRole)` | `BeakResourceScreen?` | The screen serving a role, `null` for the generated default. Throws when two screens serve the same role. |
| `isVisible` | `bool` | The model supports read and `BeakModel.permissions` allows it |
| `allowsCreate` | `bool` | `isVisible`, `canCreate`, the model supports create or a custom create screen exists, and permissions allow it |
| `allowsEdit` | `bool` | The same for update, with a custom edit screen |
| `allowsDelete` | `bool` | `isVisible`, `canDelete`, the model supports delete and permissions allow it |
| `allowsAction(BeakAction)` | `bool` | Live availability of a built-in or configured action; a custom action needs `isVisible` |
| `copyWith(...)` | `BeakResource` | A copy with the named parts replaced; a `null` argument keeps the current value |

`BeakScreenRole` has four values: `list`, `read`, `create`, `edit`. The permission hooks (`BeakModel.permissions`, a `BeakPermissions`) and the capability switches (`canCreate`, `canEdit`, `canDelete`) only hide routes and buttons. A hidden route redirects to `/403`. Authorization is enforced on the server, see [Auth and policies](../backend/auth-and-policies.md).

## BeakScreen

A custom page: a route, a navigation entry and a block tree. `BeakScreen` implements `BeakDestination`.

```dart title="packages/beak_frontend/lib/src/panel/beak_screen.dart"
const BeakScreen({
  required this.path,
  required this.title,
  required this.icon,
  required this.body,
  this.navigationTitle,
  this.navigationGroup,
  this.showInNav = true,
  this.framed = true,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `path` | `String` | required | The route this screen is mounted at (e.g. `'/analytics'`). |
| `title` | `String` | required | The screen title, shown in the framed header and used as the sidebar title fallback. |
| `icon` | `BeakIconToken` | required | The sidebar icon. |
| `body` | `BeakBlock` | required | The declarative screen content. |
| `navigationTitle` | `String?` | `null` | Sidebar title override; defaults to `title`. |
| `navigationGroup` | `String?` | `null` | Optional sidebar group heading this screen is filed under. |
| `showInNav` | `bool` | `true` | Whether the screen appears in the sidebar. Set false for detail pages reached only by navigation (e.g. an invoice document). |
| `framed` | `bool` | `true` | Whether to provide the standard page header, gutters and scrolling. The frame does not add a card or background behind the body: card, chart and table blocks own their surfaces. Wrap the body in a `BeakCardBlock` to deliberately place it on one shared surface. Set false for full-bleed screens like a calendar or kanban board. |

`effectiveNavigationTitle` is `navigationTitle ?? title`, and `location` is `path`. A screen at `/` becomes the landing page. The block reference is [Blocks](blocks.md).

## BeakDestination

```dart title="packages/beak_frontend/lib/src/panel/beak_destination.dart"
abstract interface class BeakDestination {
  /// The router location this destination is served at: a screen's path or a
  /// resource's list route.
  String get location;
}
```

`BeakResource` and `BeakScreen` implement it. `BeakPanelConfig.home` takes one, so no route string is spelled by hand. `/` resolves in this order:

1. A `BeakScreen` whose `path` is `/`.
2. `home`, while it is visible.
3. The first visible item of `navigation.sections` (regular sections first, then `bottom` ones).
4. The first visible resource in `navigationResources`.
5. The first page with `showInNav: true`.

A panel with none of these has no `/` route.

## BeakNavigation

Without `navigation`, the shell generates a sidebar from the resources (grouped by `navigationGroup`, ordered by `navigationRank`) and the pages with `showInNav`. With it, the shell shows a primary rail of `sections` and the active section's items beside it. Every item goes through the same resource visibility checks.

```dart title="packages/beak_frontend/lib/src/panel/beak_navigation.dart"
const BeakNavigation({
  required this.sections,
  this.leading,
  this.footer,
  this.headerBuilder,
  this.userMenu,
  this.searchPlaceholder,
  this.searchShortcut = const ['meta', 'K'],
  this.showCreateAction = true,
  this.showThemeToggle = true,
  this.showCurrentRecord = true,
  this.currentRecordBranch = false,
  this.searchInHeader = true,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `sections` | `List<BeakNavigationSection>` | required | Workspace sections, filtered through the same resource permissions. |
| `leading` | `Widget?` | `null` | Brand widget in the primary rail. |
| `footer` | `Widget?` | `null` | Shared contextual navigation footer. |
| `headerBuilder` | `Widget Function(BuildContext context, String section)?` | `null` | Replaces the contextual heading with an application workspace header. |
| `userMenu` | `Widget?` | `null` | Profile or account menu placed after the shared header actions. |
| `searchPlaceholder` | `String?` | `null` | Command search hint; the same shared search still handles activation. |
| `searchShortcut` | `List<String>` | `const ['meta', 'K']` | Visible logical shortcut keys beside the shared command-search hint. |
| `showCreateAction` | `bool` | `true` | Automatically offers creation for the first creatable workspace resource. The resource's current visibility and creation permissions are respected. |
| `showThemeToggle` | `bool` | `true` | Whether the shared theme switch is included in the top bar. |
| `showCurrentRecord` | `bool` | `true` | Includes the loaded current record under its resource when applicable. |
| `currentRecordBranch` | `bool` | `false` | Presents the current record as a contextual branch without a repeated icon. |
| `searchInHeader` | `bool` | `true` | Shows a full command-search field in the shell header. |

```dart title="examples/foodio-adminpanel/lib/navigation.dart"
--8<-- "examples/foodio-adminpanel/lib/navigation.dart:foodioNavigationOptions"
```

### BeakNavigationSection

```dart title="packages/beak_frontend/lib/src/panel/beak_navigation.dart"
const BeakNavigationSection({
  required this.key,
  required this.label,
  required this.icon,
  required this.items,
  this.bottom = false,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `key` | `String` | required | Stable presentation identity. |
| `label` | `String` | required | Accessible rail label. |
| `icon` | `IconData` | required | Rail icon. |
| `items` | `List<BeakNavigationItem>` | required | Contextual destinations in display order. |
| `bottom` | `bool` | `false` | Anchors this rail destination below the primary workspace links. |

The first visible item of a section is its landing destination.

### BeakNavigationItem

An item is a generated resource list or a custom screen. The constructors are named.

```dart title="packages/beak_frontend/lib/src/panel/beak_navigation.dart"
  const BeakNavigationItem.resource(
    this.model, {
    String? label,
    IconData? icon,
    this.preset,
    this.showCount = false,
    this.recordLabelMonospace = false,
  }) : screen = null,
       _label = label,
       _icon = icon;
```

```dart title="packages/beak_frontend/lib/src/panel/beak_navigation.dart"
  const BeakNavigationItem.screen(this.screen, {String? label, IconData? icon})
    : model = null,
      preset = null,
      showCount = false,
      recordLabelMonospace = false,
      _label = label,
      _icon = icon;
```

| Parameter | Constructor | Type | Default | Meaning |
| --- | --- | --- | --- | --- |
| `model` | `resource` | `BeakModel` | required (positional) | Model owning the generated list route |
| `screen` | `screen` | `BeakScreen` | required (positional) | A screen registered in `pages` |
| `label` | both | `String?` | `null` | Label; the resource's navigation label or the screen's when null |
| `icon` | both | `IconData?` | `null` | Icon; the resource's or the screen's when null |
| `preset` | `resource` | `BeakQueryPreset?` | `null` | One preset declared in the resource's `BeakListDefinition.presets`, passed as the object |
| `showCount` | `resource` | `bool` | `false` | Shows an authorized live count for the item's base query and preset. A missing, loading or failed count stays unavailable instead of showing zero. |
| `recordLabelMonospace` | `resource` | `bool` | `false` | Sets the current-record label in the code text role |

`route` is the item's local URI, with the preset serialised into the `list` query parameter. `matches(Uri)` tells whether the current location is this item.

```dart title="examples/foodio-adminpanel/lib/navigation.dart"
--8<-- "examples/foodio-adminpanel/lib/navigation.dart:foodioNavigationSections"
```

## BeakAuthConfig

Sign-in routes and the idle lock over one session authority. `/login` and `/lock` are mounted for every panel; `/register` and `/recover` only when opted in and the adapter supports them.

```dart title="packages/beak_frontend/lib/src/panel/beak_auth_config.dart"
const BeakAuthConfig({
  this.adapter,
  this.register = false,
  this.recover = false,
  this.idleLockTimeout,
  this.lockUserName,
  this.onUnlock,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `adapter` | `BeakAuthAdapter?` | `null` | Backend authority; null uses the registered HTTP session store. |
| `register` | `bool` | `false` | Opt-in to the adapter's registration flow. |
| `recover` | `bool` | `false` | Opt-in to the adapter's password recovery flow. |
| `idleLockTimeout` | `Duration?` | `null` | Optional inactivity timeout before opening the configured lock screen. |
| `lockUserName` | `String?` | `null` | Display name used on the lock screen. |
| `onUnlock` | `Future<bool> Function(String password)?` | `null` | Validates unlocking; an absent callback never accepts a password. |

| Member | Returns | Meaning |
| --- | --- | --- |
| `allowsRegistration` | `bool` | `register` is set and `adapter.registration` is not null |
| `allowsRecovery` | `bool` | `recover` is set and `adapter.recovery` is not null |

With `adapter: null` the panel uses the `BeakSessionStore` over its HTTP `BeakClient`, which has no registration or recovery flow, so `register` and `recover` have no effect there. They need a `BeakAuthAdapter` that returns a `BeakEmailVerificationFlow` from `registration` or `recovery`.

The idle lock is a client-side route. After `idleLockTimeout` without a pointer or key event inside the shell, the panel navigates to `/lock`. Unlocking runs `onUnlock(password)` and, on `true`, navigates to `/`. The lock does not sign out or revoke the session token, and an absent `onUnlock` never accepts a password. The guide is [Auth and idle-lock](../panel/auth-and-idle-lock.md); the adapter interface is in `packages/beak_frontend/lib/src/auth/beak_auth_adapter.dart`.

## BeakMaintenanceConfig

Mounts `/maintenance` and `/coming-soon` as `OiMaintenancePage` routes outside the shell. `redirectTo` sends every other route to one of them; without it nothing does. They never stop API traffic. See [Maintenance and coming soon](../panel/maintenance-and-coming-soon.md).

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

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `maintenanceTitle` | `String` | `'Under maintenance'` | Heading of the `/maintenance` screen. |
| `maintenanceDescription` | `String?` | `null` | Supporting copy of the `/maintenance` screen. |
| `estimatedReturn` | `DateTime?` | `null` | When service is expected back; drives the maintenance countdown. |
| `comingSoonTitle` | `String` | `'Coming soon'` | Heading of the `/coming-soon` screen. |
| `comingSoonDescription` | `String?` | `null` | Supporting copy of the `/coming-soon` screen. |
| `launchAt` | `DateTime?` | `null` | Launch moment; drives the coming-soon countdown. |
| `redirectTo` | `BeakMaintenancePage?` | `null` | `maintenance` or `comingSoon`: the page every other route redirects to. `null` only mounts the pages. |

```dart title="packages/beak_frontend/test/src/panel/beak_screen_routing_test.dart"
          maintenance: const BeakMaintenanceConfig(
            maintenanceTitle: 'Back soon',
            comingSoonTitle: 'Launching',
          ),
```

A countdown shows when `estimatedReturn` (maintenance) or `launchAt` (coming soon) is set.

## BeakNotificationSource

Binds the rows of one model to a bell with an unread badge in the shell header. The model is taken from the fields. The constructor throws a `BeakConfigurationException` when a field belongs to another model or is reached through a relationship.

```dart title="packages/beak_frontend/lib/src/panel/beak_notifications.dart"
  BeakNotificationSource({
    required this.titleField,
    this.bodyField,
    this.timeField,
    this.readField,
    this.categoryField,
  }) {
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `titleField` | `BeakScalarField<String>` | required | The field holding each notification's title |
| `bodyField` | `BeakScalarField<String>?` | `null` | The field holding the body |
| `timeField` | `BeakScalarField<DateTime>?` | `null` | The timestamp field; orders newest first |
| `readField` | `BeakScalarField<bool>?` | `null` | The boolean read flag; enables the unread badge and mark-as-read |
| `categoryField` | `BeakScalarField<Object>?` | `null` | The field grouping notifications into categories |

The bell loads the newest 30 rows and refetches after writes to the model. Without `readField` every loaded row counts as unread and mark-as-read does nothing. Marking a row read updates the row through the data source. The panel-level example:

```dart title="examples/foodio-adminpanel/lib/main.dart"
--8<-- "examples/foodio-adminpanel/lib/main.dart:foodioPanelConfig"
```

## BeakRefreshPolicy

A remote change feed for backends that push nothing. A local write already notifies the surfaces that subscribe to the written table (tables, metrics, summaries, relation managers). The policy adds invalidation for changes made elsewhere.

```dart title="packages/beak_frontend/lib/src/data/beak_data_changes.dart"
const BeakRefreshPolicy({this.interval, this.onResume = true});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `interval` | `Duration?` | `null` | Poll cadence; null relies on local writes and foreground resume only. |
| `onResume` | `bool` | `true` | Refreshes when the application returns from a background lifecycle state. |

While the app is in the foreground and a surface is listening, the panel invalidates every registered table each `interval`. Returning from the background invalidates once when `onResume` is true. A background window does not poll. An `interval` of zero or less throws a `BeakConfigurationException` (`A refresh interval must be positive.`) when the panel builds. The mechanism is described in [Block system internals](../architecture/block-system-internals.md) and `packages/beak_frontend/lib/src/data/beak_data_changes.dart`.

## BeakFormatting

One display policy for tables, forms, summaries and exports. It changes presentation only: values stay typed in drafts and API payloads.

```dart title="packages/beak_frontend/lib/src/formatting/beak_formatting.dart"
  const BeakFormatting({
    super.locale,
    super.currency,
    super.datePattern,
    super.dateInputPattern,
    super.dateTimePattern,
    super.timePattern,
    super.numberPrecision,
    super.currencyPrecision,
    super.useGrouping,
    super.useLocalTime,
    super.timeZoneOffsetMinutes,
    super.emptyValue,
  });
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `locale` | `String` | `'en_US'` | ICU locale for separators, grouping and currency position |
| `currency` | `String` | `'USD'` | ISO 4217 currency code |
| `datePattern` | `String` | `'yyyy-MM-dd'` | ICU pattern for dates |
| `dateInputPattern` | `String?` | `datePattern` | ICU pattern for editable calendar controls and range endpoints |
| `dateTimePattern` | `String` | `'yyyy-MM-dd HH:mm'` | ICU pattern for dates with a time |
| `timePattern` | `String` | `'HH:mm'` | ICU pattern for times |
| `numberPrecision` | `int` | `2` | Decimal places of non-integer numbers; integers show none |
| `currencyPrecision` | `int?` | `null` | Decimal places of money; the currency's standard when null |
| `useGrouping` | `bool` | `true` | Thousands separators |
| `useLocalTime` | `bool` | `true` | Convert timestamps to the device's local time zone |
| `timeZoneOffsetMinutes` | `int?` | `null` | A fixed UTC offset in minutes; overrides `useLocalTime`. It is an offset, not an IANA zone, so daylight saving is not modelled. |
| `emptyValue` | `String` | an em dash | Text shown for a null value |

| Member | Meaning |
| --- | --- |
| `BeakFormatting.of(context)` | The nearest policy, or a default `BeakFormatting()` outside a configured panel |
| `BeakFormatting.maybeOf(context)` | The nearest policy, `null` when none is set (columns then keep their own formatting) |
| `BeakFormattingScope(formatting:, child:)` | Overrides the policy for a subtree; `BeakPanel` mounts one when `formatting` is set |
| `number`, `currency`, `percent`, `date`, `dateTime`, `time` | Format a value; inherited from `BeakFormatPolicy` in `beak_core` |
| `parseNumber(String)` | Parses a localised number, `null` on malformed grouping or separators |
| `currencySymbol`, `moneyPrecision`, `decimalSeparator`, `groupingSeparator` | The parts monetary inputs need |
| `toEditorDateTime`, `fromEditorDateTime` | Convert between an instant and the wall-clock components an editor shows in the panel's zone |

`BeakValueFormat` (`text`, `number`, `currency`, `date`, `dateTime`, `time`, `percent`) selects a formatter for one field. Two extension methods on a scalar field set it without touching the stored value:

```dart title="packages/beak_frontend/lib/src/formatting/beak_field_format.dart"
  BeakFormattedField<T> currency({
    bool minorUnits = false,
    int scale = 2,
    String? label,
  }) => BeakFormattedField<T>(
```

```dart title="packages/beak_frontend/lib/src/formatting/beak_field_format.dart"
  BeakFormattedField<T> formatted(BeakValueFormat format, {String? label}) =>
      BeakFormattedField<T>(field: this, format: format, label: label);
```

`scale` (0 to 12) is the number of decimal places in an integer minor-unit column, so `minorUnits: true, scale: 2` shows `1999` as `19.99`. Nothing formatted enters a query or an API payload. The guide is [Formatting and localization](../theming/formatting-and-localization.md).

## Locale, themes and shell

| Option | Behaviour |
| --- | --- |
| `locale` | Explicit `Locale`; the platform's when null |
| `supportedLocales` | Defaults to `BeakLocalizations.supportedLocales`, which is `en` and `de` |
| `localizationsDelegates` | Application delegates installed first; Beak's own delegate is always appended, so a custom `BeakLocalizations` delegate can override framework text |
| `theme`, `darkTheme` | `OiThemeData`; `OiThemeData.light()` and `OiThemeData.dark()` when null |
| `initialThemeMode` | `OiThemeMode.system` by default; `light` and `dark` are the others. The shell's toggle changes it live through the registered `BeakThemeController`. |
| `sidebarCollapsible` | `true`: the sidebar collapses to an icon rail |
| `sidebarDefaultCollapsed` | `false`: the sidebar starts expanded |
| `shellActions` | `List<Widget> Function(BuildContext)`; extra controls in the shell header. When null and `auth` is set, the shell shows the sign-out button instead. |

```dart title="packages/beak_frontend/lib/src/panel/beak_theme_controller.dart"
--8<-- "packages/beak_frontend/lib/src/panel/beak_theme_controller.dart:BeakThemeController"
```

The shell header also carries the command search (Ctrl or Cmd plus K), which lists every visible resource and page and searches `globalSearchSources`. `BeakNavigation` controls its placement and hint.

## mapException

`BeakPanelConfig.mapException` is `BeakException? Function(Exception exception, StackTrace stackTrace)?`. `BeakPanel(mapException: ...)` takes the same parameter; with `config:` it goes on the config, because `config:` together with another everyday option throws. It is handed to the panel's data source and wraps every operation on it:

- A `BeakException` passes through unchanged and the mapper is not called.
- Any other `Exception` goes to the mapper. A non-null result is thrown in its place, with the original stack trace.
- A null result rethrows the original exception. An `Error` is never caught.

Use it to turn a host transport failure, such as a Serverpod client exception, into a typed `BeakException` the forms can show. The exception family is in [Exceptions](exceptions.md).

## Routes

`createBeakRouter` builds these routes. Resource routes are flat on purpose, so leaving a form and returning to the list queries again instead of showing stale rows.

| Route | Page | Guard |
| --- | --- | --- |
| `/` | The screen with `path: '/'`, else a redirect to the home destination | none |
| `/<table>` | List | `isVisible`, else `/403` |
| `/<table>/create` | Create form | `allowsCreate`, else `/403` |
| `/<table>/:id` | Show | `isVisible`, else `/403` |
| `/<table>/:id/edit` | Edit form | `allowsEdit`, else `/403` |
| `<screen.path>` | A custom screen | none |
| `/login` | Sign-in | always mounted |
| `/register`, `/recover` | Registration, recovery | `auth.allowsRegistration`, `auth.allowsRecovery` |
| `/lock` | Lock screen | always mounted |
| `/maintenance`, `/coming-soon` | Maintenance pages | `maintenance` is set |
| `/403`, `/500` | Error pages | always mounted |
| any other path | Not-found page | none |

`BeakRoutes.list(table)`, `.create(table)`, `.show(table, id)` and `.edit(table, id)` build the four resource paths. With `auth` set, every panel route sits behind `BeakAuthGate`. The four resource routes ask for confirmation before leaving a form with unsaved changes.

## Panel dependencies

Each `BeakPanel` owns one GetIt container, exposed to its subtree by `BeakDependencyScope`. `beakDependencies(context)` returns the nearest one and falls back to the global `beakLocator`.

```dart title="packages/beak_frontend/lib/src/di/beak_locator.dart"
--8<-- "packages/beak_frontend/lib/src/di/beak_locator.dart:registerDataLayer"
```

| Registered | Type | Notes |
| --- | --- | --- |
| Backend client | `BeakClient` | Not registered when `auth.adapter` is set |
| Session store | `BeakSessionStore` | Not registered when `auth.adapter` is set |
| Data source | `BeakDataSource` | A `ModelBeakDataSource` routing each table to its model's own source or the fallback |
| Model registry | `BeakModelRegistry` | Every resource model and every model they relate to |
| Panel config | `BeakPanelConfig` | The config in use |
| Theme controller | `BeakThemeController` | Starts in `initialThemeMode` |
| Action runner | `BeakModelActionRunner` | Runs model commands and keeps unresolved ones recoverable |

## Embedding

A host with its own router and app widget can mount Beak's routes and skip `BeakPanel`. The steps and a worked host are in [Using Beak widgets standalone](../extending/using-beak-widgets-standalone.md).

| Function | Signature | Purpose |
| --- | --- | --- |
| `registerBeakDependencies` | `void registerBeakDependencies({required BeakPanelConfig config, GetIt? locator, BeakDataSource? dataSource, http.Client? httpClient, String? Function()? tokenProvider, bool externalAuthentication = false})` | Registers the container entries above; synchronous, and re-registration replaces the previous entries |
| `createBeakRouter` | `GoRouter createBeakRouter(BeakPanelConfig config, {BeakAuthRouterRefresh? authRefresh})` | The full router the panel uses |
| `beakPanelRoutes` | `List<RouteBase> beakPanelRoutes(BeakPanelConfig config)` | The shell and the resource and screen routes, for a host router |
| `beakAuthRoutes` | `List<RouteBase> beakAuthRoutes(BeakPanelConfig config)` | The sign-in, registration, recovery and lock routes |
| `openBeakCommandBar` | `void openBeakCommandBar(BuildContext context, BeakPanelConfig config)` | Opens the command palette |

## Rules and limits

- Pass `config:` or `resources:`, never both; the constructor asserts. Passing `config:` together with `title:`, `theme:` or any other individual argument throws a `BeakConfigurationException` naming them when the panel builds, because the configuration would win silently. `dataSource:` and `httpClient:` are the exceptions: they work with either form.
- `BeakPanel` builds its container and router once per config object. A config created inside `build` is a new panel on every frame and loses state. Build it once, as the generated `beakPanelConfig` does.
- The validation errors under [BeakPanelConfig](#beakpanelconfig) surface when the panel first builds, not when the config object is created.
- With a custom `auth.adapter` the panel registers no `BeakClient` and no `BeakSessionStore`. Every model must then carry its own data source, or you pass `dataSource:`; otherwise the panel throws `External authentication requires bound models or a data source.`
- `dataSource:` wins over a model's own data source for every table.
- `canCreate`, `canEdit`, `canDelete`, `BeakModel.permissions` and `BeakNavigation` filtering hide routes and buttons. The server decides what is allowed.
- The idle lock and the maintenance pages are client-side. Neither ends a session nor blocks requests.
- `home` is ignored while its resource is not visible, and `/` then falls through to the next destination.
- The notification bell reads 30 rows. Older rows are not reachable from it.
- The `BeakPanel` shorthand has no `notifications`, `shellActions`, locale delegate or sidebar options. Move to `BeakPanel(config: BeakPanelConfig(...))` when you need one.

## Source

- `packages/beak_frontend/lib/src/panel/beak_panel.dart` is `BeakPanel`.
- `packages/beak_frontend/lib/src/panel/beak_panel_config.dart` is `BeakPanelConfig` and its validation.
- `packages/beak_frontend/lib/src/panel/beak_resource.dart` is `BeakResource` and `BeakIconToken`.
- `packages/beak_frontend/lib/src/panel/beak_screen.dart`, `beak_destination.dart`, `beak_navigation.dart`, `beak_auth_config.dart`, `beak_maintenance_config.dart`, `beak_notifications.dart`, `beak_routes.dart` and `beak_theme_controller.dart` are the smaller types in the same directory.
- `packages/beak_frontend/lib/src/panel/beak_router.dart` builds the routes, the shell and the idle lock.
- `packages/beak_frontend/lib/src/di/beak_locator.dart` registers the container.
- `packages/beak_frontend/lib/src/formatting/beak_formatting.dart` and `packages/beak_core/lib/src/formatting/beak_format_policy.dart` hold the display policy.
- `packages/beak_frontend/lib/src/data/model_beak_data_source.dart` applies `mapException` and the refresh policy.
- `packages/beak_cli/lib/src/project/beak_emitters.dart` writes the generated bootstrap.

## Continue reading

- [The panel](../panel/index.md) teaches resources, navigation, auth and dashboards with worked pages.
- [beak.yaml](beak-yaml.md) lists the project file keys the generated bootstrap reads.
- [Configuration and environment](configuration.md) covers the override files, environment variables and backend settings.
- [Screens and form layouts](screens-and-layouts.md) lists the resource screens a `BeakResource` takes.
- [Blocks](blocks.md) lists the blocks a `BeakScreen` body is made of.
