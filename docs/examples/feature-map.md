---
title: Feature map
description: Find the example, the file and the docs page for a Beak feature, from column kinds to graph preparers, in one table per area.
type: reference
audience: [expert, agent]
status: stable
search: {boost: 2}
---

# Feature map

Look up a feature, get the example that shows it, the file to open and the docs page that explains it. Each row points at a real file that contains the feature, so the map answers "where is this done in working code" without a search.

## Import

Nothing to import: the examples are applications, not libraries. Read the columns like this.

| Column | Meaning |
| --- | --- |
| Feature | What the row demonstrates, in the words the docs use |
| Example | Which example holds it. The link goes to that example's tour |
| File | Path from the repository root. Open it, or ask an agent to |
| Docs | The pages that explain the feature |

To run an example, follow its tour page or the run table on [Examples](index.md). The paths below use the folder names on disk:

| Example | Folder |
| --- | --- |
| [Quickstart](quickstart.md) | `examples/quickstart` |
| [Shop](clean-shop.md) | `examples/clean_beak_config` |
| [Foodio](foodio.md) | `examples/foodio-adminpanel` |
| [Showcase](showcase.md) | `examples/showcase` |
| [Serverpod](serverpod-admin.md) | `examples/serverpod` |

## Summary

106 rows in eight groups. When several examples show a feature, the row names the smallest or clearest one. The shop is the default choice for anything a normal application does, the showcase for anything about column, relationship and block kinds, Foodio for lists, wizards, effects and theming at full size, and the Serverpod example for auth and policy.

### Project, generation and tooling

| Feature | Example | File | Docs |
| --- | --- | --- | --- |
| Generated panel bootstrap | [Quickstart](quickstart.md) | `examples/quickstart/lib/main.dart` | [Two ways to boot a panel](../start-here/generated-or-authored.md) |
| Authored panel bootstrap | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/main.dart` | [Two ways to boot a panel](../start-here/generated-or-authored.md), [Resources](../panel/resources.md) |
| Panel built from a public config function | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/main.dart` | [Panel and resource options](../reference/panel-options.md) |
| Generated registry, panel, app and server wiring | [Quickstart](quickstart.md) | `examples/quickstart/lib/beak/server.g.dart` | [Generated files and symbols](../reference/generated-files.md), [Code generation](../architecture/code-generation.md) |
| Project configuration in beak.yaml | [Quickstart](quickstart.md) | `examples/quickstart/beak.yaml` | [beak.yaml](../reference/beak-yaml.md) |
| Server port set in beak.yaml | [Showcase](showcase.md) | `examples/showcase/beak.yaml` | [beak.yaml](../reference/beak-yaml.md) |
| The agent rules block | [Quickstart](quickstart.md) | `examples/quickstart/AGENTS.md` | [Set up your agent](../ai/setup.md) |

### Models and fields

