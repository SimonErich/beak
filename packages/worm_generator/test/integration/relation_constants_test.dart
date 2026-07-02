/// Golden snapshot of the relation-constant section emitted by
/// the companion generator for a model with both single- and
/// multi-valued relations, plus a no-relations control case.
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';

const ModelDescriptor _userWithRelations = ModelDescriptor(
  className: 'User',
  tableName: 'users',
  columns: <ColumnDescriptor>[
    ColumnDescriptor(
      dartName: 'id',
      dbName: 'id',
      dartType: 'String',
      isPrimaryKey: true,
    ),
  ],
  relations: <RelationDescriptor>[
    RelationDescriptor(
      dartName: 'posts',
      relatedClassName: 'Post',
      kind: RelationDescriptorKind.many,
      foreignKey: 'user_id',
    ),
    RelationDescriptor(
      dartName: 'profile',
      relatedClassName: 'Profile',
      kind: RelationDescriptorKind.one,
      foreignKey: 'user_id',
    ),
  ],
);

const ModelDescriptor _accountNoRelations = ModelDescriptor(
  className: 'Account',
  tableName: 'accounts',
  columns: <ColumnDescriptor>[
    ColumnDescriptor(
      dartName: 'id',
      dbName: 'id',
      dartType: 'String',
      isPrimaryKey: true,
    ),
  ],
);

const String _expectedPostsConstant =
    '  /// Relation reference for `posts`.\n'
    '  static const RelationField<User, Post> posts = RelationField(\n'
    "    'posts',\n"
    "    foreignKey: 'user_id',\n"
    '  );';

const String _expectedProfileConstant =
    '  /// Relation reference for `profile`.\n'
    '  static const RelationField<User, Profile> profile = RelationField(\n'
    "    'profile',\n"
    "    foreignKey: 'user_id',\n"
    '  );';

void main() {
  group('CompanionGenerator relation constants', () {
    final source = const CompanionGenerator(_userWithRelations).generate();

    test('emits User\$.posts as a typed RelationField<List<Post>>', () {
      expect(source, contains(_expectedPostsConstant));
    });

    test('emits User\$.profile as a typed RelationField<Profile>', () {
      expect(source, contains(_expectedProfileConstant));
    });

    test('relation block lives inside the companion class body', () {
      final classStart = source.indexOf('class User\$ {');
      final classEnd = source.lastIndexOf('}');
      expect(classStart, greaterThanOrEqualTo(0));
      expect(
        source.indexOf(_expectedPostsConstant),
        inInclusiveRange(classStart, classEnd),
      );
      expect(
        source.indexOf(_expectedProfileConstant),
        inInclusiveRange(classStart, classEnd),
      );
    });
  });

  group('Generator output cast-free', () {
    test('CompanionGenerator output contains no ` as ` cast operator', () {
      final source = const CompanionGenerator(_userWithRelations).generate();
      expect(source, isNot(contains(' as ')));
    });

    test('WormFileGenerator output contains no ` as ` cast operator', () {
      final source = const WormFileGenerator(_userWithRelations).generate();
      expect(source, isNot(contains(' as ')));
    });
  });

  group('Companion without relations is still valid', () {
    final source = const CompanionGenerator(_accountNoRelations).generate();

    test('emits the companion class with no relation constants', () {
      expect(source, contains('class Account\$ {'));
      expect(source, isNot(contains('RelationField')));
      expect(source, isNot(contains('Relation reference')));
    });

    test('still emits the table-name and column constants', () {
      expect(source, contains("static const String tableName = 'accounts';"));
      expect(source, contains('static const Field<String> id ='));
    });
  });
}
