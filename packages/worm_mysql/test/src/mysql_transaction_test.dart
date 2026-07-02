/// Live-database transaction and savepoint tests for [MysqlAdapter].
///
/// Gated by `MYSQL_URL`. Skipped gracefully when absent.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_mysql/worm_mysql.dart';

PredicateTree _idEq(int id) =>
    LeafNode(Predicate(fieldName: 'id', operator: Operator.eq, value: id));

void main() {
  final url = Platform.environment['MYSQL_URL'];
  if (url == null || url.isEmpty) {
    test(
      'MysqlAdapter transaction suite skipped — MYSQL_URL unset',
      () {},
      skip:
          'Set MYSQL_URL (mysql://user:pass@host:port/db) to '
          'run transaction + savepoint integration tests.',
    );
    return;
  }

  group('MysqlAdapter transactions', () {
    late MysqlAdapter adapter;

    setUp(() async {
      adapter = MysqlAdapter(pool: MysqlConnectionPool.fromUri(url));
      await adapter.executeSchema(
        const SchemaDescriptor.dropTable(table: 'tx_sample', ifExists: true),
      );
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(
          table: 'tx_sample',
          columns: <SchemaColumn>[
            SchemaColumn(
              name: 'id',
              type: ColumnType.integer,
              isPrimaryKey: true,
            ),
            SchemaColumn(name: 'label', type: ColumnType.text),
          ],
        ),
      );
    });

    tearDown(() async {
      await adapter.executeSchema(
        const SchemaDescriptor.dropTable(table: 'tx_sample', ifExists: true),
      );
      await adapter.disconnect();
    });

    test(
      'throwing inside transaction rolls the outer transaction back',
      () async {
        await expectLater(
          adapter.transaction((tx) async {
            await tx.insert(
              const InsertDescriptor(
                table: 'tx_sample',
                values: <String, Object?>{'id': 1, 'label': 'rolled'},
              ),
            );
            throw StateError('abort');
          }),
          throwsA(isA<StateError>()),
        );

        final row = await adapter.selectOne(
          QueryDescriptor(table: 'tx_sample', where: _idEq(1)),
        );
        expect(row, isNull);
      },
    );

    test(
      'nested savepoint: outer persists, inner-rolled-back does not',
      () async {
        await adapter.transaction((tx) async {
          await tx.insert(
            const InsertDescriptor(
              table: 'tx_sample',
              values: <String, Object?>{'id': 1, 'label': 'outer'},
            ),
          );
          await expectLater(
            tx.transaction((inner) async {
              await inner.insert(
                const InsertDescriptor(
                  table: 'tx_sample',
                  values: <String, Object?>{'id': 2, 'label': 'inner'},
                ),
              );
              throw StateError('rollback inner');
            }),
            throwsA(isA<StateError>()),
          );
        });

        final rows = await adapter.select(
          const QueryDescriptor(
            table: 'tx_sample',
            orderBy: <SortClause>[SortClause('id')],
          ),
        );
        expect(rows, hasLength(1));
        expect(rows.first['id'], 1);
        expect(rows.first['label'], 'outer');
      },
    );

    test(
      'nested savepoint release keeps both outer and inner writes',
      () async {
        await adapter.transaction((tx) async {
          await tx.insert(
            const InsertDescriptor(
              table: 'tx_sample',
              values: <String, Object?>{'id': 1, 'label': 'outer'},
            ),
          );
          await tx.transaction((inner) async {
            await inner.insert(
              const InsertDescriptor(
                table: 'tx_sample',
                values: <String, Object?>{'id': 2, 'label': 'inner'},
              ),
            );
          });
        });

        final rows = await adapter.select(
          const QueryDescriptor(
            table: 'tx_sample',
            orderBy: <SortClause>[SortClause('id')],
          ),
        );
        expect(rows, hasLength(2));
      },
    );

    test(
      'unique constraint violation maps to UniqueConstraintException',
      () async {
        await adapter.executeSchema(
          const SchemaDescriptor.dropTable(table: 'uniq_t', ifExists: true),
        );
        await adapter.executeSchema(
          const SchemaDescriptor.createTable(
            table: 'uniq_t',
            columns: <SchemaColumn>[
              SchemaColumn(
                name: 'id',
                type: ColumnType.integer,
                isPrimaryKey: true,
              ),
            ],
          ),
        );
        await adapter.insert(
          const InsertDescriptor(
            table: 'uniq_t',
            values: <String, Object?>{'id': 1},
          ),
        );
        await expectLater(
          adapter.insert(
            const InsertDescriptor(
              table: 'uniq_t',
              values: <String, Object?>{'id': 1},
            ),
          ),
          throwsA(isA<UniqueConstraintException>()),
        );
        await adapter.executeSchema(
          const SchemaDescriptor.dropTable(table: 'uniq_t', ifExists: true),
        );
      },
    );
  });
}
