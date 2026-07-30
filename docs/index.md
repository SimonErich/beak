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

## One declaration, a whole panel

Here is a resource. One file, one class, plain typed Dart.

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

The field's **type** picks the column: `String` is single-line text, `BeakText`
is multi-line, `double` is a decimal, `BeakImageRef` is an upload. Its
**nullability** decides required-ness, once, for the form validator, the API's
validation and the database's `NOT NULL` alike.

Then:

```bash
beak prepare
```

From that one class Beak generates the typed column constants, the model, both
sides of every relationship, a typed record view, the migration that creates
the table, and the wiring that registers all of it. There is no registry to
edit and no resource to declare. A file under `lib/models/` is a resource.

```bash
beak dev
```

You now have a REST API with query, batch, relations, aggregates, global search
and CSV export, and a panel with a list, a detail page, create and edit forms,
filters, sorting, pagination, soft delete and restore. Per resource, you wrote
the class above.

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
- **Four worked examples.** [`examples/quickstart`](https://github.com/SimonErich/beak/tree/main/examples/quickstart)
  is what `beak create` gives you, [`store`](https://github.com/SimonErich/beak/tree/main/examples/store)
  is the whole feature surface at teaching size, `superdashboard` is 49 models
  of it, and `embedded` mounts Beak inside an app that already exists.
- **A source-agnostic data seam.** `BeakDataSource` is an interface. worm backs it
  today; a future adapter can back it without touching `beak_core`.

## Where to go next

<div class="grid cards" markdown>

-   **[Start here](start-here/index.md)**

    Install Beak, create a project, and have a panel running against your own
    resource in about a minute.

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
- [Quickstart](start-here/quickstart.md) an empty folder to a running panel, in about a minute.
- [The one-definition promise](concepts/the-one-definition-promise.md) how one column drives six surfaces.
