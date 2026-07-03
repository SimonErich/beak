import 'package:beak_core/beak_core.dart';

/// Searches every registered model's `searchable` columns for a term —
/// the engine behind `GET /api/search`, producing the shared
/// [BeakSearchHit] wire type from `beak_core`.
final class GlobalSearchService {
  /// Creates a search service over [registry] and [dataSource].
  const GlobalSearchService(this.registry, this.dataSource);

  /// The models searched.
  final BeakModelRegistry registry;

  /// The source queries run against.
  final BeakDataSource dataSource;

  /// Searches [term] across every registered model (or just [tables]),
  /// returning at most [perModel] hits per model, in registration order.
  ///
  /// Models without searchable columns never produce hits.
  Future<List<BeakSearchHit>> search(
    String term, {
    int perModel = 5,
    List<String>? tables,
  }) async {
    final hits = <BeakSearchHit>[];
    for (final model in registry.all) {
      if (tables != null && !tables.contains(model.table)) {
        continue;
      }
      final searchableColumns = [
        for (final column in model.columns)
          if (column.searchable) column,
      ];
      if (searchableColumns.isEmpty) {
        continue;
      }
      final page = await dataSource.query(
        BeakQuerySpec(table: model.table)
            .searching(term, searchableColumns)
            .paginate(page: 1, perPage: perModel),
      );
      for (final record in page.items) {
        hits.add(
          BeakSearchHit(
            table: model.table,
            id: record[model.primaryKey.key]?.raw ?? '',
            displayLabel: record[model.displayColumnKey]?.raw?.toString() ?? '',
            matchedColumnKey: _matchedColumnKey(
              record,
              searchableColumns,
              term,
            ),
          ),
        );
      }
    }
    return hits;
  }

  String _matchedColumnKey(
    BeakRecord record,
    List<BeakColumn> searchableColumns,
    String term,
  ) {
    final String needle = term.trim().toLowerCase();
    for (final column in searchableColumns) {
      final String? haystack = record[column.key]?.raw?.toString();
      if (haystack != null && haystack.toLowerCase().contains(needle)) {
        return column.key;
      }
    }
    return searchableColumns.first.key;
  }
}
