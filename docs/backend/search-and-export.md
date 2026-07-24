---
title: Search and export
description: Two endpoints the registry gives you for free: a global search across every searchable column, and a streamed CSV export that honours the current query.
---

# Search and export

Registering a model gets you two more endpoints without a line of extra code: a
global search across every model's searchable columns, and a CSV export that
streams the exact rows a table view is showing. This page covers both, what
drives them, and the small design choices that keep them honest.

Both features read through the same [`BeakDataSource`](../concepts/how-data-flows.md)
the rest of the backend uses, so they respect your relations, soft deletes, and
storage seam. Neither one has a bespoke query path.

## Global search: `GET /api/search`

One endpoint searches everything. `GlobalSearchService` walks the registry, and
for each model asks the data source for the top few records matching a term,
then returns flat `BeakSearchHit`s in registration order.

The rule that keeps it predictable: **only columns you declared `searchable`
participate.** A model with no searchable columns is skipped entirely.

```dart title="packages/beak_backend/lib/src/search/global_search_service.dart"
final searchableColumns = [
  for (final column in model.columns)
    if (column.searchable) column,
];
if (searchableColumns.isEmpty) {
  continue;
}
final page = await dataSource.query(
  BeakQuerySpec(table: model.table)
      .searching(term, searchableColumns)
      .paginate(page: 1, perPage: perModel),
);
```

The `searchable` flag lives on the column, next to everything else that column
drives. Mark the two or three fields worth matching (a name, an email) and leave
the rest off. See [Column basics](../models/column-basics.md) for where the flag
sits.

Each hit is the shared `BeakSearchHit` wire type from `beak_core`: the table, the
record's id, its display label, and which searchable column actually matched.

| Field | What it is |
| --- | --- |
| `table` | the model the hit belongs to |
| `id` | the matching record's primary key |
| `displayLabel` | the record's `displayColumnKey` value, ready to show |
| `matchedColumnKey` | the searchable column whose value contained the term |

### The request and response

The handler parses `q` (required), an optional `perModel` cap, and an optional
`tables` allow-list, then narrows to the tables the policy says this caller may
view before searching. Results come back grouped by table.

| Query parameter | Default | Meaning |
| --- | --- | --- |
| `q` | (required) | the term to search for; empty is a 400 |
| `perModel` | `5` | max hits per model; must be a positive integer |
| `tables` | all | comma-separated allow-list of tables to search |

```dart title="packages/beak_backend/lib/src/search/search_router.dart"
final viewableTables = [
  for (final model in service.registry.all)
    if (policy.canView(principal, model.table) &&
        (requestedTables == null || requestedTables.contains(model.table)))
      model.table,
];
final hits = await service.search(
  term,
  perModel: perModel,
  tables: viewableTables,
);
final grouped = <String, List<Map<String, Object?>>>{};
for (final hit in hits) {
  grouped.putIfAbsent(hit.table, () => []).add(hit.toJson());
}
return Response.ok(jsonEncode({'results': grouped}));
```

The [policy](auth-and-policies.md) gate runs before the search, not after, so a
caller never even learns that a table they cannot view exists. Against the
reference store on port 8080:

```bash
curl -s 'http://localhost:8080/api/search?q=roast&perModel=3'
# {"results":{"products":[{"table":"products","id":"...",
#   "displayLabel":"House Roast","matchedColumnKey":"name"}]}}
```

From the panel you call it through `BeakClient.search`, which flattens the
grouped response back into a flat list in table order. The command bar's search
box is the usual caller.

!!! note "What just happened"
    - Only `name` and `description` on the product model carry `searchable: true`,
      so those are the only columns searched.
    - `perModel: 3` capped each model to three hits, keeping a broad search fast.
    - The response groups hits by table so the UI can render one section per
      model.

## CSV export: `POST /api/{table}/export`

Every model gets a `POST /export` route that streams its rows as CSV. The body is
a `BeakQuerySpec`, the same filter-and-sort object a table view builds, so an
export gives you exactly what you are looking at: filter the table, hit export,
get those rows and no others.

