import 'dart:io';

import 'package:beak_cli/beak_cli.dart';
import 'package:test/test.dart';

/// A project with [files] under `lib/models/`.
Directory modelsWith(Map<String, String> files) {
  final root = Directory.systemTemp.createTempSync('beak_schema_');
  addTearDown(() => root.deleteSync(recursive: true));
  File('${root.path}/pubspec.yaml').writeAsStringSync('name: shop\n');
  for (final MapEntry(key: name, value: source) in files.entries) {
    final file = File('${root.path}/lib/models/$name')
      ..parent.createSync(recursive: true);
    file.writeAsStringSync(source);
  }
  return root;
}

const String categorySchema = '''
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

part 'category.beak.dart';

/// A product category.
@BeakResource()
final class Category extends BeakSchema {
  /// Display name.
  @Display()
  @Column(searchable: true)
  late final String name;
}
''';

const String productSchema = '''
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

part 'product.beak.dart';

/// The catalog's centerpiece.
@BeakResource(softDeletes: true, timestamps: true)
final class Product extends BeakSchema {
  /// Display name.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(255)])
  late final String name;

  /// Optional notes.
  @Column()
  late final BeakText? notes;

  /// Sale price.
  @Column(prefix: '€')
  late final double price;

  /// The category a product is filed under.
  @BelongsTo()
  late final Category? category;
}
''';

(List<BeakSchemaIr>, List<BeakDiscoveryIssue>) readSchemas(
  Map<String, String> files,
) => BeakSchemaReader(modelsWith(files)).read();

BeakSchemaIr schemaNamed(List<BeakSchemaIr> schemas, String name) =>
    schemas.firstWhere((schema) => schema.className == name);

