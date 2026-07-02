import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('Field', () {
    test('stores name and optional tableName', () {
      const field = Field<bool>('is_active');
      expect(field.name, 'is_active');
      expect(field.tableName, isNull);
    });

    test('stores tableName when provided', () {
      const field = Field<int>('id', tableName: 'users');
      expect(field.tableName, 'users');
    });

    test('toString without table', () {
      const field = Field<int>('age');
      expect(field.toString(), 'age');
    });

    test('toString with table', () {
      const field = Field<int>('age', tableName: 'users');
      expect(field.toString(), 'users.age');
    });

    test('equality by name and tableName', () {
      const a = Field<int>('age');
      const b = Field<int>('age');
      const c = Field<int>('name');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('equality includes tableName', () {
      const a = Field<int>('id', tableName: 'users');
      const b = Field<int>('id', tableName: 'posts');
      expect(a, isNot(equals(b)));
    });
  });

  group('ComparableField', () {
    test('extends Field', () {
      const field = ComparableField<int>('age');
      expect(field, isA<Field<int>>());
      expect(field.name, 'age');
    });

    test('supports const construction', () {
      const field = ComparableField<int>('age');
      expect(field.name, 'age');
    });
  });

  group('StringField', () {
    test('extends Field<String>', () {
      const field = StringField('name');
      expect(field, isA<Field<String>>());
      expect(field.name, 'name');
    });

    test('supports const construction', () {
      const field = StringField('email');
      expect(field.name, 'email');
    });
  });
}
