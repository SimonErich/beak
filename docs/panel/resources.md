---
title: Resources
description: The anatomy of a BeakResource (model, icon, section, actions, filters, view modes, detail, and form layout) and the CRUD pages it generates.
---

# Resources

After this page you can turn any registered model into a full list/create/show/edit
surface, file it under a sidebar section, and add typed actions and filters to it,
all without writing a page.

## What a resource is

A `BeakResource` is one model surfaced in the panel. Declaring it is all it takes
to get four generated pages (a list, a create form, a show page, and an edit form)
plus the built-in view, edit, delete, and create actions. Everything else on the
constructor is opt-in refinement.

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

| Field | Type | Default | What it does |
| --- | --- | --- | --- |
| `model` | `BeakModel` | required | The model this resource exposes. |
| `icon` | `BeakIconToken` | required | The sidebar icon (wrap an `OiIcons` value). |
| `label` | `String?` | `null` | Navigation label override (defaults to the title-cased table name). |
| `section` | `String?` | `null` | Sidebar group heading this resource is filed under. |
| `recordActions` | `List<BeakRecordAction>` | `[]` | Extra per-row actions (view/edit/delete are built in). |
| `bulkActions` | `List<BeakBulkAction>` | `[]` | Actions over the list page's selection. |
| `globalActions` | `List<BeakGlobalAction>` | `[]` | Extra page-level list actions (create is built in). |
| `filters` | `List<BeakFilterDef>` | `[]` | The list page's filter controls. |
| `viewModes` | `List<BeakResourceView>` | `[BeakTableView()]` | The list page's presentations; more than one adds a switcher. |
| `detail` | `BeakBlock?` | `null` | A custom, record-bound show-page layout. |
| `formSteps` | `List<BeakFormStep>?` | `null` | Renders the create/edit form as a multi-step wizard. |
| `formLayout` | `BeakBlock?` | `null` | Renders the create/edit form through a record-bound block layout. |

### The icon is typed too

`icon` is a `BeakIconToken`, a zero-cost wrapper over `IconData` so resource
declarations stay expressive without leaking raw icon plumbing into the config
surface. Wrap any obers_ui `OiIcons` value:

```dart title="apps/beak_superdashboard/lib/panel/resources.dart"
BeakResource(
  model: ProductModel(),
  icon: BeakIconToken(OiIcons.package),
  section: 'Store',
  detail: productLayout,
  formLayout: productLayout,
  filters: [
    BeakSelectFilter(column: ProductColumns.status, label: 'Status'),
    BeakTextFilter(column: ProductColumns.name, label: 'Name'),
  ],
),
```

## The pages you get for free

One `BeakResource` generates four routes and their pages, keyed on the model's
table name:

| Page | Route | What it renders |
| --- | --- | --- |
| List | `/{table}` | The model's table-context columns in a `BeakDataTable`, with the filter bar and the create action. |
| Create | `/{table}/create` | A `BeakDataForm` in create mode that returns to the list after saving. |
| Show | `/{table}/{id}` | The record through the detail view (or your `detail` layout), plus its to-many relation managers. |
| Edit | `/{table}/{id}/edit` | A `BeakDataForm` prefilled from `getOne`, returning to the show page after saving. |

The resource exposes those first two as helpers: `effectiveLabel` is the label
shown in navigation and page titles (falling back to the title-cased table name),
and `route` is the resource's list route.

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
matching list on the resource. [Actions](actions.md) covers the full family and
the `BeakActionContext` an action executes against.

## Sections group the sidebar

Give resources a `section` string and Beak groups them under that heading in the
sidebar, in declaration order. The superdashboard files its 17 resources into
Store, People, Projects, and Content:

```dart title="apps/beak_superdashboard/lib/panel/resources.dart"
List<BeakResource> buildResources() => const [
  // ── Store ─────────────────────────────────────────────────────────────────
  BeakResource(
    model: ProductModel(),
    icon: BeakIconToken(OiIcons.package),
    section: 'Store',
    detail: productLayout,
    formLayout: productLayout,
    // …
  ),
  // ── People ────────────────────────────────────────────────────────────────
  BeakResource(
    model: UserModel(),
    icon: BeakIconToken(OiIcons.users),
    section: 'People',
    detail: userDetail,
    formLayout: userDetail,
    filters: [
      BeakSelectFilter(column: UserColumns.role, label: 'Role'),
      BeakSelectFilter(column: UserColumns.status, label: 'Status'),
    ],
  ),
  // …
];
```

Leave `section` off and the resource sits at the top level of the sidebar, which
is how the tutorial store keeps its handful of models flat:

```dart title="apps/reference_admin/lib/main.dart"
BeakResource(
  model: ProductModel(),
  icon: BeakIconToken(OiIcons.package),
  filters: [
    BeakSelectFilter(column: ProductColumns.status, label: 'Status'),
    BeakTextFilter(column: ProductColumns.name, label: 'Name'),
  ],
  recordActions: [
    BeakRecordAction(
      key: 'duplicate',
      label: 'Duplicate',
      icon: OiIcons.copy,
      onExecute: duplicateProduct,
    ),
  ],
),
```

!!! note "Notice the column constants"
    `ProductColumns.status`, `UserColumns.role`, `CalendarEventColumns.title`:
    filters, actions, and view modes bind to the typed column constants your
    model exports, never to a string field name. That is the one-definition
    promise reaching the panel. See [Column basics](../models/column-basics.md).

## Custom detail and form layouts

`detail`, `formLayout`, and `formSteps` let a resource replace the generated show
page and form with your own block tree. `detail` takes a record-bound `BeakBlock`
(cards, sections, tabs, grids of field blocks) rendered inside the loaded record's
scope; when it is `null`, the show page falls back to the generated
definition-grid detail plus the record's to-many relation managers.

`formLayout` gives the create/edit form that same cards-and-columns structure.
The trick the superdashboard uses is to pass the **same block tree** to both, so
the show page and the form share one layout. `formSteps` instead turns the form
into a multi-step wizard and takes precedence over `formLayout`.

These three are the bridge to Beak's dual-mode record blocks: one tree renders
read-only in a detail scope and editable in a form scope. That story lives on
[Detail views and dual-mode blocks](detail-and-dual-mode.md) and
[Multi-step forms](multi-step-forms.md).

## Continue reading

- [Tables and filters](tables-and-filters.md) how the generated list renders,
  sorts, filters, and paginates.
- [View modes](view-modes.md) add a calendar or a board beside the table.
- [Actions](actions.md) the typed action family behind view/edit/delete/create.
- [Defining models](../models/defining-models.md) the model a resource wraps.