| Feature | Example | File | Docs |
| --- | --- | --- | --- |
| Schema class with timestamps | [Quickstart](quickstart.md) | `examples/quickstart/lib/resources/notes/models/note.dart` | [Defining models](../models/defining-models.md) |
| Required and optional from the Dart type | [Quickstart](quickstart.md) | `examples/quickstart/lib/resources/notes/models/note.dart` | [Fields](../models/fields.md) |
| Column options: searchable, sortable, rules | [Quickstart](quickstart.md) | `examples/quickstart/lib/resources/notes/models/note.dart` | [Fields](../models/fields.md) |
| All 13 column kinds | [Showcase](showcase.md) | `examples/showcase/lib/resources/specimens/models/specimen.dart` | [Field types](../reference/field-types.md) |
| Enum labels and badges | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/models/order.dart` | [An enum badge column](../recipes/an-enum-badge-column.md) |
| Exact money | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/products/models/product.dart` | [Semantic fields](../models/semantic-fields.md), [A money field](../recipes/a-money-field.md) |
| Money in the currency of another field | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart` | [Semantic fields](../models/semantic-fields.md) |
| Percentage, quantity with unit, slug and typed object | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart` | [Semantic fields](../models/semantic-fields.md) |
| Phone, email, url and file size semantics | [Showcase](showcase.md) | `examples/showcase/lib/resources/keepers/models/keeper_profile.dart` | [Semantic fields](../models/semantic-fields.md) |
| Money stored as integer cents | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart` | [Formatting and localization](../theming/formatting-and-localization.md) |
| Soft deletes | [Showcase](showcase.md) | `examples/showcase/lib/resources/specimens/models/specimen.dart` | [Defining models](../models/defining-models.md) |
| Image column with a thumbnail transform | [Showcase](showcase.md) | `examples/showcase/lib/resources/specimens/models/specimen.dart` | [Files and storage columns](../models/files-and-storage-columns.md) |
| File column with type and size rules | [Showcase](showcase.md) | `examples/showcase/lib/resources/specimens/models/specimen.dart` | [Files and storage columns](../models/files-and-storage-columns.md) |
| Custom column and its renderer | [Showcase](showcase.md) | `examples/showcase/lib/widgets/band_code_cell.dart` | [Custom columns](../extending/custom-columns.md) |
| Dynamic attributes driven by a category | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/domain/shop_attributes.dart` | [Dynamic attributes and variants](../models/dynamic-attributes-and-variants.md) |
| Variant builder | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/products/screens/variant_builder.dart` | [Dynamic attributes and variants](../models/dynamic-attributes-and-variants.md) |
| A column kept out of the Beak model | [Serverpod](serverpod-admin.md) | `examples/serverpod/bookshop_server/lib/src/catalog/book.spy.yaml` | [How the admin app works](../serverpod/admin-app/how-it-works.md) |

### Relationships

| Feature | Example | File | Docs |
| --- | --- | --- | --- |
| Belongs to | [Showcase](showcase.md) | `examples/showcase/lib/resources/specimens/models/specimen.dart` | [Relationships](../models/relationships.md) |
| Has one, owned | [Showcase](showcase.md) | `examples/showcase/lib/resources/keepers/models/keeper.dart` | [Relationships](../models/relationships.md) |
| Has many | [Showcase](showcase.md) | `examples/showcase/lib/resources/habitats/models/habitat.dart` | [Relationships](../models/relationships.md) |
| Belongs to many through a pivot table | [Showcase](showcase.md) | `examples/showcase/lib/resources/keepers/models/keeper.dart` | [Relationships](../models/relationships.md) |
| Owned children with cascade delete | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/products/models/product.dart` | [Relationships](../models/relationships.md) |
| Attach and detach over the API | [Showcase](showcase.md) | `examples/showcase/test/aviary_api_test.dart` | [REST API](../reference/rest-api.md) |

### Validation and behavior

