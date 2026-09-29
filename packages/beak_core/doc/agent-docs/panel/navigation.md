# Navigation

> Order the automatic sidebar, replace it with sections and counts, and configure the command bar, notification bell and shell actions.

Without any configuration the panel builds a sidebar from your resources and pages. This page shows how to order and group that sidebar, when to replace it with a two-level `BeakNavigation` that carries counts and the current record, and how the command bar, the notification bell and the top-bar actions fit around it.

## At a glance

| | |
| --- | --- |
| Default | Visible resources by `navigationRank`, then pages with `showInNav`, grouped by `navigationGroup` |
| Replaced by | `BeakNavigation(sections: [...])` on `BeakPanelConfig.navigation` or `BeakPanel(navigation: ...)` |
| Types | `BeakNavigation`, `BeakNavigationSection`, `BeakNavigationItem` |
| Generated panel | `beak eject panel`, then `defaults.copyWith(navigation: ...)` in `lib/panel.dart` |
| Command bar | Ctrl-K or Cmd-K in every screen inside the shell, no configuration |
| Notifications, shell actions | `BeakPanelConfig` only, not the `BeakPanel(...)` shorthand |
| Enforces access | No. Navigation hides entries. The server enforces |

## The automatic sidebar

A panel with no `navigation` lists every resource the current account may read, in `navigationRank` order (ties keep declaration order), followed by every page with `showInNav: true`. Entries that share a `navigationGroup` sit under one heading, in the order the group first appears. Entries with no group form a headless block.

The label of a resource is `navigationTitle`, then `title`, then the title-cased table name. A page uses its `navigationTitle`, then its `title`. This is the shop's product resource, which files itself under Catalog:

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
model: const ProductModel(),
title: 'Products',
icon: const BeakIconToken(OiIcons.package),
navigationGroup: 'Catalog',
navigationRank: 3,
```

The sidebar collapses to an icon rail. `sidebarCollapsible` (default `true`) allows it and `sidebarDefaultCollapsed` (default `false`) starts that way. Both live on `BeakPanelConfig`. In a generated project set them in `beak.yaml` instead:

```yaml
theme:
  sidebar:
    collapsible: true
    startCollapsed: false
