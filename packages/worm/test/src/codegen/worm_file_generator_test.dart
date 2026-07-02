import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('WormFileGenerator', () {
    test('emits header and combined sections', () {
      const descriptor = ModelDescriptor(
        className: 'User',
        tableName: 'users',
        columns: <ColumnDescriptor>[
          ColumnDescriptor(
            dartName: 'id',
            dbName: 'id',
            dartType: 'String',
            isPrimaryKey: true,
          ),
          ColumnDescriptor(
            dartName: 'name',
            dbName: 'name',
            dartType: 'String',
            fieldKind: FieldKind.string,
          ),
        ],
        scopes: <ScopeDescriptor>[ScopeDescriptor(name: 'active')],
      );
      final source = const WormFileGenerator(descriptor).generate();
      expect(source, contains('GENERATED CODE'));
      expect(source, contains('class User\$'));
      expect(source, contains('extension UserHydration on User'));
      expect(source, contains('extension UserQuery on User'));
      expect(source, contains('extension UserWormScopes on User\$'));
      expect(source, contains("'active'"));
    });

    test('uses part-of when partOfImport is set', () {
      const descriptor = ModelDescriptor(
        className: 'User',
        tableName: 'users',
        columns: <ColumnDescriptor>[
          ColumnDescriptor(dartName: 'id', dbName: 'id', dartType: 'String'),
        ],
        partOfImport: 'user.dart',
      );
      final source = const WormFileGenerator(descriptor).generate();
      expect(source, contains("part of 'user.dart'"));
      expect(source, isNot(contains('import')));
    });

    test('emits no as casts and no dynamic calls', () {
      const descriptor = ModelDescriptor(
        className: 'User',
        tableName: 'users',
        columns: <ColumnDescriptor>[
          ColumnDescriptor(dartName: 'id', dbName: 'id', dartType: 'String'),
          ColumnDescriptor(
            dartName: 'createdAt',
            dbName: 'created_at',
            dartType: 'DateTime',
            isNullable: true,
            fieldKind: FieldKind.comparable,
          ),
        ],
      );
      final source = const WormFileGenerator(descriptor).generate();
      expect(source, isNot(contains(' as String')));
      expect(source, isNot(contains(' as DateTime')));
      expect(source, isNot(contains(' as dynamic')));
    });
  });
}
