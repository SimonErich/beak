# The Aviary

A small admin panel for an aviary keeper. It exists to show, in real code, every
Beak feature the other examples do not use: all thirteen column kinds, all four
relationship kinds, and every block type. The docs quote these files, and three
tests fail when Beak grows a column kind, a relationship kind or a block type
this example does not demonstrate.

It is deliberately small: four resources, one page per block category, and no
auth, idle lock, host app or maintenance wiring (the docs quote package tests
for those).

## Run

From this directory:

```sh
flutter pub get
dart run ../../packages/beak_cli/bin/beak.dart prepare
dart run bin/migrate.dart migrate
dart run bin/migrate.dart db:seed
dart run bin/serve.dart
```

The API listens on `http://localhost:8082` and keeps its data in a local SQLite
file, `beak.db`. The seed is repeatable and leaves existing rows alone.

In a second terminal:

```sh
flutter run -d chrome --web-port=3003 \
  --dart-define=BEAK_API_BASE_URL=http://127.0.0.1:8082
```

## Test

```sh
flutter analyze --fatal-infos --fatal-warnings
flutter test --no-pub
dart run ../../packages/beak_cli/bin/beak.dart doctor --json
```

For the coverage gate, generate the report first, then run the checker from the
repository root:

```sh
flutter test --no-pub --coverage
cd ../.. && dart run tool/check_coverage.dart
```

## Feature to file

Snippets the docs quote sit between `// --8<-- [start:Name]` and
`// --8<-- [end:Name]` comments.

| Feature | Where |
| --- | --- |
| All 13 column kinds (string, text, richText, int, decimal, bool, dateTime, enum, json, color, file, image, custom) | `lib/resources/specimens/models/specimen.dart` |
| Semantic fields (money with `currencyFrom`, email, url) | `lib/resources/specimens/models/specimen.dart` |
| Semantic fields (phone, file size) | `lib/resources/keepers/models/keeper_profile.dart`, `lib/resources/assets/models/asset.dart` |
| A custom column and the renderer that draws it | `specimen.dart` (`@Custom('band-code')`), `lib/widgets/band_code_cell.dart` |
| `softDeletes` and `timestamps` | `Specimen` (both), `Keeper` (soft deletes), `Habitat` (timestamps) |
| BelongsTo | `Specimen.habitat` |
| HasOne | `Keeper.profile` in `lib/resources/keepers/models/keeper.dart` |
| HasMany | `Habitat.specimens` in `lib/resources/habitats/models/habitat.dart` |
| BelongsToMany with a pivot table | `Keeper.habitats` and `Habitat.keepers`, joined by `habitat_keeper` |
| Enum columns with labels and badges | `Diet` in `specimen.dart`, `TaskStatus` in `lib/resources/tasks/models/task.dart` |
| Resource classes: filters, global search, navigation groups, table fields | `lib/resources/*/*_resource.dart` |
| A custom resource screen | `lib/resources/keepers/keeper_resource.dart`, `keeper_sheet.dart` |
| Record blocks (field, field group, relation) inside a record scope | `lib/resources/keepers/keeper_sheet.dart` |
| The panel: theme, formatting, resources, pages | `lib/main.dart` |
| Layout blocks (grid, row, column, card, section, tabs, accordion, masonry, divider, spacer, widget) | `lib/pages/layout_blocks.dart` |
| Content blocks (text, markdown, image, badge, alert, progress, rating, radial slider, breadcrumbs, icon gallery) | `lib/pages/content_blocks.dart` |
| Data blocks (metric, summary, table, timeline) | `lib/pages/data_blocks.dart` |
| Kanban and calendar | `lib/pages/data_blocks.dart` (`plannerPage`) |
| Charts (line, area, bar, pie, donut, radar, funnel, bubble, candlestick, heat map) | `lib/pages/chart_blocks.dart`, `lib/pages/chart_data.dart` |
| Maps (choropleth and tile map) | `lib/pages/map_blocks.dart` |
| Modules (chat, inbox, file manager, three pane, carousel, gallery, video, profile, invoice, pricing, FAQ) | `lib/pages/module_blocks.dart` |
| Migrations, one per table, plus the pivot | `lib/migrations/` |
| Repeatable demo data | `lib/seeders/aviary_seeder.dart` |
| Every block type is built somewhere | `test/block_type_matrix_test.dart` |
| Every column kind is declared on `Specimen` | `test/column_kind_matrix_test.dart` |
| Every relationship kind is declared | `test/relation_kind_matrix_test.dart` |
| Every page and resource renders | `test/aviary_pages_test.dart`, `test/aviary_resources_test.dart` |
| Migrate, seed and CRUD over the real host on in-memory SQLite | `test/aviary_api_test.dart`, `test/aviary_migrations_test.dart`, `test/support/aviary_test_api.dart` |

## Adding a feature Beak gains

Beak's sealed hierarchies make the matrix tests exhaustive, with no default
branch. A new block type stops `block_type_matrix_test.dart` compiling until it
has an arm, and the arm then fails the test until a page under `lib/pages/`
builds one. New column and relationship kinds work the same way, against
`Specimen` and the schema classes.
