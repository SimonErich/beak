import 'package:test/test.dart';
import 'package:worm/src/logging/query_log.dart';

void main() {
  group('QueryLog', () {
    test('renders adapter, statement, params, duration and rows', () {
      const log = QueryLog(
        statement: 'SELECT * FROM users WHERE id = ?',
        parameters: <Object?>[42],
        duration: Duration(microseconds: 123),
        rowCount: 1,
        adapter: 'TestAdapter',
        table: 'users',
      );

      expect(log.toString(), contains('SELECT * FROM users WHERE id = ?'));
      expect(log.toString(), contains('params=[42]'));
      expect(log.toString(), contains('123us, 1 rows'));
      expect(log.toString(), contains('table=users'));
      expect(log.toString(), contains('TestAdapter'));
    });

    test('omits params block when empty', () {
      const log = QueryLog(
        statement: 'DDL',
        parameters: <Object?>[],
        duration: Duration.zero,
        rowCount: 0,
        adapter: 'TestAdapter',
      );
      expect(log.toString(), isNot(contains('params=')));
    });
  });
}