```dart title="packages/beak_backend/lib/src/export/csv_export_service.dart"
Future<Stream<List<int>>> exportCsv(String table, BeakQuerySpec spec) async {
  final model = registry.byTableOrThrow(table);
  if (spec.table != model.table) {
    throw BeakValidationException(
      'Export spec targets "${spec.table}" but this endpoint serves '
      '"${model.table}".',
    );
  }
  final firstPage = await dataSource.query(
    spec.paginate(page: 1, perPage: pageSizeInRows),
  );
  return _stream(model, spec, firstPage);
}
```

### Why the first page runs before the stream

Look at the order in `exportCsv`. Spec validation and the first page's query both
run **eagerly**, before the returned `Stream` exists. That is deliberate. Once a
`200 OK` and the CSV header bytes are on the wire, no error envelope can follow.
By fetching the first page inside the request, a bad spec or a dead database
surfaces as a typed exception that the handler maps to a clean 400 or 500,
instead of a truncated download with a misleading success status. Later pages can
still fail (and will truncate the body), but the common failures are caught while
a proper error response is still possible.

After that, rows stream in pages of 500 (`pageSizeInRows`), so exporting a large
table keeps memory flat rather than buffering every row.

### The rows

The header comes from the model's table-context column labels, then one row per
record. `renderCell` decides how each value serialises: timestamps as ISO-8601,
decimals at their configured precision, everything else as its raw string, and
`null` as an empty cell.

```dart title="packages/beak_backend/lib/src/export/csv_export_service.dart"
static String renderCell(BeakColumn column, BeakValue? value) {
  final Object? raw = value?.raw;
  if (raw == null) {
    return '';
  }
  return switch (column) {
    BeakDateTimeColumn() => switch (raw) {
      final DateTime instant => instant.toIso8601String(),
      final Object other => other.toString(),
    },
    BeakDecimalColumn(:final precision) => switch (raw) {
      final num number => number.toStringAsFixed(precision),
      final Object other => other.toString(),
    },
    _ => raw.toString(),
  };
}
```

Cells that contain a comma, a quote, or a newline are quoted and their quotes
doubled, so the output is valid CSV even for messy text.

### The endpoint

The export handler checks `canView` before it parses the spec, then returns the
stream as a downloadable attachment.

```dart title="packages/beak_backend/lib/src/export/export_router.dart"
Future<Response> export(Request request) async {
  enforcePolicyDecision(
    allowed: policy.canView(beakPrincipal(request), model.table),
    principal: beakPrincipal(request),
    action: 'export',
    table: model.table,
  );
  final spec = readBeakSpec(
    await readJsonObject(request),
    BeakQuerySpec.fromJson,
  );
  return Response.ok(
    await service.exportCsv(model.table, spec),
    headers: {
      'content-type': 'text/csv; charset=utf-8',
      'content-disposition': 'attachment; filename="${model.table}.csv"',
    },
  );
}
```

Export the in-stock products, sorted, straight to a file:

```bash
curl -s http://localhost:8080/api/products/export \
  -H 'content-type: application/json' \
  -d '{"table":"products","sorts":[{"columnKey":"name","descending":false}]}' \
  -o products.csv
```

`BeakClient.export` is the panel-side wrapper; the table view's export action
posts the current spec for you. See [Tables and filters](../panel/tables-and-filters.md)
for where that button lives.

## Continue reading

- [The generated API](the-generated-api.md) the full route list search and
  export slot into.
- [Column basics](../models/column-basics.md) the `searchable` flag that decides
  what search touches.
- [How data flows](../concepts/how-data-flows.md) the `BeakQuerySpec` an export
  reuses.
- [Auth and policies](auth-and-policies.md) the `canView` gate both endpoints
  consult.
- [Tables and filters](../panel/tables-and-filters.md) the panel views that build
  the specs.
