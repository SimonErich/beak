/// Partial-unique index DDL rendering via the schema builder.
library;

import 'package:test/test.dart';
import 'package:worm/src/schema/blueprint.dart';

void main() {
  group('Blueprint.index(unique: true, where: ...)', () {
    test('renders CREATE UNIQUE INDEX with the WHERE predicate', () {
      final blueprint = Blueprint.create('t', (table) {
        table.index(
          <String>['email'],
          unique: true,
          where: 'deleted_at IS NULL',
          name: 'idx',
        );
      });
      final sql = blueprint.toSql();
      expect(sql, contains('CREATE UNIQUE INDEX "idx"'));
      expect(sql, contains('WHERE deleted_at IS NULL'));
      expect(sql, contains('("email")'));
    });

    test('omits the WHERE clause when no predicate is supplied', () {
      final blueprint = Blueprint.create('t', (table) {
        table.index(<String>['email'], unique: true, name: 'idx');
      });
      final sql = blueprint.toSql();
      expect(sql, contains('CREATE UNIQUE INDEX "idx"'));
      expect(sql, isNot(contains('WHERE')));
    });

    test('non-unique partial index renders without the UNIQUE keyword', () {
      final blueprint = Blueprint.create('t', (table) {
        table.index(
          <String>['email'],
          where: 'deleted_at IS NULL',
          name: 'partial_idx',
        );
      });
      final sql = blueprint.toSql();
      expect(sql, contains('CREATE INDEX "partial_idx"'));
      expect(sql, isNot(contains('CREATE UNIQUE INDEX')));
      expect(sql, contains('WHERE deleted_at IS NULL'));
    });
  });
}
