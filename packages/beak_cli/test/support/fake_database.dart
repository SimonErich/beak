/// A Postgres stand-in for introspection tests.
///
/// Canned rows rather than a server: every consumer of
/// [PostgresIntrospector] wants the same five result sets, and a shared
/// fixture is the difference between one schema to keep honest and three.
library;

import 'beak_cli_internals.dart';

/// Canned `information_schema` rows, so introspection is tested without a
/// server. The shapes match what Postgres actually returns.
final class FakeDatabase {
  FakeDatabase({
    this.columns = const [],
    this.foreignKeys = const [],
    this.primaryKeys = const [],
    this.enums = const [],
    this.indexes = const [],
  });

  final List<Map<String, Object?>> columns;
  final List<Map<String, Object?>> foreignKeys;
  final List<Map<String, Object?>> primaryKeys;
  final List<Map<String, Object?>> enums;
  final List<Map<String, Object?>> indexes;

  Future<List<Map<String, Object?>>> query(String sql) async {
    if (sql.contains('pg_enum')) {
      return enums;
    }
    if (sql.contains('pg_index')) {
      return indexes;
    }
    if (sql.contains("contype = 'f'")) {
      return foreignKeys;
    }
    if (sql.contains("contype = 'p'")) {
      return primaryKeys;
    }
    return columns;
  }
}

Map<String, Object?> column(
  String table,
  String name,
  String type, {
  bool nullable = true,
  int? maxLength,
  Object? defaultValue,
  String? udt,
}) => {
  'table_name': table,
  'column_name': name,
  'data_type': type,
  'is_nullable': nullable ? 'YES' : 'NO',
  'character_maximum_length': maxLength,
  'column_default': defaultValue,
  'udt_name': udt ?? type,
};

/// A small shop schema: two resources, a pivot, an enum, and a secret.
FakeDatabase shopDatabase() => FakeDatabase(
  columns: [
    column('categories', 'id', 'uuid', nullable: false),
    column(
      'categories',
      'name',
      'character varying',
      nullable: false,
      maxLength: 60,
    ),
    column('products', 'id', 'uuid', nullable: false),
    column(
      'products',
      'name',
      'character varying',
      nullable: false,
      maxLength: 255,
    ),
    column(
      'products',
      'sku',
      'character varying',
      nullable: false,
      maxLength: 40,
    ),
    column('products', 'description', 'text'),
    column('products', 'price', 'numeric', nullable: false),
    column('products', 'stock', 'integer', nullable: false, defaultValue: '0'),
    column(
      'products',
      'status',
      'USER-DEFINED',
      nullable: false,
      udt: 'product_status',
    ),
    column('products', 'image', 'character varying', maxLength: 255),
    column('products', 'spec_file', 'character varying', maxLength: 255),
    column('products', 'category_id', 'uuid'),
    column('products', 'created_at', 'timestamp with time zone'),
    column('products', 'updated_at', 'timestamp with time zone'),
    column('products', 'deleted_at', 'timestamp with time zone'),
    column('tags', 'id', 'uuid', nullable: false),
    column('tags', 'name', 'character varying', nullable: false),
    column('product_tag', 'product_id', 'uuid', nullable: false),
    column('product_tag', 'tag_id', 'uuid', nullable: false),
    column('users', 'id', 'uuid', nullable: false),
    column('users', 'email', 'character varying', nullable: false),
    column('users', 'password_hash', 'character varying', nullable: false),
    column('worm_migrations', 'id', 'integer', nullable: false),
  ],
  foreignKeys: [
    {
      'table_name': 'products',
      'column_name': 'category_id',
      'referenced_table': 'categories',
    },
    {
      'table_name': 'product_tag',
      'column_name': 'product_id',
      'referenced_table': 'products',
    },
    {
      'table_name': 'product_tag',
      'column_name': 'tag_id',
      'referenced_table': 'tags',
    },
  ],
  primaryKeys: [
    for (final table in ['categories', 'products', 'tags', 'users'])
      {'table_name': table, 'column_name': 'id'},
  ],
  enums: [
    {'enum_name': 'product_status', 'enum_value': 'draft'},
    {'enum_name': 'product_status', 'enum_value': 'published'},
  ],
  indexes: [
    {'table_name': 'products', 'column_name': 'name', 'indisunique': false},
    {'table_name': 'products', 'column_name': 'sku', 'indisunique': true},
  ],
);

Future<List<IntrospectedTable>> readShop() =>
    PostgresIntrospector(shopDatabase().query).read();

IntrospectedTable tableNamed(List<IntrospectedTable> tables, String name) =>
    tables.firstWhere((table) => table.name == name);
