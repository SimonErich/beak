---
title: Resources
description: Declare how a model appears in the panel with a BeakResource, from its title and sidebar group to its screens, filters, search sources and actions.
type: guide
audience: [beginner]
status: stable
---

# Resources

You have a model and no screen for it yet. A `BeakResource` says how that model shows up in the panel: its title, its place in the sidebar, the screens behind its four routes, the filters, the search fields and the actions on its rows.

You only write one when the defaults are not enough. A resource that names nothing but `model:` already gets a list, a create form, a show page and an edit form, all derived from the model's columns.

## At a glance

| | |
| --- | --- |
| Declared in | `lib/resources/<feature>/<name>_resource.dart`, one `final class XResource extends BeakResource` per model |
| Smallest form | `BeakResource(model: const NoteModel())` |
| Routes it owns | `/notes`, `/notes/create`, `/notes/:id`, `/notes/:id/edit` (the path comes from `model.table`) |
| Registered by | Generated panel: `beak prepare` finds the class. Authored panel: you list it in `BeakPanel(resources: [...])` |
| Enforces access | No. It hides UI. The server enforces |

## The smallest useful resource

This is the shop's category resource. `model` is the only required argument, everything else is a decision you make on purpose.

```dart title="examples/clean_beak_config/lib/resources/categories/category_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/categories/category_resource.dart:CategoryResource"
```

Typing the class yourself is optional. `beak eject resource <table>` writes it for a model that exists:

```console
$ beak eject resource notes
  created lib/resources/notes/note_resource.dart

  run `beak prepare` to wire it up
```

The file is a `BeakResource` subclass that carries whatever `beak.yaml` gave the default resource, so it changes nothing until your first edit:

```dart title="lib/resources/notes/note_resource.dart"
final class NoteResource extends BeakResource {
  /// Creates the notes resource.
  const NoteResource()
    : super(
        model: const NoteModel(),
        icon: const BeakIconToken(OiIcons.fileText),
        navigationGroup: 'Content',
      );
}
```

## What a resource holds

| Field | Default | What it does |
| --- | --- | --- |
| `model` | required | The model this resource exposes |
| `icon` | `BeakIconToken(OiIcons.database)` | Sidebar icon. Wrap any `OiIcons` value. Default resources from `beak prepare` use `OiIcons.table` |
| `title` | table name, title-cased (`order_items` becomes "Order Items") | Page title of the list |
| `navigationTitle` | `title` | Sidebar label, when it should differ from the page title |
| `navigationGroup` | none | Heading in the automatic sidebar. See [Navigation](navigation.md) |
| `navigationRank` | `0` | Order among resources. Ties keep declaration order |
| `screens` | `[]` | Table, form, wizard or custom screens for the four routes |
| `globalSearchSources` | `[]` | Fields the command bar and a composed list's search box use. Empty means the model's `searchable` columns |
| `filters` | `[]` | Filter controls on the list. Empty means the model's `filterable` columns |
| `recordActions`, `bulkActions`, `globalActions` | `[]` | Extra actions on a row, on a selection and on the page. See [Actions](actions.md) |
| `canCreate`, `canEdit`, `canDelete` | `true` | Switches for the matching route and button |
| `deleteAction` | `BeakDeleteAction()` | What the Delete button does. `BeakDeleteAction.confirmed()` asks first and waits for the server, `BeakArchiveAction()` is the same under another label |
| `duplication` | none | Adds a Duplicate row action to the list. See below |
| `onActionError` | none | Your hook for failures of custom actions. Without it Beak shows an error toast |
| `filePicker`, `uploader` | none | Overrides for upload fields in this resource's forms |

