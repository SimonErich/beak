/// The [Schema] facade must carry a blueprint's indexes and foreign keys
/// through to the adapter.
///
/// It used to forward columns only, so every `table.foreign(...)` and every
/// `table.unique(...)` written in a migration was silently discarded: the
/// migration ran, the table appeared, and the database enforced nothing.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/exception/schema_definition_exception.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/schema/column_type.dart';
import 'package:worm/src/schema/on_delete.dart';
import 'package:worm/src/schema/schema_facade.dart';

import '../logging/_test_adapters.dart';

/// Captures the descriptors the facade sends, without executing them.
final class _CapturingAdapter extends DelegatingAdapter {
  _CapturingAdapter() : super(InMemoryAdapter());

  final List<SchemaDescriptor> descriptors = <SchemaDescriptor>[];

  @override
  Future<void> executeSchema(SchemaDescriptor descriptor) async =>
      descriptors.add(descriptor);
}

void main() {
  late _CapturingAdapter adapter;
  late Schema schema;

  setUp(() {
    adapter = _CapturingAdapter();
    schema = Schema.forRunner(adapter);
  });

  SchemaDescriptor lastDescriptor() => adapter.descriptors.last;

  group('Schema.create', () {
    test('carries a single-column foreign key through', () async {
      await schema.create('products', (table) {
        table
          ..uuid('id').primary()
          ..uuid('category_id').makeNullable()
          ..foreign(
            column: 'category_id',
            references: 'id',
            onTable: 'categories',
            onDelete: OnDelete.setNull,
          );
      });

      final key = lastDescriptor().foreignKeys.single;
      expect(key.columns, <String>['category_id']);
      expect(key.referencedTable, 'categories');
      expect(key.referencedColumns, <String>['id']);
      expect(key.onDelete, OnDelete.setNull);
    });

    test('carries a composite foreign key through with both lists', () async {
      await schema.create('order_lines', (table) {
        table
          ..uuid('order_id')
          ..uuid('tenant_id')
          ..foreignComposite(
            columns: <String>['order_id', 'tenant_id'],
            referencedColumns: <String>['id', 'tenant_id'],
            onTable: 'orders',
            onDelete: OnDelete.cascade,
          );
      });

      final key = lastDescriptor().foreignKeys.single;
      expect(key.columns, <String>['order_id', 'tenant_id']);
      expect(key.referencedColumns, <String>['id', 'tenant_id']);
      expect(key.onDelete, OnDelete.cascade);
    });

    test('carries indexes through, unique flag intact', () async {
      await schema.create('product_tag', (table) {
        table
          ..uuid('product_id')
          ..uuid('tag_id')
          ..unique(<String>['product_id', 'tag_id'])
          ..index(<String>['tag_id']);
      });

      final indexes = lastDescriptor().indexes;
      expect(indexes, hasLength(2));
      expect(indexes.where((index) => index.unique).single.columns, <String>[
        'product_id',
        'tag_id',
      ]);
    });

    test('a table with no constraints reports empty lists', () async {
      await schema.create('notes', (table) => table.uuid('id').primary());

      expect(lastDescriptor().foreignKeys, isEmpty);
      expect(lastDescriptor().indexes, isEmpty);
    });
  });

  group('Schema.create carries the column sizing', () {
    test('a declared length and precision reach the descriptor', () async {
      // A VARCHAR(120) that arrives as a bare VARCHAR is a column the
      // database never got told about, and it looks identical in the
      // migration source.
      await schema.create('products', (table) {
        table
          ..string('sku', length: 40)
          ..decimal('price', precision: 10, scale: 2);
      });

      final columns = {
        for (final column in lastDescriptor().columns) column.name: column,
      };
      expect(columns['sku']!.length, 40);
      expect(columns['price']!.precision, 10);
      expect(columns['price']!.scale, 2);
    });

    test('a column-level unique becomes a unique index', () async {
      // One representation downstream, so the compilers do not each have to
      // know two ways of saying the same thing.
      await schema.create(
        'users',
        (table) => table.string('email')..makeUnique(),
      );

      final index = lastDescriptor().indexes.single;
      expect(index.unique, isTrue);
      expect(index.columns, <String>['email']);
    });

    test('change() inside a create is rejected', () {
      expect(
        () => schema.create('products', (table) {
          table.string('name').change();
        }),
        throwsA(isA<SchemaDefinitionException>()),
      );
    });
  });

  group('Schema.alter', () {
    test('carries added foreign keys through as an ordered step', () async {
      await schema.alter('products', (table) {
        table.foreign(
          column: 'brand_id',
          references: 'id',
          onTable: 'brands',
          onDelete: OnDelete.restrict,
        );
      });

      expect(lastDescriptor().operation, SchemaOperation.alter);
      final step = lastDescriptor().alterations.single;
      expect(step, isA<SchemaAddForeignKey>());
      if (step case SchemaAddForeignKey(:final foreignKey)) {
        expect(foreignKey.referencedTable, 'brands');
      }
    });

    test(
      'orders steps so nothing references what does not exist yet',
      () async {
        // Declaration order here is deliberately the wrong order.
        await schema.alter('products', (table) {
          table
            ..index(<String>['status'], name: 'products_status_idx')
            ..string('status', length: 20)
            ..dropColumn('legacy')
            ..dropIndex('products_legacy_idx');
        });

        expect(
          lastDescriptor().alterations.map((a) => a.runtimeType.toString()),
          <String>[
            'SchemaDropIndex',
            'SchemaDropColumn',
            'SchemaAddColumn',
            'SchemaAddIndex',
          ],
        );
      },
    );

    test('carries dropColumn through — it used to be a silent no-op', () async {
      await schema.alter('products', (table) => table.dropColumn('legacy'));

      final step = lastDescriptor().alterations.single;
      expect(step, isA<SchemaDropColumn>());
      if (step case SchemaDropColumn(:final column)) {
        expect(column, 'legacy');
      }
    });

    test('change() becomes a change step carrying the end state', () async {
      await schema.alter('products', (table) {
        table.string('bio', length: 500)
          ..makeNullable()
          ..change();
      });

      final step = lastDescriptor().alterations.single;
      expect(step, isA<SchemaChangeColumn>());
      if (step case SchemaChangeColumn(:final column)) {
        expect(column.length, 500);
        expect(column.nullable, isTrue);
      }
    });

    test('dropping and adding one column in one alter is rejected', () {
      // No ordering makes that coherent, so it fails here rather than
      // producing SQL whose meaning depends on the compiler.
      expect(
        () => schema.alter('products', (table) {
          table
            ..dropColumn('status')
            ..string('status');
        }),
        throwsA(isA<SchemaDefinitionException>()),
      );
    });
  });

  group('SchemaForeignKey.toMap', () {
    test('serializes every field, action by name', () {
      const key = SchemaForeignKey(
        columns: <String>['a', 'b'],
        referencedTable: 'other',
        referencedColumns: <String>['x', 'y'],
        onDelete: OnDelete.cascade,
        name: 'my_fk',
      );

      expect(key.toMap(), <String, Object?>{
        'columns': <String>['a', 'b'],
        'referencedTable': 'other',
        'referencedColumns': <String>['x', 'y'],
        'onDelete': 'cascade',
        'name': 'my_fk',
      });
    });

    test('an unnamed key omits the name rather than emitting null', () {
      const key = SchemaForeignKey(
        columns: <String>['a'],
        referencedTable: 'other',
        referencedColumns: <String>['id'],
      );

      expect(key.toMap().containsKey('name'), isFalse);
      expect(key.toMap()['onDelete'], 'restrict');
    });
  });

  group('SchemaDescriptor.toMap', () {
    test('includes foreign keys so descriptors log and compare fully', () {
      const descriptor = SchemaDescriptor.createTable(
        table: 'products',
        columns: <SchemaColumn>[
          SchemaColumn(name: 'category_id', type: ColumnType.uuid),
        ],
        foreignKeys: <SchemaForeignKey>[
          SchemaForeignKey(
            columns: <String>['category_id'],
            referencedTable: 'categories',
            referencedColumns: <String>['id'],
          ),
        ],
      );

      expect(descriptor.toMap()['foreignKeys'], <Map<String, Object?>>[
        <String, Object?>{
          'columns': <String>['category_id'],
          'referencedTable': 'categories',
          'referencedColumns': <String>['id'],
          'onDelete': 'restrict',
        },
      ]);
    });
  });
}
