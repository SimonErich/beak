# Example map (writers: quote from these exact files)

Not published. Maps each page to the real, compiling source it should lift
snippets from. Paths are workspace-relative to the repo root. When a page needs a
snippet not listed here, open the nearest listed file, read it, and quote it
verbatim. Never invent an API.

Two demo apps, two model sets (see STYLE_GUIDE "two-app rule"):
- `reference_admin*` = the tutorial store, port 8080.
- `beak_superdashboard` = the showcase, port 8180.

## Start here
- what-is-beak / why-beak: `README.md`, package barrels
  (`packages/beak_*/lib/beak_*.dart`).
- installation: `packages/beak_frontend/pubspec.yaml`,
  `apps/reference_admin/pubspec.yaml`, `apps/reference_admin_server/pubspec.yaml`,
  `melos.yaml`, `docker-compose.yml`, `.env.example`.
- quickstart: `apps/reference_admin/lib/main.dart`,
  `apps/reference_admin_server/bin/reference_admin_server.dart`,
  `apps/reference_admin_server/bin/worm.dart`.
- project-structure: repo tree; `apps/` roles; `melos.yaml` packages block.

## Tutorial (First Flight) — all chapters anchor to the reference_admin trio
- 01 hatch: `apps/reference_admin_server/lib/src/server_builder.dart`,
  `apps/reference_admin_models/lib/reference_admin_models.dart`, `.env.example`.
- 02 first model + migration:
  `apps/reference_admin_models/lib/src/product.dart` (start with the simplest,
  e.g. `category.dart` / `tag.dart`, then grow),
  `apps/reference_admin_server/lib/src/migrations/reference_migrations.dart`.
- 03 panel comes alive: `apps/reference_admin/lib/main.dart`
  (`buildReferencePanelConfig`, the inline `main`).
- 04 relationships + rich columns: `apps/reference_admin_models/lib/src/order.dart`,
  `order_item.dart`, `user.dart`, `product.dart` (enum + image + belongsTo +
  belongsToMany). `hasOne` is not in reference_admin: pull it from
  `apps/beak_superdashboard/lib/models/commerce/order.dart` and label it.
- 05 seeding: `apps/reference_admin_server/lib/src/seeders/reference_seeder.dart`
  (plain), then show the richer factory pattern from
  `apps/beak_superdashboard/lib/seeders/seed_context.dart` as "leveling up".
- 06 filters/actions/view-modes: `apps/reference_admin/lib/main.dart`
  (`duplicateProduct`, `BeakSelectFilter`, `BeakTextFilter`, `BeakRecordAction`),
  `apps/beak_superdashboard/lib/panel/resources.dart` (view modes).
- 07 dashboard: `apps/reference_admin/lib/main.dart` (`dashboardStats`,
  `dashboardCharts`) for the config-only version, then
  `apps/beak_superdashboard/lib/panel/dashboard.dart` (custom block tree).
- 08 forms/wizard/dual-mode:
  `apps/beak_superdashboard/lib/panel/details/commerce_layouts.dart`,
  `apps/beak_superdashboard/lib/panel/forms/calendar_event_form.dart`.
- 09 auth/theming: `apps/beak_superdashboard/lib/panel/config.dart` (auth,
  maintenance, theme, notifications).
- 10 wrap-up: cross-links only.

## Core concepts
- the-one-definition-promise: `apps/reference_admin_models/lib/src/product.dart`;
  narrative in `README.md` and `docs/_internal/architecture-original.md`.
- the-type-safety-promise: `product.dart` column consts;
  `packages/beak_core/lib/src/query/beak_value.dart`.
- the-four-layers: `docs/_internal/architecture-original.md` (already correct, no
  UseCase); backend `packages/beak_backend/lib/src/{endpoints,service,data/worm}`,
  frontend `packages/beak_frontend/lib/src/{table,state,data}`.
- how-data-flows: `packages/beak_core/lib/src/query/beak_query_spec.dart`,
  `beak_filter.dart`, `beak_operator.dart`.
- rendering-per-surface: `packages/beak_core/lib/src/context/beak_context.dart`,
  `beak_render_intent.dart`, `packages/beak_core/lib/src/columns/beak_render_config.dart`,
  `packages/beak_frontend/lib/src/table/column_cell_renderer.dart`.
- the-block-system: `packages/beak_frontend/lib/src/blocks/beak_block.dart`,
  `beak_block_host.dart`.
- results-and-errors: `packages/beak_core/lib/src/common/beak_result.dart`,
  `beak_exception.dart`, `packages/beak_core/lib/src/query/{beak_value,beak_record}.dart`.

## Models and data (mostly beak_core + reference_admin_models)
- defining-models: `apps/reference_admin_models/lib/src/product.dart`,
  `packages/beak_core/lib/src/model/beak_model.dart`.
- column-basics: `packages/beak_core/lib/src/columns/beak_column.dart`.
- column-types: every file in `packages/beak_core/lib/src/columns/` (all 13),
  real usage in `product.dart` and
  `apps/beak_superdashboard/lib/models/**` (e.g. `calendar_event.dart` for color).