The shop's product resource fills the first block of that table like this. Group and rank shape the sidebar, the search sources and filters come further down the same file:

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:ProductResourceIdentity"
```

## Registering resources

A resource that nobody registers is a class in a folder. How it gets into the panel depends on how the panel boots. Both ways take the same classes, and `beak eject main` moves a generated project to the authored form, see [Two ways to boot a panel](../start-here/generated-or-authored.md).

=== "Generated panel"

    `beak prepare` scans `lib/` for classes that extend `BeakResource`. It finds public, non-abstract classes with an unnamed constructor that takes no required arguments. Each one replaces the default resource of the model it configures, matched by table when the panel starts. A resource that needs arguments is composed by hand, and the generated panel keeps the default for its model.

    Models without a class get a default resource, dressed with whatever `beak.yaml` says under `resources:`, keyed by table:

    ```yaml title="examples/quickstart/beak.yaml"
    resources:
      notes:
        icon: fileText
        section: Content
    ```

    | Key | Becomes | Meaning |
    | --- | --- | --- |
    | `icon` | `icon` | An `OiIcons` name in lowerCamelCase. `beak prepare` rejects anything that is not a lowerCamelCase identifier, and a name `OiIcons` lacks fails the compile of `panel.g.dart` |
    | `label` | `title` | Page title and sidebar label |
    | `section` | `navigationGroup` | Heading in the automatic sidebar |
    | `hidden` | none | `true` skips the default resource. No sidebar entry, no routes. The model keeps its API and stays reachable through relationships |

    A `BeakResource` class for a hidden model is still shown: writing the class is the decision. The result is `lib/beak/panel.g.dart`:

    ```dart title="examples/quickstart/lib/beak/panel.g.dart"
    --8<-- "examples/quickstart/lib/beak/panel.g.dart"
    ```

    To change something about the whole panel that no resource owns, run `beak eject panel`. It writes `lib/panel.dart`, and its `beakPanel` function receives the finished config:

    ```console
    $ cat lib/panel.dart
    BeakPanelConfig beakPanel(BeakPanelConfig defaults) => defaults;
    ```

    Return `defaults.copyWith(...)` there to add a navigation, a notification source or a maintenance page, see [Navigation](navigation.md).

=== "Authored panel"

    You own the list. `beak prepare` never rewrites an authored `lib/main.dart`, so a new resource class is unused until you add it to `resources:`. `beak doctor` warns about the ones you forgot:

    ```console
    $ beak doctor
      OK   discovered 1 model · 1 resource class · 0 screens · 1 override
      WARN NoteResource (lib/resources/notes/note_resource.dart) is not listed in lib/main.dart's resources: [...], so the panel never shows it
           → add NoteResource() to the resources list in lib/main.dart; `beak prepare` never rewrites an authored entrypoint
    ```

    The shop registers its resources this way:

    ```dart title="examples/clean_beak_config/lib/main.dart"
    --8<-- "examples/clean_beak_config/lib/main.dart:shopMain"
    ```

The shop registers 11 resources for 20 models. Related models register themselves through the relationships that reach them, so a line-item model does not need a sidebar entry to take part in an order form.

## The panel around your resources

`BeakPanel(...)` takes the everyday options directly. A complete `BeakPanelConfig` takes all of them, and `BeakPanel(config: ...)` hands it over. You cannot pass both: `config:` together with `resources:` fails an assertion.

| Option | `BeakPanel(...)` | `BeakPanelConfig` |
| --- | --- | --- |
| `title`, `resources`, `pages`, `apiBaseUrl`, `theme`, `darkTheme`, `locale`, `formatting`, `auth`, `navigation`, `refreshPolicy`, `home` | yes | yes |
| `maintenance`, `notifications`, `shellActions`, `mapException` | no | yes |
| `initialThemeMode`, `supportedLocales`, `localizationsDelegates` | no | yes |
| `sidebarCollapsible`, `sidebarDefaultCollapsed` | no | yes |
| `dataSource`, `httpClient` | yes | no |

`dataSource` and `httpClient` replace the transport under the panel. Widget tests use them to pump a panel against an in-memory source, and a panel with an external authentication adapter needs `dataSource` unless its models bring their own. Foodio builds a `BeakPanelConfig` because it uses notifications and shell actions:

```dart title="examples/foodio-adminpanel/lib/main.dart"
--8<-- "examples/foodio-adminpanel/lib/main.dart:foodioPanelConfig"
```

Every option with its default is on [Panel and resource options](../reference/panel-options.md).

### Where `/` goes

`home:` takes a `BeakResource` or a `BeakScreen`, never a route string. It is where `/` sends the user, and where sign-in and the error pages' back buttons land. The order is fixed:

1. A `BeakScreen` mounted at `/` wins, and `home` is not consulted.
2. `home`, when the resource is visible to the current account.
3. The first visible item of the `BeakNavigation` sections, in order, bottom sections last.
4. The first visible resource in navigation order, then the first page with `showInNav`.
5. Nothing to show: the not-found page.

## The four routes

Every resource owns four routes, all flat (a list page is not kept alive under its create or edit page, so coming back re-queries).

| Route | Role | Generated page | Opens when | Otherwise |
| --- | --- | --- | --- | --- |
| `/notes` | `list` | Table with filters, search and pagination | `isVisible` | redirect to `/403` |
| `/notes/create` | `create` | Create form | `allowsCreate` | redirect to `/403` |
| `/notes/:id` | `read` | Read-only show page with Edit, Delete and record actions | `isVisible` | redirect to `/403` |
| `/notes/:id/edit` | `edit` | Edit form | `allowsEdit` | redirect to `/403` |

`screens` replaces any of them. It takes any mix of `BeakTableScreen` (the list), `BeakFormScreen` and `BeakWizardScreen` (read, create and edit) and `BeakCustomResourceScreen` (any role, your widget). Each screen declares the roles it serves. A `BeakFormScreen` serves create and edit unless you say otherwise, so the shop lists `read` too and gets one layout for all three routes:

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:ProductScreens"
```

