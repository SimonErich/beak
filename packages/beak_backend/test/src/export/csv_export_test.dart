import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

void main() {
  late Handler handler;
  late WormDataSource dataSource;
  late BeakModelRegistry registry;

  final createdAt = DateTime.utc(2026, 7, 1, 8, 30);

  setUp(() async {
    Worm.seedRandom(42);
    final adapter = await createApiTestDatabase();
    registry = createApiRegistry();
    dataSource = WormDataSource(registry, adapter: adapter);
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(beakApiRouter(registry: registry, dataSource: dataSource));

    for (final (index, (title, rating)) in [
      ('Alpha, with comma', 5),
      ('Beta "quoted"', 3),
      ('Gamma', 1),
    ].indexed) {
      await dataSource.create(
        'notes',
        BeakRecord.fromRow({
          'id': 'n${index + 1}',
          'title': title,
          'rating': rating,
          'published': index == 0,
          'created_at': createdAt,
        }),
      );
    }
  });

  tearDown(Worm.reset);

  /// Minimal RFC-4180 CSV parser for round-trip assertions.
  List<List<String>> parseCsv(String content) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < content.length; i += 1) {
      final char = content[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            cell.write('"');
            i += 1;
          } else {
            inQuotes = false;
          }
        } else {
          cell.write(char);
        }
      } else if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        row.add(cell.toString());
        cell.clear();
      } else if (char == '\r' &&
          i + 1 < content.length &&
          content[i + 1] == '\n') {
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
        i += 1;
      } else {
        cell.write(char);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }

  test(
    'ordered export projection preserves permissions and ignores pagination',
    () async {
      final csv = await CsvExportService(registry, dataSource).exportCsv(
        'notes',
        const BeakQuerySpec(
          table: 'notes',
          pagination: BeakPagination(page: 3, perPage: 1),
        ),
        columns: ['title', 'id'],
        canRead: (column) => column.key != 'id',
      );
      final rows = parseCsv(await utf8.decoder.bind(csv).join());
      expect(rows.first, ['Title']);
      expect(rows, hasLength(4));
      expect(rows[1], ['Alpha, with comma']);
    },
  );

  test(
    'export route validates and preserves the explicit scalar projection',
    () async {
      for (final columns in <Object>[
        [],
        ['title', 'title'],
        ['unknown'],
        [12],
      ]) {
        final response = await handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/notes/export'),
            body: jsonEncode({'table': 'notes', 'columns': columns}),
          ),
        );
        expect(response.statusCode, 422);
      }
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/notes/export'),
          body: jsonEncode({
            'table': 'notes',
            'columns': ['title'],
          }),
        ),
      );
      expect(response.statusCode, 200);
      expect(parseCsv(await response.readAsString()).first, ['Title']);
    },
  );

  test(
    'formatted integer units retain their declared scale in authorized exports',
    () async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/notes/export'),
          body: jsonEncode({
            'table': 'notes',
            'columns': ['rating'],
            'formatting': const BeakFormatPolicy(
              locale: 'en_US',
              currency: 'EUR',
            ).toJson(),
            'formats': {
              'rating': const BeakExportFormat(
                BeakValueFormat.currency,
                minorUnits: true,
              ).toJson(),
            },
          }),
        ),
      );
      expect(response.statusCode, 200);
      expect(parseCsv(await response.readAsString())[1], ['€0.05']);
      for (final formats in <Object>[
        'bad',
        {'rating': 'bad'},
        {
          'rating': {'format': 'unknown'},
        },
        {
          'title': {'format': 'text'},
        },
      ]) {
        final invalid = await handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/notes/export'),
            body: jsonEncode({
              'table': 'notes',
              'columns': ['rating'],
              'formats': formats,
            }),
          ),
        );
        expect(invalid.statusCode, 422);
      }
      final raw = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/notes/export'),
          body: jsonEncode({
            'table': 'notes',
            'columns': ['rating'],
            'raw': true,
            'formats': {
              'rating': const BeakExportFormat(
                BeakValueFormat.currency,
              ).toJson(),
            },
          }),
        ),
      );
      expect(raw.statusCode, 422);
    },
  );

  test('streams a well-formed CSV with the table-context header', () async {
    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/notes/export'),
        body: jsonEncode(const BeakQuerySpec(table: 'notes').toJson()),
      ),
    );

    expect(response.statusCode, 200);
    expect(response.headers['content-type'], contains('text/csv'));
    expect(
      response.headers['content-disposition'],
      'attachment; filename="notes.csv"',
    );

    final rows = parseCsv(await response.readAsString());
    final model = registry.byTableOrThrow('notes');
    final expectedHeader = [
      for (final column in model.columns)
        if (column.visibleOn.contains(BeakContext.table)) column.label,
    ];
    expect(rows.first, expectedHeader);
    expect(rows, hasLength(4), reason: 'header plus three records');

    final titleIndex = expectedHeader.indexOf('Title');
    expect(rows[1][titleIndex], 'Alpha, with comma');
    expect(rows[2][titleIndex], 'Beta "quoted"');

    final createdIndex = expectedHeader.indexOf('Created at');
    expect(rows[1][createdIndex], createdAt.toIso8601String());
  });

  test('formatted exports accept explicit portable display policy', () async {
    const formatting = BeakFormatPolicy(
      locale: 'de_AT',
      useLocalTime: false,
      timeZoneOffsetMinutes: 120,
      dateTimePattern: 'dd.MM.yyyy HH:mm',
    );
    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/notes/export'),
        body: jsonEncode({
          ...const BeakQuerySpec(table: 'notes').toJson(),
          'formatting': formatting.toJson(),
        }),
      ),
    );
    expect(response.statusCode, 200);
    final rows = parseCsv(await response.readAsString());
    final dateIndex = rows.first.indexOf('Created at');
    expect(rows[1][dateIndex], '01.07.2026 10:30');
  });

  test('malformed export display options return a validation error', () async {
    for (final options in <Map<String, Object?>>[
      {'formatting': 4},
      {
        'formatting': {'numberPrecision': -1},
      },
      {
        'formatting': {'locale': 'not_a_real_locale'},
      },
      {'raw': 'yes'},
      {'raw': true, 'formatting': const BeakFormatPolicy().toJson()},
    ]) {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/notes/export'),
          body: jsonEncode({
            ...const BeakQuerySpec(table: 'notes').toJson(),
            ...options,
          }),
        ),
      );
      expect(response.statusCode, 422, reason: '$options');
    }
  });

  test('semantic CSV preserves exact amounts and offers raw stored units', () {
    const amount = BeakIntColumn(
      key: 'amount',
      label: 'Amount',
      semantic: BeakSemantic.money(scale: 3, currency: 'EUR'),
    );
    const secret = BeakStringColumn(
      key: 'secret',
      label: 'Secret',
      semantic: BeakSemantic.password(),
    );
    const value = BeakIntValue(9007199254740991);
    expect(CsvExportService.renderCell(amount, value), '9007199254740.991');
    expect(
      CsvExportService.renderCell(amount, value, raw: true),
      '9007199254740991',
    );
    expect(
      CsvExportService.renderCell(
        amount,
        value,
        formatting: const BeakFormatPolicy(locale: 'en_US'),
      ),
      '€9,007,199,254,740.991',
    );
    expect(
      CsvExportService.renderCell(
        secret,
        const BeakStringValue('private'),
        raw: true,
      ),
      '••••••••',
    );
  });

  test('honors the posted spec filter and sort', () async {
    final spec = const BeakQuerySpec(table: 'notes')
        .withFilter(
          const BeakFieldFilter(
            column: NoteColumns.rating,
            operator: BeakOperator.gte,
            value: BeakIntValue(3),
          ),
        )
        .orderBy(NoteColumns.rating);
    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/notes/export'),
        body: jsonEncode(spec.toJson()),
      ),
    );

    final rows = parseCsv(await response.readAsString());
    expect(rows, hasLength(3), reason: 'header plus the two rating>=3 notes');
    final ratingIndex = rows.first.indexOf('Rating');
    expect(rows[1][ratingIndex], '3');
    expect(rows[2][ratingIndex], '5');
  });

  test('rejects a spec whose table mismatches the route', () async {
    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/notes/export'),
        body: jsonEncode(const BeakQuerySpec(table: 'labels').toJson()),
      ),
    );
    expect(response.statusCode, 422);
  });

  test('decimal columns render with their configured precision', () {
    final rendered = CsvExportService.renderCell(
      const BeakDecimalColumn(key: 'price', label: 'Price', precision: 2),
      const BeakDoubleValue(12.5),
    );
    expect(rendered, '12.50');
  });

  test('a malformed export spec returns 422, not 500', () async {
    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/notes/export'),
        body: jsonEncode(const <String, Object?>{}),
      ),
    );
    expect(response.statusCode, 422);
  });

  test('a first-page query failure maps through the error boundary', () async {
    final failing = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: const _FailingDataSource(),
          ),
        );

    final response = await failing(
      Request(
        'POST',
        Uri.parse('http://localhost/api/notes/export'),
        body: jsonEncode(const BeakQuerySpec(table: 'notes').toJson()),
      ),
    );

    expect(
      response.statusCode,
      500,
      reason: 'a mapped error envelope, never a 200 with a truncated CSV',
    );
    expect(await response.readAsString(), contains('"code":"storage"'));
  });
}

/// A data source whose queries always fail — pins that export failures
/// surface before the 200 status and CSV header hit the wire.
final class _FailingDataSource implements BeakDataSource {
  const _FailingDataSource();

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) =>
      throw const BeakStorageException('The notes store is unavailable.');

  @override
  Future<BeakRecord?> getOne(String table, Object id) =>
      throw UnimplementedError();

  @override
  Future<BeakRecord> create(String table, BeakRecord data) =>
      throw UnimplementedError();

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String table, Object id, {bool force = false}) =>
      throw UnimplementedError();

  @override
  Future<BeakRecord> restore(String table, Object id) =>
      throw UnimplementedError();

  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) =>
      throw UnimplementedError();

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => throw UnimplementedError();

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => throw UnimplementedError();

  @override
  Future<num> aggregate(BeakAggregateSpec spec) => throw UnimplementedError();
}