- validation-rules: every file in `packages/beak_core/lib/src/rules/` (all 11);
  usage in `product.dart`, `user.dart`.
- relationships: `packages/beak_core/lib/src/relations/*`;
  all four kinds together in `apps/beak_superdashboard/lib/models/commerce/order.dart`;
  belongsToMany in `product.dart` (tags).
- the-registry: `packages/beak_core/lib/src/model/beak_model_registry.dart`,
  `apps/reference_admin_models/lib/reference_admin_models.dart`.
- files-and-storage-columns: `packages/beak_core/lib/src/columns/beak_image_column.dart`,
  `beak_file_column.dart`, `packages/beak_core/lib/src/storage/*`; usage in
  `product.dart` (image) and `apps/beak_superdashboard/lib/models/people/user.dart`.

## The backend (beak_backend)
- overview / the-generated-api:
  `packages/beak_backend/lib/src/endpoints/beak_resource_router.dart`,
  `crud_handlers.dart`; route list from `beakResourceRouter`.
- running-the-server: `packages/beak_backend/lib/src/server/beak_server.dart`,
  `packages/beak_backend/lib/src/config/beak_backend_config.dart`,
  `env_loader.dart`, `apps/reference_admin_server/{bin/reference_admin_server.dart,lib/src/server_builder.dart}`.
- migrations: `apps/beak_superdashboard/lib/migrations/model_schema.dart`
  (`defineModelColumns`, `definePivotTable`),
  `apps/reference_admin_server/lib/src/migrations/reference_migrations.dart`
  (hand-written), `apps/*/bin/worm.dart` (registration).
- seeding: `apps/beak_superdashboard/lib/seeders/seed_context.dart`,
  `demo_database_seeder.dart`, `commerce_seeder.dart`,
  `apps/reference_admin_server/lib/src/seeders/reference_seeder.dart`.
- auth-and-policies: `packages/beak_backend/lib/src/auth/{auth_router,beak_policy,beak_auth_guard,token_session_store}.dart`.
- search-and-export: `packages/beak_backend/lib/src/search/{global_search_service,search_router}.dart`,
  `packages/beak_backend/lib/src/export/{csv_export_service,export_router}.dart`.
- uploads-and-storage-wiring: `packages/beak_backend/lib/src/uploads/{upload_service,upload_handler,upload_router}.dart`,
  `packages/beak_backend/lib/src/server/storage_wiring.dart`.
- the-data-source-seam: `packages/beak_backend/lib/src/data/worm/{worm_data_source,query_translator,worm_record_model,worm_bootstrap,column_type_mapper}.dart`,
  `packages/beak_core/lib/src/data/beak_data_source.dart`.
- middleware: `packages/beak_backend/lib/src/server/middleware/*`.

## The panel (beak_frontend)
- overview / auth / theming / maintenance / notifications:
  `apps/beak_superdashboard/lib/panel/config.dart`,
  `packages/beak_frontend/lib/src/panel/{beak_panel,beak_panel_config,beak_auth_config,beak_maintenance_config,beak_theme_controller,beak_notifications}.dart`.
- resources / tables-and-filters / view-modes / actions:
  `apps/beak_superdashboard/lib/panel/resources.dart`,
  `apps/reference_admin/lib/main.dart`,
  `packages/beak_frontend/lib/src/panel/{beak_panel_config,beak_resource_view,beak_routes}.dart`,
  `packages/beak_frontend/lib/src/table/beak_data_table.dart`,
  `packages/beak_frontend/lib/src/filters/beak_filter_widget.dart`,
  `packages/beak_frontend/lib/src/actions/beak_action.dart`.
- forms / multi-step-forms:
  `packages/beak_frontend/lib/src/form/{beak_data_form,beak_form_step,beak_form_scope,beak_form_controller_builder}.dart`,
  `apps/beak_superdashboard/lib/panel/forms/calendar_event_form.dart`.
- detail-and-dual-mode:
  `packages/beak_frontend/lib/src/detail/{beak_detail_view,beak_record_scope,relation_manager}.dart`,
  `apps/beak_superdashboard/lib/panel/details/commerce_layouts.dart`.
- overlays: `packages/beak_frontend/lib/src/overlays/beak_overlays.dart`,
  `packages/beak_frontend/lib/src/actions/beak_action.dart` (`BeakActionContext`).
- dashboards: `apps/beak_superdashboard/lib/panel/dashboard.dart`,
  `packages/beak_frontend/lib/src/dashboard/{beak_stat,beak_chart,beak_dashboard}.dart`.
- custom-screens: `apps/beak_superdashboard/lib/screens/*.dart`,
  `packages/beak_frontend/lib/src/panel/beak_screen.dart`.
- the-navigation-shell: `packages/beak_frontend/lib/src/panel/{beak_command_bar,beak_notifications,beak_theme_controller}.dart`.
- auth-and-idle-lock: `packages/beak_frontend/lib/src/panel/beak_auth_config.dart`;
  idle-lock wiring in `beak_router.dart`.

