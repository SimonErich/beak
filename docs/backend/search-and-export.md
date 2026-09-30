---
title: Search and export
description: Search across own and related fields with the query spec, and download the same authorized rows as CSV, with display formatting or raw values.
type: guide
audience: [expert]
status: stable
---

# Search and export

Search and export are the query you already know, with one more field on it. After this page you can search a table through its relationships, predict what the server does with a term, and download exactly the rows a user is looking at as CSV.

There is no `GET /api/search`. A search is a `search` field on the spec that `POST /api/{table}/query` takes, and an export is `POST /api/{table}/export` with that same spec. Both go through the same policy, row scope and field access as any other read, so nothing on this page opens a second door.

## At a glance

| You want | Send | Gate |
| --- | --- | --- |
| Rows of one table that match a term | `"search": {"term": "...", "columns": [...]}` in the query spec | `canView`, row scope, read access to every searched column and relationship |
| A term across all resources | One query per resource. The panel's command bar does exactly that | Each resource's own gate |
| The rows of a query as CSV | `POST /api/{table}/export` with the spec plus `columns`, `formatting`, `formats`, `raw` | The same as `query` |

## Search is a field of the query

```console
$ curl -s -X POST localhost:8392/api/products/query -H 'content-type: application/json' \
    -d '{"table":"products","search":{"term":"grind","columns":["name"]}}'
{"items":[{"values":{"id":"00000000-0000-4000-8000-000000000002","name":"Grinder","price":48.0,"active":null,"stock":null,"created_at":null,"updated_at":null},"relations":{}}],"total":1,"page":1,"perPage":25}
```

`columns` are column keys, and a dotted key walks a relationship: `variants.sku` searches the SKUs of a product's variants. The server folds the search into the spec's `filter` before it runs anything, as one `OR` over the columns, then combines it with the permanent filter and the caller's row scope. So `total`, paging and sorting all describe the searched population, and the query that reaches the database carries no separate search.

The shop searches a product by its own fields, its category, and its images, attributes and variants. A search through a to-many path is a relation filter, so no product is listed twice:

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:listProductSearch"
```

A resource lists its search sources as typed fields (`ProductModel.category.name`, `ProductModel.variants.search(ProductVariantModel.sku)`), so a rename is a compile error. Without `globalSearchSources`, the panel searches the model's columns marked `searchable: true`. The shop's API tests send the same searches over the wire, through real SQLite:

```dart title="examples/clean_beak_config/test/shop_api_test.dart"
--8<-- "examples/clean_beak_config/test/shop_api_test.dart:shopCollectionSearch"
```

### What a term becomes

The term is trimmed, and a blank term adds no predicate at all, so every row matches. Each column turns it into a predicate suited to its kind, and the results are joined with `OR`:

| Column | Predicate |
| --- | --- |
| Text, long text, rich text, enum names, colors, file keys | Case-insensitive `LIKE '%term%'`, with `%`, `_` and `\` in the term matched literally |
| Integer, decimal, boolean, timestamp | Typed equality when the term parses as that type, otherwise the column is skipped |
| Exact decimal, money, date, time, duration | Typed equality through the column's codec, skipped when the term does not parse |

A term that no searched column can represent matches no rows, and the page is empty:

```console
$ curl ... -d '{"table":"products","search":{"term":"zzz","columns":["name"]}}'
{"items":[],"total":0,"page":1,"perPage":25}
```

[Queries](../reference/queries.md#search) has the whole table and the JSON of `BeakSearch`.

### What the server refuses

| Search names | Result |
| --- | --- |
| A column the caller may not read, or a relationship on the path they may not read | `401` anonymous, `403` signed in. The search is refused, not silently narrowed, because a narrowed search would still leak |
| A related model the caller may not view | The same, and each hop applies that model's row scope |
| A password column | `422`: `Password column "..." cannot be searched.` |
| A JSON or custom column | `422`. `searchable: true` on a custom column fails here, at search time |
| A column or relationship that does not exist | `422`: `Model "products" has no column "nope".` |
| A path longer than 17 segments | `422` |

### The command bar

The panel's command bar is the one search that spans resources, and it is client-side. For each visible resource it sends one `POST /api/{table}/query` with `perPage: 5`. A resource whose searched fields are all text sends a `search`. One with numbers, enums, dates or booleans sends an `OR` filter of typed predicates instead, so a number finds a price and a word finds an enum status. A resource that is refused shows its own error, and the others still list their matches.

That is one request per visible resource per search. A panel with thirty resources sends thirty queries, and each needs to be cheap: index the columns you search, or narrow `globalSearchSources`.

## Export

An export takes the query spec plus four optional keys, and answers with a CSV attachment:

```console
$ curl -s -X POST localhost:8392/api/products/export -H 'content-type: application/json' \
    -d '{"table":"products","sorts":[{"column":"name","descending":false}]}'