| Feature | Example | File | Docs |
| --- | --- | --- | --- |
| Column rules | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/products/models/product.dart` | [Validation](../models/validation.md), [Validation rules](../reference/validation-rules.md) |
| Record rules across fields | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/invoices/models/invoice.dart` | [Validation](../models/validation.md) |
| Rules against related rows | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/models/order.dart` | [Validation](../models/validation.md) |
| Conditionally required fields | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/orders/models/order_item.dart` | [Validation](../models/validation.md) |
| Suggested values | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/orders/models/order_item.dart` | [Model behavior](../models/behavior.md) |
| Derived values | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/invoices/models/invoice.dart` | [Model behavior](../models/behavior.md) |
| Editable and deletable conditions | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/invoices/models/invoice.dart` | [Model behavior](../models/behavior.md) |
| Named model actions | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/invoices/models/invoice.dart` | [Actions](../panel/actions.md), [Behavior and actions](../reference/behavior-and-actions.md) |
| An action with typed input | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/domain/order_behavior.dart` | [Actions](../panel/actions.md) |

### Resources, lists and filters

| Feature | Example | File | Docs |
| --- | --- | --- | --- |
| Default resource from beak.yaml | [Quickstart](quickstart.md) | `examples/quickstart/lib/beak/panel.g.dart` | [Resources](../panel/resources.md) |
| Resource class | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/products/product_resource.dart` | [Resources](../panel/resources.md) |
| Typed filters | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/products/product_resource.dart` | [Tables and filters](../panel/tables-and-filters.md), [Filter builders](../reference/filter-builders.md) |
| Global search across relations | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/products/product_resource.dart` | [Tables and filters](../panel/tables-and-filters.md) |
| Composed list definition | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart` | [Composed lists and query state](../panel/composed-lists.md) |
| Query presets | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/resources/orders/list/order_list_presets.dart` | [Composed lists and query state](../panel/composed-lists.md) |
| Saved views | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart` | [A saved list view](../recipes/a-saved-list-view.md) |
| CSV export of a list | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart` | [Export to CSV](../recipes/export-to-csv.md) |
| Record templates in table cells | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/resources/orders/list/order_table_columns.dart` | [Composed lists and query state](../panel/composed-lists.md) |
| Row and bulk actions | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart` | [A row action](../recipes/a-row-action.md), [Actions](../panel/actions.md) |
| Bulk edit | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/products/product_resource.dart` | [A bulk edit](../recipes/a-bulk-edit.md) |
| Duplicating a record | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/products/product_resource.dart` | [Actions](../panel/actions.md) |
| A link action on a record | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/resources/orders/order_resource.dart` | [Actions](../panel/actions.md) |

### Forms and records

| Feature | Example | File | Docs |
| --- | --- | --- | --- |
| Form screen with a layout | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/products/product_resource.dart` | [Form screens](../forms/form-screens.md) |
| Sections projected into wizard steps and tabs | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/invoices/screens/invoice_form.dart` | [Multi-step forms](../forms/multi-step-forms.md) |
| Wizard with an aside and named steps | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/resources/orders/forms/order_wizard_screen.dart` | [Workflow presentations](../forms/workflow-presentations.md) |
| Resumable drafts and review before save | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/shop_drafts.dart` | [Drafts, review and conflicts](../forms/drafts-and-review.md) |
| Calculated read-only values | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/invoices/screens/invoice_form.dart` | [Inputs](../forms/inputs.md) |
| Inputs enabled by the draft state | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/invoices/screens/invoice_form.dart` | [Inputs](../forms/inputs.md) |
| Currency input | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/invoices/screens/invoice_form.dart` | [Input builders](../reference/input-builders.md) |
| Belongs-to picker | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/invoices/screens/invoice_form.dart` | [A belongs-to picker](../recipes/a-belongs-to-picker.md) |
| Nested table editor for owned rows | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart` | [A nested table editor](../recipes/a-nested-table-editor.md), [Related records in forms](../forms/related-records.md) |
| Gallery editor | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/resources/products/screens/product_form.dart` | [Uploads and galleries](../forms/uploads-and-galleries.md) |
| Read and edit on one screen | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/resources/orders/details/order_detail_screen.dart` | [Detail views](../forms/detail-views.md) |
| Printable record document | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/resources/orders/actions/order_documents.dart` | [Printable record documents](../forms/record-documents.md) |
| Import with preview | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/operations.dart` | [Imports and bulk edits](../forms/imports-and-bulk-edits.md), [A CSV import](../recipes/a-csv-import.md) |

### Pages, blocks and charts

