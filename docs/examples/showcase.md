---
title: Showcase
description: "Tour the Aviary, the example that uses every column kind, relationship kind and block type, and the tests that keep it complete when Beak grows."
type: example
audience: [beginner, expert, agent]
status: stable
---

# Showcase

The Aviary is a small admin for an aviary keeper. It exists to show, in real code, every Beak feature the [clean shop](clean-shop.md) and the [Foodio admin](foodio.md) do not touch: all 13 column kinds, all four relationship kinds and every block type. Three tests fail when Beak gains a kind this example does not demonstrate, so the docs can point here for any of them and the answer stays true.

## At a glance

| | |
| --- | --- |
| Domain | Birds, habitats, keepers, chores, and the media, messages and prices that fill the demo pages |
| Models | 14 schema classes in `lib/resources/*/models/` |
| Resources | 4: Specimens, Habitats, Keepers, Tasks |
| Pages | 12 custom pages, one per block category, in `lib/pages/` |
| Panel bootstrap | Authored: `buildPanel()` returns a `BeakPanel` |
| API port | 8082 (`server.port` in `beak.yaml`), panel on web port 3003 |
| Auth | None. The example has no auth, idle lock, host app or maintenance wiring |
| Database | SQLite file `beak.db` |
| Tests | 36, in two groups: exhaustiveness (kinds and blocks) and behavior (pages, resources, API, migrations) |
| Read it if | You look for a working example of one specific column, relationship or block |

## Run it

```console
cd examples/showcase
flutter pub get
beak migrate
beak seed
beak dev
```

```console
$ beak migrate
  14 models · 4 resource classes · 0 screens · 0 overrides
  generated  up to date (7 files)
migrated  20260926_000000_beak_commit_receipts
migrated  20260927_000000_beak_outbox
migrated  20260929_054949_create_assets_table
...
migrated  20260929_055002_create_tasks_table
migrated  20260929_055003_create_habitat_keeper_table

$ beak seed
seeded  AviarySeeder

$ beak dev
  14 models · 4 resource classes · 0 screens · 0 overrides
  generated  up to date (7 files)
  panel      run this in another terminal:
               flutter run -d chrome
  api        starting…
listening on http://0.0.0.0:8082
```

The last migration creates the pivot table `habitat_keeper`, which no schema class owns. The seed is repeatable and leaves existing rows alone. Start the panel with the port the README uses:

```console
flutter run -d chrome --web-port=3003 --dart-define=BEAK_API_BASE_URL=http://127.0.0.1:8082
```

The panel's default API origin is already `http://localhost:8082`. The define matters when you open the panel through `127.0.0.1`.

!!! note "What just happened"
    - Fourteen tables and one pivot table exist, filled with 14 birds, six habitats, 12 chores for the board and calendar, 20 price candles and 28 sightings for the charts.
    - The 12 pages read that data through the API. The demo data is seeded rows, not values hard-coded in a widget.

## Tour

### 1. Thirteen column kinds on one class

`Specimen` is the kitchen sink. Every field is commented with the kind it demonstrates, and `test/column_kind_matrix_test.dart` fails to compile when Beak adds a kind this class lacks.

| Column kind | Field on `Specimen` |
| --- | --- |
| string | `commonName`, `scientificName` |
| text | `notes` |
| rich text | `careGuide` |
| int | `clutchSize`, `wingspanInCentimeters` |
| decimal | `weightInGrams` (a `double`) and `acquisitionCost` (an exact `BeakDecimal`) |
| bool | `endangered` |
| date-time | `hatchedAt` |
| enum | `diet`, with labels and badge colors |
| json | `telemetry` |
| color | `plumageColor` |
| image | `photo`, resized to a thumbnail on upload |
| file | `healthCertificate`, PDF only |
| custom | `bandCode` |

The class is about 110 lines. Read it in the file, and see [Fields](../models/fields.md) and [Field types](../reference/field-types.md) for what each kind stores, validates and renders. The one kind that needs code on your side is the custom column: the schema class names a tag, the app registers a renderer for that tag.

