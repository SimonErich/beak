/// Unit tests for [RelationField].
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';

final class _Parent extends Model {
  @override
  Object get id => 0;
  @override
  Map<String, Object?> toRow() => const <String, Object?>{};
}

final class _Child extends Model {
  @override
  Object get id => 0;
  @override
  Map<String, Object?> toRow() => const <String, Object?>{};
}

final class _OtherChild extends Model {
  @override
  Object get id => 0;
  @override
  Map<String, Object?> toRow() => const <String, Object?>{};
}

void main() {
  group('RelationField', () {
    test('exposes name, foreignKey, and localKey', () {
      const field = RelationField<_Parent, _Child>(
        'posts',
        foreignKey: 'parent_id',
      );
      expect(field.name, 'posts');
      expect(field.foreignKey, 'parent_id');
      expect(field.localKey, 'id');
    });

    test('localKey defaults to "id" and accepts overrides', () {
      const field = RelationField<_Parent, _Child>(
        'posts',
        foreignKey: 'pid',
        localKey: 'parent_uuid',
      );
      expect(field.localKey, 'parent_uuid');
    });

    test('supports const construction for companion static use', () {
      const a = RelationField<_Parent, _Child>('user', foreignKey: 'uid');
      const b = RelationField<_Parent, _Child>('user', foreignKey: 'uid');
      expect(identical(a, b), isTrue);
    });

    test('is not a Field — separate class hierarchy', () {
      const relation = RelationField<_Parent, _Child>('x', foreignKey: 'fx');
      expect(relation is Field, isFalse);
    });

    test('equality matches on name, foreignKey, localKey, and types', () {
      const a = RelationField<_Parent, _Child>('xs', foreignKey: 'parent_id');
      const b = RelationField<_Parent, _Child>('xs', foreignKey: 'parent_id');
      const c = RelationField<_Parent, _Child>('ys', foreignKey: 'parent_id');
      const d = RelationField<_Parent, _Child>('xs', foreignKey: 'other_id');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality distinguishes related type at runtime', () {
      const Object child = RelationField<_Parent, _Child>(
        'x',
        foreignKey: 'fx',
      );
      const Object other = RelationField<_Parent, _OtherChild>(
        'x',
        foreignKey: 'fx',
      );
      expect(child == other, isFalse);
    });

    test('toString includes type arguments, name, and keys', () {
      const field = RelationField<_Parent, _Child>(
        'xs',
        foreignKey: 'parent_id',
      );
      final rendered = field.toString();
      expect(rendered, contains('_Parent'));
      expect(rendered, contains('_Child'));
      expect(rendered, contains('xs'));
      expect(rendered, contains('parent_id'));
    });
  });
}