Name,Price,Active,Stock,Updated
=1+1,1234.50,,,2026-09-29T14:59:49.544Z
A,1.00,,,2026-09-29T14:56:57.480Z
...
"Comma, ""quoted""",1234.50,,,2026-09-29T14:59:49.556Z
```

The response is `text/csv; charset=utf-8` with `content-disposition: attachment; filename="products.csv"`, UTF-8 without a byte order mark, and `\r\n` line endings. Cells with a comma, a quote or a line break are quoted, and quotes are doubled.

What the file contains:

- Every row that matches the spec's `filter`, `search` and `sorts`. The spec's `pagination` is ignored: the service reads the table 500 rows at a time and streams them, so memory stays flat and the browser downloads everything. Your sorts come first and the primary key breaks their ties (it is appended unless you already sort by it), so a row written while the file is being made is not skipped or written twice at a page boundary.
- The header is the labels of the columns the model shows in a table, in order, unless `columns` names others. Those are the columns whose `visibleOn` includes the table context.
- Only columns the caller may read. An unreadable column is dropped from the header and from every row.
- Password columns as `••••••••`, in every mode.
- Row scopes and soft deletes as in `query`. Send `"withTrashed": true` to include deleted rows.

The first page is queried before the response starts, so a bad spec, an unknown column, a policy refusal or a display pattern intl cannot format (a `formatting` date pattern such as `EEEEEEE`, or one longer than 64 characters) arrives as an ordinary error envelope. A failure on a later page cannot: the status line is already sent, so the stream ends short and the download is a truncated file with a `200`.

### Choosing the cell text

| Key | Type | Meaning |
| --- | --- | --- |
| `columns` | list of column keys | Which columns, in which order. Non-empty, unique, known. An unknown key is a `422` `Unknown export column "nope".` |
| `formatting` | a `BeakFormatPolicy` as JSON | Locale, currency, date patterns and precision for display values |
| `formats` | `{key: {format, minorUnits, scale}}` | A per-column override. `format` is a `BeakValueFormat` name; `scale` is 0 to 12 and the key must be among the exported columns |
| `raw` | bool | Physical storage values with no display formatting. Cannot be combined with the two keys above |

With neither `formatting` nor `raw`, a cell is the canonical text: decimals at their column precision, `true`/`false`, ISO-8601 timestamps in UTC, exact money as major-unit decimal text. That is right for a script. For a spreadsheet a person opens, send the policy the panel shows them:

```console
$ curl ... -d '{"table":"products","formatting":{"locale":"de_AT","currency":"EUR"}}'
Name,Price,Active,Stock,Updated
Espresso beans,"12,50",Yes,,
Padded beans,"3,00",,,2026-09-29 14:53
$ curl ... -d '{"table":"products","columns":["name","price"],"formatting":{"locale":"de_AT","currency":"EUR"},"formats":{"price":{"format":"currency","minorUnits":false,"scale":2}}}'
Name,Price
Espresso beans,"€ 12,50"
$ curl ... -d '{"table":"products","raw":true,"columns":["name","price","active","updated_at"]}'
Name,Price,Active,Updated
Espresso beans,12.5,true,
Padded beans,3.0,,2026-09-29T14:53:38.709Z
```

Three details of the formatted form bite in practice:

- A null cell is an empty cell, whatever `emptyValue` says. The policy's placeholder (an em dash by default) is for the screen; a file gets nothing.
- Times are UTC. The policy JSON never carries the browser's zone, so the server does not guess one. Send `"timeZoneOffsetMinutes": 120` for a fixed offset (`14:59` becomes `16:59`). There are no named zones and no daylight saving.
- Malformed options are a `422` and never a silent fallback: an unknown locale is `Malformed export formatting: Unsupported formatting locale.`, and `raw` together with `formatting` or `formats` is `Raw exports cannot also request display formatting.`

Exact decimals and money are formatted from their scaled integers, never through a floating-point value in between. `raw` keeps the storage form (`12.5` for a plain decimal, integer units for exact money), which is the right choice for a downstream job and the wrong one for a person.

### From the panel

A composed list gets its export button from `BeakListExport(fields:, label:, fileName:, raw:)`. The button freezes the query and selection at the moment of the click, sends the columns in the order the fields are listed, and attaches the panel's `BeakFormatting` and the formats that typed presentation fields carry, so a downloaded amount matches what the user saw. It needs a data source that implements `BeakExportDataSource`, which the HTTP one does. [Composed lists](../panel/composed-lists.md) shows the configuration, and [Export to CSV](../recipes/export-to-csv.md) the recipe.

From Dart, `BeakClient.export(table, spec, formatting:, columns:, formats:, raw:)` calls the same route and returns the CSV as a string.

## Rules and limits

| Rule | Consequence |
| --- | --- |
| No global search route | Search across resources is one query per resource, made by the client |
| `%`, `_` and `\` in a term match themselves | Searching `%` finds the rows that contain a percent sign. `contains`, `startsWith` and `endsWith` filters behave the same. A `like` or `ilike` operand is a pattern, so there `%` and `_` stay wildcards and a backslash escapes the next character |
| Text matching is `LIKE` | Case-insensitive on Postgres. On SQLite only for ASCII letters: `plain` matches `PLAIN`, and `äpf` does not match `Äpfel` |
| A bad column in `search` is a `422` | Validate keys in your client. The panel only sends keys from your resource definition |
| A search over an unreadable column is refused | Do not put a field in `globalSearchSources` that some roles cannot read, or their search fails as a whole |
| An export has no row limit | Every matching row is streamed. Filter it, and put a proxy timeout in front of a very large table |
| A failure after the first page truncates the file | The response is already `200`. Compare the row count with `total` from a query if the file matters |
| A cell that would run as a formula gets a leading quote | A value that begins with `=`, `+`, `-` or `@` (after any spaces, or with a tab or carriage return in front) is written with a `'` in front, so `=1+1` arrives as text: `'=1+1`. A cell that is only a number, such as `-5`, is left alone. The quote is part of the cell, so a job that reads the file back strips it |
| No byte order mark | Excel may need the import dialog with UTF-8 selected to show `Ä` correctly |
| Sort order comes from the database | Byte order on SQLite, the collation on Postgres. `Ä` sorts after `p` on SQLite |
| Formatted times are UTC or a fixed offset | Send `timeZoneOffsetMinutes`. Device-local conversion is never applied on the server |

## Verify it

Search for a term two ways, and check that the count agrees with the exported rows:

```console
$ curl -s -X POST localhost:8392/api/products/query -H 'content-type: application/json' \
    -d '{"table":"products","search":{"term":"bea","columns":["name"]}}' | sed 's/.*"total":\([0-9]*\).*/\1/'
