import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('QueryStarterGenerator', () {
    test('emits extension UserQuery on User with a working query()', () {
      const descriptor = ModelDescriptor(
        className: 'User',
        tableName: 'users',
        columns: <ColumnDescriptor>[
          ColumnDescriptor(dartName: 'id', dbName: 'id', dartType: 'String'),
        ],
      );
      final source = const QueryStarterGenerator(descriptor).generate();
      expect(source, contains('extension UserQuery on User {'));
      expect(source, contains('static QueryBuilder<User> query()'));
      expect(source, contains('QueryBuilder<User>.from('));
      expect(source, contains('QueryContext<User>('));
      expect(source, contains('adapter: Worm.adapter(),'));
      expect(source, contains('table: User\$.tableName,'));
      expect(source, contains('hydrate: UserHydration.fromRow,'));
    });

    test('class without scopes emits an empty global-scope list', () {
      const descriptor = ModelDescriptor(
        className: 'User',
        tableName: 'users',
        columns: <ColumnDescriptor>[
          ColumnDescriptor(dartName: 'id', dbName: 'id', dartType: 'String'),
        ],
      );
      final source = const QueryStarterGenerator(descriptor).generate();
      expect(source, contains('globalScopes: const <GlobalScope<Model>>[],'));
      expect(source, isNot(contains('applyScope')));
    });

    test(
      'emits typed QueryBuilder<X> extension with scope(const ...()) bodies',
      () {
        const descriptor = ModelDescriptor(
          className: 'User',
          tableName: 'users',
          columns: <ColumnDescriptor>[
            ColumnDescriptor(dartName: 'id', dbName: 'id', dartType: 'String'),
          ],
          scopes: <ScopeDescriptor>[
            ScopeDescriptor(name: 'published', className: 'PublishedScope'),
          ],
        );
        final source = const QueryStarterGenerator(descriptor).generate();
        expect(
          source,
          contains('extension UserQueryScopes on QueryBuilder<User> {'),
        );
        expect(source, contains('QueryBuilder<User> published()'));
        expect(source, contains('scope(const PublishedScope())'));
        // The model extension never carries the scope methods — they
        // sit on the QueryBuilder<X> extension only.
        expect(source, isNot(contains('static QueryBuilder<User> published(')));
        expect(source, isNot(contains('applyScope')));
      },
    );

    test('parameterised scope forwards arguments to the constructor', () {
      const descriptor = ModelDescriptor(
        className: 'User',
        tableName: 'users',
        columns: <ColumnDescriptor>[
          ColumnDescriptor(dartName: 'id', dbName: 'id', dartType: 'String'),
        ],
        scopes: <ScopeDescriptor>[
          ScopeDescriptor(
            name: 'olderThan',
            className: 'OlderThanScope',
            parameters: <ScopeParameter>[
              ScopeParameter(name: 'age', type: 'int'),
            ],
          ),
        ],
      );
      final source = const QueryStarterGenerator(descriptor).generate();
      expect(source, contains('QueryBuilder<User> olderThan(int age)'));
      expect(source, contains('scope(OlderThanScope(age))'));
    });

    test('omits the typed extension when no scope has a className', () {
      const descriptor = ModelDescriptor(
        className: 'User',
        tableName: 'users',
        columns: <ColumnDescriptor>[
          ColumnDescriptor(dartName: 'id', dbName: 'id', dartType: 'String'),
        ],
        scopes: <ScopeDescriptor>[ScopeDescriptor(name: 'active')],
      );
      final source = const QueryStarterGenerator(descriptor).generate();
      expect(source, isNot(contains('UserQueryScopes')));
    });

    test(
      '@GlobalScope entries are emitted as instances, not Type literals',
      () {
        const descriptor = ModelDescriptor(
          className: 'User',
          tableName: 'users',
          columns: <ColumnDescriptor>[
            ColumnDescriptor(dartName: 'id', dbName: 'id', dartType: 'String'),
          ],
          globalScopes: <String>['ActiveScope', 'SoftDeleteScope'],
        );
        final source = const QueryStarterGenerator(descriptor).generate();
        expect(source, contains('globalScopes: const <GlobalScope<Model>>['));
        expect(source, contains('ActiveScope(),'));
        expect(source, contains('SoftDeleteScope(),'));
        // Negative checks: the previous broken format must be gone.
        expect(source, isNot(contains('globalScopes: <Type>[')));
        expect(source, isNot(contains('<Type>[\n          ActiveScope,')));
      },
    );

    test('emits a single UserQuery extension declaration', () {
      const descriptor = ModelDescriptor(
        className: 'User',
        tableName: 'users',
        columns: <ColumnDescriptor>[
          ColumnDescriptor(dartName: 'id', dbName: 'id', dartType: 'String'),
        ],
        scopes: <ScopeDescriptor>[
          ScopeDescriptor(name: 'active'),
          ScopeDescriptor(name: 'recent'),
        ],
      );
      final source = const QueryStarterGenerator(descriptor).generate();
      expect('extension UserQuery on User'.allMatches(source).length, 1);
    });

    test('uses no extension suffix like QueryExtension or Starters', () {
      const descriptor = ModelDescriptor(
        className: 'User',
        tableName: 'users',
        columns: <ColumnDescriptor>[
          ColumnDescriptor(dartName: 'id', dbName: 'id', dartType: 'String'),
        ],
      );
      final source = const QueryStarterGenerator(descriptor).generate();
      expect(source, isNot(contains('UserQueryExtension')));
      expect(source, isNot(contains('UserQueryStarters')));
      expect(source, isNot(contains('UserWormQuery')));
    });
  });
}