```dart title="examples/showcase/lib/resources/specimens/models/specimen.dart"
--8<-- "examples/showcase/lib/resources/specimens/models/specimen.dart:SpecimenBandCode"
```

```dart title="examples/showcase/lib/widgets/band_code_cell.dart"
--8<-- "examples/showcase/lib/widgets/band_code_cell.dart:registerAviaryRenderers"
```

```dart title="examples/showcase/lib/widgets/band_code_cell.dart"
--8<-- "examples/showcase/lib/widgets/band_code_cell.dart:bandCodeCell"
```

The tag comes from the generated `SpecimenColumns.bandCode.tag`, so the schema class is the only place that spells it. [Custom columns](../extending/custom-columns.md) has the whole story.

### 2. Semantic fields

A semantic adds meaning to a plain type: how to format it, which input to show, what to validate. The Aviary uses five:

| Semantic | Where |
| --- | --- |
| `BeakSemantic.money(scale: 2)` with `currencyFrom: #currency` | `Specimen.acquisitionCost`, priced in the currency of the record's own `currency` field |
| `BeakSemantic.email()` | `Specimen.reporterEmail`, `Keeper.email` |
| `BeakSemantic.url()` | `Specimen.referenceUrl` |
| `BeakSemantic.phone()` | `KeeperProfile.emergencyPhone` |
| `BeakSemantic.fileSize()` | `Asset.sizeInBytes` |

The shop's `FulfillmentPolicy` uses the same per-record currency idea for its delivery fee, and the [clean shop](clean-shop.md) holds all its other amounts in EUR. See [Semantic fields](../models/semantic-fields.md).

### 3. Four relationship kinds

`Keeper` declares two of them, and its neighbours declare the other two:

```dart title="examples/showcase/lib/resources/keepers/models/keeper.dart"
--8<-- "examples/showcase/lib/resources/keepers/models/keeper.dart:Keeper"
```

| Kind | Declared as |
| --- | --- |
| belongs to | `Specimen.habitat` |
| has one | `Keeper.profile`, owned, deleted with the keeper |
| has many | `Habitat.specimens` |
| belongs to many | `Keeper.habitats` and `Habitat.keepers`, joined by the table `habitat_keeper` |

The many-to-many side has its own API. Attach and detach are routes on the record, and a test drives them:

```console
POST /api/habitats/<id>/relations/keepers/attach
POST /api/habitats/<id>/relations/keepers/detach
```

[Relationships](../models/relationships.md) explains ownership, `onDelete` and inverses.

### 4. Soft deletes and timestamps

`Specimen` and `Keeper` set `softDeletes: true`. A delete then hides the row instead of removing it, and a restore brings it back:

```console
$ curl -s -o /dev/null -w '%{http_code}\n' -X DELETE localhost:8082/api/specimens/00000000-0000-4000-8000-010000000001
204
$ curl -s -o /dev/null -w '%{http_code}\n' localhost:8082/api/specimens/00000000-0000-4000-8000-010000000001
404
$ curl -s -o /dev/null -w '%{http_code}\n' -X POST localhost:8082/api/specimens/00000000-0000-4000-8000-010000000001/restore
200
```

`Specimen`, `Habitat` and `Task` set `timestamps: true`, which adds `created_at` and `updated_at`. `test/aviary_api_test.dart` covers the same round trip.

### 5. Every block type, one page per category

`main.dart` lists the pages. The category is the file name:

```dart title="examples/showcase/lib/main.dart"
--8<-- "examples/showcase/lib/main.dart:aviaryPages"
```

