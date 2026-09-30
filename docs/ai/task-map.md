---
title: Task map
description: For more than seventy common Beak tasks, the page to read, the file to open and the command that verifies the change.
type: ai
audience: [agent]
status: stable
search: {boost: 2}
---

# Task map

For coding agents. Humans: see [Recipes](../recipes/index.md). Find your task, read the page in the second column, open the file in the third and copy its shape, then run the checks in the fourth. Every path exists in the repository, and every example file compiles and is tested.

## Rules

- MUST read the page before you open the file. The file shows one way; the page says which parts are required.
- MUST use the file as a shape, not as text to paste. Names, types and fields are yours.
- Paths under `examples/` and `packages/` are in the Beak repository. In your project the same file lives under `lib/`, `test/` or `bin/`, and `beak make:resource` and `beak create` show the layout.
- Checks written as commands run in your project root. `Reference test` is a test in the repository that shows how to prove the task; write the equivalent in your own `test/`. Run one with `cd examples/clean_beak_config && flutter test test/shop_api_test.dart`.
- MUST run `beak prepare` after any edit to a schema class, a resource class, a screen or `beak.yaml`, and `beak doctor` before you report a task done. Rows list them only where they matter most.
- When a task needs a rule, a role or a database change that the row does not cover, follow the link to its own row instead of improvising.
- The [Feature map](../examples/feature-map.md) lists 106 features by example and file. This page starts from the task, that page starts from the feature.

## Project and tooling

| Task | Read | Open | Verify |
| --- | --- | --- | --- |
| Create a project with a generated panel | [Quickstart](../start-here/quickstart.md) | `examples/quickstart/lib/resources/notes/models/note.dart` | `beak create acme`, `beak migrate`, `beak doctor` |
| Create a project with an authored panel | [Two ways to boot a panel](../start-here/generated-or-authored.md) | `examples/clean_beak_config/lib/main.dart` | `beak create acme --authored`, `beak doctor` |
| Switch a generated project to an authored one | [Two ways to boot a panel](../start-here/generated-or-authored.md) | `examples/clean_beak_config/lib/main.dart` | `beak eject main`, then `beak prepare` leaves `lib/main.dart` untouched, `beak doctor` |
| Add Beak to an existing Flutter app | [An existing Flutter app](../start-here/paths/existing-flutter-app.md) | `packages/beak_cli/test/e2e/init_embedded_test.dart` | `beak init`, `beak doctor`, `flutter run -d chrome -t lib/admin_main.dart` |
| Put an admin on an existing database | [An existing database](../start-here/paths/existing-database.md) | `packages/beak_cli/test/e2e/adopt_existing_schema_test.dart` | `beak introspect <url> --dry-run`, `beak introspect <url>`, `beak doctor` |
| Put the panel on a backend you keep | [An existing backend](../start-here/paths/existing-backend.md) | `packages/beak_frontend/test/src/panel/model_configuration_test.dart` | `runBeakDataSourceContract` passes for your `BeakDataSource`, and a widget test boots the panel against it |
| Regenerate after an edit | [Generated code](../models/generated-code.md) | `examples/quickstart/lib/beak/registry.g.dart` | `beak prepare` twice, the second says `up to date`; `beak doctor` |
| Change the panel title, API origin or port | [beak.yaml](../reference/beak-yaml.md) | `examples/showcase/beak.yaml` | `beak prepare` (an unknown key is named in the error) |
| Keep a resource out of the sidebar | [Hide a resource](../recipes/hide-a-resource.md) | `examples/clean_beak_config/lib/main.dart` | `beak prepare`, open the panel, follow a link to the hidden model from a form |
| Upgrade Beak | [Upgrading](../start-here/upgrading.md) | `CHANGELOG.md` | `beak prepare` lists the punch list, then `beak doctor`, `dart analyze`, `beak agents --check` |
| Set up or repair the agent files | [Set up your agent](setup.md) | `examples/quickstart/AGENTS.md` | `beak agents --check`, `beak doctor` |

## Models and fields

