import 'dart:convert';

import 'package:test/test.dart';
import 'package:worm/worm.dart';

/// Mutable test model implementing [Serializable].
final class _User implements Serializable {
  _User({
    required this.id,
    required this.name,
    List<_Post>? posts,
    _User? mentor,
  }) : posts = posts ?? <_Post>[],
       _mentor = mentor;

  final String id;
  final String name;
  final String password = 'secret';
  final List<_Post> posts;
  _User? _mentor;

  set mentor(_User? value) => _mentor = value;

  @override
  String get serializationId => id;

  @override
  String get serializationType => 'User';

  @override
  SerializationDescriptor describe() {
    final mentor = _mentor;
    return SerializationDescriptor(
      fields: <String, Object?>{'id': id, 'name': name, 'password': password},
      hidden: const <String>{'password'},
      appended: <String, Object?>{'displayName': '@$name'},
      relations: <String, Object>{
        'posts': posts,
        // ignore: use_null_aware_elements
        if (mentor != null) 'mentor': mentor,
      },
    );
  }
}

final class _Post implements Serializable {
  _Post({required this.id, required this.title, _User? author})
    : _author = author;

  final String id;
  final String title;
  _User? _author;

  set author(_User? value) => _author = value;

  @override
  String get serializationId => id;

  @override
  String get serializationType => 'Post';

  @override
  SerializationDescriptor describe() {
    final author = _author;
    return SerializationDescriptor(
      fields: <String, Object?>{'id': id, 'title': title},
      relations: <String, Object>{
        // ignore: use_null_aware_elements
        if (author != null) 'author': author,
      },
    );
  }
}

final class _Person implements Serializable {
  const _Person({
    required this.id,
    required this.firstName,
    required this.lastName,
  });

  final String id;
  final String firstName;
  final String lastName;

  @override
  String get serializationId => id;

  @override
  String get serializationType => 'Person';

  @override
  SerializationDescriptor describe() => SerializationDescriptor(
    fields: <String, Object?>{
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
    },
    appended: <String, Object?>{'fullName': '$firstName $lastName'},
  );
}

final class _PlainProduct implements Serializable {
  const _PlainProduct({
    required this.id,
    required this.name,
    required this.sku,
  });

  final String id;
  final String name;
  final String sku;

  @override
  String get serializationId => id;

  @override
  String get serializationType => 'Product';

  @override
  SerializationDescriptor describe() => SerializationDescriptor(
    fields: <String, Object?>{'id': id, 'name': name, 'sku': sku},
  );
}

void main() {
  group('Serializer', () {
    test('omits @Hidden fields and includes @Appended fields', () {
      const serializer = Serializer();
      final user = _User(id: 'u-1', name: 'ada');
      final map = serializer.toMap(user);
      expect(map['password'], isNull);
      expect(map.containsKey('password'), isFalse);
      expect(map['displayName'], '@ada');
    });

    test('renders posts as nested list', () {
      const serializer = Serializer();
      final user = _User(
        id: 'u-1',
        name: 'ada',
        posts: <_Post>[
          _Post(id: 'p-1', title: 'Hello'),
          _Post(id: 'p-2', title: 'World'),
        ],
      );
      final map = serializer.toMap(user);
      final posts = map['posts']! as List<Object?>;
      expect(posts.length, 2);
      expect((posts.first! as Map<String, Object?>)['title'], 'Hello');
    });

    test('detects circular references and emits {ref: true}', () {
      const serializer = Serializer();
      final user = _User(id: 'u-1', name: 'ada');
      final post = _Post(id: 'p-1', title: 'Hi', author: user);
      user.posts.add(post);
      final map = serializer.toMap(user);
      final posts = map['posts']! as List<Object?>;
      final firstPost = posts.first! as Map<String, Object?>;
      final author = firstPost['author']! as Map<String, Object?>;
      expect(author['ref'], isTrue);
      expect(author['id'], 'u-1');
      expect(author['type'], 'User');
    });

    test('respects maxDepth (relations beyond depth are dropped)', () {
      const serializer = Serializer(maxDepth: 1);
      final mentor = _User(id: 'u-2', name: 'mentor');
      final user = _User(id: 'u-1', name: 'ada', mentor: mentor);
      final map = serializer.toMap(user);
      expect(map.containsKey('mentor'), isTrue);
      final inner = map['mentor']! as Map<String, Object?>;
      expect(inner.containsKey('mentor'), isFalse);
    });

    test('toJson emits valid JSON', () {
      const serializer = Serializer();
      final user = _User(id: 'u-1', name: 'ada');
      final json = serializer.toJson(user);
      final parsed = jsonDecode(json) as Map<String, Object?>;
      expect(parsed['name'], 'ada');
    });

    test('maxDepth = 0 drops all relations', () {
      const serializer = Serializer(maxDepth: 0);
      final user = _User(
        id: 'u-1',
        name: 'ada',
        posts: <_Post>[_Post(id: 'p-1', title: 'Hello')],
      );
      final map = serializer.toMap(user);
      expect(map.containsKey('posts'), isFalse);
    });
  });

  group('Serializer literal examples', () {
    test("appended 'fullName' surfaces as 'Alice Smith'", () {
      const serializer = Serializer();
      const person = _Person(id: 'p-1', firstName: 'Alice', lastName: 'Smith');
      final map = serializer.toMap(person);
      expect(map['fullName'], 'Alice Smith');
    });

    test('AC #7 — no hidden/appended yields fields verbatim', () {
      const serializer = Serializer();
      const product = _PlainProduct(id: 'prod-1', name: 'Widget', sku: 'W-1');
      final map = serializer.toMap(product);
      expect(map, <String, Object?>{
        'id': 'prod-1',
        'name': 'Widget',
        'sku': 'W-1',
      });
    });

    test('AC #9 — shared non-cyclic node emits ref on second visit', () {
      const serializer = Serializer();
      final author = _User(id: 'u-1', name: 'ada');
      final p1 = _Post(id: 'p-1', title: 'First', author: author);
      final p2 = _Post(id: 'p-2', title: 'Second', author: author);
      final root = _User(id: 'u-root', name: 'root', posts: <_Post>[p1, p2]);
      final map = serializer.toMap(root);
      final posts = map['posts']! as List<Object?>;
      final firstAuthor =
          (posts[0]! as Map<String, Object?>)['author']!
              as Map<String, Object?>;
      final secondAuthor =
          (posts[1]! as Map<String, Object?>)['author']!
              as Map<String, Object?>;
      expect(firstAuthor['name'], 'ada');
      expect(secondAuthor, <String, Object?>{
        'type': 'User',
        'id': 'u-1',
        'ref': true,
      });
    });
  });
}
