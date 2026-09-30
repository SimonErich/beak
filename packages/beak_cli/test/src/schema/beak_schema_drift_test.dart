import '../../support/beak_cli_internals.dart';
import 'package:test/test.dart';

/// The `products` table as the schema class describes it.
BeakSchemaIr productSchema({
  List<BeakColumnIr> columns = const [],
  List<BeakRelationIr> relations = const [],
  bool softDeletes = false,
  bool timestamps = false,
  bool managesSchema = true,
}) => BeakSchemaIr(
  className: 'Product',
  table: 'products',
  libraryPath: 'models/product.dart',
  columns: [column('name'), ...columns],
  relations: relations,
  displayColumnKey: 'name',
  softDeletes: softDeletes,
  timestamps: timestamps,
  managesSchema: managesSchema,
);

/// A declared string column named [key].
BeakColumnIr column(String key) => BeakColumnIr(
  fieldName: key,
  columnKey: key,
  label: key,
  kind: BeakColumnKind.string,
  isRequired: false,
  arguments: const {},
);

/// A declared belongs-to over [foreignKey].
BeakRelationIr belongsTo(String field, String foreignKey) => BeakRelationIr(
  fieldName: field,
  key: field,
  label: field,
  kind: BeakRelationKind.belongsTo,
  relatedSchema: 'Category',
  foreignKey: foreignKey,
  arguments: const {},
);

/// The `products` table as the database has it.
IntrospectedTable productTable(List<String> columns) => IntrospectedTable(
  name: 'products',
  columns: [
    for (final name in columns)
      IntrospectedColumn(name: name, dataType: 'text', isNullable: true),
  ],
  foreignKeys: const [],
  primaryKey: 'id',
);

/// The rendered messages of the drift between [schemas] and [tables].
///
/// The comparison returns structured drift so the migration generator can
/// switch on it; these assertions are about what a reader is told.
List<String> messagesOf({
  required List<BeakSchemaIr> schemas,
  required List<IntrospectedTable> tables,
}) => [
  for (final drift in beakSchemaDrift(schemas: schemas, tables: tables))
    drift.message,
];

void main() {
  group('a table the database does not have', () {
    test('is named with the class that declares it', () {
      expect(messagesOf(schemas: [productSchema()], tables: const []), [
        'Product declares table "products", which the database does not have',
      ]);
    });

    test('does not also report every one of its columns', () {
      final drift = messagesOf(
        schemas: [
          productSchema(columns: [column('sku'), column('price')]),
        ],
        tables: const [],
      );
      expect(drift, hasLength(1));
    });
  });

  group('a column', () {
    test('the schema declares and the database lacks is drift', () {
      expect(
        messagesOf(
          schemas: [
            productSchema(columns: [column('stock')]),
          ],
          tables: [
            productTable(['id', 'name']),
          ],
        ),
        [
          'products.stock is declared by Product.stock but missing from the '
              'database',
        ],
      );
    });

    test('the database has and the schema lacks is drift too', () {
      expect(
        messagesOf(
          schemas: [productSchema()],
          tables: [
            productTable(['id', 'name', 'legacy_sku']),
          ],
        ),
        [
          'products.legacy_sku is in the database but Product does not declare '
              'it',
        ],
      );
    });

    test('is not reported in either direction when they agree', () {
      expect(
        messagesOf(
          schemas: [
            productSchema(columns: [column('stock')]),
          ],
          tables: [
            productTable(['id', 'name', 'stock']),
          ],
        ),
        isEmpty,
      );
    });

    test('the primary key is accounted for without being declared', () {
      expect(
        messagesOf(
          schemas: [productSchema()],
          tables: [
            productTable(['id', 'name']),
          ],
        ),
        isEmpty,
      );
    });
  });

  group('columns a schema implies rather than declares', () {
    test('a belongs-to key is checked', () {
      expect(
        messagesOf(
          schemas: [
            productSchema(relations: [belongsTo('category', 'category_id')]),
          ],
          tables: [
            productTable(['id', 'name']),
          ],
        ),
        [
          'products.category_id backs Product.category but is missing from '
              'the database',
        ],
      );
    });

    test('and is not then reported as an undeclared column', () {
      expect(
        messagesOf(
          schemas: [
            productSchema(relations: [belongsTo('category', 'category_id')]),
          ],
          tables: [
            productTable(['id', 'name', 'category_id']),
          ],
        ),
        isEmpty,
      );
    });

    test('soft deletes need deleted_at', () {
      expect(
        messagesOf(
          schemas: [productSchema(softDeletes: true)],
          tables: [
            productTable(['id', 'name']),
          ],
        ),
        ['products soft-deletes but the database has no deleted_at column'],
      );
    });

    test('timestamps need both stamps, and each is named', () {
      expect(
        messagesOf(
          schemas: [productSchema(timestamps: true)],
          tables: [
            productTable(['id', 'name', 'created_at']),
          ],
        ),
        ['products keeps timestamps but the database has no updated_at column'],
      );
    });
  });

  group('a table another system migrates', () {
    test('may carry columns the schema knows nothing about', () {
      expect(
        messagesOf(
          schemas: [productSchema(managesSchema: false)],
          tables: [
            productTable(['id', 'name', 'billing_account_ref']),
          ],
        ),
        isEmpty,
      );
    });

    test('but a column the schema declares must still be there', () {
      expect(
        messagesOf(
          schemas: [
            productSchema(managesSchema: false, columns: [column('stock')]),
          ],
          tables: [
            productTable(['id', 'name']),
          ],
        ),
        hasLength(1),
      );
    });
  });

  group('a pivot table', () {
    /// `Product.tags`, with the pivot name left to be derived.
    const tags = BeakRelationIr(
      fieldName: 'tags',
      key: 'tags',
      label: 'Tags',
      kind: BeakRelationKind.belongsToMany,
      relatedSchema: 'Tag',
      arguments: {},
    );
    final tagSchema = BeakSchemaIr(
      className: 'Tag',
      table: 'tags',
      libraryPath: 'models/tag.dart',
      columns: [column('name')],
      relations: const [],
      displayColumnKey: 'name',
      softDeletes: false,
      timestamps: false,
      managesSchema: true,
    );
    const tagTable = IntrospectedTable(
      name: 'tags',
      columns: [
        IntrospectedColumn(name: 'id', dataType: 'uuid', isNullable: false),
        IntrospectedColumn(name: 'name', dataType: 'text', isNullable: true),
      ],
      foreignKeys: [],
      primaryKey: 'id',
    );

    test('is reported by its derived name when it is missing', () {
      expect(
        messagesOf(
          schemas: [
            productSchema(relations: [tags]),
            tagSchema,
          ],
          tables: [
            productTable(['id', 'name']),
            tagTable,
          ],
        ),
        [
          'pivot table "product_tag" joins Product.tags but the database does '
              'not have it',
        ],
      );
    });

    test('is not reported when it is there', () {
      expect(
        messagesOf(
          schemas: [
            productSchema(relations: [tags]),
            tagSchema,
          ],
          tables: [
            productTable(['id', 'name']),
            tagTable,
            const IntrospectedTable(
              name: 'product_tag',
              columns: [
                IntrospectedColumn(
                  name: 'product_id',
                  dataType: 'uuid',
                  isNullable: false,
                ),
                IntrospectedColumn(
                  name: 'tag_id',
                  dataType: 'uuid',
                  isNullable: false,
                ),
              ],
              foreignKeys: [],
              primaryKey: 'product_id',
            ),
          ],
        ),
        isEmpty,
      );
    });
  });
}
