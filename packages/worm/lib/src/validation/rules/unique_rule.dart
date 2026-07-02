/// Database-uniqueness validation rule.
library;

import '../../adapter/database_adapter.dart';
import '../../query/aggregate_descriptor.dart';
import '../../query/operator.dart';
import '../../query/predicate.dart';
import '../../query/predicate_tree.dart';
import '../validation_result.dart';
import '../validation_rule.dart';

/// Validates that a value does not already exist in
/// `table.column`.
final class Unique extends ValidationRule {
  /// Creates a [Unique] rule.
  const Unique({
    required this.adapter,
    required this.table,
    required this.column,
    this.exceptId,
    this.primaryKey = 'id',
    this.message,
  });

  /// Adapter used to execute the uniqueness lookup.
  final DatabaseAdapter adapter;

  /// Table containing the unique column.
  final String table;

  /// Column constrained to be unique.
  final String column;

  /// Primary key value of the current row, when
  /// updating.
  final Object? exceptId;

  /// Primary-key column name used for exclusion.
  final String primaryKey;

  /// Override message reported when validation
  /// fails.
  final String? message;

  @override
  String get name => 'unique';

  @override
  Future<ValidationResult> validate(Object? value) async {
    if (value == null) return const ValidationResult.valid();
    final base = LeafNode(
      Predicate(fieldName: column, operator: Operator.eq, value: value),
    );
    final where = exceptId == null
        ? base
        : base.and(
            LeafNode(
              Predicate(
                fieldName: primaryKey,
                operator: Operator.neq,
                value: exceptId,
              ),
            ),
          );
    final count = await adapter.count(
      AggregateDescriptor.count(table: table, where: where),
    );
    if (count > 0) {
      return ValidationResult.invalid(
        message ?? 'The $column has already been taken.',
      );
    }
    return const ValidationResult.valid();
  }
}