| Feature | Example | File | Docs |
| --- | --- | --- | --- |
| Custom page from blocks | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/overview.dart` | [Custom screens](../panel/custom-screens.md) |
| Dashboard metrics | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/overview.dart` | [Dashboards](../panel/dashboards.md), [A dashboard KPI](../recipes/a-dashboard-kpi.md) |
| Summaries over a whole population | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart` | [Population summaries](../blocks/summaries.md) |
| Custom widget on the panel's data | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/widgets/receivables_card.dart` | [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md) |
| Custom screen for one resource | [Showcase](showcase.md) | `examples/showcase/lib/resources/keepers/keeper_resource.dart` | [Custom screens](../panel/custom-screens.md) |
| Record blocks in a record scope | [Showcase](showcase.md) | `examples/showcase/lib/resources/keepers/keeper_sheet.dart` | [Record blocks](../blocks/record-blocks.md) |
| Layout blocks | [Showcase](showcase.md) | `examples/showcase/lib/pages/layout_blocks.dart` | [Layout blocks](../blocks/layout-blocks.md) |
| Content blocks | [Showcase](showcase.md) | `examples/showcase/lib/pages/content_blocks.dart` | [Content blocks](../blocks/content-blocks.md) |
| Data blocks | [Showcase](showcase.md) | `examples/showcase/lib/pages/data_blocks.dart` | [Data blocks](../blocks/data-blocks.md) |
| Kanban board | [Showcase](showcase.md) | `examples/showcase/lib/pages/data_blocks.dart` | [A kanban view](../recipes/a-kanban-view.md) |
| Calendar | [Showcase](showcase.md) | `examples/showcase/lib/pages/data_blocks.dart` | [Data blocks](../blocks/data-blocks.md) |
| Charts | [Showcase](showcase.md) | `examples/showcase/lib/pages/chart_blocks.dart` | [Charts](../blocks/charts.md) |
| Maps | [Showcase](showcase.md) | `examples/showcase/lib/pages/map_blocks.dart` | [Maps](../blocks/maps.md) |
| Module blocks: chat, inbox, files, media | [Showcase](showcase.md) | `examples/showcase/lib/pages/module_blocks.dart` | [Module blocks](../blocks/module-blocks.md) |
| Custom navigation | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/navigation.dart` | [Navigation](../panel/navigation.md) |
| Notifications and refresh policy | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/main.dart` | [Panel and resource options](../reference/panel-options.md) |
| Theme from a brand color | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/main.dart` | [Theming basics](../theming/theming-basics.md) |
| A complete custom theme | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/theme/gabel_theme.dart` | [Colors and tokens](../theming/colors-and-tokens.md), [Typography and icons](../theming/typography-and-icons.md) |
| Locale, currency and date formats | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/main.dart` | [Formatting and localization](../theming/formatting-and-localization.md) |
| Sign-in screens over an auth adapter | [Serverpod](serverpod-admin.md) | `examples/serverpod/bookshop_admin/lib/src/bookshop_admin.dart` | [Auth and idle-lock](../panel/auth-and-idle-lock.md) |

### Backend

| Feature | Example | File | Docs |
| --- | --- | --- | --- |
| Transactional preparer | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/server.dart` | [Transactional business rules](../backend/graph-business-rules.md) |
| Tables that only accept graph commits | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/server.dart` | [Graph commits](../architecture/graph-commits.md) |
| Candidate graph inside a preparer | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/domain/shop_graph_preparer.dart` | [Transactional business rules](../backend/graph-business-rules.md) |
| Outbox scheduled by the server | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/server.dart` | [Durable effects](../backend/durable-effects.md) |
| Effects enqueued in the save transaction | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/domain/foodio_effects.dart` | [Durable effects](../backend/durable-effects.md) |
| Explicit migrations that upgrade data | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/migrations/expand_shop_catalog.dart` | [Migrations](../backend/migrations.md) |
| Repeatable seeder | [Shop](clean-shop.md) | `examples/clean_beak_config/lib/seeders/shop_seeder.dart` | [Seeding](../backend/seeding.md) |
| A large seeded fixture | [Foodio](foodio.md) | `examples/foodio-adminpanel/lib/seeders/foodio_seeder.dart` | [Seeding](../backend/seeding.md) |
| Deny-by-default policy | [Serverpod](serverpod-admin.md) | `examples/serverpod/bookshop_server/lib/src/beak/bookshop_policy.dart` | [Auth and policies](../backend/auth-and-policies.md) |
| A gated endpoint carrying the API | [Serverpod](serverpod-admin.md) | `examples/serverpod/bookshop_server/lib/src/beak/beak_admin_endpoint.dart` | [How the admin app works](../serverpod/admin-app/how-it-works.md) |
| Beak engine on a Serverpod session | [Serverpod](serverpod-admin.md) | `examples/serverpod/bookshop_server/lib/src/beak/bookshop_beak_engine.dart` | [How the admin app works](../serverpod/admin-app/how-it-works.md) |
| Panel data source over the tunnel | [Serverpod](serverpod-admin.md) | `examples/serverpod/bookshop_admin/lib/src/bookshop_admin.dart` | [How the admin app works](../serverpod/admin-app/how-it-works.md) |
| Serverpod scopes for the policy | [Serverpod](serverpod-admin.md) | `examples/serverpod/bookshop_server/lib/src/beak/bookshop_scopes.dart` | [Authentication and scopes](../serverpod/authentication.md) |

### Tests

| Feature | Example | File | Docs |
| --- | --- | --- | --- |
| Widget test on an in-memory data source | [Quickstart](quickstart.md) | `examples/quickstart/test/widget_test.dart` | [Testing](../shipping/testing.md) |
| Real host on in-memory SQLite | [Shop](clean-shop.md) | `examples/clean_beak_config/test/support/shop_test_api.dart` | [Testing](../shipping/testing.md) |
| Arithmetic tests with exact amounts | [Shop](clean-shop.md) | `examples/clean_beak_config/test/shop_totals_test.dart` | [Testing](../shipping/testing.md) |
| Migration round-trip test | [Showcase](showcase.md) | `examples/showcase/test/aviary_migrations_test.dart` | [Migrations](../backend/migrations.md) |
| Exhaustiveness tests over sealed hierarchies | [Showcase](showcase.md) | `examples/showcase/test/block_type_matrix_test.dart` | [Writing tests](../contributing/writing-tests.md) |
| Adapter contract on another database | [Serverpod](serverpod-admin.md) | `examples/serverpod/bookshop_server/test/integration/beak/session_adapter_data_source_contract_test.dart` | [The data source seam](../architecture/data-source-seam.md) |
| Panel tests against a fake dispatch | [Serverpod](serverpod-admin.md) | `examples/serverpod/bookshop_admin/test/admin_panel_test.dart` | [Testing](../shipping/testing.md) |
| Browser verification scripts | [Foodio](foodio.md) | `examples/foodio-adminpanel/tool/verify_list.cjs` | [Testing](../shipping/testing.md) |

### Features no example shows

These have no maintained example, so the docs page explains them from package code and package tests. A search of the examples for the symbol comes back empty.

| Feature | Symbol to search for | Docs |
| --- | --- | --- |
| Maintenance and coming-soon pages | `BeakMaintenanceConfig` | [Maintenance and coming soon](../panel/maintenance-and-coming-soon.md) |
| Idle lock | `idleLockTimeout` | [Auth and idle-lock](../panel/auth-and-idle-lock.md) |
| S3 and FTP storage drivers | `S3StorageDriver`, `registerS3Storage` | [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md), [Custom storage drivers](../extending/custom-storage-drivers.md) |
| Field-level access | `BeakFieldAccess` | [Auth and policies](../backend/auth-and-policies.md) |
| The Serverpod client bridge | `ServerpodResource` | [Client bridge](../serverpod/bridge/index.md) |

## Source

Every path in the tables above exists; `dart run tool/check_docs.dart` fails when one does not. Nothing checks that a file still demonstrates its feature. When you move or rename a symbol an example quotes, update its row.

The completeness of the column, relationship and block rows is pinned by tests, not by this page:

- `examples/showcase/test/column_kind_matrix_test.dart` fails when Beak has a column kind the showcase does not declare.
- `examples/showcase/test/relation_kind_matrix_test.dart` does the same for relationship kinds.
- `examples/showcase/test/block_type_matrix_test.dart` does the same for block types.

Where the map comes from: the run and layout notes in each example's `README.md`, and the tour pages in this section.

## Continue reading

- [Examples](index.md): the five examples side by side, with ports and run commands.
- [Cheatsheet](../reference/cheatsheet.md): the same features as signatures instead of files.
- [Libraries](../reference/libraries.md): which import gives you which symbol.
