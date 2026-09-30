import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_backend/src/export/csv_export_service.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_test/beak_test.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

void main() {
  late Handler handler;
  late WormDataSource dataSource;
  late BeakModelRegistry registry;

  setUp(() async {
    Worm.seedRandom(42);
    final adapter = await createApiTestDatabase();
    registry = createApiRegistry();
    dataSource = WormDataSource(registry, adapter: adapter);
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(beakApiRouter(registry: registry, dataSource: dataSource));
  });

  tearDown(Worm.reset);

  Future<Response> export(Map<String, Object?> options) async => handler(
    Request(
      'POST',
      Uri.parse('http://localhost/api/notes/export'),
      body: jsonEncode({
        ...const BeakQuerySpec(table: 'notes').toJson(),
        ...options,
      }),
    ),
  );

  test('every page is read in primary-key order, so no row is skipped or '
      'repeated between pages', () async {
    final spy = BeakRecordingDataSource(dataSource);
    final Stream<List<int>> csv = await CsvExportService(
      registry,
      spy,
    ).exportCsv('notes', const BeakQuerySpec(table: 'notes'));
    await csv.drain<void>();
    expect(spy.queryCalls, isNotEmpty);
    for (final BeakQuerySpec spec in spy.queryCalls) {
      expect(spec.sorts.map((BeakSort sort) => sort.columnKey), ['id']);
    }
  });

  test(
    'a sort the caller asked for stays first, the key breaks its ties',
    () async {
      final spy = BeakRecordingDataSource(dataSource);
      final Stream<List<int>> csv = await CsvExportService(registry, spy)
          .exportCsv(
            'notes',
            const BeakQuerySpec(table: 'notes', sorts: [BeakSort('title')]),
          );
      await csv.drain<void>();
      expect(
        spy.queryCalls.single.sorts.map((BeakSort sort) => sort.columnKey),
        ['title', 'id'],
      );
    },
  );

  test('a key sort the caller already gave is not doubled', () async {
    final spy = BeakRecordingDataSource(dataSource);
    final Stream<List<int>> csv = await CsvExportService(registry, spy)
        .exportCsv(
          'notes',
          const BeakQuerySpec(
            table: 'notes',
            sorts: [BeakSort('id', descending: true)],
          ),
        );
    await csv.drain<void>();
    expect(spy.queryCalls.single.sorts, const [
      BeakSort('id', descending: true),
    ]);
  });

  test('a formula hidden behind leading whitespace is still text', () async {
    for (final String title in [' =1+1', '  +SUM(A1)', '\t=cmd']) {
      await dataSource.create(
        'notes',
        BeakRecord.fromRow({'id': 'x${title.hashCode}', 'title': title}),
      );
    }
    final Response response = await export({
      'columns': ['title'],
    });
    final String body = await response.readAsString();
    final List<String> cells = const LineSplitter()
        .convert(body)
        .skip(1)
        .toList();
    expect(cells, hasLength(greaterThanOrEqualTo(3)));
    for (final String cell in cells) {
      expect(cell.replaceAll('"', ''), startsWith("'"));
    }
  });

  test('a display pattern that cannot be formatted is refused up front, '
      'not after the file has started', () async {
    await dataSource.create(
      'notes',
      BeakRecord.fromRow({
        'id': 'dated',
        'title': 'Dated',
        'created_at': DateTime.utc(2026, 7, 1),
      }),
    );
    final Response response = await export({
      'columns': ['title', 'created_at'],
      'formatting': {'dateTimePattern': 'yyyy EEEEEEE'},
    });
    expect(response.statusCode, 422);
  });
}
