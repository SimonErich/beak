import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;
  late ReferenceCache cache;

  BeakRecord note(String id, String title) =>
      BeakRecord.fromRow({'id': id, 'title': title});

  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'notes': {'n1': note('n1', 'One'), 'n2': note('n2', 'Two')},
        'labels': {
          'l1': BeakRecord.fromRow(const {'id': 'l1', 'name': 'hot'}),
        },
      },
    );
    final registry = BeakModelRegistry()
      ..register(const NoteModel())
      ..register(const LabelModel());
    cache = ReferenceCache(dataSource, registry);
  });

  test('same-frame resolves coalesce into one batchGet', () async {
    final results = await Future.wait<BeakRecord>([
      cache.resolve('notes', 'n1'),
      cache.resolve('notes', 'n2'),
      cache.resolve('notes', 'n1'),
    ]);

    expect(dataSource.batchGetCalls, hasLength(1));
    expect(dataSource.batchGetCalls.single.$2, unorderedEquals(['n1', 'n2']));
    expect(results[0]['title'], const BeakStringValue('One'));
    expect(results[1]['title'], const BeakStringValue('Two'));
    expect(results[2], same(results[0]));
  });

  test('different tables batch separately', () async {
    await Future.wait<BeakRecord>([
      cache.resolve('notes', 'n1'),
      cache.resolve('labels', 'l1'),
    ]);
    expect(dataSource.batchGetCalls, hasLength(2));
  });

  test('cache hits never refetch', () async {
    await cache.resolve('notes', 'n1');
    await cache.resolve('notes', 'n1');
    expect(dataSource.batchGetCalls, hasLength(1));
  });

  test('invalidate forces the next resolve to refetch', () async {
    await cache.resolve('notes', 'n1');
    cache.invalidate('notes', 'n1');
    await cache.resolve('notes', 'n1');
    expect(dataSource.batchGetCalls, hasLength(2));
  });

  test('invalidateTable drops every cached record of the table', () async {
    await Future.wait<BeakRecord>([
      cache.resolve('notes', 'n1'),
      cache.resolve('notes', 'n2'),
    ]);
    cache.invalidateTable('notes');
    await cache.resolve('notes', 'n2');
    expect(dataSource.batchGetCalls, hasLength(2));
  });

  test('a missing id fails with a typed not-found', () {
    expect(
      () => cache.resolve('notes', 'ghost'),
      throwsA(isA<BeakNotFoundException>()),
    );
  });

  test('a batch failure propagates to every waiting resolve', () async {
    final failing = _FailingDataSource();
    final registry = BeakModelRegistry()..register(const NoteModel());
    final failingCache = ReferenceCache(failing, registry);

    final futures = [
      failingCache.resolve('notes', 'n1'),
      failingCache.resolve('notes', 'n2'),
    ];
    for (final future in futures) {
      await expectLater(future, throwsA(isA<BeakStorageException>()));
    }
  });
}

/// A data source whose batch fetch always fails.
final class _FailingDataSource extends FakeDataSource {
  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) async {
    throw const BeakStorageException('backend unreachable');
  }
}
