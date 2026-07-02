/// `ScopeGenerator` emission tests covering the metadata extension.
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('ScopeGenerator metadata extension', () {
    test('emits scopeNames and globalScopes constants', () {
      const descriptor = ModelDescriptor(
        className: 'User',
        tableName: 'users',
        columns: <ColumnDescriptor>[
          ColumnDescriptor(dartName: 'id', dbName: 'id', dartType: 'String'),
        ],
        scopes: <ScopeDescriptor>[ScopeDescriptor(name: 'active')],
        globalScopes: <String>['TenantScope'],
      );
      final source = const ScopeGenerator(descriptor).generate();
      expect(source, contains('extension UserWormScopes on User\$'));
      expect(source, contains('static const List<String> scopeNames'));
      expect(source, contains("'active',"));
      expect(
        source,
        contains('static const List<GlobalScope<Model>> globalScopes'),
      );
      expect(source, contains('TenantScope(),'));
    });

    test('emits empty globalScopes list when none declared', () {
      const descriptor = ModelDescriptor(
        className: 'Post',
        tableName: 'posts',
        columns: <ColumnDescriptor>[
          ColumnDescriptor(dartName: 'id', dbName: 'id', dartType: 'String'),
        ],
      );
      final source = const ScopeGenerator(descriptor).generate();
      expect(
        source,
        contains('static const List<GlobalScope<Model>> globalScopes'),
      );
      expect(source, contains('<GlobalScope<Model>>[\n  ];'));
    });

    test('does not emit the typed-method extension — that lives on '
        'QueryStarterGenerator output', () {
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
      final source = const ScopeGenerator(descriptor).generate();
      expect(source, isNot(contains('UserQueryScopes')));
      expect(source, isNot(contains('scope(const PublishedScope())')));
    });
  });
}
