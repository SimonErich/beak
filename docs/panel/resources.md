---
title: Resources
description: How Beak assembles a resource from the schema class, beak.yaml, and an optional lib/resources/<table>.dart, and the four CRUD pages it generates.
---

# Resources

After this page you can turn any schema class into a full list/create/show/edit
surface, file it under a sidebar section, and add typed actions, filters, and
view modes to it. You will not write a `BeakResource` to do any of it.

## What a resource is

A `BeakResource` is one model surfaced in the panel: the model, its navigation
presentation, and the typed actions, filters, and view modes its generated pages
expose. Beak builds that value for you. Your side of the deal is a schema class:

```dart title="examples/store/lib/models/category.dart"
@Resource()
final class Category extends BeakSchema {
  /// What the category is called.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// The one-line blurb shown above the product list.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? blurb;
}
```

`beak prepare` reads that class, writes `lib/models/category.beak.dart` (the
columns, the relationships, the model, the typed record view), writes the
migration once, and adds the resource to `lib/beak/panel.g.dart`. Categories now
have a sidebar entry, four pages, and an API. Nobody typed a `BeakResource`.

### Where each decision lives

The split is the thing to learn. Each decision has exactly one home.

| Decision | Where it lives |
| --- | --- |
| Columns, relationships, table name, soft deletes, timestamps | the `@Resource` class in `lib/models/<name>.dart` |
| Panel title, API origin, server port | `beak.yaml` |
| A resource's sidebar icon, label, section, or whether it is hidden | `beak.yaml`, under `resources.<table>` |
| A resource's filters, actions, view modes, detail layout, form steps | `lib/resources/<table>.dart` |
| Theme, auth, dashboard, server, whole-panel overrides | `lib/theme.dart`, `lib/auth.dart`, `lib/dashboard.dart`, `lib/server.dart`, `lib/panel.dart` |
| Everything else | generated into `lib/beak/*.g.dart` and `lib/models/*.beak.dart`, committed, never edited |

The type Beak assembles is still worth knowing, because the file you write to
adjust one resource takes it and returns it:

```dart title="packages/beak_frontend/lib/src/panel/beak_panel_config.dart"
const BeakResource({
  required this.model,
  required this.icon,
  this.label,
  this.section,
  this.recordActions = const [],
  this.bulkActions = const [],
  this.globalActions = const [],
  this.filters = const [],
  this.viewModes = const [BeakTableView()],
  this.detail,
  this.formSteps,
  this.formLayout,
});
```

| Field | Type | Comes from | What it does |
| --- | --- | --- | --- |
| `model` | `BeakModel` | the schema class | The model this resource exposes. |
| `icon` | `BeakIconToken` | `beak.yaml` | The sidebar icon. |
| `label` | `String?` | `beak.yaml` | Navigation label override (defaults to the title-cased table name). |
| `section` | `String?` | `beak.yaml` | Sidebar group heading this resource is filed under. |
| `recordActions` | `List<BeakRecordAction>` | your override | Extra per-row actions (view/edit/delete are built in). |
| `bulkActions` | `List<BeakBulkAction>` | your override | Actions over the list page's selection. |
| `globalActions` | `List<BeakGlobalAction>` | your override | Extra page-level list actions (create is built in). |
| `filters` | `List<BeakFilterDef>` | your override, or derived | The list page's filter controls. Empty means "derive them from the model". |
| `viewModes` | `List<BeakResourceView>` | your override | The list page's presentations; more than one adds a switcher. |
| `detail` | `BeakBlock?` | your override | A custom, record-bound show-page layout. |
| `formSteps` | `List<BeakFormStep>?` | your override | Renders the create/edit form as a multi-step wizard. |
| `formLayout` | `BeakBlock?` | your override | Renders the create/edit form through a record-bound block layout. |

Three of those never need an override at all. `filters` falls back to the
controls the model's `filterable` columns imply, `detail` falls back to the
layout the model implies, and `label` falls back to the title-cased table name.

### The icon is typed too

