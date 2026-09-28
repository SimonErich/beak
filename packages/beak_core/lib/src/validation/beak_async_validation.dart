import '../model/beak_model.dart';
import '../model/beak_model_registry.dart';
import '../relations/beak_relationship.dart';
import '../query/beak_filter.dart';
import '../query/beak_operator.dart';
import '../query/beak_page.dart';
import '../query/beak_pagination.dart';
import '../query/beak_query_spec.dart';
import '../query/beak_record.dart';
import '../query/beak_value.dart';
import 'beak_record_rule.dart';
import 'beak_validation_data_source.dart';

/// Query seam used by authoritative validators; implementations apply policy.
typedef BeakValidationQuery =
    Future<BeakPage<BeakRecord>> Function(BeakQuerySpec spec);

/// Evaluates declared uniqueness and existence against an authorized source.
final class BeakAsyncValidation {
  /// Creates a stateless query-backed validator.
  const BeakAsyncValidation();

  /// Checks trusted model rules and unique column metadata on a full candidate.
  /// [query] must enforce the same row policy as ordinary resource reads.
  Future<BeakValidationReport> validate(
    BeakModel model,
    BeakRecord record, {
    required BeakValidationQuery query,
    Object? recordId,
    BeakModelRegistry? registry,
  }) async {
    final errors = <String, List<String>>{};
    void report(String key, String message) {
      final messages = errors.putIfAbsent(key, () => []);
      if (!messages.contains(message)) messages.add(message);
    }

    Future<bool> hasMatch(String table, List<BeakFilter> filters) async =>
        (await query(
          BeakQuerySpec(
            table: table,
            filter: BeakAndFilter(filters),
            pagination: const BeakPagination(perPage: 1),
          ),
        )).items.isNotEmpty;
    BeakFilter equals(String key, Object? value) => BeakFieldFilter.forKey(
      key,
      value == null ? BeakOperator.isNull : BeakOperator.eq,
      BeakValue.of(value),
    );
    List<BeakFilter> excludeCurrent(List<BeakFilter> filters) => [
      ...filters,
      if (recordId != null)
        BeakFieldFilter.forKey(
          model.primaryKey.key,
          BeakOperator.neq,
          BeakValue.of(recordId),
        ),
    ];
    final explicit = model.validationRules
        .whereType<BeakUnique<Object>>()
        .where((rule) => rule.scope.isEmpty)
        .map((rule) => rule.field.key)
        .toSet();
    for (final column in model.columns.where(
      (column) => column.unique && !explicit.contains(column.key),
    )) {
      final value = record[column.key]?.raw;
      if (value != null &&
          await hasMatch(
            model.table,
            excludeCurrent([equals(column.key, value)]),
          )) {
        report(column.key, 'This value is already in use.');
      }
    }
    for (final relation in model.relationships.whereType<BeakBelongsTo>()) {
      final value = record[relation.foreignKey]?.raw;
      if (value == null) continue;
      final target =
          registry?.byTable(relation.relatedTable) ??
          model.relatedModels
              .where((item) => item.table == relation.relatedTable)
              .firstOrNull;
      if (!await hasMatch(relation.relatedTable, [
        equals(target?.primaryKey.key ?? 'id', value),
      ])) {
        report(relation.foreignKey, 'The selected value is not available.');
      }
    }
    for (final rule in model.validationRules) {
      switch (rule) {
        case BeakUnique<Object>(:final field, :final scope, :final ignoreNull):
          final value = record[field.key]?.raw;
          if (value == null && ignoreNull) continue;
          if (await hasMatch(
            model.table,
            excludeCurrent([
              equals(field.key, value),
              for (final scoped in scope)
                equals(scoped.key, record[scoped.key]?.raw),
            ]),
          )) {
            report(field.key, 'This value is already in use.');
          }
        case BeakExists<Object>(
          :final field,
          :final target,
          :final where,
          :final matching,
        ):
          final value = record[field.key]?.raw;
          if (value == null) continue;
          if (!await hasMatch(target.model.table, [
            equals(target.key, value),
            ?where,
            for (final match in matching)
              equals(match.target.key, record[match.source.key]?.raw),
          ])) {
            report(field.key, 'The selected value is not available.');
          }
        default:
          break;
      }
    }
    return BeakValidationReport(fieldErrors: errors);
  }
}
