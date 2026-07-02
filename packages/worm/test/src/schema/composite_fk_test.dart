/// Composite (multi-column) foreign-key DDL rendering and
/// metadata serialization.
library;

import 'package:test/test.dart';
import 'package:worm/src/schema/blueprint.dart';
import 'package:worm/src/schema/foreign_key_definition.dart';
import 'package:worm/src/schema/on_delete.dart';

void main() {
  group('Blueprint.foreignComposite()', () {
    test('renders multi-column FK referencing matching parent columns', () {
      final blueprint = Blueprint.create('t', (table) {
        table.foreignComposite(
          columns: <String>['a', 'b'],
          referencedColumns: <String>['x', 'y'],
          onTable: 'other',
          onDelete: OnDelete.cascade,
        );
      });
      final sql = blueprint.toSql();
      expect(
        sql,
        contains('FOREIGN KEY ("a", "b") REFERENCES "other"("x", "y")'),
      );
      expect(sql, contains('ON DELETE CASCADE'));
    });

    test('honors the ON DELETE action passed in', () {
      final blueprint = Blueprint.create('t', (table) {
        table.foreignComposite(
          columns: <String>['x'],
          referencedColumns: <String>['id'],
          onTable: 'parents',
          onDelete: OnDelete.setNull,
        );
      });
      expect(blueprint.toSql(), contains('ON DELETE SET NULL'));
    });

    test('single-column foreign() continues to render the old shape', () {
      final blueprint = Blueprint.create('t', (table) {
        table.foreign(column: 'user_id', references: 'id', onTable: 'users');
      });
      final sql = blueprint.toSql();
      expect(sql, contains('FOREIGN KEY ("user_id") REFERENCES "users"("id")'));
    });
  });

  group('ForeignKeyDefinition.toMap()', () {
    test('serializes the composite form with column lists', () {
      const fk = ForeignKeyDefinition.composite(
        columns: <String>['a', 'b'],
        referencedTable: 'other',
        referencedColumns: <String>['x', 'y'],
        onDelete: OnDelete.cascade,
      );
      expect(fk.toMap(), <String, Object?>{
        'columns': <String>['a', 'b'],
        'referencedTable': 'other',
        'referencedColumns': <String>['x', 'y'],
        'onDelete': 'cascade',
      });
    });

    test('serializes the single-column form as a one-entry list', () {
      final fk = ForeignKeyDefinition(
        column: 'user_id',
        referencedTable: 'users',
        referencedColumn: 'id',
      );
      expect(fk.toMap(), <String, Object?>{
        'columns': <String>['user_id'],
        'referencedTable': 'users',
        'referencedColumns': <String>['id'],
        'onDelete': 'restrict',
      });
    });
  });
}
