import 'package:beak_core/beak_core.dart';

import 'codec.dart';

/// Validates the query vocabulary emitted by a resolved endpoint adapter.
///
/// Field-name tables are generated; application configuration uses typed fields.
final class ServerpodQueryReader {
  /// Resolves fields against the configured identity branch and rejects loss.
  ServerpodQueryReader({
    required this.spec,
    required this.model,
    required this.fields,
    Set<String> filters = const {},
    bool supportsSearch = false,
    bool supportsSort = true,
    bool supportsArchived = false,
  }) {
    if (spec.table != model.table ||
        spec.relationLoads.isNotEmpty ||
        spec.sorts.length > 1 ||
        (spec.sorts.isNotEmpty && !supportsSort) ||
        (spec.withTrashed && !supportsArchived) ||
        spec.pagination.page < 1 ||
        spec.pagination.perPage < 1) {
      _unsupported();
    }
    final search = spec.search;
    if (search != null &&
        (!supportsSearch ||
            search.columnKeys.any(
              (key) => !model.columns.any(
                (column) => column.key == key && column.searchable,
              ),
            ))) {
      _unsupported();
    }
    final allowed = {for (final name in filters) resolveField(name)};
    void visit(BeakFilter filter) {
      switch (filter) {
        case BeakAndFilter(:final filters):
          for (final child in filters) {
            visit(child);
          }
        case BeakFieldFilter(
          :final columnKey,
          operator: BeakOperator.eq,
          :final value,
        ):
          if (!allowed.contains(columnKey) || _values.containsKey(columnKey)) {
            _unsupported();
          }
          _values[columnKey] = value;
        default:
          _unsupported();
      }
    }

    final filter = spec.filter;
    if (filter != null) visit(filter);
  }

  /// The validated Beak request.
  final BeakQuerySpec spec;

  /// The resource's selected presentation metadata.
  final BeakModel model;

  /// Generated leaf-name to fully qualified field-path candidates.
  final Map<String, List<String>> fields;
  final Map<String, BeakValue> _values = {};

  /// The requested page translated to a documented endpoint page origin.
  int page(int firstPage) {
    if (firstPage != 0 && firstPage != 1) {
      throw const BeakConfigurationException(
        'The endpoint page origin must be configured as zero or one.',
      );
    }
    return spec.pagination.page - 1 + firstPage;
  }

  /// Requested page size.
  int get perPage => spec.pagination.perPage;

  /// Search text, if supported and requested.
  String? get search => spec.search?.term;

  /// Direction retaining the endpoint's declared default.
  bool descending(bool fallback) =>
      spec.sorts.firstOrNull?.descending ?? fallback;

  /// Resolves a generated leaf without guessing between unrelated branches.
  String resolveField(String name) {
    final candidates = fields[name] ?? const [];
    final id = model.primaryKey.key;
    final separator = id.lastIndexOf('.');
    final prefix = separator < 0 ? '' : id.substring(0, separator + 1);
    final direct = '$prefix$name';
    if (candidates.contains(direct)) return direct;
    final preferred = candidates
        .where((key) => key.startsWith(prefix))
        .toList();
    if (preferred.length == 1) return preferred.single;
    if (candidates.length == 1) return candidates.single;
    throw BeakConfigurationException(
      'Ambiguous or missing query field "$name".',
    );
  }

  /// Maps the selected column onto the endpoint's resolved sort enum.
  E sort<E extends Enum>(
    List<E> values,
    E fallback, {
    Map<String, E> overrides = const {},
  }) {
    final requested = spec.sorts.firstOrNull;
    if (requested == null) return fallback;
    if (!model.columns.any(
      (column) => column.key == requested.columnKey && column.sortable,
    )) {
      _unsupported();
    }
    final override = overrides[requested.columnKey];
    if (override != null) return override;
    for (final value in values) {
      if ((fields[value.name]?.contains(requested.columnKey) ?? false) &&
          resolveField(value.name) == requested.columnKey) {
        return value;
      }
    }
    return _unsupported();
  }

  /// Reads one allowlisted equality through its generated value codec.
  V equal<V>(String name, ServerpodValueCodec<V> codec) {
    final value = _values[resolveField(name)];
    return codec.decode(value);
  }

  Never _unsupported() => throw BeakConfigurationException(
    'Unsupported query for resource "${model.table}".',
  );
}

/// Count uses the same authorized query rather than a second endpoint policy.
Future<num> serverpodCount<T>(
  BeakAggregateSpec spec,
  Future<BeakPage<T>> Function(BeakQuerySpec) query,
) async {
  if (spec.function != BeakAggregateFunction.count || spec.columnKey != null) {
    throw const BeakConfigurationException('Unsupported aggregate.');
  }
  final page = await query(
    BeakQuerySpec(
      table: spec.table,
      filter: spec.filter,
      withTrashed: spec.withTrashed,
      pagination: const BeakPagination(perPage: 1),
    ),
  );
  return page.total;
}

/// Projects matching command fields, failing when domain mapping is required.
BeakRecord serverpodProjectInput(
  BeakRecord record, {
  required List<String> inputKeys,
  required String primaryKey,
}) {
  final separator = primaryKey.lastIndexOf('.');
  final prefix = separator < 0 ? '' : primaryKey.substring(0, separator + 1);
  final values = <String, BeakValue>{};
  for (final target in inputKeys) {
    if (record.values.containsKey(target)) {
      values[target] = record.values[target]!;
      continue;
    }
    final leaf = target.split('.').last;
    final candidates = record.values.keys
        .where((key) => key.split('.').last == leaf)
        .toList();
    final preferred = candidates
        .where((key) => key.startsWith(prefix))
        .toList();
    final source = preferred.length == 1
        ? preferred.single
        : candidates.length == 1
        ? candidates.single
        : null;
    if (source == null) {
      throw BeakConfigurationException(
        'Configure an edit projection for command field "$target".',
      );
    }
    values[target] = record.values[source]!;
  }
  return BeakRecord(values: values);
}
