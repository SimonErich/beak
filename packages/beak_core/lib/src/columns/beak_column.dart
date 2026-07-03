import 'package:meta/meta.dart';

import '../common/beak_color.dart';
import '../context/beak_context.dart';
import '../context/beak_render_intent.dart';
import '../rules/beak_rule.dart';
import '../storage/file_rules/beak_dimensions.dart';
import '../storage/file_rules/beak_file_type.dart';
import '../storage/transforms/beak_image_transform.dart';
import 'beak_json.dart';
import 'beak_render_config.dart';

part 'beak_bool_column.dart';
part 'beak_color_column.dart';
part 'beak_custom_column.dart';
part 'beak_date_time_column.dart';
part 'beak_decimal_column.dart';
part 'beak_enum_column.dart';
part 'beak_file_column.dart';
part 'beak_image_column.dart';
part 'beak_int_column.dart';
part 'beak_json_column.dart';
part 'beak_rich_text_column.dart';
part 'beak_string_column.dart';
part 'beak_text_column.dart';

/// The heart of Beak: a typed, `const`, define-once column.
///
/// A column is declared once (as a `static const` on a user's columns class)
/// and drives every surface: table cell, form input, detail entry, and
/// filter control. The hierarchy is sealed so consumers — the frontend
/// renderer, the backend mapper — switch exhaustively and are forced to
/// handle new column types at compile time.
@immutable
sealed class BeakColumn {
  /// Creates a column stored under [key] and labelled [label].
  const BeakColumn({
    required this.key,
    required this.label,
    this.visibleOn = const {
      BeakContext.table,
      BeakContext.form,
      BeakContext.detail,
    },
    this.sortable = false,
    this.searchable = false,
    this.filterable = false,
    this.rules = const [],
  });

  /// Storage/DB column name (snake_case). Beak wires it internally; users
  /// reference the column constant itself, never this string.
  final String key;

  /// Human-readable label shown in tables, forms, and detail views.
  final String label;

  /// The contexts this column appears in.
  final Set<BeakContext> visibleOn;

  /// Whether table views may sort by this column.
  final bool sortable;

  /// Whether search includes this column.
  final bool searchable;

  /// Whether table views may filter by this column.
  final bool filterable;

  /// Declarative validation rules enforced on input, in order.
  final List<BeakRule> rules;

  /// The per-context render configuration of this column.
  BeakRenderConfig get renderConfig;

  /// The rendering hint for a given [context] (the frontend maps each intent
  /// to an obers_ui widget).
  BeakRenderIntent intentFor(BeakContext context) =>
      renderConfig.intentFor(context);

  /// The Dart type this column's values take (for typed form/data access).
  Type get valueType;
}