void main() {
  group('reading', () {
    late List<BeakSchemaIr> schemas;
    late List<BeakDiscoveryIssue> issues;

    setUp(() {
      (schemas, issues) = readSchemas({
        'category.dart': categorySchema,
        'product.dart': productSchema,
      });
    });

    test('finds every annotated class, in path order', () {
      expect(issues, isEmpty);
      expect(schemas.map((schema) => schema.className), [
        'Category',
        'Product',
      ]);
    });

    test('derives the table name from the class name', () {
      expect(schemaNamed(schemas, 'Product').table, 'products');
      expect(schemaNamed(schemas, 'Category').table, 'categories');
    });

    test('honours @Display for the display column', () {
      expect(schemaNamed(schemas, 'Product').displayColumnKey, 'name');
    });

    test('implies id, timestamps, soft-delete and foreign-key columns', () {
      final keys = [
        for (final column in schemaNamed(schemas, 'Product').columns)
          column.columnKey,
      ];
      expect(
        keys,
        containsAll(['id', 'created_at', 'updated_at', 'deleted_at']),
      );
      expect(keys, contains('category_id'), reason: 'the FK is synthesised');
      expect(
        schemaNamed(schemas, 'Category').columns.map((c) => c.columnKey),
        isNot(contains('created_at')),
        reason: 'timestamps are opt-in',
      );
    });

    test('maps the Dart type to the column kind', () {
      final columns = {
        for (final column in schemaNamed(schemas, 'Product').columns)
          column.columnKey: column,
      };
      expect(columns['name']!.kind, BeakColumnKind.string);
      expect(columns['notes']!.kind, BeakColumnKind.text);
      expect(columns['price']!.kind, BeakColumnKind.decimal);
      expect(columns['created_at']!.kind, BeakColumnKind.dateTime);
    });

    test('nullability decides required-ness', () {
      final columns = {
        for (final column in schemaNamed(schemas, 'Product').columns)
          column.columnKey: column,
      };
      expect(columns['name']!.isRequired, isTrue);
      expect(columns['notes']!.isRequired, isFalse);
      expect(columns['price']!.isRequired, isTrue);
    });

    test('labels default to the title-cased field name', () {
      final product = schemaNamed(schemas, 'Product');
      expect(
        product.columns.firstWhere((c) => c.columnKey == 'name').label,
        'Name',
      );
    });

    test('carries the field doc comment onto the column', () {
      final product = schemaNamed(schemas, 'Product');
      expect(
        product.columns.firstWhere((c) => c.columnKey == 'price').docComment,
        'Sale price.',
      );
    });

    test('reads the relationship and its default foreign key', () {
      final relation = schemaNamed(schemas, 'Product').relations.single;
      expect(relation.kind, BeakRelationKind.belongsTo);
      expect(relation.relatedSchema, 'Category');
      expect(relation.foreignKey, 'category_id');
    });
  });

  group('issues', () {
    test('a relationship to an unknown schema is reported', () {
      final (_, issues) = readSchemas({'product.dart': productSchema});
      expect(issues, hasLength(1));
      expect(issues.single.message, contains('Category'));
      expect(issues.single.message, contains('not a @BeakResource'));
    });

    test('an unmappable field type is reported by name', () {
      final (_, issues) = readSchemas({
        'thing.dart': '''
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

@BeakResource()
final class Thing extends BeakSchema {
  @Column()
  late final Uri link;
}
''',
      });
      expect(issues.single.message, contains('Thing.link'));
      expect(issues.single.message, contains('Uri'));
    });

    test('a to-many relationship that is not a List is reported', () {
      final (_, issues) = readSchemas({
        'category.dart': categorySchema,
        'thing.dart': '''
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

@BeakResource()
final class Thing extends BeakSchema {
  @Display()
  @Column()
  late final String name;

  @HasMany()
  late final Category items;
}
''',
      });
      expect(issues.single.message, contains('must be'));
      expect(issues.single.message, contains('List'));
    });

    test('a class with no fields is reported', () {
      final (_, issues) = readSchemas({
        'empty.dart': '''
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

@BeakResource()
final class Empty extends BeakSchema {}
''',
      });
      expect(issues.single.message, contains('declares no fields'));
    });

    test('an unannotated class is simply not a schema', () {
      final (schemas, issues) = readSchemas({
        'helper.dart': 'final class Helper {}\n',
      });
      expect(schemas, isEmpty);
      expect(issues, isEmpty);
    });
  });

  group('emitting', () {
    late List<BeakSchemaIr> schemas;
    late String product;
    late String category;

    setUp(() {
      (schemas, _) = readSchemas({
        'category.dart': categorySchema,
        'product.dart': productSchema,
      });
      product = BeakSchemaEmitter.emit(
        schemaNamed(schemas, 'Product'),
        schemas,
      );
      category = BeakSchemaEmitter.emit(
        schemaNamed(schemas, 'Category'),
        schemas,
      );
    });

    test('emits a part of the declaring library', () {
      expect(product, contains("part of 'product.dart';"));
    });

    test('emits the columns class and its values list', () {
      expect(product, contains('abstract final class ProductColumns'));
      expect(product, contains('static const List<BeakColumn> values'));
      // The double declaration that used to be hand-maintained.
      expect(product, contains('name,'));
    });

    test('derives BeakRequired from non-nullability, once', () {
      expect(product, contains('rules: [BeakRequired(), BeakMaxLength(255)]'));
      expect(
        'BeakRequired()'.allMatches(product).length,
        greaterThanOrEqualTo(2),
        reason: 'name and price are both non-nullable',
      );
    });

    test('emits the model with its table, display column and soft deletes', () {
      expect(product, contains('final class ProductModel extends BeakModel'));
      expect(product, contains("String get table => 'products';"));
      expect(product, contains("String get displayColumnKey => 'name';"));
      expect(product, contains('bool get softDeletes => true;'));
    });

    test('emits the relationship with the related table resolved', () {
      expect(product, contains('static const BeakBelongsTo category'));
      expect(product, contains("relatedTable: 'categories'"));
      expect(product, contains("foreignKey: 'category_id'"));
    });

    test('emits the inverse on the other side, from one declaration', () {
      // The 4x-duplicated foreign key, declared once.
      expect(category, contains('abstract final class CategoryRelations'));
      expect(category, contains('static const BeakHasMany products'));
      expect(category, contains("foreignKey: 'category_id'"));
      expect(category, contains("relatedTable: 'products'"));
    });

    test('suppresses the inverse when the declaration opts out', () {
      final (opted, _) = readSchemas({
        'category.dart': categorySchema,
        'product.dart': productSchema.replaceAll(
          '@BelongsTo()',
          '@BelongsTo(inverse: false)',
        ),
      });
      final emitted = BeakSchemaEmitter.emit(
        schemaNamed(opted, 'Category'),
        opted,
      );
      expect(emitted, isNot(contains('CategoryRelations')));
    });

    test('emits a typed record whose getters match nullability', () {
      expect(product, contains('extension type const ProductRecord'));
      expect(
        product,
        contains('String get name => ProductColumns.name.require(record)'),
      );
      expect(
        product,
        contains('String? get notes => ProductColumns.notes.readFrom(record)'),
      );
    });

    test('emits a typed relation accessor', () {
      expect(product, contains('CategoryRecord? get category'));
    });

    test('emits the record-access extension', () {
      expect(product, contains('ProductRecord get asProduct'));
    });

    test('names the foreign-key column distinctly from the relationship', () {
      // ProductColumns.categoryId vs ProductRelations.category: a column and a
      // relationship that look alike are exactly what this surface avoids.
      expect(product, contains('categoryId = BeakStringColumn'));
      expect(product, contains('BeakBelongsTo category'));
    });

    test('output is formatted, so the project stays format-clean', () {
      expect(BeakEmitters.format(product), product);
      expect(BeakEmitters.format(category), category);
    });
  });

  group('many-to-many', () {
    test('derives the pivot table and both key columns', () {
      final (schemas, issues) = readSchemas({
        'tag.dart': '''
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

@BeakResource()
final class Tag extends BeakSchema {
  @Display()
  @Column()
  late final String name;
}
''',
        'product.dart': '''
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

import 'tag.dart';

@BeakResource()
final class Product extends BeakSchema {
  @Display()
  @Column()
  late final String name;

  @BelongsToMany()
  late final List<Tag> tags;
}
''',
      });
      expect(issues, isEmpty);

      final emitted = BeakSchemaEmitter.emit(
        schemaNamed(schemas, 'Product'),
        schemas,
      );
      expect(emitted, contains("pivotTable: 'product_tag'"));
      expect(emitted, contains("foreignPivotKey: 'product_id'"));
      expect(emitted, contains("relatedPivotKey: 'tag_id'"));
    });

    test('mirrors the pivot on the other side with the keys swapped', () {
      final (schemas, _) = readSchemas({
        'tag.dart': '''
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

@BeakResource()
final class Tag extends BeakSchema {
  @Display()
  @Column()
  late final String name;
}
''',
        'product.dart': '''
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

import 'tag.dart';

@BeakResource()
final class Product extends BeakSchema {
  @Display()
  @Column()
  late final String name;

  @BelongsToMany()
  late final List<Tag> tags;
}
''',
      });
      final emitted = BeakSchemaEmitter.emit(
        schemaNamed(schemas, 'Tag'),
        schemas,
      );
      expect(emitted, contains('BeakBelongsToMany products'));
      expect(emitted, contains("pivotTable: 'product_tag'"));
      expect(emitted, contains("foreignPivotKey: 'tag_id'"));
      expect(emitted, contains("relatedPivotKey: 'product_id'"));
    });
  });

  group('naming', () {
    test('derives the table name from the class name', () {
      // Shared with the make:* generators, so a scaffolded resource and an
      // annotated one agree about where the rows live.
      expect(tableNameOf('Product'), 'products');
      expect(tableNameOf('Category'), 'categories');
      expect(tableNameOf('Box'), 'boxes');
      expect(tableNameOf('OrderItem'), 'order_items');
    });

    test('title-cases a camelCase field name', () {
      expect(titleCaseOf('unitPrice'), 'Unit Price');
      expect(titleCaseOf('name'), 'Name');
    });
  });
}
