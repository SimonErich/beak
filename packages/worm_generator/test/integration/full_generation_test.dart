/// End-to-end generator chain exercised against a fixture
/// `User` model descriptor. Hermetic — no `build_runner`
/// subprocess is spawned; the in-process [WormFileGenerator]
/// is invoked directly.
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';

ModelDescriptor _userFixture() => const ModelDescriptor(
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
    ColumnDescriptor(
      dartName: 'age',
      dbName: 'age',
      dartType: 'int',
      fieldKind: FieldKind.comparable,
    ),
    ColumnDescriptor(
      dartName: 'createdAt',
      dbName: 'created_at',
      dartType: 'DateTime',
      fieldKind: FieldKind.comparable,
    ),
  ],
  scopes: <ScopeDescriptor>[ScopeDescriptor(name: 'active')],
);

void main() {
  group('full generator chain', () {
    final source = WormFileGenerator(_userFixture()).generate();

    test('emits all three sections — User\$, UserHydration, UserQuery', () {
      expect(source, contains('class User\$ {'));
      expect(source, contains('extension UserHydration on User {'));
      expect(source, contains('extension UserQuery on User {'));
    });

    test('emits no `as ` operator anywhere in the generated source', () {
      // Match the operator: ` as ` with surrounding spaces so we
      // don't trip on identifiers like `tableName` containing
      // the substring `as`.
      expect(source, isNot(contains(' as ')));
    });

    test('User\$ exposes a Field for every fixture column', () {
      final fields = RegExp(
        r'static const \w+(<[^>]+>)? \w+ = \w+(<[^>]+>)?\(',
      ).allMatches(source).length;
      expect(fields, _userFixture().columns.length);
    });

    test('UserHydration.fromRow uses switch patterns for every column', () {
      for (final column in _userFixture().columns) {
        expect(
          source,
          contains("switch (row['${column.dbName}'])"),
          reason: 'missing switch arm for ${column.dbName}',
        );
      }
    });

    test('UserWormScopes.scopeNames lists the active scope', () {
      expect(source, contains('extension UserWormScopes on User\$'));
      expect(source, contains("'active',"));
    });

    test('UserQuery.query() static entry point is present', () {
      expect(source, contains('static QueryBuilder<User> query()'));
      expect(source, contains('table: User\$.tableName'));
    });

    test('generated source begins with the GENERATED CODE header', () {
      expect(source, startsWith('// GENERATED CODE'));
    });
  });
}