## Blocks — overview from beak_block.dart/beak_block_host.dart; each category
enumerates its `packages/beak_frontend/lib/src/blocks/beak_*_block.dart` files.
Pair module blocks with their demo screen:
- layout-blocks: `beak_{column,row,grid,card,section,tabs,accordion,breadcrumbs,masonry,three_pane,carousel,divider,spacer,timeline}_block.dart`.
- display-blocks: `beak_{text,markdown,image,video,icon_gallery}_block.dart`.
- ui-kit-blocks: `beak_{alert,badge,progress,rating,radial_slider}_block.dart`;
  usage in `apps/beak_superdashboard/lib/screens/ui_kit_screen.dart`.
- data-blocks: `beak_{kpi,metric,table,calendar,kanban}_block.dart`;
  dashboard usage in `apps/beak_superdashboard/lib/panel/dashboard.dart`.
- record-blocks: `beak_{field,field_group,relation}_block.dart`;
  dual usage in `commerce_layouts.dart`.
- module-blocks: chat<->`screens/chat_screen.dart`, inbox<->`email_screen.dart`,
  file-manager<->`files_screen.dart`, invoice<->`invoice_screen.dart`,
  gallery<->`gallery_screen.dart`, profile<->`profile_screen.dart`,
  pricing<->`pricing_screen.dart`, faq<->`faq_screen.dart`, wizard<->`beak_wizard_block.dart`.
- the-widget-escape-hatch: `beak_widget_block.dart`.

## Charts and maps
- chart-basics: `packages/beak_frontend/lib/src/dashboard/beak_chart.dart`
  (`BeakChartType`, `BeakChartPoint`), `blocks/beak_chart_block.dart`,
  `apps/beak_superdashboard/lib/screens/charts_screen.dart`,
  `apps/beak_superdashboard/lib/services/dashboard_charts.dart` (mappers).
- advanced-charts: `blocks/beak_{bubble,candlestick,heatmap}_chart_block.dart`,
  `apps/beak_superdashboard/lib/models/analytics/*`.
- maps: `blocks/beak_{map,tile_map}_block.dart`,
  `apps/beak_superdashboard/lib/screens/maps_screen.dart`.

## Styling and theming
- `apps/beak_superdashboard/lib/panel/config.dart` (theme/darkTheme/initialThemeMode),
  `packages/beak_core/lib/src/common/beak_color.dart`,
  `packages/beak_frontend/lib/src/panel/beak_theme_controller.dart`,
  `apps/beak_superdashboard/lib/screens/{typography_screen,icons_screen}.dart`.

## Extending Beak
- custom-columns: `packages/beak_core/lib/src/columns/beak_custom_column.dart`.
- custom-blocks-and-widgets: `packages/beak_frontend/lib/src/blocks/beak_widget_block.dart`.
- custom-screens-and-pages: `packages/beak_frontend/lib/src/panel/beak_screen.dart`,
  `apps/beak_superdashboard/lib/screens/*.dart`.
- custom-data-sources: `packages/beak_core/lib/src/data/beak_data_source.dart`,
  `packages/beak_frontend/lib/src/data/http_beak_data_source.dart`, README seam section.
- custom-storage-drivers: `packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart`
  (cleanest reference impl), `packages/beak_storage_s3/lib/src/s3_storage_driver.dart`,
  `packages/beak_core/lib/src/storage/beak_storage_driver.dart`.
- using-beak-widgets-standalone: `obers_ui` barrels; a plain HookWidget using
  `BeakBlockHost` or a single `Oi*` widget.

## Deployment
- `docker-compose.yml`, `.env.example`, `.github/workflows/ci.yaml` (two-repo
  checkout), `melos.yaml`, and the new `deploy/*` files this pass creates.

## Guides
- testing: `packages/beak_frontend/test/**` (fake BeakDataSource),
  `packages/beak_backend/test/**` (InMemoryAdapter, Worm.reset).
- working-with-ai-agents: the config-over-code story; `beak_cli` scaffolding.
- performance: eager loading, pagination; `packages/beak_backend/lib/src/data/worm/query_translator.dart`.
- security: `packages/beak_backend/lib/src/auth/*`,
  `packages/beak_core/lib/src/storage/beak_storage_key.dart`,
  `beak_upload_validator.dart`.

## Reference (exhaustive; synthesize from source listed in API_INVENTORY.md)
- rest-api: `packages/beak_backend/lib/src/endpoints/beak_resource_router.dart`.
- cli-commands: `packages/beak_cli/lib/src/cli_runner.dart`, the command classes.
- exceptions: `packages/beak_core/lib/src/common/beak_exception.dart`.
- configuration-options: `.env.example`,
  `packages/beak_backend/lib/src/config/beak_backend_config.dart`,
  `packages/beak_frontend/lib/src/panel/beak_panel_config.dart`.
- packages: all `packages/beak_*/lib/beak_*.dart` barrels + per-package READMEs.

## Architecture deep dive
- expand `docs/_internal/architecture-original.md` (already correct) into the 9
  pages; sources per topic as in the backend/panel rows above.

## Contributing
- `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `melos.yaml`
  (`guard-material`, gate scripts), `tool/check_no_material.dart`,
  `tool/check_coverage.dart`.
