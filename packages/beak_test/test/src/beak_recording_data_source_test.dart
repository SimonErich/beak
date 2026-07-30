import 'package:beak_core/beak_core.dart';
import 'package:beak_test/beak_test.dart';
import 'package:test/test.dart';

import '../support/contract_models.dart';

const _product = ProductModel();

BeakRecord _row(String id, {String name = 'Item'}) =>
    BeakRecord.fromRow({'id': id, 'name': name, 'price': 10.0, 'stock': 1});

void main() {
  late InMemoryBeakDataSource inner;
  late BeakRecordingDataSource source;

  setUp(() {
    inner = InMemoryBeakDataSource(
      registry: buildContractRegistry(),
      generateId: () => 'generated-id',
    )..seed(_product, [_row('p1'), _row('p2', name: 'Other')]);
    source = BeakRecordingDataSource(inner);
  });

  test(
    'every read is recorded and still answered by the inner source',
    () async {
      final page = await source.query(const BeakQuerySpec(table: 'products'));
      final BeakRecord? one = await source.getOne('products', 'p1');
      final many = await source.batchGet('products', const ['p1', 'p2']);

      expect(page.items, hasLength(2));
      expect(one?['name']?.raw, 'Item');
      expect(many, hasLength(2));
      expect(source.queryCalls.single.table, 'products');
      expect(source.getOneCalls, [('products', 'p1')]);
      expect(source.batchGetCalls.single.$2, ['p1', 'p2']);
    },
  );

  test('every write is recorded, force and all', () async {
    final created = await source.create('products', _row('p3', name: 'New'));
    await source.update('products', 'p3', _row('p3', name: 'Renamed'));
    await source.delete('products', 'p3', force: true);
    await source.create('products', _row('p4'));
    await source.delete('products', 'p4');
    await source.restore('products', 'p4');

    expect(created['id']?.raw, 'p3');
    expect(source.createCalls.map((call) => call.$1), ['products', 'products']);
    expect(source.updateCalls.single.$2, 'p3');
    expect(source.deleteCalls, [
      ('products', 'p3', true),
      ('products', 'p4', false),
    ]);
    expect(source.restoreCalls, [('products', 'p4')]);
  });

  test('relations and aggregates are recorded', () async {
    await source.attach('products', 'p1', 'tags', const ['t1']);
    await source.detach('products', 'p1', 'tags', const ['t1']);
    final num total = await source.aggregate(
      const BeakAggregateSpec.count(table: 'products'),
    );

    expect(total, 2);
    expect(source.attachCalls.single.$3, 'tags');
    expect(source.detachCalls.single.$4, ['t1']);
    expect(source.aggregateCalls.single.table, 'products');
  });

  test('clearing forgets the calls, not the data', () async {
    await source.query(const BeakQuerySpec(table: 'products'));
    source.clearRecordedCalls();

    expect(source.queryCalls, isEmpty);
    expect(source.getOneCalls, isEmpty);
    expect(source.batchGetCalls, isEmpty);
    expect(source.createCalls, isEmpty);
    expect(source.updateCalls, isEmpty);
    expect(source.deleteCalls, isEmpty);
    expect(source.restoreCalls, isEmpty);
    expect(source.attachCalls, isEmpty);
    expect(source.detachCalls, isEmpty);
    expect(source.aggregateCalls, isEmpty);
    expect(await source.getOne('products', 'p1'), isNotNull);
  });

  test('a subclass can fail one operation and forward the rest', () async {
    final failing = _FailingUpdates(inner);

    expect(
      () => failing.update('products', 'p1', _row('p1')),
      throwsA(isA<BeakValidationException>()),
    );
    expect(await failing.getOne('products', 'p1'), isNotNull);
    expect(failing.getOneCalls, hasLength(1));
  });
}

/// The documented way to make one call fail: extend, override, and leave
/// everything else recording and forwarding.
final class _FailingUpdates extends BeakRecordingDataSource {
  _FailingUpdates(super.inner);

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) async =>
      throw const BeakValidationException('nope');
}
