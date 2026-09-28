import '../columns/beak_column.dart';
import '../columns/beak_semantic.dart';
import '../columns/beak_semantic_values.dart';
import '../common/beak_exception.dart';
import '../model/beak_model.dart';
import '../model/beak_model_registry.dart';
import 'beak_filter.dart';
import 'beak_operator.dart';
import 'beak_query_spec.dart';
import 'beak_value.dart';

/// Converts search terms to portable predicates using model field types.
///
/// Text uses case-insensitive contains. Numbers, booleans and timestamps use
/// typed equality, avoiding database-specific implicit string conversions.
/// A term that cannot represent any selected field matches no records.
BeakFilter? beakSearchFilter(
  BeakSearch? search,
  BeakModel model,
  BeakModelRegistry registry,
) {
  if (search == null ||
      search.term.trim().isEmpty ||
      search.columnKeys.isEmpty) {
    return null;
  }
  final term = search.term.trim();
  final filters = <BeakFilter>[];
  for (final path in search.columnKeys) {
    final parts = path.split('.');
    if (parts.length > 17) {
      throw const BeakConfigurationException(
        'Search relationship path is too deep.',
      );
    }
    var owner = model;
    for (final part in parts.take(parts.length - 1)) {
      final relation = owner.relationshipByKey(part);
      if (relation == null) {
        throw BeakConfigurationException(
          'Model "${owner.table}" has no relation "$part".',
        );
      }
      owner = registry.byTableOrThrow(relation.relatedTable);
    }
    final column = owner.columnByKey(parts.last);
    if (column == null) {
      throw BeakConfigurationException(
        'Model "${owner.table}" has no column "${parts.last}".',
      );
    }
    if (column.semantic.kind == BeakSemanticKind.password) {
      throw BeakConfigurationException(
        'Password column "$path" cannot be searched.',
      );
    }
    if (column.semantic.hasCodec && column is! BeakJsonColumn) {
      final Object? decoded = switch (column.semantic.kind) {
        BeakSemanticKind.exactDecimal || BeakSemanticKind.money =>
          BeakDecimal.tryParse(term, scale: column.semantic.scale),
        BeakSemanticKind.calendarDate => BeakDate.tryParse(term),
        BeakSemanticKind.time => BeakTime.tryParse(term),
        BeakSemanticKind.duration => int.tryParse(term),
        _ => null,
      };
      if (decoded != null) {
        filters.add(
          BeakFieldFilter.forKey(
            path,
            BeakOperator.eq,
            column.semantic.encode(decoded),
          ),
        );
      }
      continue;
    }
    final Object? value = switch (column) {
      BeakIntColumn() => int.tryParse(term),
      BeakDecimalColumn() => double.tryParse(term),
      BeakBoolColumn() => switch (term.toLowerCase()) {
        'true' => true,
        'false' => false,
        _ => null,
      },
      BeakDateTimeColumn() => DateTime.tryParse(term),
      BeakJsonColumn() ||
      BeakCustomColumn() => throw BeakConfigurationException(
        'Column "$path" does not support automatic search.',
      ),
      _ => term,
    };
    if (value == null) continue;
    filters.add(
      BeakFieldFilter.forKey(
        path,
        value is String ? BeakOperator.ilike : BeakOperator.eq,
        BeakValue.of(value is String ? '%$value%' : value),
      ),
    );
  }
  if (filters.isEmpty) {
    return BeakFieldFilter.forKey(
      model.primaryKey.key,
      BeakOperator.inList,
      const BeakListValue([]),
    );
  }
  return BeakOrFilter(filters);
}
