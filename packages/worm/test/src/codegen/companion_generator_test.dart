import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('CompanionGenerator', () {
    test('emits typed Field for every column with dart/db names', () {
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
            dartName: 'firstName',
            dbName: 'first_name',
            dartType: 'String',
            fieldKind: FieldKind.string,
          ),
          ColumnDescriptor(
            dartName: 'age',
            dbName: 'age',
            dartType: 'int',
            fieldKind: FieldKind.comparable,
          ),
        ],
      );
      final source = const CompanionGenerator(descriptor).generate();
      expect(source, contains('class User\$'));
      expect(source, contains("static const String tableName = 'users'"));
      expect(source, contains('Field<String> id'));
      expect(source, contains("'id'"));
      expect(source, contains('StringField firstName'));
      expect(source, contains("'first_name'"));
      expect(source, contains('ComparableField<int> age'));
    });

    test('renders one field per column without omitting any', () {
      const descriptor = ModelDescriptor(
        className: 'Post',
        tableName: 'posts',
        columns: <ColumnDescriptor>[
          ColumnDescriptor(
            dartName: 'id',
            dbName: 'id',
            dartType: 'String',
            isPrimaryKey: true,
          ),
          ColumnDescriptor(
            dartName: 'title',
            dbName: 'title',
            dartType: 'String',
            fieldKind: FieldKind.string,
          ),
          ColumnDescriptor(
            dartName: 'createdAt',
            dbName: 'created_at',
            dartType: 'DateTime',
            fieldKind: FieldKind.comparable,
          ),
        ],
      );
      final source = const CompanionGenerator(descriptor).generate();
      expect('Field'.allMatches(source).length, greaterThanOrEqualTo(3));
      expect(source, contains('createdAt'));
      expect(source, contains("'created_at'"));
    });
  });
}
