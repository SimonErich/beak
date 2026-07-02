import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('HydrationGenerator', () {
    test('emits fromRow using pattern matching, no as casts', () {
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
          ),
        ],
      );
      final source = const HydrationGenerator(descriptor).generate();
      expect(source, contains('static User fromRow'));
      expect(source, contains('switch (row['));
      expect(source, isNot(contains(' as String')));
      expect(source, isNot(contains(' as int')));
      expect(source, isNot(contains(' as dynamic')));
      expect(source, contains('final String value => value'));
    });

    test('nullable columns hydrate via null pattern arm', () {
      const descriptor = ModelDescriptor(
        className: 'Post',
        tableName: 'posts',
        columns: <ColumnDescriptor>[
          ColumnDescriptor(
            dartName: 'subtitle',
            dbName: 'subtitle',
            dartType: 'String',
            isNullable: true,
          ),
        ],
      );
      final source = const HydrationGenerator(descriptor).generate();
      expect(source, contains('String? subtitle'));
      expect(source, contains('null => null'));
    });

    test('toRow projects every column by dbName', () {
      const descriptor = ModelDescriptor(
        className: 'User',
        tableName: 'users',
        columns: <ColumnDescriptor>[
          ColumnDescriptor(
            dartName: 'firstName',
            dbName: 'first_name',
            dartType: 'String',
          ),
          ColumnDescriptor(dartName: 'age', dbName: 'age', dartType: 'int'),
        ],
      );
      final source = const HydrationGenerator(descriptor).generate();
      expect(source, contains('toRow'));
      expect(source, contains("'first_name': firstName"));
      expect(source, contains("'age': age"));
    });
  });
}