| Task | Read | Open | Verify |
| --- | --- | --- | --- |
| Define a model | [Defining models](../models/defining-models.md) | `examples/quickstart/lib/resources/notes/models/note.dart` | `beak prepare`, `beak migrate`, `beak doctor` |
| Scaffold a resource with its model | [Add a resource](../recipes/add-a-resource.md) | `examples/clean_beak_config/lib/resources/categories/category_resource.dart` | `beak make:resource Category --fields name:string!`, `beak prepare`, `beak migrate` |
| Choose a field type | [Fields](../models/fields.md) | `examples/showcase/lib/resources/specimens/models/specimen.dart` | `beak prepare`. Reference test `examples/showcase/test/column_kind_matrix_test.dart` |
| Store money exactly | [A money field](../recipes/a-money-field.md) | `examples/clean_beak_config/lib/resources/products/models/product.dart` | `beak prepare`. Reference test `examples/clean_beak_config/test/shop_totals_test.dart` |
| Add an email, URL, phone, slug or percentage field | [Semantic fields](../models/semantic-fields.md) | `examples/showcase/lib/resources/keepers/models/keeper_profile.dart` | `beak prepare`, then the form rejects a malformed value |
| Show an enum as a badge | [An enum badge column](../recipes/an-enum-badge-column.md) | `examples/showcase/lib/resources/tasks/models/task.dart` | `beak prepare`, open the list page |
| Relate two models | [Relationships](../models/relationships.md) | `examples/showcase/lib/resources/keepers/models/keeper.dart` | `beak prepare`. Reference test `examples/showcase/test/relation_kind_matrix_test.dart` |
| Bound or format one column | [Validation](../models/validation.md) | `examples/clean_beak_config/lib/resources/products/models/product.dart` | `beak prepare`. Reference test `examples/clean_beak_config/test/order_form_test.dart` |
| Validate across fields or rows | [Validation rules](../reference/validation-rules.md) | `examples/clean_beak_config/lib/resources/invoices/models/invoice.dart` | An API test posts the invalid save. Reference test `examples/clean_beak_config/test/shop_api_test.dart` |
| Suggest or derive a value | [Model behavior](../models/behavior.md) | `examples/clean_beak_config/lib/resources/orders/models/order_item.dart` | Reference test `examples/clean_beak_config/test/order_form_test.dart` |
| Add a guarded state change such as issue or approve | [Actions](../panel/actions.md) | `examples/clean_beak_config/lib/resources/invoices/models/invoice.dart` | Reference test `examples/clean_beak_config/test/invoice_form_test.dart` |
| Add an image or file column | [Files and storage columns](../models/files-and-storage-columns.md) | `examples/showcase/lib/resources/specimens/models/specimen.dart` | Reference test `examples/showcase/test/aviary_api_test.dart` |
| Add attributes or variants driven by a category | [Dynamic attributes and variants](../models/dynamic-attributes-and-variants.md) | `examples/clean_beak_config/lib/domain/shop_attributes.dart` | `beak prepare`. Reference test `examples/clean_beak_config/test/custom_shop_test.dart` (the variant preview) |
| Add a column Beak has no type for | [Custom columns](../extending/custom-columns.md) | `examples/showcase/lib/widgets/band_code_cell.dart` | `beak prepare`. Reference test `examples/showcase/test/aviary_resources_test.dart` (a custom column draws with its renderer) |

## The panel

