import 'dart:async';

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

  test(
    'coalescing shares pending reads but never caches completed responses',
    () async {
      final source = _DelayedSource();
      final owner = BeakResourceRepository.coalescing(source);
      const query = BeakQuerySpec(table: 'notes');
      final first = owner.query(query);
      final duplicate = owner.query(const BeakQuerySpec(table: 'notes'));
      expect(identical(first, duplicate), isTrue);
      expect(source.calls, 1);
      source.pending.removeAt(0).complete();
      await first;
      final next = owner.query(query);
      expect(source.calls, 2);
      source.pending.removeAt(0).complete();
      await next;
    },
  );

  test(
    'invalidated and distinct queries never join an old pending response',
    () async {
      final source = _DelayedSource();
      final owner = BeakResourceRepository.coalescing(source);
      const query = BeakQuerySpec(table: 'notes');
      final old = owner.query(query);
      owner.invalidateQueries();
      final current = owner.query(query);
      final distinct = owner.query(query.paginate(perPage: 1));
      expect(source.calls, 3);
      source.pending.removeAt(0).complete();
      await old;
      expect(
        identical(current, owner.query(query)),
        isTrue,
        reason: 'Old completion must not remove the current request',
      );
      for (final gate in source.pending) {
        gate.complete();
      }
      await Future.wait([current, distinct]);
    },
  );

  test('failed coalesced queries remain retryable', () async {
    final owner = BeakResourceRepository.coalescing(_FailingSource());
    const query = BeakQuerySpec(table: 'notes');
    expect(await owner.query(query), isA<BeakErr<BeakPage<BeakRecord>>>());
    expect(await owner.query(query), isA<BeakErr<BeakPage<BeakRecord>>>());
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
      await repository.attach('notes', 'n2', 'labels', const ['l1']),
      isA<BeakOk<void>>(),
    );
    expect(
      await repository.detach('notes', 'n2', 'labels', const ['l1']),
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

    dataSource.aggregateHandler = (spec) =>
        throw const BeakStorageException('backend unreachable');
    final failed = await repository.aggregate(
      const BeakAggregateSpec.count(table: 'notes'),
    );
    expect(failed, isA<BeakErr<num>>());
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

final class _DelayedSource extends FakeDataSource {
  int calls = 0;
  final pending = <Completer<void>>[];
  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    calls++;
    final gate = Completer<void>();
    pending.add(gate);
    await gate.future;
    return super.query(spec);
  }
}
