---
title: Beak
description: A low-code, configuration-driven admin-panel framework for Dart and Flutter. Define a model once, get a whole dashboard.
---

# Beak

Beak turns a single typed model definition into a running admin panel: a REST
backend and a Flutter dashboard, generated from the same columns, with no
hand-written endpoints and no client/server plumbing. You define what your data
is; Beak wires up how it is served, listed, filtered, edited, validated, and
exported.

Flutter's mascot is a bird, and birds have beaks. Beak is the toolbox for the
admin panel almost every app grows into. Its ORM sibling is `worm` (a bird has
to eat something).

## One definition, a whole panel

Here is a resource's columns, declared once as plain, typed Dart. No strings, no
`dynamic`, no annotations to remember.

```dart title="apps/reference_admin_models/lib/src/product.dart"
abstract final class ProductColumns {
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(255)],
  );

  static const price = BeakDecimalColumn(
    key: 'price',
    label: 'Price',
    prefix: '€',
    sortable: true,
    filterable: true,
    rules: [BeakRequired(), BeakMin(0)],
  );

  static const status = BeakEnumColumn<ProductStatus>(
    key: 'status',
    label: 'Status',
    values: ProductStatus.values,
    defaultValue: ProductStatus.draft,
    filterable: true,
    badgeColors: {
      ProductStatus.draft: BeakColor.muted,
      ProductStatus.published: BeakColor.success,
      ProductStatus.archived: BeakColor.warning,
    },
  );

  // ...plus description, stock, image, timestamps, and the category FK.

  static const List<BeakColumn> values = [name, price, status /* ... */];
}
```

That one `price` column is declared once and feeds six mouths: the table cell,
the form field (with client-side validation that mirrors the server), the detail
row, the filter, the REST validation, and the CSV export column.

To turn those columns into pages, name the model on a `BeakResource` and hand the
list to a `BeakPanel`. This is the whole app.

```dart title="apps/reference_admin/lib/main.dart"
BeakPanelConfig buildReferencePanelConfig({
  String apiBaseUrl = 'http://localhost:8080',
}) => BeakPanelConfig(
  title: 'Beak Admin',
  apiBaseUrl: apiBaseUrl,
  resources: const [
    BeakResource(
      model: ProductModel(),
      icon: BeakIconToken(OiIcons.package),
    ),
    // ...one BeakResource per model.
  ],
);

void main() => runApp(const ReferenceAdminApp());
```

The panel renders navigation, a list/create/show/edit page per resource, its
filters and actions, and the dashboard. The matching backend, generated from the
same models, serves it on port 8080.

## What you get

- **A generated REST backend.** CRUD, query, batch, relations, and aggregate
  endpoints, plus global search, CSV export, and validated file uploads, all from
  a `BeakModelRegistry` over the worm ORM.
- **A generated Flutter panel.** Tables, forms, detail views, filters, actions,
  and dashboards on `obers_ui`, built with HookWidgets, Signals, GetIt, and
  go_router. No Material, no per-page code.
- **Client validation that mirrors the server.** The rules on a column run in the
  form and again in the API, byte-for-byte, so bad data is caught twice.
- **Pluggable storage with file rules.** Memory and local disk ship in core; S3
  and FTP plug in via driver packages. Size and type limits live on the column.
- **Typed all the way down.** No `dynamic`, no `Map<String, Object?>` domain
  types, and no string field references in your app code.
- **A source-agnostic data seam.** `BeakDataSource` is an interface. worm backs it
  today; a future adapter can back it without touching `beak_core`.

## Where to go next

<div class="grid cards" markdown>

-   **[Start here](start-here/index.md)**

    Install Beak, boot the reference admin, and see the generated panel running
    against a live backend.

-   **[Tutorial: First Flight](tutorial/index.md)**

    Build a small coffee-roastery admin from an empty folder to a themed,
    authenticated panel, one model at a time.

-   **[Core concepts](concepts/index.md)**

    The one-definition promise, the four layers, and how a typed query travels
    from the panel to the database and back.

-   **[Reference](reference/index.md)**

    Every column, rule, block, REST route, exception, and config option, in
    tables you can scan.

-   **[Deployment](deployment/index.md)**

    The dev infrastructure, environment and config, and what changes when you take
    Beak to production.

</div>

## Continue reading

- [What is Beak?](start-here/what-is-beak.md) the elevator pitch and who Beak is for.
- [Quickstart](start-here/quickstart.md) the reference admin up and running in a few commands.
- [The one-definition promise](concepts/the-one-definition-promise.md) how one column drives six surfaces.
