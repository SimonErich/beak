import 'dart:convert';

import 'package:beak_core/beak_core.dart';

/// Streams query results as CSV — the engine behind
/// `POST /api/{table}/export`.
///
/// It reuses a [BeakQuerySpec] (the same filter/sort a table view builds), so
/// an export honours exactly what the user is looking at. Rows stream in
/// pages of [pageSizeInRows], keeping memory flat for large tables.
///
/// ```dart
/// final service = CsvExportService(registry, dataSource);
/// final csv = await service.exportCsv(
///   'products',
///   BeakQuerySpec(table: 'products'),
/// );
/// await response.addStream(csv); // stream straight to the client
/// ```
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
  ///
  /// Spec validation AND the first page's query run eagerly — before the
  /// returned stream exists — so their typed exceptions surface inside
  /// the handler and map to proper error responses. Failures on later
  /// pages truncate the already-streaming body: once the 200 status and
  /// header bytes are on the wire, no error envelope can follow.
  Future<Stream<List<int>>> exportCsv(String table, BeakQuerySpec spec) async {
    final model = registry.byTableOrThrow(table);
    if (spec.table != model.table) {
      throw BeakValidationException(
        'Export spec targets "${spec.table}" but this endpoint serves '
        '"${model.table}".',
      );
    }
    final firstPage = await dataSource.query(
      spec.paginate(page: 1, perPage: pageSizeInRows),
    );
    return _stream(model, spec, firstPage);
  }

  Stream<List<int>> _stream(
    BeakModel model,
    BeakQuerySpec spec,
    BeakPage<BeakRecord> firstPage,
  ) async* {
    final columns = model.columnsFor(BeakContext.table);
    yield utf8.encode(_csvRow([for (final column in columns) column.label]));

    var page = 1;
    var result = firstPage;
    while (true) {
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
      result = await dataSource.query(
        spec.paginate(page: page, perPage: pageSizeInRows),
      );
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