```

The automatic sidebar is fine while it fits on one screen. Past that, or when you want counts, workspaces and a current-record trail, write a `BeakNavigation`.

## Two levels with BeakNavigation

A `BeakNavigation` splits the shell in two. **Sections** become the primary rail: one icon and label each. The **items** of the active section fill the contextual sidebar next to it. Foodio has six sections, one of them anchored to the bottom of the rail:

```dart title="examples/foodio-adminpanel/lib/navigation.dart"
sections: [
  BeakNavigationSection(
    key: 'home',
    label: 'Home',
    icon: OiIcons.layoutDashboard,
    items: [BeakNavigationItem.screen(overviewScreen, label: 'Overview')],
  ),
  BeakNavigationSection(
    key: 'orders',
    label: 'Orders',
    icon: OiIcons.shoppingBag,
    items: [
      const BeakNavigationItem.resource(
        OrderModel(),
        showCount: true,
        recordLabelMonospace: true,
      ),
      const BeakNavigationItem.resource(DeliverySlotModel()),
      BeakNavigationItem.screen(kitchenScreen),
      const BeakNavigationItem.resource(ComplaintModel(), showCount: true),
    ],
  ),
  const BeakNavigationSection(
    key: 'people',
    label: 'People',
    icon: OiIcons.users,
    items: [
      BeakNavigationItem.resource(CustomerModel()),
      BeakNavigationItem.resource(OrganizationModel()),
      BeakNavigationItem.resource(DeliveryProfileModel()),
      BeakNavigationItem.resource(StaffMemberModel()),
    ],
  ),
  const BeakNavigationSection(
    key: 'kitchen',
    label: 'Kitchen',
    icon: OiIcons.chefHat,
    items: [
      BeakNavigationItem.resource(DishModel()),
      BeakNavigationItem.resource(MenuPlanModel()),
    ],
  ),
  const BeakNavigationSection(
    key: 'finance',
    label: 'Finance',
    icon: OiIcons.receipt,
    items: [
      BeakNavigationItem.resource(InvoiceModel()),
      BeakNavigationItem.resource(VoucherModel()),
      BeakNavigationItem.resource(BudgetAccountModel()),
    ],
  ),
  const BeakNavigationSection(
    key: 'settings',
    bottom: true,
    label: 'Settings',
    icon: OiIcons.settings,
    items: [
      BeakNavigationItem.resource(DeliveryLocationModel()),
      BeakNavigationItem.resource(AppSettingModel()),
      BeakNavigationItem.resource(NotificationModel()),
    ],
  ),
],
```

An item is either a resource list or a custom screen:

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

You name a model or a screen object, never a route. `BeakNavigationItem.resource(OrderModel())` points at the list of whatever resource registers that model, and `BeakNavigationItem.screen(kitchenScreen)` at the page's path. Label and icon default to the resource's `navigationTitle` and `icon`, or the screen's.

| Parameter | Applies to | Effect |
| --- | --- | --- |
| `label`, `icon` | both | Override the resource's or screen's own |
| `preset` | resource | Opens the list on one of its `BeakQueryPreset` objects. The item is active only while that preset is selected |
| `showCount` | resource | Shows a live record count as the item's badge |
| `recordLabelMonospace` | resource | Draws the current record's label in the code font, for identifiers such as order numbers |

`BeakNavigationSection` takes `key` (stable identity), `label` (the rail's accessible name and the heading of the contextual sidebar), `icon`, `items` and `bottom` (default `false`). A bottom section sits below the primary destinations, as a second rail, and is meant for settings.

### Presets as destinations

`preset:` takes the object, not its key. The item's route is the list path plus a `list` query parameter that holds the serialized preset, so the destination is an ordinary bookmarkable URL:

```dart title="packages/beak_frontend/test/src/panel/beak_composed_list_test.dart"
const urgent = BeakQueryPreset(key: 'urgent', label: 'Urgent');
// ...
const item = BeakNavigationItem.resource(NoteModel(), preset: urgent);
final uri = Uri.parse(item.route);
expect(uri.path, '/notes');
expect(BeakQueryController.readUri(uri)?.preset, 'urgent');
```

The preset's filters stay declared once, in the list definition, see [Composed lists and query state](composed-lists.md).

### Counts

`showCount: true` puts the number of matching records on the item. It is the server's own total for the list's permanent query plus the item's preset, so it respects the same authorization and row scope as the list. An item without `preset:` counts against the list's `initialPreset`. That is why Foodio's Orders badge shows today's orders: the list opens on the Today preset.

Counts load for the items of the active section only. They show a dash while loading and when a count fails, never `0`. Any confirmed write in the panel, and every tick of a `BeakRefreshPolicy`, recounts. On a screen item `showCount` does nothing, since the constructor has no such parameter.

### The current record

Open `/orders/1042` and, with a `BeakNavigation` set, the shell fetches that record and does two things. It adds a child under that resource's item, labelled with the record's display column, and from 600 logical pixels of width up it takes over the breadcrumbs: the resource name, then the record. `showCurrentRecord` (default `true`) turns the child off, and `currentRecordBranch: true` draws it as a branch without a repeated icon.

Opening a record from a list adds a `returnTo` parameter, so Back and the first breadcrumb return to the list with its preset, filters and page intact. Only local paths are accepted as `returnTo`; a value with a scheme, an authority or a leading `//` is ignored.

### The shell around it

```dart title="examples/foodio-adminpanel/lib/navigation.dart"
searchPlaceholder: 'Search orders, customers, invoices…',
showThemeToggle: false,
currentRecordBranch: true,
searchShortcut: ['⌘', 'K'],
userMenu: const Builder(builder: _accountMenu),
```

| Parameter | Default | Effect |
| --- | --- | --- |
| `leading` | none | Brand widget above the rail |
| `footer` | none | Widget under the contextual list |
| `headerBuilder` | none | `Widget Function(BuildContext, String section)` replaces the section heading, and with it the create button |
| `userMenu` | none | Account widget at the end of the top bar |
| `searchPlaceholder` | `Search (Ctrl-K)`, localized | Text of the search field in the header |
| `searchShortcut` | `['meta', 'K']` | The keys drawn on the field. A hint only, the key binding is fixed |
| `searchInHeader` | `true` | A full search field in the header. `false` leaves the search icon button |
| `showCreateAction` | `true` | A plus button beside the section heading that opens the create form of the first creatable resource in the section |
| `showThemeToggle` | `true` | The light, dark and system switch in the top bar |
| `showCurrentRecord` | `true` | The record child under its resource |
| `currentRecordBranch` | `false` | The record child without a repeated icon |

## The command bar

Ctrl-K or Cmd-K opens it from every screen inside the shell. It does two jobs in one field.

Typing filters the destinations: one entry per visible resource and per page with `showInNav`, matched by label. An empty field lists all of them, each under its `navigationGroup` (or `Resources` and `Pages` when it has none). This list comes from the resources and pages, not from `BeakNavigation`, so a resource that no section mentions is still there.