2
$ curl -s -X POST localhost:8392/api/products/export -H 'content-type: application/json' \
    -d '{"table":"products","search":{"term":"bea","columns":["name"]}}' | wc -l
3
```

Three lines are the header and two rows. Then check the policy the same way you would for a query: an anonymous export of a model that needs a login must answer `401`, and an export as a row-scoped user must contain only their rows. The export tests in `packages/beak_backend/test/src/export/csv_export_test.dart` cover formatting, raw values, redaction, paging and errors.

## Reference

- `packages/beak_core/lib/src/query/beak_search_filter.dart`: `beakSearchFilter`, the predicate per column kind.
- `packages/beak_backend/lib/src/auth/beak_query_authorizer.dart`: where the search is folded into the filter and authorized.
- `packages/beak_backend/lib/src/export/csv_export_service.dart` and `packages/beak_backend/lib/src/export/export_router.dart`: the export.
- `packages/beak_core/lib/src/formatting/beak_format_policy.dart`: `BeakFormatPolicy` and its JSON.
- `packages/beak_frontend/lib/src/panel/beak_command_bar.dart`: the cross-resource search.

## Continue reading

- [Queries](../reference/queries.md) the spec both routes take, with filters, sorts and pagination.
- [Export to CSV](../recipes/export-to-csv.md) the panel button and the client call in a recipe.
- [Auth and policies](auth-and-policies.md) the read, field and row rules a search and an export obey.
- [Security](../shipping/security.md) the hardening list, spreadsheet formulas included.