| Page (route) | Blocks | Block docs |
| --- | --- | --- |
| Layout blocks (`/layout`) | grid, row, column, card, section, tabs, accordion, masonry, divider, spacer, widget | [Layout blocks](../blocks/layout-blocks.md) |
| Content blocks (`/content`) | text, markdown, image, badge, alert, progress, rating, radial slider, breadcrumbs, icon gallery | [Content blocks](../blocks/content-blocks.md) |
| Data blocks (`/`) | metric, summary, table, timeline | [Data blocks](../blocks/data-blocks.md) |
| Planner (`/planner`) | kanban, calendar | [Data blocks](../blocks/data-blocks.md), [A kanban view](../recipes/a-kanban-view.md) |
| Charts (`/charts`) | line, area, bar, pie, donut, radar, funnel, bubble, candlestick, heat map | [Charts](../blocks/charts.md) |
| Maps (`/maps`) | choropleth, tile map | [Maps](../blocks/maps.md) |
| Chat, Inbox, Files, Media, Documents, FAQ (`/chat`, `/inbox`, `/files`, `/media`, `/documents`, `/faq`) | chat, inbox, file manager, three pane, carousel, gallery, video, profile, invoice, pricing, FAQ | [Module blocks](../blocks/module-blocks.md) |
| Keeper read screen | field, field group, relation | [Record blocks](../blocks/record-blocks.md) |

The pattern is the same everywhere: a block names a model or a query, and Beak fetches. This is a complete chart, and the board and the calendar are the same shape:

```dart title="examples/showcase/lib/pages/chart_blocks.dart"
--8<-- "examples/showcase/lib/pages/chart_blocks.dart:chart"
```

```dart title="examples/showcase/lib/pages/data_blocks.dart"
--8<-- "examples/showcase/lib/pages/data_blocks.dart:board"
```

### 6. Record blocks on a custom read screen

Record blocks have no query. They read the record that a surrounding `BeakRecordScope` carries, so one block tree shows whichever keeper the route names:

```dart title="examples/showcase/lib/resources/keepers/keeper_sheet.dart"
--8<-- "examples/showcase/lib/resources/keepers/keeper_sheet.dart:keeperSheetBlock"
```

No built-in page mounts that scope, so the example does it itself when it loads the record:

```dart title="examples/showcase/lib/resources/keepers/keeper_sheet.dart"
--8<-- "examples/showcase/lib/resources/keepers/keeper_sheet.dart:recordScopeHandOff"
```

`KeeperResource` plugs the screen in with `BeakCustomResourceScreen(roles: {BeakScreenRole.read}, ...)`. See [Record blocks](../blocks/record-blocks.md) and [Custom screens](../panel/custom-screens.md).

### 7. Why the example stays complete

Beak's column kinds, relationship kinds and block types are sealed class hierarchies. Dart cannot list the subtypes of a sealed class at runtime, so each matrix test switches over the hierarchy with no default branch. When Beak adds a subtype, the switch stops compiling. Adding the arm forces a new enum value, and the test then fails until the Aviary builds one.

```dart title="examples/showcase/test/column_kind_matrix_test.dart"
--8<-- "examples/showcase/test/column_kind_matrix_test.dart:kindOf"
```

The block matrix does the same for the 47 block kinds, and walks the panel's pages to find each one. If you add a block to Beak, the checklist is: compile, add the arm, add the block to a page under `lib/pages/`.

## Where things are

| Path | Role |
| --- | --- |
| `lib/main.dart` | `buildPanel()`: theme, formatting, resources, the 12 pages |
| `lib/resources/specimens/` | The 13-kind schema class and its resource |
| `lib/resources/keepers/` | Has-one, belongs-to-many, soft deletes, and the record-block read screen |
| `lib/resources/habitats/`, `lib/resources/tasks/` | Has-many and belongs-to-many, the board and calendar model with enum badges |
| `lib/resources/{assets,candles,faqs,invoices,messages,plans,sightings}/models/` | Models that feed the demo pages |
| `lib/pages/` | One file per block category, plus `chart_data.dart` for the chart queries and mappers |
| `lib/widgets/band_code_cell.dart` | The custom column's renderer |
| `lib/migrations/` | One migration per table, plus the pivot |
| `lib/seeders/aviary_seeder.dart` | Repeatable demo data |
| `test/` | Three matrix tests, page and resource tests, API and migration tests |

## Features shown