A role you leave out falls back to the generated page. The screens themselves are covered in [Tables and filters](tables-and-filters.md), [Form screens](../forms/form-screens.md) and [Custom screens](custom-screens.md).

## Who may see and change it

Two layers hide UI, and neither one protects data.

`canCreate`, `canEdit` and `canDelete` are per-resource switches. `BeakModel.permissions` is per model, so every resource that uses the model shares it. It maps each `BeakOperation` (`read`, `create`, `update`, `delete`) to a closure that answers for the account signed in right now. A missing rule denies, and a model without a `permissions` getter allows everything.

A schema class supplies the getter as `static BeakPermissions get permissions` and the generated model forwards it. Here it is on a plain model, from the panel's own tests:

```dart title="packages/beak_frontend/test/src/panel/beak_panel_test.dart"
--8<-- "packages/beak_frontend/test/src/panel/beak_panel_test.dart:WriteGatedNoteModel"
```

Three inputs decide each operation. All must say yes:

| Operation | Model transport supports it | Resource switch | `permissions` rule |
| --- | --- | --- | --- |
| Read (list, show, sidebar, command bar) | `capabilities` has `read` | none | `read` |
| Create | `capabilities` has `create`, or a custom create screen exists | `canCreate` | `create` |
| Edit | `capabilities` has `update`, or a custom edit screen exists | `canEdit` | `update` |
| Delete | `capabilities` has `delete` | `canDelete` | `delete` |

Every other operation needs read access first. A resource whose `read` rule says no leaves the sidebar and the command bar, and its routes redirect to `/403`. A `create` or `update` rule that says no does the same for its route and button, and `delete` hides the Delete button. Custom actions need read access and keep their own checks.

The server keeps answering anyone who calls the API directly. The real rule belongs in `BeakPolicies` on the backend, see [Auth and policies](../backend/auth-and-policies.md). One case is worth knowing: a `deletableWhen` on the model's behavior is checked by the server too, because a model with behavior is served graph-only and the panel deletes through a graph commit (the HTTP source does; a source without commits sends a plain delete).

## Duplicating a record

