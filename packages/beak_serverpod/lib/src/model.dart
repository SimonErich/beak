import 'package:beak_core/beak_core.dart';

/// Resource presentation over generated fields; this never owns a DB schema.
final class ServerpodModel extends BeakModel {
  /// Creates metadata from selected, generated columns and a stable identity.
  const ServerpodModel({
    required String resource,
    required this.columns,
    required this.primaryKey,
    required BeakColumn displayColumn,
    this.relationships = const [],
    this.formSlots,
  }) : table = resource,
       _displayColumn = displayColumn;

  /// Logical resource key dispatched by the registered data-source binding.
  @override
  final String table;

  @override
  final List<BeakColumn> columns;

  @override
  final BeakColumn primaryKey;

  final BeakColumn _displayColumn;

  @override
  String get displayColumnKey => _displayColumn.key;

  @override
  final List<BeakRelationship> relationships;

  @override
  final List<Enum>? formSlots;
}
