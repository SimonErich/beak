import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

enum _Status { draft, published }

void main() {
  group('wormFieldForColumn', () {
    test('maps every column variant to its worm field type', () {
      const cases = <(BeakColumn, Type)>[
        (BeakIntColumn(key: 'age', label: 'Age'), ComparableField<num>),
        (BeakDecimalColumn(key: 'price', label: 'Price'), ComparableField<num>),
        (
          BeakDateTimeColumn(key: 'created_at', label: 'Created'),
          ComparableField<DateTime>,
        ),
        (BeakStringColumn(key: 'name', label: 'Name'), StringField),
        (BeakTextColumn(key: 'body', label: 'Body'), StringField),
        (BeakRichTextColumn(key: 'html', label: 'Html'), StringField),
        (BeakColorColumn(key: 'tint', label: 'Tint'), StringField),
        (
          BeakFileColumn(key: 'doc', label: 'Doc', storagePath: 'docs'),
          StringField,
        ),
        (
          BeakImageColumn(key: 'photo', label: 'Photo', storagePath: 'photos'),
          StringField,
        ),
        (
          BeakEnumColumn<_Status>(
            key: 'status',
            label: 'Status',
            values: _Status.values,
          ),
          StringField,
        ),
        (BeakBoolColumn(key: 'active', label: 'Active'), Field<bool>),
        (BeakJsonColumn(key: 'meta', label: 'Meta'), Field<Object>),
        (
          BeakCustomColumn(
            key: 'widget',
            label: 'Widget',
            tag: BeakColumnTag('custom'),
          ),
          Field<Object>,
        ),
      ];
      for (final (column, fieldType) in cases) {
        final field = wormFieldForColumn(column);
        expect(field.runtimeType, fieldType, reason: column.key);
        expect(field.name, column.key, reason: column.key);
      }
    });
  });

  group('wormNumericFieldForColumn', () {
    test('maps numeric columns to Field<num>', () {
      const numeric = <BeakColumn>[
        BeakIntColumn(key: 'age', label: 'Age'),
        BeakDecimalColumn(key: 'price', label: 'Price'),
      ];
      for (final column in numeric) {
        final Field<num> field = wormNumericFieldForColumn(column);
        expect(field.name, column.key, reason: column.key);
      }
    });

    test('rejects non-numeric columns', () {
      expect(
        () => wormNumericFieldForColumn(
          const BeakStringColumn(key: 'name', label: 'Name'),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });
}