`duplication` adds a Duplicate action to each list row. It opens the create form with a copy of the record, and nothing is written until the user saves. Ordinary values and shared references (the category, the tax rate) are kept. Identity, timestamps, unique columns, password columns and calculated values are cleared. Collections you name in `relations` are copied with new identities, and `reset` clears further fields that must be unique again.

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:ProductDuplication"
```

`relations` accepts owned has-many relationships of the resource's own model, and `includeNestedOwned` (default `true`) copies the owned descendants of those collections too. `reset` accepts fields of the model and of the copied child models. The action shows only when the resource allows create.

## Rules and limits

| Rule | What happens |
| --- | --- |
| A panel needs a resource or a page | `A panel needs at least one resource or page to show.` |
| At most one screen per role | `Resource "orders" defines more than one list screen.` |
| `BeakTableScreen.query` targets the resource's own table | `Table screen query must target "orders".` |
| A `BeakFormScreen` cannot serve the list route | `A form screen cannot serve the list route.` Use `BeakTableScreen` or `BeakCustomResourceScreen` |
| `globalSearchSources` are scalar fields rooted at this model | Related paths are fine (`OrderModel.customer.email`, `OrderModel.items.search(OrderItemModel.label)`). Otherwise `Global search for "orders" requires scalar fields rooted at that model.` |
| One resource per table | `A model for table "orders" is already registered.` |
| `home` is one of the panel's resources or pages | `The home destination "/other" must be one of the panel's resources or pages.` |
| `home` does not sit behind a screen at `/` | `The home destination "/orders" is unreachable: a screen already claims "/".` |
| A password column is never searched | The command bar reports `Password column "password" cannot be searched.` under the resource name. This one shows at search time, not at boot |
| `BeakModel.permissions` holds closures, not values | They run each time a route or button is evaluated, so they see the account signed in at that moment |
| `canDelete: false` hides the button | Only the model's `deletableWhen` (or a server policy) stops the API. The shop's invoice sets both, its order sets the switch alone |
| `copyWith` cannot clear a value | Passing `null` keeps the current one |

The first eight fail when the panel first builds, not at the first click. That is the point of writing resources as typed objects.

## Verify it

The shop tests its own resources: duplication resets the selling identities, and the catalog and customer resources share one read, create and edit layout. From `examples/clean_beak_config`:

```console
$ flutter test test/shop_resource_test.dart
00:00 +0: product duplication preserves catalog values and resets selling identities
00:00 +1: catalog and customer forms share a structured read/create/edit layout
00:00 +2: All tests passed!
```

For a generated project, `beak prepare` prints what it found (`1 model · 1 resource class · 0 screens · 1 override`) and `beak doctor` names any resource class the authored panel does not list, as shown above.

## Reference

The constructor, verbatim:

```dart title="packages/beak_frontend/lib/src/panel/beak_resource.dart"
--8<-- "packages/beak_frontend/lib/src/panel/beak_resource.dart:BeakResource"
```

| Member | Meaning |
| --- | --- |
| `screenFor(BeakScreenRole role)` | The configured screen for a role, or `null` for the generated page. Throws when a role has two |
| `isVisible`, `allowsCreate`, `allowsEdit`, `allowsDelete` | Live availability: the model's `capabilities`, the resource switch and `BeakModel.permissions` combined |
| `allowsAction(BeakAction action)` | The same answer for one action. The `deleteAction` follows `allowsDelete`, create and edit follow theirs, other actions need read access |
| `effectiveLabel`, `effectiveNavigationTitle` | The title and the sidebar label after defaults |
| `effectiveFilters` | The declared `filters`, or the ones `filterable` columns imply |
| `route`, `location` | The list route, `/<table>` |
| `copyWith(...)` | A copy with parts replaced, for adjusting a shared resource without redeclaring it |

`BeakIconToken` is an extension type over Flutter's `IconData`: `BeakIconToken(OiIcons.package)`. The columns, roles and layouts a screen takes are in [Screens and form layouts](../reference/screens-and-layouts.md), the filter definitions in [Filter builders](../reference/filter-builders.md).

## Continue reading

- [Navigation](navigation.md): build the sidebar, counts and command bar around your resources.
- [Tables and filters](tables-and-filters.md): choose the columns, filters and search of the list.
- [Actions](actions.md): row, bulk and global actions and model commands.
- [Form screens](../forms/form-screens.md): one layout for read, create and edit.
- [Add a resource](../recipes/add-a-resource.md): the shortest path from a schema class to a working screen.
