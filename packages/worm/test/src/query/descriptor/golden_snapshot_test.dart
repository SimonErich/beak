// Golden snapshot tests for descriptor serialization.
//
// Verifies that QueryDescriptor / InsertDescriptor / InsertManyDescriptor
// / UpdateDescriptor / DeleteDescriptor / SchemaDescriptor produce stable
// JSON representations across 13 distinct query shapes.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/worm.dart';

const _encoder = JsonEncoder.withIndent('  ');

/// Compares [actual] against a `.golden` file.
///
/// Set `UPDATE_GOLDENS=true` to regenerate.
void expectGolden(String name, Map<String, Object?> actual) {
  final json = _encoder.convert(actual);
  final file = File('test/goldens/$name.golden');
  final update = Platform.environment['UPDATE_GOLDENS'] == 'true';
  if (update || !file.existsSync()) {
    file.writeAsStringSync('$json\n');
  }
  final expected = file.readAsStringSync().trimRight();
  expect(json, equals(expected));
}

// Shared field definitions for all golden tests.
const _id = Field<String>('id');
const _name = StringField('name');
const _age = ComparableField<int>('age');
const _active = Field<bool>('is_active');
const _score = ComparableField<int>('score');
const _role = StringField('role');

void main() {
  group('Golden snapshots', () {
    // Shape 1: Simple select all.
    test('01_select_all', () {
      const descriptor = QueryDescriptor(table: 'users');
      expectGolden('01_select_all', descriptor.toMap());
    });

    // Shape 2: Select with single WHERE eq.
    test('02_select_where_eq', () {
      final descriptor = QueryDescriptor(
        table: 'users',
        where: _name.eq('Alice'),
      );
      expectGolden('02_select_where_eq', descriptor.toMap());
    });

    // Shape 3: Select with AND conditions.
    test('03_select_where_and', () {
      final descriptor = QueryDescriptor(
        table: 'users',
        where: _age.gte(18).and(_active.eq(true)),
      );
      expectGolden('03_select_where_and', descriptor.toMap());
    });

    // Shape 4: Select with OR conditions.
    test('04_select_where_or', () {
      final descriptor = QueryDescriptor(
        table: 'users',
        where: _role.eq('admin').or(_role.eq('mod')),
      );
      expectGolden('04_select_where_or', descriptor.toMap());
    });

    // Shape 5: Select with NOT condition.
    test('05_select_where_not', () {
      final descriptor = QueryDescriptor(
        table: 'users',
        where: _active.eq(false).not(),
      );
      expectGolden('05_select_where_not', descriptor.toMap());
    });

    // Shape 6: Select with grouped conditions.
    test('06_select_where_grouped', () {
      final orGroup = _name.eq('Alice').or(_name.eq('Bob')).group();
      final descriptor = QueryDescriptor(
        table: 'users',
        where: orGroup.and(_age.gte(18)),
      );
      expectGolden('06_select_where_grouped', descriptor.toMap());
    });

    // Shape 7: Select with ORDER BY and LIMIT.
    test('07_select_order_limit', () {
      const descriptor = QueryDescriptor(
        table: 'users',
        columns: ['name', 'email'],
        orderBy: [SortClause('created_at', direction: SortDirection.desc)],
        limit: 10,
        offset: 20,
      );
      expectGolden('07_select_order_limit', descriptor.toMap());
    });

    // Shape 8: Select with BETWEEN and DISTINCT.
    test('08_select_between_distinct', () {
      final descriptor = QueryDescriptor(
        table: 'users',
        columns: ['name'],
        where: _score.between(80, 100),
        distinct: true,
      );
      expectGolden('08_select_between_distinct', descriptor.toMap());
    });

    // Shape 9: Insert single row.
    test('09_insert', () {
      const descriptor = InsertDescriptor(
        table: 'users',
        values: {'name': 'Alice', 'email': 'alice@example.com', 'age': 30},
      );
      expectGolden('09_insert', descriptor.toMap());
    });

    // Shape 10: Update with WHERE clause.
    test('10_update_where', () {
      final descriptor = UpdateDescriptor(
        table: 'users',
        values: {'name': 'Bob', 'age': 31},
        where: _id.eq('abc-123'),
      );
      expectGolden('10_update_where', descriptor.toMap());
    });

    // Shape 11: Delete with complex WHERE.
    test('11_delete_complex_where', () {
      final descriptor = DeleteDescriptor(
        table: 'users',
        where: _active.eq(false).and(_age.lt(18)).or(_role.eq('banned')),
      );
      expectGolden('11_delete_complex_where', descriptor.toMap());
    });

    // Shape 12: Insert many rows.
    test('12_insert_many', () {
      const descriptor = InsertManyDescriptor(
        table: 'users',
        rows: [
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
          {'name': 'Charlie', 'age': 35},
        ],
      );
      expectGolden('12_insert_many', descriptor.toMap());
    });

    // Shape 13: Schema create table.
    test('13_schema_create', () {
      const descriptor = SchemaDescriptor(
        table: 'users',
        operation: SchemaOperation.create,
        columns: [
          SchemaColumn(name: 'id', type: ColumnType.uuid, isPrimaryKey: true),
          SchemaColumn(name: 'name', type: ColumnType.string),
          SchemaColumn(name: 'email', type: ColumnType.string),
          SchemaColumn(name: 'bio', type: ColumnType.text, nullable: true),
        ],
        indexes: [
          SchemaIndex(
            name: 'idx_users_email',
            columns: ['email'],
            unique: true,
          ),
        ],
      );
      expectGolden('13_schema_create', descriptor.toMap());
    });
  });
}
