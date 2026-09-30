# Source map

> Find, for a Beak symbol or area, the library to import, the source file that defines it and the test that covers it.

For coding agents. Humans: see [Libraries](../reference/libraries.md). Use this page when the [Task map](task-map.md) named a page and you need the symbol behind it: which `package:beak/...` library carries it, the file that defines it, and the test that shows it working. Paths are relative to the repository root. Every path exists.

## Rules

- MUST import through the umbrella libraries in the second column. NEVER import `package:beak_core`, `package:beak_frontend` or `package:beak_backend` directly in an app, and NEVER add them to `pubspec.yaml`. The exceptions are the Serverpod and storage packages, whose libraries appear in full in their own sections below.
- MUST open the source file before you copy a signature. Docs can lag the code, and the file is the truth.
- MUST NOT import `package:beak/server.dart` or `package:beak/migrations.dart` from a file the panel reaches. `beak doctor` fails on it.
- The test column names the test to read for behavior and edge cases. It is not a place to add yours: tests for your project go in your project's `test/`.
- To find a symbol that is not listed, run `grep -rn "class <Name>" packages/*/lib`, then look up the library in [Libraries](../reference/libraries.md).

## Schema and model (`beak_core`)

| Symbol or area | Import | Source | Test |
| --- | --- | --- | --- |
| `@Resource`, `@Column`, `@Display`, `@BelongsTo`, `@HasMany`, `@Image`, `@FileField`, `BeakSchema` | `package:beak/schema.dart` | `packages/beak_core/lib/src/schema/beak_schema_annotations.dart` | `packages/beak_cli/test/src/schema/beak_schema_test.dart` |
| `BeakText`, `BeakRichText`, `BeakHexColor`, `BeakImageRef`, `BeakFileRef` | `package:beak/schema.dart` | `packages/beak_core/lib/src/schema/beak_schema_types.dart` | `packages/beak_cli/test/src/schema/beak_schema_test.dart` |
| `BeakModel`, the generated `XModel` | `package:beak/beak.dart` | `packages/beak_core/lib/src/model/beak_model.dart` | `packages/beak_core/test/src/model/beak_model_test.dart` |
| Field references such as `ProductModel.name`, `.ascending()`, `.to(value)` | `package:beak/beak.dart` | `packages/beak_core/lib/src/model/beak_field_ref.dart` | `packages/beak_core/test/src/model/beak_field_ref_test.dart` |
| `BeakModelRegistry`, the generated `buildBeakRegistry()` | `package:beak/beak.dart` | `packages/beak_core/lib/src/model/beak_model_registry.dart` | `packages/beak_core/test/src/model/beak_model_registry_test.dart` |
| `BeakColumn` and its leaves (`BeakStringColumn`, `BeakDecimalColumn`, ...) | `package:beak/beak.dart` | `packages/beak_core/lib/src/columns/beak_column.dart` | `packages/beak_core/test/src/columns/columns_registry_test.dart` |
| `BeakSemantic`, `BeakDecimal`, `BeakDate` and the other semantic values | `package:beak/beak.dart` | `packages/beak_core/lib/src/columns/beak_semantic.dart` | `packages/beak_core/test/src/columns/beak_semantic_test.dart` |
| `BeakRule`; its leaves (`BeakMin`, `BeakMaxLength`, `BeakEmail`, `BeakPattern`) sit next to it in `rules/` | `package:beak/beak.dart` | `packages/beak_core/lib/src/rules/beak_rule.dart` | `packages/beak_core/test/src/rules/rules_registry_test.dart` |
| `BeakRecordRule`, `BeakRequiredIf`, `BeakSum`, `BeakExists`, `BeakFieldMatch` | `package:beak/beak.dart` | `packages/beak_core/lib/src/validation/beak_record_rule.dart` | `packages/beak_core/test/src/validation/beak_record_rules_test.dart` |
| `BeakRelationship`; the four kinds (`BeakBelongsTo`, `BeakHasOne`, `BeakHasMany`, `BeakBelongsToMany`) and `BeakOnDelete` sit next to it in `relations/` | `package:beak/beak.dart` | `packages/beak_core/lib/src/relations/beak_relationship.dart` | `packages/beak_core/test/src/relations/relations_registry_test.dart` |
| `BeakModelBehavior`, `BeakModelAction`, `BeakValueBehavior` | `package:beak/beak.dart` | `packages/beak_core/lib/src/behavior/beak_model_behavior.dart` | `packages/beak_core/test/src/behavior/beak_model_behavior_test.dart` |
| `BeakPermissions`, `BeakOperation` | `package:beak/beak.dart` | `packages/beak_core/lib/src/model/beak_permissions.dart` | `packages/beak_core/test/src/model/beak_permissions_test.dart` |
| `BeakAttributeDefinition` | `package:beak/beak.dart` | `packages/beak_core/lib/src/model/beak_attribute_definition.dart` | `packages/beak_core/test/src/model/beak_attribute_definition_test.dart` |
| `BeakVariantMatrix` | `package:beak/beak.dart` | `packages/beak_core/lib/src/model/beak_variant_matrix.dart` | `packages/beak_core/test/src/model/beak_variant_matrix_test.dart` |
| `BeakFormatPolicy`, `BeakValueFormat` | `package:beak/beak.dart` | `packages/beak_core/lib/src/formatting/beak_format_policy.dart` | `packages/beak_core/test/src/columns/beak_format_policy_test.dart` |