| Task | Read | Open | Verify |
| --- | --- | --- | --- |
| Configure a resource: title, group, icon, actions | [Resources](../panel/resources.md) | `examples/clean_beak_config/lib/resources/products/product_resource.dart` | `beak prepare`. Reference test `examples/clean_beak_config/test/shop_resource_test.dart` |
| Group, order or replace the sidebar | [Navigation](../panel/navigation.md) | `examples/foodio-adminpanel/lib/navigation.dart` | `beak doctor`, open the panel |
| Add a filter | [Tables and filters](../panel/tables-and-filters.md) | `examples/clean_beak_config/lib/resources/products/product_resource.dart` | Reference test `examples/clean_beak_config/test/shop_api_test.dart` (filters on the real API) |
| Search across own and related fields | [Tables and filters](../panel/tables-and-filters.md) | `examples/clean_beak_config/lib/resources/products/product_resource.dart` | Reference test `examples/clean_beak_config/test/shop_api_test.dart` (search on the real API) |
| Build a list with presets, counts and query state | [Composed lists and query state](../panel/composed-lists.md) | `examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart` | Reference test `examples/foodio-adminpanel/test/foodio_panel_test.dart` |
| Add a button to each row | [A row action](../recipes/a-row-action.md) | `examples/clean_beak_config/lib/resources/invoices/models/invoice.dart` | Reference test `examples/clean_beak_config/test/invoice_form_test.dart` |
| Act on a selection, or edit many rows | [A bulk edit](../recipes/a-bulk-edit.md) | `examples/clean_beak_config/lib/resources/products/product_resource.dart` | Reference test `packages/beak_frontend/test/src/pages/resource_actions_test.dart` |
| Export a list to CSV | [Export to CSV](../recipes/export-to-csv.md) | `examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart` | Reference test `packages/beak_backend/test/src/export/csv_export_test.dart` |
| Import rows from CSV | [A CSV import](../recipes/a-csv-import.md) | `examples/clean_beak_config/lib/operations.dart` | Reference test `packages/beak_frontend/test/src/form/beak_import_view_test.dart` |
| Save and reload list views | [A saved list view](../recipes/a-saved-list-view.md) | `examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart` | `flutter test`. Read the 200-row trap on [Rules for agents](rules.md#known-traps) first |
| Choose the page `/` opens | [Dashboards](../panel/dashboards.md) | `examples/clean_beak_config/lib/overview.dart` | Reference test `examples/clean_beak_config/test/shop_widget_test.dart`, then open `/` |
| Add a metric tile | [A dashboard KPI](../recipes/a-dashboard-kpi.md) | `examples/clean_beak_config/lib/overview.dart` | Reference test `examples/clean_beak_config/test/shop_widget_test.dart` (the overview loads its metrics) |
| Add a page that is not a table or a form | [Custom screens](../panel/custom-screens.md) | `examples/showcase/lib/resources/keepers/keeper_resource.dart` | Reference test `examples/showcase/test/aviary_resources_test.dart` |
| Show records on a board or a calendar | [A kanban view](../recipes/a-kanban-view.md) | `examples/showcase/lib/pages/data_blocks.dart` | Reference test `examples/showcase/test/aviary_pages_test.dart` |
| Draw a chart | [Charts](../blocks/charts.md) | `examples/showcase/lib/pages/chart_blocks.dart` | Reference test `packages/beak_frontend/test/src/blocks/beak_advanced_charts_test.dart` |
| Draw a map | [Maps](../blocks/maps.md) | `examples/showcase/lib/pages/map_blocks.dart` | Reference test `examples/showcase/test/aviary_pages_test.dart` |
| Put your own widget on a page | [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md) | `examples/clean_beak_config/lib/widgets/receivables_card.dart` | Reference test `examples/clean_beak_config/test/custom_shop_test.dart` |
| Add sign-in and an idle lock to the panel | [Auth and idle-lock](../panel/auth-and-idle-lock.md) | `examples/serverpod/bookshop_admin/lib/src/bookshop_admin.dart` | Reference test `examples/serverpod/bookshop_admin/test/admin_login_test.dart` |
| Set the theme | [Theming basics](../theming/theming-basics.md) | `examples/clean_beak_config/lib/main.dart` | `flutter test`, open the panel in light and dark |
| Set locale, currency and date formats | [Formatting and localization](../theming/formatting-and-localization.md) | `examples/clean_beak_config/lib/main.dart` | Reference test `packages/beak_core/test/src/columns/beak_format_policy_test.dart`, then a widget test finds the formatted text |
| Show a maintenance or coming-soon page | [Maintenance and coming soon](../panel/maintenance-and-coming-soon.md) | `packages/beak_frontend/lib/src/panel/beak_maintenance_config.dart` | The package tests under `packages/beak_frontend/test/src/panel/` |

## Forms and records

| Task | Read | Open | Verify |
| --- | --- | --- | --- |
| Lay out a form | [Form screens](../forms/form-screens.md) | `examples/clean_beak_config/lib/resources/products/screens/product_form.dart` | `beak prepare`. Reference test `examples/clean_beak_config/test/shop_widget_test.dart` (the product tabs keep the draft) |
| Split a form into steps | [A multi-step form](../recipes/a-multi-step-form.md) | `examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart` | Reference test `examples/clean_beak_config/test/order_form_test.dart` |
| Pick a related record | [A belongs-to picker](../recipes/a-belongs-to-picker.md) | `examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart` | Reference test `examples/clean_beak_config/test/order_form_test.dart` |
| Edit owned child rows in the parent form | [A nested table editor](../recipes/a-nested-table-editor.md) | `examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart` | Reference test `examples/clean_beak_config/test/order_form_test.dart` |
| Upload images into a gallery | [Uploads and galleries](../forms/uploads-and-galleries.md) | `examples/clean_beak_config/lib/resources/products/screens/product_form.dart` | Reference test `packages/beak_frontend/test/src/form/beak_gallery_test.dart` |
| Resume drafts and review before saving | [Drafts, review and conflicts](../forms/drafts-and-review.md) | `examples/clean_beak_config/lib/shop_drafts.dart` | Reference test `packages/beak_frontend/test/src/form/resumable_draft_test.dart` |
| Read and edit on one screen | [Detail views](../forms/detail-views.md) | `examples/foodio-adminpanel/lib/resources/orders/details/order_detail_screen.dart` | Reference test `examples/foodio-adminpanel/test/foodio_panel_test.dart` |
| Print a record as a document | [Printable record documents](../forms/record-documents.md) | `examples/foodio-adminpanel/lib/resources/orders/actions/order_documents.dart` | Reference test `packages/beak_frontend/test/src/documents/beak_record_document_test.dart` |
| Add an input Beak does not have | [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md) | `examples/clean_beak_config/lib/resources/products/screens/variant_builder.dart` | Reference test `examples/clean_beak_config/test/custom_shop_test.dart` |

## The backend

| Task | Read | Open | Verify |
| --- | --- | --- | --- |
| Decide who may read and write what | [Auth and policies](../backend/auth-and-policies.md) | `examples/serverpod/bookshop_server/lib/src/beak/bookshop_policy.dart` | A per-role API test. Reference test `packages/beak_backend/test/src/auth/beak_policies_handlers_test.dart` |
| Run a rule inside the save transaction | [Transactional business rules](../backend/graph-business-rules.md) | `examples/clean_beak_config/lib/domain/shop_graph_preparer.dart` | Reference test `examples/clean_beak_config/test/shop_api_test.dart` |
| Force a model's writes through those rules | [Transactional business rules](../backend/graph-business-rules.md) | `examples/clean_beak_config/lib/server.dart` | A per-record `PATCH` from a caller the policy allows answers `422` |
| Send an email or call a provider after a save | [Durable effects](../backend/durable-effects.md) | `examples/foodio-adminpanel/lib/domain/foodio_effects.dart` | Reference test `examples/foodio-adminpanel/test/foodio_api_test.dart` |
| Add middleware or routes | [Middleware](../backend/middleware.md) | `packages/beak_backend/lib/src/server/beak_server.dart` | Reference test `packages/beak_backend/test/src/server/middleware_test.dart` |
| Choose where uploads are stored | [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) | `packages/beak_backend/lib/src/server/beak_serve_host.dart` | Reference test `packages/beak_backend/test/src/server/beak_storage_settings_test.dart` |
| Configure the database, port and secrets | [Environment and config](../shipping/environment-and-config.md) | `packages/beak_backend/lib/src/config/beak_backend_config.dart` | `beak doctor`, `beak migrate status` |
| Change a table that already shipped | [Migrations](../backend/migrations.md) | `examples/clean_beak_config/lib/migrations/expand_shop_catalog.dart` | `beak make:migration Name --from-drift`, `beak migrate status`. Reference test `examples/showcase/test/aviary_migrations_test.dart` |
| Load demo data | [Seeding](../backend/seeding.md) | `examples/clean_beak_config/lib/seeders/shop_seeder.dart` | `beak seed` |
| Write a data source of your own | [Custom data sources](../extending/custom-data-sources.md) | `packages/beak_test/lib/src/data_source_contract.dart` | `runBeakDataSourceContract` passes |
| Search or export on the server | [Search and export](../backend/search-and-export.md) | `packages/beak_backend/lib/src/export/csv_export_service.dart` | Reference test `packages/beak_backend/test/src/export/csv_export_test.dart` |
| Call the API from Dart or curl | [REST API](../reference/rest-api.md) | `packages/beak_backend/lib/src/endpoints/beak_resource_router.dart` | Reference test `packages/beak_backend/test/src/endpoints/beak_api_router_test.dart` |

## Testing and shipping

| Task | Read | Open | Verify |
| --- | --- | --- | --- |
| Test that the panel boots and renders | [Testing](../shipping/testing.md) | `examples/quickstart/test/widget_test.dart` | `flutter test` |
| Test form logic without a screen | [Testing](../shipping/testing.md) | `examples/clean_beak_config/test/order_form_test.dart` | `flutter test test/order_form_test.dart` |
| Test the real API on in-memory SQLite | [Testing](../shipping/testing.md) | `examples/clean_beak_config/test/support/shop_test_api.dart` | `flutter test test/shop_api_test.dart` |
| Prove models and migrations agree | [Testing](../shipping/testing.md) | `examples/clean_beak_config/test/shop_migration_test.dart` | `expectSchemaParity` passes |
| Prepare for production | [Going to production](../shipping/going-to-production.md) | `examples/clean_beak_config/lib/server.dart` | The checklist on [Security](../shipping/security.md) passes, `beak doctor` |

## Serverpod

| Task | Read | Open | Verify |
| --- | --- | --- | --- |
| Choose between the admin app and the bridge | [Choosing an integration](../serverpod/choosing-an-integration.md) | `examples/serverpod/README.md` | The choice is written in the change |
| Add an admin app to a Serverpod workspace | [Setting up the admin app](../serverpod/admin-app/setup.md) | `examples/serverpod/bookshop_server/lib/src/beak/beak_admin_endpoint.dart` | `flutter test` in the admin, `dart analyze` in the server. Reference test `examples/serverpod/bookshop_server/test/integration/beak/beak_admin_security_test.dart` |
| Map Serverpod scopes to a policy | [Authentication and scopes](../serverpod/authentication.md) | `examples/serverpod/bookshop_server/lib/src/beak/bookshop_scopes.dart` | Reference test `examples/serverpod/bookshop_server/test/integration/beak/beak_admin_security_test.dart` |
| Put the panel over an existing Serverpod client | [Bridge resources](../serverpod/bridge/resources.md) | `packages/beak_serverpod/lib/src/resource.dart` | Reference test `packages/beak_serverpod/test/src/resource_test.dart` |
| Generate bridge resources from a client | [Generating bridge resources](../serverpod/bridge/generator.md) | `packages/beak_serverpod_generator/lib/src/resource_generator.dart` | Reference test `packages/beak_serverpod_generator/test/src/resource_generator_test.dart` |

## Machine-readable twin

This page as Markdown: `https://simonerich.github.io/beak/ai/task-map/index.md`. In a project that ran `beak docs`: `.dart_tool/beak/docs/ai/task-map.md`. Search it with `grep -n "<task words>" .dart_tool/beak/docs/ai/task-map.md`.

## Continue reading

- [Source map](source-map.md): the import, file and test for a symbol, once the task map named the page.
- [Prompt recipes](prompts.md): prompts that send an agent through this map and ask for the evidence.
- [Feature map](../examples/feature-map.md): the same files, listed by feature.
- [Rules for agents](rules.md): what to check before you call a row done.
