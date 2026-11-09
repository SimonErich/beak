/// End-to-end build_runner snapshot for the relation-annotation
/// pipeline.
///
/// Resolves a real Dart source file annotated with `@HasMany`
/// and `@HasOne`, runs the worm builder against it via
/// `build_test`, and asserts that the generated companion class
/// exposes `User$.posts` and `User$.profile` as typed
/// `RelationField` constants.
@TestOn('vm')
library;

import 'package:test/test.dart';

import '../support/generate_worm.dart';

const String _userSource = '''
import 'package:worm/annotations.dart';

part 'user.worm.dart';

@Table()
class User {
  @PrimaryKey()
  final String id;

  @HasMany(Post)
  final List<Post> posts;

  @HasOne(Profile)
  final Profile profile;

  @BelongsToMany(Role)
  final List<Role> roles;

  User({
    required this.id,
    this.posts = const [],
    required this.profile,
    this.roles = const [],
  });
}

class Post {
  final String id;
  Post({required this.id});
}

class Profile {
  final String id;
  Profile({required this.id});
}

class Role {
  final String id;
  Role({required this.id});
}
''';

void main() {
  group('build_runner emits typed RelationField constants', () {
    test(
      'User\$.posts and User\$.profile appear in generated output',
      () async {
        final source = await generateWormPart('user.dart', _userSource);
        expect(
          source,
          contains("static const RelationField<User, Post> posts ="),
        );
        expect(source, contains("foreignKey: 'user_id'"));
        expect(
          source,
          contains("static const RelationField<User, Profile> profile ="),
        );
        expect(source, isNot(contains(' as ')));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('emits HasMany/HasOne accessor extension on User', () async {
      final source = await generateWormPart('user.dart', _userSource);

      // Extension header.
      expect(source, contains('extension UserAccessors on User {'));

      // HasMany accessor: typed getter wired through Post\$.tableName
      // with the conventional foreign key 'user_id', the const
      // HasManyRelation factory, and the generated hydrator.
      expect(source, contains('HasManyAccessor<User, Post> get posts\$ =>'));
      expect(source, contains('const HasManyRelation<User, Post>('));
      expect(source, contains('childTable: Post\$.tableName'));
      expect(source, contains("foreignKey: 'user_id'"));
      expect(source, contains('hydrateChild: PostHydration.fromRow'));

      // HasOne accessor: same shape against the Profile model.
      expect(
        source,
        contains('HasOneAccessor<User, Profile> get profile\$ =>'),
      );
      expect(source, contains('const HasOneRelation<User, Profile>('));
      expect(source, contains('childTable: Profile\$.tableName'));

      // Each generated getter references Worm.adapter — the
      // generated source must include the explicit token so the
      // adapter lookup is part of the generated artifact rather
      // than an implicit runtime detail.
      expect(
        source,
        contains('resolveAdapter: () => Worm.adapter(connectionName)'),
      );

      // Zero as-casts in generated output (constitution).
      expect(source, isNot(contains(' as ')));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
      'emits BelongsToMany accessor with alphabetical pivot convention',
      () async {
        final source = await generateWormPart('user.dart', _userSource);

        // Typed BelongsToManyAccessor getter.
        expect(
          source,
          contains('BelongsToManyAccessor<User, Role> get roles\$ =>'),
        );
        // Const relation wiring through the related companion.
        expect(source, contains('const BelongsToManyRelation<User, Role>('));
        expect(source, contains('relatedTable: Role\$.tableName'));
        // Alphabetical pivot table convention: 'role' < 'user' →
        // 'role_user'.
        expect(source, contains("pivotTable: 'role_user'"));
        // Conventional pivot keys derived from class names.
        expect(source, contains("parentPivotKey: 'user_id'"));
        expect(source, contains("relatedPivotKey: 'role_id'"));
        expect(source, contains('hydrateRelated: RoleHydration.fromRow'));

        // Constitution: zero as-casts.
        expect(source, isNot(contains(' as ')));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