## Queries and data (`beak_core`)

| Symbol or area | Import | Source | Test |
| --- | --- | --- | --- |
| `BeakQuerySpec` | `package:beak/beak.dart` | `packages/beak_core/lib/src/query/beak_query_spec.dart` | `packages/beak_core/test/src/query/beak_query_spec_test.dart` |
| `BeakFilter`, `BeakOperator` | `package:beak/beak.dart` | `packages/beak_core/lib/src/query/beak_filter.dart` | `packages/beak_core/test/src/query/beak_filter_test.dart` |
| `BeakSort` | `package:beak/beak.dart` | `packages/beak_core/lib/src/query/beak_sort.dart` | `packages/beak_core/test/src/query/beak_sort_test.dart` |
| `BeakPagination` | `package:beak/beak.dart` | `packages/beak_core/lib/src/query/beak_pagination.dart` | `packages/beak_core/test/src/query/beak_pagination_test.dart` |
| `BeakPage` | `package:beak/beak.dart` | `packages/beak_core/lib/src/query/beak_page.dart` | `packages/beak_core/test/src/query/beak_page_test.dart` |
| `BeakRelationLoad` | `package:beak/beak.dart` | `packages/beak_core/lib/src/query/beak_relation_load.dart` | `packages/beak_core/test/src/query/beak_relation_load_test.dart` |
| `BeakAggregateSpec` | `package:beak/beak.dart` | `packages/beak_core/lib/src/query/beak_aggregate_spec.dart` | `packages/beak_core/test/src/query/beak_aggregate_spec_test.dart` |
| `BeakSummarySpec`, `BeakSummaryMeasure`, `model.summary(...)` | `package:beak/beak.dart` | `packages/beak_core/lib/src/query/beak_summary_spec.dart` | `packages/beak_core/test/src/query/beak_summary_spec_test.dart` |
| `BeakRecord`, `BeakValue` | `package:beak/beak.dart` | `packages/beak_core/lib/src/query/beak_record.dart` | `packages/beak_core/test/src/query/beak_record_test.dart` |
| `BeakDataSource` | `package:beak/beak.dart` | `packages/beak_core/lib/src/data/beak_data_source.dart` | `packages/beak_core/test/src/data/beak_commit_test.dart` |
| `BeakSavePlan`, `BeakSaveOperation`, `BeakSaveResult` | `package:beak/beak.dart` | `packages/beak_core/lib/src/data/beak_commit.dart` | `packages/beak_core/test/src/data/beak_commit_test.dart` |
| `BeakCandidateGraph`, `BeakCandidateNode` | `package:beak/beak.dart` | `packages/beak_core/lib/src/data/beak_candidate_graph.dart` | `packages/beak_core/test/src/data/beak_candidate_graph_test.dart` |
| `BeakDuplicationSpec` | `package:beak/beak.dart` | `packages/beak_core/lib/src/data/beak_record_duplicator.dart` | `packages/beak_core/test/src/data/beak_record_duplicator_test.dart` |
| `BeakClient`, `BeakSession` | `package:beak/beak.dart` | `packages/beak_core/lib/src/client/beak_client.dart` | `packages/beak_core/test/src/client/beak_client_test.dart` |
| `BeakException` and its subtypes | `package:beak/beak.dart` | `packages/beak_core/lib/src/common/beak_exception.dart` | `packages/beak_core/test/src/common/beak_exception_test.dart` |
| `BeakResult`, `BeakOk`, `BeakErr` | `package:beak/beak.dart` | `packages/beak_core/lib/src/common/beak_result.dart` | `packages/beak_core/test/src/common/beak_result_test.dart` |
| `BeakStorageConfig`, `BeakStorageDriver`, `BeakStorageRegistry` | `package:beak/beak.dart` | `packages/beak_core/lib/src/storage/beak_storage_registry.dart` | `packages/beak_core/test/src/storage/beak_storage_registry_test.dart` |
| `BeakLocalDiskStorageDriver` | `package:beak/server.dart` | `packages/beak_core/lib/src/storage/drivers/beak_local_disk_storage_driver.dart` | `packages/beak_core/test/src/storage/drivers/beak_local_disk_storage_driver_test.dart` |

