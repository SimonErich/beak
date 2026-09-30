import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../test_tools/serverpod_test_tools.dart';
import 'support/zone_bound_adapter.dart';

/// What the session adapter does with the errors a real Postgres raises. The
/// unit suite proves the mapping against a fake database; this proves the
/// driver hands Serverpod the SQLSTATE the mapping keys on.
void main() {
  withServerpod(
    'Given the session adapter on Serverpod\'s database',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, endpoints) {
      ZoneBoundAdapter adapterWith({int? statementTimeoutInSeconds}) =>
          ZoneBoundAdapter(
            sessionBuilder.build(),
            ServerpodSessionAdapter(
              statementTimeoutInSeconds: statementTimeoutInSeconds,
            ),
          );

      test(
        'a statement over its timeout is a QueryException that says so',
        () async {
          final adapter = adapterWith(statementTimeoutInSeconds: 1);

          await expectLater(
            adapter.rawQuery('SELECT pg_sleep(4)', const []),
            throwsA(
              isA<QueryException>().having(
                (error) => error.message,
                'message',
                contains('timeout'),
              ),
            ),
          );
        },
        timeout: const Timeout(Duration(minutes: 1)),
      );

      test('the connection is still usable after a timeout', () async {
        final adapter = adapterWith(statementTimeoutInSeconds: 1);
        await expectLater(
          adapter.rawQuery('SELECT pg_sleep(4)', const []),
          throwsA(isA<QueryException>()),
        );

        final rows = await adapter.rawQuery('SELECT 1 AS one', const []);

        expect(rows.single['one'], 1);
      }, timeout: const Timeout(Duration(minutes: 1)));

      test(
        'a unique violation at any depth is a UniqueConstraintException',
        () async {
          final adapter = adapterWith();
          // A real table, not TEMP: the pool hands the transaction another
          // connection than the one that created it.
          await adapter.rawExecute(
            'DROP TABLE IF EXISTS beak_unique_probe',
            const [],
          );
          await adapter.rawExecute(
            'CREATE TABLE beak_unique_probe (code text UNIQUE)',
            const [],
          );
          addTearDown(
            () => adapter.rawExecute('DROP TABLE beak_unique_probe', const []),
          );

          Future<void> insertTwice(DatabaseAdapter target) async {
            await target.rawExecute(
              'INSERT INTO beak_unique_probe (code) VALUES (\$1)',
              ['a'],
            );
            await target.rawExecute(
              'INSERT INTO beak_unique_probe (code) VALUES (\$1)',
              ['a'],
            );
          }

          await expectLater(
            insertTwice(adapter),
            throwsA(isA<UniqueConstraintException>()),
          );
          await expectLater(
            adapter.transaction(insertTwice),
            throwsA(isA<UniqueConstraintException>()),
          );
        },
      );
    },
  );
}
