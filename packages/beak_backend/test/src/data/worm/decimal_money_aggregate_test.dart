import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

/// A ledger whose amounts are exact money: whole cents in an integer column,
/// read and written as `BeakDecimal`.
final class _LedgerModel extends BeakModel {
  const _LedgerModel();

  static const kind = BeakScalarField<String>(
    model: _LedgerModel(),
    column: _kind,
  );

  static const amount = BeakScalarField<BeakDecimal>(
    model: _LedgerModel(),
    column: _amount,
  );

  static const BeakColumn _kind = BeakStringColumn(key: 'kind', label: 'Kind');

  static const BeakColumn _amount = BeakIntColumn(
    key: 'amount',
    label: 'Amount',
    semantic: BeakSemantic.money(currency: 'EUR'),
  );

  @override
  String get table => 'ledger';

  @override
  String get displayColumnKey => 'kind';

  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'id', label: 'Id'),
    _kind,
    _amount,
  ];
}

const List<SchemaColumn> _schema = [
  SchemaColumn(name: 'id', type: ColumnType.integer, isPrimaryKey: true),
  SchemaColumn(name: 'kind', type: ColumnType.text),
  SchemaColumn(name: 'amount', type: ColumnType.integer),
];

/// Cents per row: 3 sales (10.05, 20.10, 0.35) and 1 refund (-5.00).
const List<(int, String, int)> _rows = [
  (1, 'sale', 1005),
  (2, 'sale', 2010),
  (3, 'sale', 35),
  (4, 'refund', -500),
];

Future<void> _seed(DatabaseAdapter adapter) async {
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'ledger', columns: _schema),
  );
  await adapter.insertMany(
    InsertManyDescriptor(
      table: 'ledger',
      rows: [
        for (final (id, kind, cents) in _rows)
          {'id': id, 'kind': kind, 'amount': cents},
      ],
    ),
  );
}

void main() {
  const ledger = _LedgerModel();
  final registry = BeakModelRegistry()..register(ledger);

  Future<void> exactMoneyAggregates(BeakDataSource source) async {
    expect(await _LedgerModel.amount.sum(source), BeakDecimal.parse('25.50'));
    expect(
      await source.aggregate(ledger.sumDecimal(_LedgerModel.amount)),
      2550,
    );
    expect(
      await _LedgerModel.amount.sum(
        source,
        filter: _LedgerModel.kind.eq('sale'),
      ),
      BeakDecimal.parse('30.50'),
    );
    expect(
      await _LedgerModel.amount.avg(source, rounding: BeakRounding.halfToEven),
      BeakDecimal.parse('6.38'),
    );
    expect(
      await _LedgerModel.amount.avg(source, rounding: BeakRounding.floor),
      BeakDecimal.parse('6.37'),
    );
  }

  Future<void> exactMoneySummaries(BeakSummaryDataSource source) async {
    final revenue = BeakSummaryMeasure.sumDecimal(
      'revenue',
      field: _LedgerModel.amount,
    );
    final byKind = await source.summary(
      ledger.summary(groupBy: _LedgerModel.kind, measures: [revenue]),
    );
    expect(
      {for (final row in byKind.rows) row.group.raw: row.decimalOf(revenue)},
      {
        'refund': BeakDecimal.parse('-5.00'),
        'sale': BeakDecimal.parse('30.50'),
      },
    );
    final total = await source.summary(ledger.summary(measures: [revenue]));
    expect(total.rows.single.decimalOf(revenue), BeakDecimal.parse('25.50'));
    expect(total.rows.single.valueOf(revenue), 2550);
  }

  group('InMemory adapter', () {
    late WormDataSource source;

    setUp(() async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      await _seed(adapter);
      source = WormDataSource(registry, adapter: adapter);
    });

    test('sums and averages exact money', () => exactMoneyAggregates(source));
    test('summarises exact money', () => exactMoneySummaries(source));
  });

  group('SQLite adapter', () {
    late WormDataSource source;

    setUp(() async {
      final adapter = SqliteAdapter.memory();
      await adapter.connect();
      addTearDown(adapter.disconnect);
      await _seed(adapter);
      source = WormDataSource(registry, adapter: adapter);
    });

    test('sums and averages exact money', () => exactMoneyAggregates(source));
    test('summarises exact money', () => exactMoneySummaries(source));
  });

  test('the HTTP API summarises and aggregates money the same way', () async {
    final adapter = InMemoryAdapter();
    await adapter.connect();
    await _seed(adapter);
    final handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: WormDataSource(registry, adapter: adapter),
          ),
        );
    Future<Object?> post(String path, Object body) async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/ledger/$path'),
          body: jsonEncode(body),
        ),
      );
      final decoded = jsonDecode(await response.readAsString());
      expect(response.statusCode, 200, reason: '$decoded');
      return decoded;
    }

    final revenue = BeakSummaryMeasure.sumDecimal(
      'revenue',
      field: _LedgerModel.amount,
    );
    final summary = BeakSummaryResult.fromJson(switch (await post(
      'summary',
      ledger.summary(measures: [revenue]).toJson(),
    )) {
      final Map<String, Object?> json => json,
      final Object? other => fail('Expected a JSON object, got $other.'),
    });
    expect(summary.rows.single.decimalOf(revenue), BeakDecimal.parse('25.50'));
    expect(
      await post('aggregate', ledger.sumDecimal(_LedgerModel.amount).toJson()),
      {'value': 2550},
    );
  });
}