## The panel (`beak_frontend`)

All of these import from `package:beak/panel.dart`. Add `package:beak/ui.dart` when the file names an `Oi...` widget or an `OiIcons` value.

| Symbol or area | Import | Source | Test |
| --- | --- | --- | --- |
| `BeakPanel` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/panel/beak_panel.dart` | `packages/beak_frontend/test/src/panel/beak_panel_test.dart` |
| `BeakPanelConfig`, `home:` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/panel/beak_panel_config.dart` | `packages/beak_frontend/test/src/panel/beak_home_route_test.dart` |
| `BeakResource` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/panel/beak_resource.dart` | `packages/beak_frontend/test/src/panel/model_configuration_test.dart` |
| `BeakTableScreen`, `BeakFormScreen`, `BeakWizardScreen` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/panel/beak_resource_screen.dart` | `packages/beak_frontend/test/src/panel/declarative_panel_test.dart` |
| `BeakScreen` (a custom page) | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/panel/beak_screen.dart` | `packages/beak_frontend/test/src/panel/beak_screen_routing_test.dart` |
| `BeakNavigation`, `BeakNavigationItem.screen` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/panel/beak_navigation.dart` | `packages/beak_frontend/test/src/panel/beak_home_route_test.dart` |
| `BeakAuthConfig` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/panel/beak_auth_config.dart` | `packages/beak_frontend/test/src/auth/beak_auth_gate_test.dart` |
| `BeakSessionStore` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/auth/beak_session_store.dart` | `packages/beak_frontend/test/src/auth/beak_session_store_test.dart` |
| `BeakMaintenanceConfig` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/panel/beak_maintenance_config.dart` | `packages/beak_frontend/test/src/panel/beak_screen_routing_test.dart` |
| `BeakThemeController` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/panel/beak_theme_controller.dart` | `packages/beak_frontend/test/src/panel/beak_screen_routing_test.dart` |
| `BeakFormatting` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/formatting/beak_formatting.dart` | `packages/beak_frontend/test/src/form/date_input_format_test.dart` |
| `BeakFormLayout`, `BeakFormSections`, `BeakDraftScope`, `X.name.inputText()` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/form/beak_form_layout.dart` | `packages/beak_frontend/test/src/form/beak_form_layout_test.dart` |
| `BeakConfiguredForm` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/form/beak_configured_form.dart` | `packages/beak_frontend/test/src/form/beak_configured_form_test.dart` |
| `BeakFormSession` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/form/beak_form_session.dart` | `packages/beak_frontend/test/src/form/beak_form_session_test.dart` |
| `BeakImportView` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/form/beak_import_view.dart` | `packages/beak_frontend/test/src/form/beak_import_view_test.dart` |
| `BeakImportDefinition` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/data/beak_record_batch.dart` | `packages/beak_frontend/test/src/data/beak_record_batch_test.dart` |
| `BeakListDefinition` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/query/beak_list_definition.dart` | `packages/beak_frontend/test/src/panel/beak_composed_list_test.dart` |
| `BeakQueryController`, `BeakQueryPreset` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/query/beak_query_controller.dart` | `packages/beak_frontend/test/src/table/beak_query_controller_test.dart` |
| `BeakSavedViews`, `BeakSavedViewStore` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/query/beak_saved_views.dart` | `packages/beak_frontend/test/src/table/beak_saved_views_test.dart` |
| `BeakDataTable`, `BeakTableViewModel` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/table/beak_data_table.dart` | `packages/beak_frontend/test/src/table/beak_data_table_test.dart` |
| `BeakSelectFilter` and the other filters, `X.status.selectFilter()` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/filters/beak_filter_widget.dart` | `packages/beak_frontend/test/src/filters/filters_test.dart` |
| `BeakRecordAction`, `BeakBulkAction`, `BeakGlobalAction` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/actions/beak_action.dart` | `packages/beak_frontend/test/src/actions/actions_test.dart` |
| `BeakModelActionRunner` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/actions/beak_model_action_runner.dart` | `packages/beak_frontend/test/src/actions/beak_model_action_runner_test.dart` |
| `BeakBlock`, `BeakBlockHost` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/blocks/beak_block_host.dart` | `packages/beak_frontend/test/src/blocks/beak_block_host_test.dart` |
| `BeakMetricBlock` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/blocks/beak_metric_block.dart` | `packages/beak_frontend/test/src/blocks/beak_metric_block_test.dart` |
| `BeakKanbanBlock` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/blocks/beak_kanban_block.dart` | `packages/beak_frontend/test/src/blocks/beak_module_blocks_test.dart` |
| `BeakCalendarBlock` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/blocks/beak_calendar_block.dart` | `packages/beak_frontend/test/src/blocks/beak_module_blocks_test.dart` |
| `BeakTimelineBlock` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/blocks/beak_timeline_block.dart` | `packages/beak_frontend/test/src/blocks/beak_uikit_blocks_test.dart` |
| `BeakWidgetBlock` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/blocks/beak_widget_block.dart` | `packages/beak_frontend/test/src/blocks/beak_block_host_test.dart` |
| `BeakRecordScope` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/detail/beak_record_scope.dart` | `packages/beak_frontend/test/src/blocks/beak_detail_blocks_test.dart` |
| `HttpBeakDataSource` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/data/http_beak_data_source.dart` | `packages/beak_frontend/test/src/data/http_beak_data_source_test.dart` |
| `BeakResourceRepository` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/data/beak_resource_repository.dart` | `packages/beak_frontend/test/src/data/beak_resource_repository_test.dart` |
| `BeakOverlays` (`toast`, `confirm`, `ask`, `sheet`, `sheetWithResult`), `BeakConfirmResult` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/overlays/beak_overlays.dart` | `packages/beak_frontend/test/src/overlays/beak_overlays_test.dart` |
| `BeakRecordDocument` | `package:beak/panel.dart` | `packages/beak_frontend/lib/src/documents/beak_record_document.dart` | `packages/beak_frontend/test/src/documents/beak_record_document_test.dart` |

## The server (`beak_backend`)

| Symbol or area | Import | Source | Test |
| --- | --- | --- | --- |
| `BeakServer` | `package:beak/server.dart` | `packages/beak_backend/lib/src/server/beak_server.dart` | `packages/beak_backend/test/src/server/beak_server_test.dart` |
| `BeakServerDefaults`, `BeakServeHost`, `defaults.build(...)` | `package:beak/server.dart` | `packages/beak_backend/lib/src/server/beak_serve_host.dart` | `packages/beak_backend/test/src/server/beak_serve_host_test.dart` |
| `BeakPolicies`, `BeakModelRules` | `package:beak/server.dart` | `packages/beak_backend/lib/src/auth/beak_policies.dart` | `packages/beak_backend/test/src/auth/beak_policies_test.dart` |
| `BeakAccess` | `package:beak/server.dart` | `packages/beak_backend/lib/src/auth/beak_access.dart` | `packages/beak_backend/test/src/auth/beak_policies_test.dart` |
| `BeakPolicy`, `BeakAllowAllPolicy`, `BeakRowPolicy`, `BeakPrincipal` | `package:beak/server.dart` | `packages/beak_backend/lib/src/auth/beak_policy.dart` | `packages/beak_backend/test/src/auth/policy_test.dart` |
| `BeakFieldPolicy` | `package:beak/server.dart` | `packages/beak_backend/lib/src/auth/beak_field_policy.dart` | `packages/beak_backend/test/src/auth/field_authorization_test.dart` |
| `BeakAuthSessions`, `BeakUserAccount`, `hashBeakPassword` | `package:beak/server.dart` | `packages/beak_backend/lib/src/auth/auth_router.dart` | `packages/beak_backend/test/src/auth/auth_test.dart` |
| `BeakAuthGuard`, `TokenSessionAuthGuard` | `package:beak/server.dart` | `packages/beak_backend/lib/src/auth/beak_auth_guard.dart` | `packages/beak_backend/test/src/auth/auth_test.dart` |
| The REST routes under `/api/{table}` | none, over HTTP | `packages/beak_backend/lib/src/endpoints/beak_resource_router.dart` | `packages/beak_backend/test/src/endpoints/beak_api_router_test.dart` |
| `POST /api/commits` | none, over HTTP | `packages/beak_backend/lib/src/endpoints/commit_router.dart` | `packages/beak_backend/test/src/endpoints/commit_router_test.dart` |
| `BeakGraphCommitService`, `BeakSavePlanPreparer` (`preparePlan:`) | `package:beak/server.dart` | `packages/beak_backend/lib/src/service/beak_graph_commit_service.dart` | `packages/beak_backend/test/src/service/beak_graph_commit_service_test.dart` |
| `BeakOutbox`, `BeakOutboxSchedule` | `package:beak/server.dart` | `packages/beak_backend/lib/src/service/beak_outbox.dart` | `packages/beak_backend/test/src/service/beak_outbox_test.dart` |
| `WormDataSource` | `package:beak/server.dart` | `packages/beak_backend/lib/src/data/worm/worm_data_source.dart` | `packages/beak_backend/test/src/data/worm/worm_data_source_test.dart` |
| The query translation to SQL | none, internal | `packages/beak_backend/lib/src/data/worm/query_translator.dart` | `packages/beak_backend/test/src/data/worm/query_translator_test.dart` |
| `BeakBlueprint` | `package:beak/migrations.dart` | `packages/beak_backend/lib/src/data/worm/beak_blueprint.dart` | `packages/beak_backend/test/src/data/worm/beak_blueprint_test.dart` |
| `BeakBaselineMigration` | `package:beak/migrations.dart` | `packages/beak_backend/lib/src/data/worm/beak_baseline_migration.dart` | `packages/beak_backend/test/src/data/worm/beak_baseline_migration_test.dart` |
| The error-to-status mapping | none, internal | `packages/beak_backend/lib/src/server/middleware/error_mapping_middleware.dart` | `packages/beak_backend/test/src/server/middleware_test.dart` |
| Uploads | none, over HTTP | `packages/beak_backend/lib/src/uploads/upload_router.dart` | `packages/beak_backend/test/src/uploads/upload_service_test.dart` |
| CSV export | none, over HTTP | `packages/beak_backend/lib/src/export/csv_export_service.dart` | `packages/beak_backend/test/src/export/csv_export_test.dart` |
| `BeakEnv`, `BeakBackendConfig` | `package:beak/server.dart` | `packages/beak_backend/lib/src/config/env_loader.dart` | `packages/beak_backend/test/src/config/env_loader_test.dart` |
| `BeakStorageSettings` | `package:beak/server.dart` | `packages/beak_backend/lib/src/server/beak_storage_settings.dart` | `packages/beak_backend/test/src/server/beak_storage_settings_test.dart` |

## Testing (`beak_test`)

| Symbol or area | Import | Source | Test |
| --- | --- | --- | --- |
| `InMemoryBeakDataSource` | `package:beak/testing.dart` | `packages/beak_test/lib/src/in_memory_beak_data_source.dart` | `packages/beak_test/test/src/in_memory_beak_data_source_test.dart` |
| `BeakRecordingDataSource` | `package:beak/testing.dart` | `packages/beak_test/lib/src/beak_recording_data_source.dart` | `packages/beak_test/test/src/beak_recording_data_source_test.dart` |
| `runBeakDataSourceContract` | `package:beak/testing.dart` | `packages/beak_test/lib/src/data_source_contract.dart` | `packages/beak_backend/test/src/data/worm/worm_data_source_contract_test.dart` |
| `beakFakeRecord`, `BeakRecordFactory` | `package:beak/testing.dart` | `packages/beak_test/lib/src/beak_record_factory.dart` | `packages/beak_test/test/src/beak_record_factory_test.dart` |
| `expectSchemaParity`, `expectNoOrphanTables` | `package:beak/testing.dart` | `packages/beak_test/lib/src/beak_schema_parity.dart` | `packages/beak_test/test/src/beak_schema_parity_test.dart` |

## The command line (`beak_cli`)

The CLI is an executable, so there is no import. Run it as `beak <command>`.

| Symbol or area | Import | Source | Test |
| --- | --- | --- | --- |
| The command runner and exit codes | none, `beak` | `packages/beak_cli/lib/src/cli_runner.dart` | `packages/beak_cli/test/src/cli_test.dart` |
| `beak create` and the scaffold text | none, `beak` | `packages/beak_cli/lib/src/commands/create_command.dart` | `packages/beak_cli/test/src/commands/create_command_test.dart` |
| `beak init` | none, `beak` | `packages/beak_cli/lib/src/commands/init_command.dart` | `packages/beak_cli/test/src/commands/init_command_test.dart` |
| `beak prepare`, discovery, the emitters | none, `beak` | `packages/beak_cli/lib/src/commands/prepare_command.dart` | `packages/beak_cli/test/src/commands/prepare_command_test.dart` |
| Reading schema classes | none, `beak` | `packages/beak_cli/lib/src/schema/beak_schema_reader.dart` | `packages/beak_cli/test/src/schema/beak_schema_test.dart` |
| Create-table and drift migrations | none, `beak` | `packages/beak_cli/lib/src/schema/beak_migration_emitter.dart` | `packages/beak_cli/test/src/schema/beak_migration_emitter_test.dart` |
| `beak.yaml` | none, `beak` | `packages/beak_cli/lib/src/project/beak_project_config.dart` | `packages/beak_cli/test/src/project/beak_project_config_test.dart` |
| `beak eject` | none, `beak` | `packages/beak_cli/lib/src/commands/eject_command.dart` | `packages/beak_cli/test/src/commands/eject_command_test.dart` |
| `beak introspect` | none, `beak` | `packages/beak_cli/lib/src/commands/introspect_command.dart` | `packages/beak_cli/test/src/introspect/introspect_test.dart` |
| `beak doctor` | none, `beak` | `packages/beak_cli/lib/src/commands/doctor_command.dart` | `packages/beak_cli/test/src/commands/doctor_command_test.dart` |
| `beak agents`, the managed block | none, `beak` | `packages/beak_cli/lib/src/agents/beak_agent_files.dart` | `packages/beak_cli/test/src/agents/agent_files_test.dart` |
| The `AGENTS.md` markers | none, `beak` | `packages/beak_cli/lib/src/agents/beak_managed_block.dart` | `packages/beak_cli/test/src/agents/managed_block_test.dart` |
| The `CLAUDE.md` pairing | none, `beak` | `packages/beak_cli/lib/src/agents/beak_claude_md.dart` | `packages/beak_cli/test/src/agents/claude_md_test.dart` |
| Skill installation | none, `beak` | `packages/beak_cli/lib/src/agents/beak_skill_installer.dart` | `packages/beak_cli/test/src/agents/skill_installer_test.dart` |
| `beak docs`, the docs copy | none, `beak` | `packages/beak_cli/lib/src/agents/beak_docs_bundle.dart` | `packages/beak_cli/test/src/agents/docs_materializer_test.dart` |

## Serverpod

| Symbol or area | Import | Source | Test |
| --- | --- | --- | --- |
| `ServerpodResource` (bridge) | `package:beak_serverpod/beak_serverpod.dart` | `packages/beak_serverpod/lib/src/resource.dart` | `packages/beak_serverpod/test/src/resource_test.dart` |
| `ServerpodModel` | `package:beak_serverpod/beak_serverpod.dart` | `packages/beak_serverpod/lib/src/model.dart` | `packages/beak_serverpod/test/src/query_test.dart` |
| `ServerpodField` | `package:beak_serverpod/beak_serverpod.dart` | `packages/beak_serverpod/lib/src/field.dart` | `packages/beak_serverpod/test/src/field_test.dart` |
| The tunnel envelope, `BeakWireRequest` | `package:beak_serverpod/wire.dart` | `packages/beak_serverpod/lib/src/wire.dart` | `packages/beak_serverpod/test/wire_test.dart` |
| `BeakServerpodEngine` | `package:beak_serverpod_server/beak_serverpod_server.dart` | `packages/beak_serverpod_server/lib/src/beak_serverpod_engine.dart` | `packages/beak_serverpod_server/test/beak_serverpod_engine_test.dart` |
| `BeakAdminGate` | `package:beak_serverpod_server/beak_serverpod_server.dart` | `packages/beak_serverpod_server/lib/src/beak_admin_gate.dart` | `packages/beak_serverpod_server/test/beak_tunnel_path_test.dart` |
| `ServerpodSessionAdapter` | `package:beak_serverpod_server/beak_serverpod_server.dart` | `packages/beak_serverpod_server/lib/src/serverpod_session_adapter.dart` | `packages/beak_serverpod_server/test/serverpod_session_adapter_test.dart` |
| `serverpodBeakDataSource` | `package:beak_serverpod_flutter/beak_serverpod_flutter.dart` | `packages/beak_serverpod_flutter/lib/src/serverpod_beak_data_source.dart` | `packages/beak_serverpod_flutter/test/serverpod_beak_data_source_test.dart` |
| `ServerpodAuthAdapter` | `package:beak_serverpod_flutter/beak_serverpod_flutter.dart` | `packages/beak_serverpod_flutter/lib/src/serverpod_auth_adapter.dart` | `packages/beak_serverpod_flutter/test/serverpod_auth_adapter_test.dart` |
| `generateServerpodCompanions` | `package:beak_serverpod_generator/beak_serverpod_generator.dart` | `packages/beak_serverpod_generator/lib/src/generator.dart` | `packages/beak_serverpod_generator/test/src/generator_test.dart` |

## Storage drivers

A project adds these to its `pubspec.yaml` when it stores files outside the local disk. See [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md).

| Symbol or area | Import | Source | Test |
| --- | --- | --- | --- |
| `S3StorageDriver`, `S3ObjectClient` | `package:beak_storage_s3/beak_storage_s3.dart` | `packages/beak_storage_s3/lib/src/s3_storage_driver.dart` | `packages/beak_storage_s3/test/s3_storage_driver_test.dart` |
| `HttpS3ObjectClient` | `package:beak_storage_s3/beak_storage_s3.dart` | `packages/beak_storage_s3/lib/src/http_s3_object_client.dart` | `packages/beak_storage_s3/test/http_s3_object_client_test.dart` |
| `FtpStorageDriver`, `FtpTransport` | `package:beak_storage_ftp/beak_storage_ftp.dart` | `packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart` | `packages/beak_storage_ftp/test/ftp_storage_driver_test.dart` |

## Repository tools

| Symbol or area | Import | Source | Test |
| --- | --- | --- | --- |
| The docs gate, `dart run tool/check_docs.dart` | none | `tool/check_docs.dart` | `test/check_docs_test.dart` |
| The docs bundle and the corrections table check | none | `tool/build_agent_docs.dart` | `test/build_agent_docs_test.dart` |
| The skill validator | none | `tool/published_skills.dart` | `test/published_skills_test.dart` |
| The Material guard, `melos run guard-material` | none | `tool/check_no_material.dart` | `test/check_no_material_test.dart` |
| The hook-widget guard, `melos run guard-hooks` | none | `tool/check_hook_widgets.dart` | `test/check_hook_widgets_test.dart` |
| The web-safety guard, `melos run guard-web` | none | `tool/check_web_safe.dart` | `test/check_web_safe_test.dart` |

## Machine-readable twin

This page as Markdown: `https://simonerich.github.io/beak/ai/source-map/index.md`. In a project that ran `beak docs`: `.dart_tool/beak/docs/ai/source-map.md`. The exports behind each import line are listed on [Libraries](../reference/libraries.md).

## Continue reading

- [Libraries](../reference/libraries.md): every export of the eight `package:beak` libraries, and what each may reach.
- [Prompt recipes](prompts.md): prompts that ask an agent to cite the file and the test.
- [Task map](task-map.md): the page and the example file for a task.