`icon` is a `BeakIconToken`, a zero-cost wrapper over `IconData` so the config
surface stays expressive without leaking raw icon plumbing. You do not construct
one. You name an `OiIcons` value in `beak.yaml`, in lowerCamelCase:

```yaml title="examples/store/beak.yaml"
resources:
  products:
    icon: package
    section: Catalog
  categories:
    icon: folderTree
    section: Catalog
```

and `beak prepare` splices it into the generated resource:

```dart title="examples/store/lib/beak/panel.g.dart"
      BeakResource(
        model: const CategoryModel(),
        icon: BeakIconToken(OiIcons.folderTree),
        section: 'Catalog',
      ),
```

An icon name that is not a lowerCamelCase identifier fails at `beak prepare`,
naming the offending line, rather than becoming a compile error inside a file you
did not write. Leave `icon` out and the resource gets `OiIcons.table`.

## The pages you get for free

One resource generates four routes and their pages, keyed on the model's table
name:

| Page | Route | What it renders |
| --- | --- | --- |
| List | `/{table}` | The model's table-context columns in a `BeakDataTable`, with the filter bar and the create action. |
| Create | `/{table}/create` | A `BeakDataForm` in create mode that returns to the list after saving. |
| Show | `/{table}/{id}` | The record through the detail layout, plus its to-many relation managers. |
| Edit | `/{table}/{id}/edit` | A `BeakDataForm` prefilled from `getOne`, returning to the show page after saving. |

The resource exposes helpers the pages read: `effectiveLabel` is the label shown
in navigation and page titles, `route` is the resource's list route,
`effectiveDetail` is the show-page layout, and `effectiveFilters` is the filter
bar. The last two are the fallbacks, and they are the reason most resources need
no file of their own.

## The built-in actions

Every resource carries four actions you never declare. The list page adds a
**view** and an **edit** row action to each row and a **create** global action to
the page header; the show page adds an **edit** and a **delete** action. They are
ordinary members of the sealed `BeakAction` family, so your custom actions sit
right beside them.

```dart title="packages/beak_frontend/lib/src/actions/built_in_actions.dart"
/// Navigates to the record's show page.
final class BeakViewAction extends BeakRecordAction {
  /// Creates the built-in view action.
  const BeakViewAction()
    : super(key: 'view', label: 'View', icon: OiIcons.eye, onExecute: _run);

  static Future<void> _run(BeakRecord record, BeakActionContext context) async {
    final Object? id = context.model.primaryKeyOf(record);
    if (id != null) {
      context.router.go(BeakRoutes.show(context.model.table, id));
    }
  }
}
```

The **delete** action is the interesting one: it renders destructively
(`BeakColor.error`) and commits through an optimistic-with-undo path. The delete
is offered with an undo toast and only hits the data source once the undo window
passes, after which the list refreshes and the router navigates back.

To add your own, hand a `BeakRecordAction` (or a bulk or global action) to the
matching list in your `copyWith`. [Actions](actions.md) covers the full family
and the `BeakActionContext` an action executes against.

## Sections group the sidebar

Give a resource a `section` in `beak.yaml` and Beak groups it under that heading
in the sidebar. The superdashboard files its 17 navigable resources into Store,
People, Projects, and Content, and keeps the other 32 models out of the sidebar
entirely:

```yaml title="examples/superdashboard/beak.yaml"
resources:
  # Store
  products:
    icon: package
    section: Store
  categories:
    icon: folderTree
    section: Store
  tags:
    icon: tag
    section: Store
  orders:
    icon: shoppingCart
    section: Store
  transactions:
    icon: creditCard
    section: Store
  # People
  users:
    icon: users
    section: People
```

Leave `section` off and the resource sits at the top level of the sidebar. Set
`hidden: true` and it leaves the sidebar without leaving the panel:

```yaml title="examples/store/beak.yaml"
  order_items:
    hidden: true
```

A hidden resource is still registered, still has an API, and is still reachable
as the far side of a relationship. It does not earn a sidebar entry, and that is
the whole of the difference.
[beak.yaml](../reference/beak-yaml.md) is the full key list.

