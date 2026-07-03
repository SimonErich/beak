import 'dart:convert';

import 'package:beak_core/beak_core.dart';

import '../data/beak_data_source.dart';

/// Streams query results as CSV — the engine behind
/// `POST /api/{table}/export`.
final class CsvExportService {
  /// Creates an export service over [registry] and [dataSource].
  const CsvExportService(this.registry, this.dataSource);

  /// The models exported.
  final BeakModelRegistry registry;

  /// The source queried page by page.
  final BeakDataSource dataSource;

  /// How many rows each page fetch pulls while streaming.
  static const int pageSizeInRows = 500;

  /// Streams the CSV for [spec] over [table]: a header from the model's
  /// table-context column labels, then one row per matching record
  /// (paged through [pageSizeInRows] at a time).
  Stream<List<int>> exportCsv(String table, BeakQuerySpec spec) async* {
    final model = registry.byTableOrThrow(table);
    final columns = [
      for (final column in model.columns)
        if (column.visibleOn.contains(BeakContext.table)) column,
    ];
    yield utf8.encode(_csvRow([for (final column in columns) column.label]));

    var page = 1;
    while (true) {
      final result = await dataSource.query(
        spec.paginate(page: page, perPage: pageSizeInRows),
      );
      for (final record in result.items) {
        yield utf8.encode(
          _csvRow([
            for (final column in columns)
              renderCell(column, record[column.key]),
          ]),
        );
      }
      if (result.items.isEmpty || page * pageSizeInRows >= result.total) {
        break;
      }
      page += 1;
    }
  }

  /// Renders one cell per the column's display semantics: timestamps as
  /// ISO-8601, decimals at their configured precision, everything else via
  /// its raw value ('' for null).
  static String renderCell(BeakColumn column, BeakValue? value) {
    final Object? raw = value?.raw;
    if (raw == null) {
      return '';
    }
    return switch (column) {
      BeakDateTimeColumn() => switch (raw) {
        final DateTime instant => instant.toIso8601String(),
        final Object other => other.toString(),
      },
      BeakDecimalColumn(:final precision) => switch (raw) {
        final num number => number.toStringAsFixed(precision),
        final Object other => other.toString(),
      },
      _ => raw.toString(),
    };
  }

  String _csvRow(List<String> cells) =>
      '${cells.map(_escapeCell).join(',')}\r\n';

  String _escapeCell(String cell) => cell.contains(RegExp(r'[",\r\n]'))
      ? '"${cell.replaceAll('"', '""')}"'
      : cell;
}
