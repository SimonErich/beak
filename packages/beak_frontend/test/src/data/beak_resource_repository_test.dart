import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;
  late BeakResourceRepository repository;

  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'notes': {
          'n1': BeakRecord.fromRow(const {'id': 'n1', 'title': 'One'}),
        },
      },
    );
    repository = BeakResourceRepository(dataSource);
  });

  test('every operation wraps success into BeakOk', () async {
    expect(
      await repository.query(const BeakQuerySpec(table: 'notes')),
      isA<BeakOk<BeakPage<BeakRecord>>>(),
    );
    expect(await repository.getOne('notes', 'n1'), isA<BeakOk<BeakRecord>>());
    expect(
      await repository.create('notes', BeakRecord.fromRow(const {'id': 'n2'})),
      isA<BeakOk<BeakRecord>>(),
    );
    expect(
      await repository.update(
        'notes',
        'n1',
        BeakRecord.fromRow(const {'title': 'Two'}),
      ),
      isA<BeakOk<BeakRecord>>(),
    );
    expect(await repository.delete('notes', 'n1'), isA<BeakOk<void>>());
    expect(
      await repository.attach('notes', 'n1', 'labels', const ['l1']),
      isA<BeakOk<void>>(),
    );
    expect(
      await repository.detach('notes', 'n1', 'labels', const ['l1']),
      isA<BeakOk<void>>(),
    );
  });

  test('aggregate wraps values and failures alike', () async {
    dataSource.aggregateHandler = (spec) => 42;
    final result = await repository.aggregate(
      const BeakAggregateSpec.count(table: 'notes'),
    );
    expect(result, isA<BeakOk<num>>());
    if (result case BeakOk(:final value)) {
      expect(value, 42);
    }
  });

  test('a missing record surfaces as a typed not-found error', () async {
    final result = await repository.getOne('notes', 'ghost');
    expect(result, isA<BeakErr<BeakRecord>>());
    if (result case BeakErr(:final error)) {
      expect(error, isA<BeakNotFoundException>());
    }
  });

  test('thrown BeakExceptions become BeakErr, never escape', () async {
    final failing = BeakResourceRepository(_FailingSource());
    final result = await failing.query(const BeakQuerySpec(table: 'notes'));
    expect(result, isA<BeakErr<BeakPage<BeakRecord>>>());
  });
}

/// A data source whose queries always fail.
final class _FailingSource extends FakeDataSource {
  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    throw const BeakStorageException('backend unreachable');
  }
}