| Feature | File | Docs page |
| --- | --- | --- |
| All 13 column kinds | `lib/resources/specimens/models/specimen.dart` | [Field types](../reference/field-types.md) |
| Enum labels and badges | `lib/resources/tasks/models/task.dart` | [An enum badge column](../recipes/an-enum-badge-column.md) |
| A custom column and its renderer | `lib/widgets/band_code_cell.dart` | [Custom columns](../extending/custom-columns.md) |
| Semantic fields: money with `currencyFrom`, email, url, phone, file size | `lib/resources/specimens/models/specimen.dart` | [Semantic fields](../models/semantic-fields.md) |
| Image and file columns with upload rules | `lib/resources/specimens/models/specimen.dart` | [Files and storage columns](../models/files-and-storage-columns.md) |
| Has one, belongs to many | `lib/resources/keepers/models/keeper.dart` | [Relationships](../models/relationships.md) |
| Soft deletes and timestamps | `lib/resources/specimens/models/specimen.dart` | [Defining models](../models/defining-models.md) |
| Layout and content blocks | `lib/pages/layout_blocks.dart`, `lib/pages/content_blocks.dart` | [Layout blocks](../blocks/layout-blocks.md) |
| Metric, summary, table, timeline | `lib/pages/data_blocks.dart` | [Data blocks](../blocks/data-blocks.md) |
| Kanban and calendar | `lib/pages/data_blocks.dart` | [A kanban view](../recipes/a-kanban-view.md) |
| Charts | `lib/pages/chart_blocks.dart`, `lib/pages/chart_data.dart` | [Charts](../blocks/charts.md) |
| Choropleth and tile map | `lib/pages/map_blocks.dart` | [Maps](../blocks/maps.md) |
| Chat, inbox, file manager, media and other module blocks | `lib/pages/module_blocks.dart` | [Module blocks](../blocks/module-blocks.md) |
| Record blocks in a record scope | `lib/resources/keepers/keeper_sheet.dart` | [Record blocks](../blocks/record-blocks.md) |
| Filters, global search, navigation groups | `lib/resources/specimens/specimen_resource.dart` | [Tables and filters](../panel/tables-and-filters.md) |
| Panel theme and formatting | `lib/main.dart` | [Theming basics](../theming/theming-basics.md) |

## Tests

```console
cd examples/showcase
flutter test --no-pub
```

All 36 passed on 2026-09-29.

| Test file | What it proves |
| --- | --- |
| `block_type_matrix_test.dart` | Every one of the 47 block kinds is built by some page, and the record blocks sit on the keeper read screen |
| `column_kind_matrix_test.dart` | `Specimen` declares all 13 column kinds, semantics carry their meaning, soft deletes and timestamps are on |
| `relation_kind_matrix_test.dart` | All four relationship kinds are declared, the pivot is named, every relationship points at a registered model |
| `aviary_pages_test.dart` | Each of the 12 pages renders without an exception |
| `aviary_resources_test.dart` | Lists, the create form, the detail page, the custom column and the keeper read screen |
| `aviary_api_test.dart` | Migrate and seed, a full column-kind round trip over HTTP, soft delete and restore, pivot loading, attach and detach |
| `aviary_migrations_test.dart` | Every migration rolls back and applies again, in the order its name declares |

`test/support/aviary_pump.dart` pumps a page against an in-memory source. `test/support/aviary_test_api.dart` starts the real host on in-memory SQLite. Both are worth copying for your own tests, see [Testing](../shipping/testing.md).

## Limits

- No auth, idle lock, maintenance page, notifications or host app. The docs for those quote package tests and say so.
- Four resources for 14 models. The others exist to feed pages, and have no resource of their own.
- The demo data is fixed. Chat messages, prices and sightings are rows, not a live feed.
- Kanban and calendar edit through the per-record routes, which a `graphOnly` model closes. This example has no such model, so it does not exercise that case.
- The Aviary is not a design reference. The look is Beak's default theme with one brand colour. For a designed panel, read the [Foodio admin](foodio.md).

## Continue reading

- [Foodio admin](foodio.md): the opposite trade-off, a few features taken all the way into a designed application.
- [Feature map](feature-map.md): every feature against the example and file that shows it.
- [Blocks and charts](../blocks/index.md): the block system these pages exercise.
- [Serverpod admin](serverpod-admin.md): the same panel on a different backend.
