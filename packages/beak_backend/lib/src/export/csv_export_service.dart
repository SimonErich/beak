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
  Future<Stream<List<int>>> exportCsv(
    String table,
    BeakQuerySpec spec, {
    BeakFormatPolicy? formatting,
    List<String>? columns,
    Map<String, BeakExportFormat> formats = const {},
    bool raw = false,
    bool Function(BeakColumn column)? canRead,
  }) async {
    if (raw && (formatting != null || formats.isNotEmpty)) {
      throw const BeakValidationException(
        'Raw exports cannot also request display formatting.',
      );
    }
    final model = registry.byTableOrThrow(table);
    if (spec.table != model.table) {
      throw BeakValidationException(
        'Export spec targets "${spec.table}" but this endpoint serves '
        '"${model.table}".',
      );
    }
    final selected = columns == null
        ? model.columnsFor(BeakContext.table)
        : [
            for (final key in columns)
              model.columns.where((column) => column.key == key).firstOrNull ??
                  (throw BeakValidationException(
                    'Unknown export column "$key".',
                  )),
          ];
    if (selected.isEmpty ||
        selected.map((column) => column.key).toSet().length !=
            selected.length) {
      throw const BeakValidationException(
        'Export columns must be non-empty and unique.',
      );
    }
    if (formats.keys.any(
          (key) => !selected.any((column) => column.key == key),
        ) ||
        formats.values.any((format) => format.scale < 0 || format.scale > 12)) {
      throw const BeakValidationException(
        'Export formatting must target selected fields with a valid scale.',
      );
    }
    final visibleColumns = selected
        .where((column) => canRead?.call(column) ?? true)
        .toList();
    final BeakQuerySpec ordered = _orderedByKey(spec, model);
    final firstPage = await dataSource.query(
      ordered.paginate(page: 1, perPage: pageSizeInRows),
    );
    return _stream(
      model,
      ordered,
      firstPage,
      columns: visibleColumns,
      formats: formats,
      formatting: formatting,
      raw: raw,
      canRead: canRead,
    );
  }

  /// [spec] with the primary key as its last sort.
  ///
  /// The export reads the table one page at a time, and a database gives no
  /// order to `LIMIT`/`OFFSET` without an `ORDER BY`: a row written or moved
  /// between two pages would then be skipped or exported twice. Sorting by
  /// the key makes every page a stable slice, and the caller's own sorts still
  /// come first.
  static BeakQuerySpec _orderedByKey(BeakQuerySpec spec, BeakModel model) {
    final String key = model.primaryKey.key;
    if (spec.sorts.any((BeakSort sort) => sort.columnKey == key)) {
      return spec;
    }
    return BeakQuerySpec(
      table: spec.table,
      filter: spec.filter,
      sorts: [...spec.sorts, BeakSort(key)],
      search: spec.search,
      relationLoads: spec.relationLoads,
      pagination: spec.pagination,
      withTrashed: spec.withTrashed,
    );
  }

  Stream<List<int>> _stream(
    BeakModel model,
    BeakQuerySpec spec,
    BeakPage<BeakRecord> firstPage, {
    required List<BeakColumn> columns,
    required Map<String, BeakExportFormat> formats,
    BeakFormatPolicy? formatting,
    required bool raw,
    bool Function(BeakColumn column)? canRead,
  }) async* {
    yield utf8.encode(_csvRow([for (final column in columns) column.label]));

    var page = 1;
    var result = firstPage;
    while (true) {
      for (final record in result.items) {
        final visible = canRead == null
            ? record
            : BeakRecord(
                values: {
                  for (final column in model.columns)
                    if (canRead(column) &&
                        record.values.containsKey(column.key))
                      column.key: record.values[column.key]!,
                },
              );
        yield utf8.encode(
          _csvRow([
            for (final column in columns)
              renderCell(
                column,
                visible[column.key],
                record: visible,
                formatting: formatting,
                override: formats[column.key],
                raw: raw,
              ),
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
  /// its raw value.
  ///
  /// A missing value is always the empty string, even under a [formatting]
  /// whose `emptyValue` is a placeholder such as the panel's em dash: a file
  /// has no use for "nothing shown here".
  static String renderCell(
    BeakColumn column,
    BeakValue? value, {
    BeakRecord? record,
    BeakExportFormat? override,
    BeakFormatPolicy? formatting,
    bool raw = false,
  }) {
    if (column.semantic.kind == BeakSemanticKind.password &&
        value?.raw != null) {
      return '••••••••';
    }
    if (override != null) {
      final decoded = column.semantic.hasCodec
          ? column.semantic.tryDecode(value)
          : value?.raw;
      final policy = formatting ?? const BeakFormatPolicy();
      final text = policy.format(
        override.minorUnits && decoded is int
            ? BeakDecimal(decoded, scale: override.scale)
            : decoded,
        override.format,
      );
      return _blankIfEmpty(text, value, policy);
    }
    if (formatting != null) {
      final text = formatting.formatCell(
        column,
        record ?? BeakRecord(values: {column.key: ?value}),
      );
      return _blankIfEmpty(text, value, formatting);
    }
    if (!raw && column.semantic.hasCodec) {
      final decoded = column.semantic.tryDecode(value);
      if (decoded is BeakDecimal ||
          decoded is BeakDate ||
          decoded is BeakTime) {
        return decoded.toString();
      }
      if (decoded is Duration) {
        return const BeakFormatPolicy().duration(decoded);
      }
    }
    return _physicalCell(column, value, raw: raw);
  }

  /// [text] unless it is the policy's placeholder for a value that is not
  /// there.
  static String _blankIfEmpty(
    String text,
    BeakValue? value,
    BeakFormatPolicy policy,
  ) => value?.raw == null && text == policy.emptyValue ? '' : text;

  static String _physicalCell(
    BeakColumn column,
    BeakValue? value, {
    required bool raw,
  }) {
    final Object? physical = value?.raw;
    if (raw) {
      return switch (physical) {
        null => '',
        final DateTime instant => instant.toIso8601String(),
        _ => physical.toString(),
      };
    }
    final Object? rawValue = physical;
    if (rawValue == null) {
      return '';
    }
    return switch (column) {
      BeakDateTimeColumn() => switch (rawValue) {
        final DateTime instant => instant.toIso8601String(),
        final Object other => other.toString(),
      },
      BeakDecimalColumn(:final precision) => switch (rawValue) {
        final num number => number.toStringAsFixed(precision),
        final Object other => other.toString(),
      },
      _ => rawValue.toString(),
    };
  }

  String _csvRow(List<String> cells) =>
      '${cells.map(_escapeCell).join(',')}\r\n';

  /// Quotes [cell] for CSV, after making sure a spreadsheet will not run it.
  ///
  /// Excel, Numbers and Sheets evaluate a cell that starts with `=`, `+`, `-`
  /// or `@` (or a tab, a carriage return or spaces that hide one) as a formula, so
  /// user-entered text such as `=HYPERLINK(...)` in an exported name would
  /// execute on the machine of whoever opens the file. A leading `'` makes it
  /// text. A cell that is only a number (`-5`) is left alone so amounts stay
  /// amounts.
  String _escapeCell(String cell) {
    final safe = _startsLikeFormula(cell) ? "'$cell" : cell;
    return safe.contains(RegExp(r'[",\r\n]'))
        ? '"${safe.replaceAll('"', '""')}"'
        : safe;
  }

  static bool _startsLikeFormula(String cell) =>
      cell.isNotEmpty &&
      ('\t\r'.contains(cell[0]) || _formulaLead.hasMatch(cell.trimLeft())) &&
      num.tryParse(cell) == null;

  static final RegExp _formulaLead = RegExp(r'^[=+\-@]');
}
