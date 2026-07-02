import 'package:test/test.dart';
import 'package:worm/annotations.dart';
import 'package:worm/src/schema/column_type.dart';
import 'package:worm/src/schema/primary_key_type.dart';

// Dummy types for relationship annotation tests.
class _User {}

class _Post {}

class _Country {}

class _SoftDeleteScope {}

class _JsonCast {}

void main() {
  group('Table', () {
    test('const with defaults', () {
      const a = Table();
      expect(a.name, isNull);
      expect(a.connection, 'default');
    });

    test('const with explicit values', () {
      const a = Table(name: 'users', connection: 'replica');
      expect(a.name, 'users');
      expect(a.connection, 'replica');
    });
  });

  group('Column', () {
    test('const with defaults', () {
      const a = Column();
      expect(a.name, isNull);
      expect(a.type, isNull);
      expect(a.nullable, false);
      expect(a.defaultValue, isNull);
    });

    test('const with explicit values', () {
      const a = Column(
        name: 'email_address',
        type: ColumnType.string,
        nullable: true,
        defaultValue: 'n/a',
      );
      expect(a.name, 'email_address');
      expect(a.type, ColumnType.string);
      expect(a.nullable, true);
      expect(a.defaultValue, 'n/a');
    });
  });

  group('PrimaryKey', () {
    test('const with defaults', () {
      const a = PrimaryKey();
      expect(a.columnName, 'id');
      expect(a.type, PrimaryKeyType.uuid);
    });

    test('const with explicit values', () {
      const a = PrimaryKey(columnName: 'user_id', type: PrimaryKeyType.integer);
      expect(a.columnName, 'user_id');
      expect(a.type, PrimaryKeyType.integer);
    });
  });

  group('HasOne', () {
    test('const with positional Type', () {
      const a = HasOne(_Post);
      expect(a.related, _Post);
      expect(a.foreignKey, isNull);
      expect(a.localKey, isNull);
    });

    test('const with named params', () {
      const a = HasOne(_Post, foreignKey: 'author_id', localKey: 'id');
      expect(a.foreignKey, 'author_id');
      expect(a.localKey, 'id');
    });
  });

  group('HasMany', () {
    test('const with positional Type', () {
      const a = HasMany(_Post);
      expect(a.related, _Post);
      expect(a.foreignKey, isNull);
      expect(a.localKey, isNull);
    });
  });

  group('BelongsTo', () {
    test('const with positional Type', () {
      const a = BelongsTo(_User);
      expect(a.related, _User);
      expect(a.foreignKey, isNull);
      expect(a.ownerKey, isNull);
    });
  });

  group('BelongsToMany', () {
    test('const with defaults', () {
      const a = BelongsToMany(_Post);
      expect(a.related, _Post);
      expect(a.pivotTable, isNull);
      expect(a.foreignPivotKey, isNull);
      expect(a.relatedPivotKey, isNull);
      expect(a.onDelete, OnDelete.restrict);
    });

    test('const with explicit values', () {
      const a = BelongsToMany(
        _Post,
        pivotTable: 'role_user',
        onDelete: OnDelete.cascade,
      );
      expect(a.pivotTable, 'role_user');
      expect(a.onDelete, OnDelete.cascade);
    });
  });

  group('HasOneThrough', () {
    test('const with positional Type', () {
      const a = HasOneThrough(_Country, through: _User);
      expect(a.related, _Country);
      expect(a.through, _User);
      expect(a.firstKey, isNull);
      expect(a.secondKey, isNull);
    });
  });

  group('HasManyThrough', () {
    test('const with positional Type', () {
      const a = HasManyThrough(_Post, through: _Country);
      expect(a.related, _Post);
      expect(a.through, _Country);
      expect(a.firstKey, isNull);
      expect(a.secondKey, isNull);
    });
  });

  group('MorphOne', () {
    test('const with positional Type', () {
      const a = MorphOne(_Post);
      expect(a.related, _Post);
      expect(a.morphName, isNull);
    });
  });

  group('MorphMany', () {
    test('const with positional Type', () {
      const a = MorphMany(_Post);
      expect(a.related, _Post);
      expect(a.morphName, isNull);
    });
  });

  group('MorphTo', () {
    test('const with defaults', () {
      const a = MorphTo();
      expect(a.types, isEmpty);
    });

    test('const with explicit map', () {
      const a = MorphTo(types: <String, Type>{'post': _Post});
      expect(a.types, {'post': _Post});
    });
  });

  group('MorphToMany', () {
    test('const with positional Type', () {
      const a = MorphToMany(_Post);
      expect(a.related, _Post);
      expect(a.morphName, isNull);
      expect(a.pivotTable, isNull);
    });
  });

  group('Scope', () {
    test('const construction', () {
      const a = Scope('active');
      expect(a.name, 'active');
    });
  });

  group('GlobalScope', () {
    test('const construction', () {
      const a = GlobalScope(_SoftDeleteScope);
      expect(a.scopeType, _SoftDeleteScope);
    });
  });

  group('Appended', () {
    test('const construction', () {
      const a = Appended('fullName');
      expect(a.name, 'fullName');
    });
  });

  group('Hidden', () {
    test('const construction', () {
      const a = Hidden();
      expect(a, isA<Hidden>());
    });
  });

  group('Attribute', () {
    test('const construction', () {
      const a = Attribute('displayName');
      expect(a.name, 'displayName');
    });
  });

  group('CastAs', () {
    test('const construction', () {
      const a = CastAs(_JsonCast);
      expect(a.castType, _JsonCast);
    });
  });

  group('Fillable', () {
    test('const construction', () {
      const a = Fillable(['name', 'email']);
      expect(a.fields, ['name', 'email']);
    });
  });

  group('Guarded', () {
    test('const construction', () {
      const a = Guarded(['role', 'password']);
      expect(a.fields, ['role', 'password']);
    });
  });

  group('Computed', () {
    test('const construction', () {
      const a = Computed('fullName');
      expect(a.name, 'fullName');
    });
  });
}
