import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';
import 'beak_schema_test.dart' show readSchemas;

const String _imports = '''
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';
''';

void main() {
  group('an upload annotation', () {
    test('without a storagePath is a prepare issue, not a part that the '
        'analyzer then rejects', () {
      // The annotation constructors require `storagePath`, so a bare
      // `@Image()` never compiled. Generating a part for it made prepare say
      // "up to date" about a project the analyzer refused.
      final (_, issues) = readSchemas({
        'gallery.dart':
            '''
$_imports
@Resource()
final class Gallery extends BeakSchema {
  late final String title;
  @Image()
  late final BeakImageRef? cover;
  @FileField(maxSizeInBytes: 1024)
  late final BeakFileRef? brochure;
}
''',
      });

      expect(issues.map((issue) => issue.message), [
        allOf(
          contains('Gallery.cover'),
          contains('@Image'),
          contains("@Image(storagePath: 'galleries')"),
        ),
        allOf(
          contains('Gallery.brochure'),
          contains('@FileField'),
          contains("@FileField(storagePath: 'galleries')"),
        ),
      ]);
      expect(issues.first.path, 'lib/models/gallery.dart');
    });

    test('with a storagePath is emitted as written', () {
      final (schemas, issues) = readSchemas({
        'gallery.dart':
            '''
$_imports
@Resource()
final class Gallery extends BeakSchema {
  late final String title;
  @Image(storagePath: 'covers', maxSizeInBytes: 2048)
  late final BeakImageRef? cover;
}
''',
      });

      expect(issues, isEmpty);
      final source = BeakSchemaEmitter.emit(schemas.single, schemas);
      expect(source, contains("storagePath: 'covers'"));
      expect(source, isNot(contains("storagePath: 'galleries'")));
    });

    test('is optional when the field has no annotation at all', () {
      final (schemas, issues) = readSchemas({
        'gallery.dart':
            '''
$_imports
@Resource()
final class Gallery extends BeakSchema {
  late final String title;
  late final BeakImageRef? cover;
}
''',
      });

      expect(issues, isEmpty);
      expect(
        BeakSchemaEmitter.emit(schemas.single, schemas),
        contains("storagePath: 'galleries'"),
      );
    });
  });

  group('@Display', () {
    test('on two fields is a prepare issue naming both', () {
      // The last one used to win silently, so the picker showed a column the
      // author had not ranked first.
      final (_, issues) = readSchemas({
        'product.dart':
            '''
$_imports
@Resource()
final class Product extends BeakSchema {
  @Display()
  late final String name;
  @Display()
  late final String sku;
}
''',
      });

      expect(issues, hasLength(1));
      expect(issues.single.path, 'lib/models/product.dart');
      expect(
        issues.single.message,
        allOf(
          contains('Product'),
          contains('@Display'),
          contains('name'),
          contains('sku'),
          contains('Exactly one'),
        ),
      );
    });

    test('on one field, or none, is fine', () {
      final (schemas, issues) = readSchemas({
        'product.dart':
            '''
$_imports
@Resource()
final class Product extends BeakSchema {
  late final String name;
  @Display()
  late final String sku;
}
''',
        'tag.dart':
            '''
$_imports
@Resource()
final class Tag extends BeakSchema {
  late final String label;
}
''',
      });

      expect(issues, isEmpty);
      expect(schemas.first.displayColumnKey, 'sku');
      expect(schemas.last.displayColumnKey, 'label');
    });
  });
}
