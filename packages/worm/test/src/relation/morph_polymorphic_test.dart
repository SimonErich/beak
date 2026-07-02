import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/relation/morph_many.dart';
import 'package:worm/src/relation/morph_one.dart';

T _read<T>(Map<String, Object?> row, String key, T fallback) {
  final value = row[key];
  if (value is T) return value;
  return fallback;
}

final class _Image extends Model {
  _Image({required this.imageId, required this.url});
  factory _Image.fromRow(Map<String, Object?> row) => _Image(
    imageId: _read<int>(row, 'id', 0),
    url: _read<String>(row, 'url', ''),
  );
  final int imageId;
  final String url;
  @override
  Object get id => imageId;
  @override
  Map<String, Object?> toRow() => <String, Object?>{'id': imageId, 'url': url};
}

final class _Post extends Model {
  _Post({required this.postId});
  final int postId;
  @override
  Object get id => postId;
  @override
  Map<String, Object?> toRow() => <String, Object?>{'id': postId};
}

Future<InMemoryAdapter> polyAdapter() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'images'),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'images',
      rows: <Map<String, Object?>>[
        <String, Object?>{
          'id': 1,
          'imageable_type': 'post',
          'imageable_id': 100,
          'url': 'a.png',
        },
        <String, Object?>{
          'id': 2,
          'imageable_type': 'post',
          'imageable_id': 100,
          'url': 'b.png',
        },
        <String, Object?>{
          'id': 3,
          'imageable_type': 'post',
          'imageable_id': 200,
          'url': 'c.png',
        },
        <String, Object?>{
          'id': 4,
          'imageable_type': 'video',
          'imageable_id': 100,
          'url': 'ignored.png',
        },
      ],
    ),
  );
  return adapter;
}

void main() {
  group('MorphOne', () {
    test('returns first matching child for the parent morph type', () async {
      final adapter = await polyAdapter();
      const relation = MorphOneRelation<Model, Model>(
        name: 'image',
        childTable: 'images',
        morphType: 'post',
        parentMorphName: 'imageable',
        hydrateChild: _Image.fromRow,
      );
      final parents = <Model>[_Post(postId: 100), _Post(postId: 200)];
      final result = await relation.load(adapter, parents);
      expect(result.stats.queriesExecuted, 1);
      for (final p in parents) {
        result.setOnParent(p);
      }
      final post1 = parents.whereType<_Post>().firstWhere(
        (p) => p.postId == 100,
      );
      expect(post1.relations['image'], isA<Model>());
    });
  });

  group('MorphMany', () {
    test('returns all matching children grouped by parent', () async {
      final adapter = await polyAdapter();
      const relation = MorphManyRelation<Model, Model>(
        name: 'images',
        childTable: 'images',
        morphType: 'post',
        parentMorphName: 'imageable',
        hydrateChild: _Image.fromRow,
      );
      final parents = <Model>[_Post(postId: 100), _Post(postId: 200)];
      final result = await relation.load(adapter, parents);
      expect(result.stats.queriesExecuted, 1);
      for (final p in parents) {
        result.setOnParent(p);
      }
      final post1 = parents.whereType<_Post>().firstWhere(
        (p) => p.postId == 100,
      );
      if (post1.relations['images'] case final List<Model> list) {
        expect(list, hasLength(2));
      } else {
        fail('Expected List<Model>');
      }
      final post2 = parents.whereType<_Post>().firstWhere(
        (p) => p.postId == 200,
      );
      if (post2.relations['images'] case final List<Model> list) {
        expect(list, hasLength(1));
      } else {
        fail('Expected List<Model>');
      }
    });

    test('ignores rows of different morph type', () async {
      final adapter = await polyAdapter();
      const relation = MorphManyRelation<Model, Model>(
        name: 'images',
        childTable: 'images',
        morphType: 'video',
        parentMorphName: 'imageable',
        hydrateChild: _Image.fromRow,
      );
      final parents = <Model>[_Post(postId: 100)];
      final result = await relation.load(adapter, parents);
      for (final p in parents) {
        result.setOnParent(p);
      }
      if (parents.first.relations['images'] case final List<Model> list) {
        expect(list, hasLength(1));
      } else {
        fail('Expected List<Model>');
      }
    });
  });
}