## Adjusting a generated resource

When a resource needs something the schema class cannot say, add
`lib/resources/<table>.dart` exporting one function:

```dart
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  // the parts a person decides
);
```

`beak prepare` notices the file by its path and wraps the generated resource in
it. Nothing else changes: the model, icon, label, and section keep coming from
the schema class and `beak.yaml`, and every other resource in the panel stays
fully generated.

```dart title="examples/store/lib/beak/panel.g.dart"
      resource_products.beakResource(
        BeakResource(
          model: const ProductModel(),
          icon: BeakIconToken(OiIcons.package),
          section: 'Catalog',
        ),
      ),
```

`beak eject resource <table>` writes the starter for you. It returns `generated`
unchanged, so it compiles and changes nothing until your first edit.

!!! note "Notice the column constants"
    `ProductColumns.status`, `UserColumns.role`, `CalendarEventColumns.title`:
    filters, actions, and view modes bind to typed column constants, never to a
    string field name. Those constants are generated from the schema class, so
    renaming a field is a compile error rather than a broken filter. See
    [Column basics](../models/column-basics.md).

## Custom detail and form layouts

`detail`, `formLayout`, and `formSteps` replace the derived show page and form
with your own block tree. `detail` takes a record-bound `BeakBlock` (cards,
sections, tabs, grids of field blocks) rendered inside the loaded record's scope.
Leave it out and `effectiveDetail` derives a layout from the model: the display
column and the first few fields as a headline card, the rest beside it, and one
tab per to-many relationship.

`formLayout` gives the create/edit form that same cards-and-columns structure.
The trick the store uses is to pass the **same block tree** to both, so the show
page and the form cannot drift apart:

```dart title="examples/store/lib/resources/products.dart"
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: productLayout,
  formLayout: productLayout,
  recordActions: [
    BeakRecordAction(
      key: 'publish',
      label: 'Publish',
      icon: OiIcons.rocket,
      onExecute: (record, context) async {
        final Object? id = context.model.primaryKeyOf(record);
        if (id == null) {
          return;
        }
        await context.dataSource.update(
          context.model.table,
          id,
          BeakRecord(
            values: {
              ProductColumns.status.key: BeakValue.of(
                ProductStatus.published.name,
              ),
              ProductColumns.publishedAt.key: BeakValue.of(DateTime.now()),
            },
          ),
        );
      },
    ),
  ],
  // ... bulk actions ...
  viewModes: const [
    BeakTableView(),
    BeakKanbanView(
      groupField: ProductColumns.status,
      titleField: ProductColumns.name,
      subtitleField: ProductColumns.sku,
    ),
  ],
);
```

`formSteps` instead turns the form into a multi-step wizard and takes precedence
over `formLayout`. The store's orders use it to break the create form into four
explained steps, each covering one or two columns:

```dart title="examples/store/lib/resources/orders.dart"
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  formSteps: const [
    BeakFormStep(
      title: 'Customer',
      subtitle: 'Who is buying',
      icon: OiIcons.user,
      description:
          'Pick the customer this order belongs to. Their past orders appear '
          'on their own page once this one is saved.',
      columns: [OrderColumns.customerId],
    ),
    // ...Order, Money, Delivery
  ],
);
```

These three are the bridge to Beak's dual-mode record blocks: one tree renders
read-only in a detail scope and editable in a form scope. That story lives on
[Detail views and dual-mode blocks](detail-and-dual-mode.md) and
[Multi-step forms](multi-step-forms.md).

## Continue reading

- [Tables and filters](tables-and-filters.md) how the generated list renders,
  sorts, filters, and paginates, and where filters come from when you declare
  none.
- [View modes](view-modes.md) add a calendar or a board beside the table.
- [Actions](actions.md) the typed action family behind view/edit/delete/create.
- [Defining models](../models/defining-models.md) the schema class a resource is
  built from.
- [beak.yaml](../reference/beak-yaml.md) the icon, label, section, and hidden
  keys.
