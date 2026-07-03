/// Beak admin-panel Flutter widgets — panel shell, data table, forms, detail
/// views, actions, and dashboards built on obers_ui.
library;

export 'src/common/hex_color.dart';
export 'src/data/beak_client.dart';
export 'src/data/beak_resource_repository.dart';
export 'src/data/beak_upload_repository.dart';
export 'src/data/http_beak_data_source.dart';
export 'src/data/optimistic.dart';
export 'src/data/reference_cache.dart';
export 'src/detail/beak_detail_view.dart';
export 'src/detail/relation_manager.dart';
export 'src/di/beak_locator.dart';
export 'src/form/beak_data_form.dart';
export 'src/form/beak_form_controller_builder.dart';
export 'src/form/field_widget_mapper.dart';
export 'src/form/form_view_model.dart';
export 'src/form/relation_field.dart';
export 'src/form/upload_field.dart';
export 'src/panel/beak_panel.dart';
export 'src/panel/beak_panel_config.dart';
export 'src/panel/beak_router.dart';
export 'src/state/beak_view_model.dart';
export 'src/table/beak_data_table.dart';
export 'src/table/beak_table_action.dart';
export 'src/table/column_cell_renderer.dart';
export 'src/table/table_view_model.dart';

/// The version of the `beak_frontend` package.
const String beakFrontendVersion = '0.0.1';
