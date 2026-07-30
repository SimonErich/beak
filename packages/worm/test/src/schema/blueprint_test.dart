// ignore_for_file: cascade_invocations
//
// This test uses sequential `table.method(...)` calls to set up
// blueprint columns. Rewriting as cascades would harm readability
// for a 27-column type-coverage matrix.

import 'package:test/test.dart';
import 'package:worm/worm.dart';

/// [Blueprint] is a builder, not a renderer.
///
/// It used to carry its own `toSql()` — a second, Postgres-flavoured DDL
/// renderer living in the dialect-neutral core, free to drift from the three
/// compilers that actually run. The rendering now belongs to the compilers,
/// one per dialect, each with its own exhaustive `ColumnType` mapping test.
/// What is left here is what a blueprint is for: turning a build callback
/// into a described table.
void main() {
  group('Blueprint create', () {
    test('captures columns with their modifiers', () {
      final blueprint = Blueprint.create('users', (table) {
        table.idUuid();
        table.string('email').makeUnique();
        table.integer('age').makeNullable();
        table.boolean('active').withDefault(true);
      });

      expect(blueprint.operation, BlueprintOperation.create);
      expect(blueprint.tableName, 'users');
      final columns = {
        for (final column in blueprint.table.columns) column.name: column,
      };
      expect(columns['id']?.isPrimaryKey, isTrue);
      expect(columns['email']?.unique, isTrue);
      expect(columns['age']?.nullable, isTrue);
      expect(columns['active']?.defaultValue, true);
      expect(columns['email']?.type, ColumnType.string);
    });
  });

  group('Blueprint type coverage', () {
    test('every column factory reaches the table definition', () {
      final blueprint = Blueprint.create('all_types', (table) {
        table.string('a');
        table.smallInteger('b');
        table.integer('c');
        table.bigInteger('d');
        table.decimal('e');
        table.boolean('f');
        table.date('g');
        table.dateTime('h');
        table.uuid('i');
        table.json('j');
        table.jsonb('k');
        table.text('l');
        table.binary('m');
        table.doublePrecision('n');
        table.enumColumn('o', <String>['x', 'y']);
        table.tsvector('p');
        table.time('q');
        table.interval('r');
        table.inet('s');
        table.macaddr('t');
        table.point('u');
        table.line('v');
        table.box('w');
        table.money('x');
        table.bit('y');
        table.xml('z');
        table.array('aa', ColumnType.integer);
      });

      expect(blueprint.table.columns, hasLength(27));
      final byName = {
        for (final column in blueprint.table.columns) column.name: column,
      };
      expect(byName['a']?.type, ColumnType.string);
      expect(byName['b']?.type, ColumnType.smallInteger);
      expect(byName['e']?.type, ColumnType.decimal);
      expect(byName['o']?.enumValues, <String>['x', 'y']);
      expect(byName['aa']?.elementType, ColumnType.integer);
    });
  });

  group('Blueprint alter and drop', () {
    test('alter records added and dropped columns', () {
      final blueprint = Blueprint.alter('users', (table) {
        table.string('bio');
        table.dropColumn('legacy');
      });

      expect(blueprint.operation, BlueprintOperation.alter);
      expect(blueprint.table.columns.single.name, 'bio');
      expect(blueprint.table.droppedColumns, <String>['legacy']);
    });

    test('drop carries nothing but the table name', () {
      final blueprint = Blueprint.drop('users');

      expect(blueprint.operation, BlueprintOperation.drop);
      expect(blueprint.tableName, 'users');
      expect(blueprint.table.columns, isEmpty);
    });
  });

  group('Blueprint indexes and foreign keys', () {
    test('a unique and a partial index over one column are two indexes', () {
      final blueprint = Blueprint.create('users', (table) {
        table.uuid('id').primary();
        table.string('email');
        table.unique(<String>['email']);
        // A partial index over the same column is a different index, so it
        // needs its own name — both would otherwise auto-derive
        // `users_email_idx` and no database accepts two under one name.
        table.index(
          <String>['email'],
          name: 'users_email_present_idx',
          where: 'email IS NOT NULL',
        );
      });

      final indexes = blueprint.table.indexes;
      expect(indexes, hasLength(2));
      expect(indexes.first.unique, isTrue);
      expect(indexes.last.name, 'users_email_present_idx');
      expect(indexes.last.partialWhere, 'email IS NOT NULL');
    });

    test('a foreign key keeps its delete action', () {
      final blueprint = Blueprint.create('posts', (table) {
        table.uuid('id').primary();
        table.uuid('user_id');
        table.foreign(
          column: 'user_id',
          references: 'id',
          onTable: 'users',
          onDelete: OnDelete.cascade,
        );
      });

      final foreignKey = blueprint.table.foreignKeys.single;
      expect(foreignKey.columns, <String>['user_id']);
      expect(foreignKey.referencedTable, 'users');
      expect(foreignKey.referencedColumns, <String>['id']);
      expect(foreignKey.onDelete, OnDelete.cascade);
    });
  });
}