After 200 milliseconds without typing it also searches records. It sends one query per visible resource that has searchable fields, five records at most each, through the same query route the list uses, and shows the display label with the resource title. Each hit opens the show page. Because the panel asks the API the way a list does, the server's authorization and row scope apply to every hit, and a resource that fails answers with its own message and a Retry button while the others still list.

Which fields a resource searches is `globalSearchSources`, or its `searchable` columns when that is empty. Text columns match by containing the term. Whole numbers and decimals match exactly. Booleans take `true`, `yes` or `ja`, and `false`, `no` or `nein`. Enums match on name or label, dates on an ISO day such as `2026-09-29`, and money, exact decimals, dates, times and durations parse through their codec. A term that no column can read produces no query for that resource.

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
globalSearchSources: [
  ProductModel.name,
  ProductModel.sku,
  ProductModel.description,
  ProductModel.images.search(ProductImageModel.caption),
  ProductModel.category.name,
  ProductModel.attributes.search(ProductAttributeModel.value),
  ProductModel.variants.search(ProductVariantModel.sku),
],
```

`ProductModel.category.name` follows a to-one relationship. `ProductModel.attributes.search(ProductAttributeModel.value)` reaches through a collection, which the server evaluates as a relation filter.

## Notifications

Give `BeakPanelConfig.notifications` a `BeakNotificationSource` and the top bar gains a bell with an unread badge. The model is taken from the fields:

```dart title="examples/foodio-adminpanel/lib/main.dart"
title: 'Gabel Admin',
theme: gabelTheme(),
darkTheme: gabelTheme(dark: true),
apiBaseUrl: apiBaseUrl,
locale: const Locale('en'),
formatting: const BeakFormatting(
  locale: 'en_US',
  currency: 'EUR',
  datePattern: 'EEE d MMM',
  dateInputPattern: 'd MMM yyyy',
  timeZoneOffsetMinutes: 120,
  dateTimePattern: 'dd MMM yyyy · HH:mm',
),
resources: foodioResources(),
pages: foodioPages(),
navigation: foodioNavigation,
sidebarCollapsible: false,
shellActions: foodioShellActions,
notifications: BeakNotificationSource(
  titleField: NotificationModel.title,
  bodyField: NotificationModel.body,
  timeField: NotificationModel.occurredAt,
  readField: NotificationModel.isRead,
),
refreshPolicy: const BeakRefreshPolicy(
  interval: Duration(seconds: 30),
  onResume: true,
),
```

| Field | Type | Meaning |
| --- | --- | --- |
| `titleField` | `BeakScalarField<String>` | Required. Names the model |
| `bodyField` | `BeakScalarField<String>?` | Secondary text |
| `timeField` | `BeakScalarField<DateTime>?` | Newest first. Without it the order is whatever the source returns |
| `readField` | `BeakScalarField<bool>?` | Enables mark as read and mark all as read. Without it every row counts as unread |
| `categoryField` | `BeakScalarField<Object>?` | Groups rows in the sheet |

Every field must belong to the model itself: a path through a relationship throws `Notification field "..." must be a field of notifications itself.` The bell reads the newest 30 rows and counts the unread among them. Marking read writes `readField = true` back through the data source, so the account needs the update permission on that model on the server. The model has to be served by the backend like any other. Foodio also lists it as a resource, in its Settings section.

## Shell actions and the theme toggle

`shellActions` is a `List<Widget> Function(BuildContext)` whose widgets come first in the top bar, ahead of the search button, the notification bell and the theme toggle. It exists on `BeakPanelConfig` only.

One thing to know before you set it. When the panel has `auth` and no `shellActions`, the shell adds a sign-out button. Once you provide `shellActions`, that button is gone and sign-out is yours. `BeakLogoutButton` is exported for the purpose:

```dart
// Illustrative: the sign-out button of the default session store, placed by hand.
List<Widget> shellActions(BuildContext context) => [
  BeakLogoutButton(adapter: beakDependencies(context)<BeakSessionStore>()),
];
```

The theme mode lives in a `BeakThemeController` (a `ValueNotifier<OiThemeMode>`) that `beakDependencies(context)<BeakThemeController>()` returns. To draw your own toggle, set `showThemeToggle: false` on the navigation and bind your control to that notifier. Foodio switches the built-in one off for that reason.

## In a generated project

The generated panel builds its own sidebar and has no place for a `BeakNavigation`. Run `beak eject panel` and return a changed copy of the config from `lib/panel.dart`:

```dart
// Illustrative: lib/panel.dart in a generated project.
BeakPanelConfig beakPanel(BeakPanelConfig defaults) => defaults.copyWith(
  navigation: myNavigation,
  shellActions: myShellActions,
);
```

`navigation`, `notifications`, `shellActions`, `maintenance` and `home` all go through `copyWith`. Sections refer to models and screens by object, so import them into `lib/panel.dart`. A screen that a section names still has to be registered as a page, which for a generated project means declaring it under `lib/screens/`.

## Rules and limits

| Rule | What happens |
| --- | --- |
| Visibility follows the resource | A resource item shows only when its resource is visible to the account. An item whose model has no resource at all is a configuration error instead (see below) |
| A section needs one visible item | Sections without one vanish. When none remain, the automatic sidebar is used |
| The first visible item is the landing | The rail button of a section opens it, and `/` falls back to it when no `home` and no screen at `/` exist |
| The active section is the one whose item path matches | It matches on equal path or `path/`. A route no section contains keeps the first section active |
| A resource in no section stays reachable | It has no sidebar entry, its routes work, and the command bar lists it |
| Items must name something the panel has | A `BeakNavigationItem.resource` whose model has no `BeakResource`, or a `BeakNavigationItem.screen` whose path is not among `pages`, throws a `BeakConfigurationException` naming the section and the item when the panel builds |
| Counts cover the active section only | Resource items with `showCount`, recounted after writes. A dash while loading or on failure |
| The record child needs a `BeakNavigation` | One extra `getOne` per record page. Without navigation the shell does not fetch it |
| `headerBuilder` owns the heading | The create button is part of the default heading and goes with it |
| `shellActions` replaces sign-out | Add `BeakLogoutButton` yourself when the panel has `auth` |
| `searchShortcut` is a label | Ctrl-K and Cmd-K are bound in the shell either way |
| Only `BeakPanelConfig` has `notifications`, `shellActions`, sidebar flags | The `BeakPanel(...)` shorthand does not, see [Resources](resources.md) |
| A full-screen form has no shell | A `BeakFormScreen(fullScreen: true)` renders without navigation, top bar and command bar |
| Hiding is not protecting | A resource left out of navigation, or hidden by permissions, still answers to anyone who calls the API |

## Verify it

Three panel tests cover the parts that are easy to get wrong: counts share the list's permanent scope and refresh after a write, the record child and breadcrumbs return to the originating preset, and a bottom section shares routing with the rest. From `packages/beak_frontend`:

```console
$ flutter test test/src/panel/beak_composed_list_test.dart --name navigation
00:00 +0: navigation counts share permanent scopes and refresh after writes
00:01 +1: contextual record navigation returns to the originating preset and clears on plain URL
00:03 +2: workspace header and bottom navigation share shell routing
00:03 +3: All tests passed!
```

The command bar and the notification bell have their own suites:

```console
$ flutter test test/src/panel/beak_command_bar_test.dart test/src/panel/beak_notifications_test.dart
00:01 +13: All tests passed!
```

The `/` fallback order, including navigation sections, is covered by `beak_home_route_test.dart` (17 tests).

## Reference

```dart title="packages/beak_frontend/lib/src/panel/beak_navigation.dart"
const BeakNavigationSection({
  required this.key,
  required this.label,
  required this.icon,
  required this.items,
  this.bottom = false,
});
```

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

| Symbol | Meaning |
| --- | --- |
| `BeakPanelConfig.navigation`, `BeakPanel(navigation:)` | The navigation of the panel |
| `BeakPanelConfig.notifications` | A `BeakNotificationSource`, or `null` for no bell |
| `BeakPanelConfig.shellActions` | Widgets at the start of the top bar |
| `BeakPanelConfig.sidebarCollapsible`, `sidebarDefaultCollapsed` | Collapse behavior of the sidebar |
| `BeakPanelConfig.home` | Where `/` goes, see [Resources](resources.md) |
| `BeakNavigationItem.route`, `.matches(Uri)` | The local URI of an item, and whether it is the active one |
| `openBeakCommandBar(BuildContext, BeakPanelConfig)` | Opens the command bar programmatically |
| `beakNavigationCommands(config, go)` | One `OiCommand` per visible resource and in-nav page |
| `BeakSearchPalette` | The palette itself, for a custom shell. Takes `config`, `onSelect`, `onDismiss` and an optional `dataSource` |
| `BeakThemeController` | The `ValueNotifier<OiThemeMode>` behind the theme toggle |
| `BeakLogoutButton(adapter:)` | The sign-out button of the shell |

Every option of the panel with its default is on [Panel and resource options](../reference/panel-options.md).

## Continue reading

- [Composed lists and query state](composed-lists.md): presets and saved views that navigation items can point at.
- [Custom screens](custom-screens.md): pages that appear as `BeakNavigationItem.screen` entries.
- [Auth and idle-lock](auth-and-idle-lock.md): the sign-in gate around the shell and its sign-out button.
- [Theming basics](../theming/theming-basics.md): the themes and the toggle the top bar drives.
