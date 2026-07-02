import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/factory/factory_base.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/registry/worm.dart';
import 'package:worm/src/relation/relation_field.dart';

/// Sequence-backed primary key generator used to produce stable IDs
/// for the tests so we can assert on row counts without depending on
/// UUID randomness.
int _nextId = 0;

final class User extends Model {
  User();

  @override
  String get tableName => 'users';

  @override
  Object get id => getAttribute('id') ?? 0;

  @override
  Map<String, Object?> toRow() => <String, Object?>{...state.attributes};
}

final class Post extends Model {
  Post();

  @override
  String get tableName => 'posts';

  @override
  Object get id => getAttribute('id') ?? 0;

  @override
  Map<String, Object?> toRow() => <String, Object?>{...state.attributes};
}

final class UserFactory extends Factory<User> {
  UserFactory();

  @override
  User definition() {
    _nextId++;
    return User()
      ..setAttribute('id', _nextId)
      ..setAttribute('name', 'default');
  }
}

final class PostFactory extends Factory<Post> {
  PostFactory();

  @override
  Post definition() {
    _nextId++;
    return Post()
      ..setAttribute('id', _nextId)
      ..setAttribute('title', 'default');
  }
}

/// Mirrors what the codegen emits for `User`: a stable static
/// reference so tests can name `User$.posts` directly.
abstract final class User$ {
  static const RelationField<User, Post> posts = RelationField<User, Post>(
    'posts',
    foreignKey: 'user_id',
  );
}

Future<InMemoryAdapter> _initWorm() async {
  _nextId = 0;
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'users'),
  );
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'posts'),
  );
  await Worm.initialize(
    config: const WormConfig(),
    adapters: <String, InMemoryAdapter>{'default': adapter},
  );
  return adapter;
}

void main() {
  tearDown(Worm.reset);

  group('Factory.count(N).create()', () {
    test('persists N rows and returns a typed List<T>', () async {
      final adapter = await _initWorm();
      final users = await UserFactory().count(5).create();
      expect(users, hasLength(5));
      // Statically List<User>; runtime check enforces persistence.
      expect(users.first.exists, isTrue);
      final rows = await adapter.select(const QueryDescriptor(table: 'users'));
      expect(rows, hasLength(5));
    });
  });

  group('Factory.has', () {
    test('persists parent + child rows linked via FK', () async {
      final adapter = await _initWorm();
      final users = await UserFactory()
          .has(PostFactory().count(3), User$.posts)
          .create();
      expect(users, hasLength(1));
      final user = users.single;
      final postRows = await adapter.select(
        const QueryDescriptor(table: 'posts'),
      );
      expect(postRows, hasLength(3));
      for (final row in postRows) {
        expect(row['user_id'], user.id);
      }
    });
  });

  group('Factory.sequence', () {
    test('cycles override maps across count(N) rows', () async {
      final adapter = await _initWorm();
      final users = await UserFactory()
          .sequence(const <Map<String, Object?>>[
            <String, Object?>{'name': 'a'},
            <String, Object?>{'name': 'b'},
          ])
          .count(4)
          .create();
      expect(users.map((u) => u.getAttribute('name')), <String>[
        'a',
        'b',
        'a',
        'b',
      ]);
      final rows = await adapter.select(const QueryDescriptor(table: 'users'));
      expect(rows.map((r) => r['name']), containsAll(<String>['a', 'b']));
    });
  });

  group('Factory.faker', () {
    test('emits deterministic values after Worm.seedRandom', () {
      final factory = UserFactory();
      Worm.seedRandom(42);
      final first = <String>[
        for (var i = 0; i < 4; i++) factory.faker.firstName(),
      ];
      Worm.seedRandom(42);
      final second = <String>[
        for (var i = 0; i < 4; i++) factory.faker.firstName(),
      ];
      expect(first, equals(second));
    });
  });
}
