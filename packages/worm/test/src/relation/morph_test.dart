import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/relation/eager_loader.dart';
import 'package:worm/src/relation/morph.dart';
import 'package:worm/src/relation/morph_many.dart';
import 'package:worm/src/relation/morph_one.dart';
import 'package:worm/src/relation/morph_to_many.dart';
import 'package:worm/src/relation/relation_definition.dart';

T _read<T>(Map<String, Object?> row, String key, T fallback) {
  final value = row[key];
  if (value is T) return value;
  return fallback;
}

T? _readNullable<T>(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is T) return value;
  return null;
}

/// Post model — a possible morph target.
final class Post extends Model {
  Post({required this.postId, required this.title});

  factory Post.fromRow(Map<String, Object?> row) => Post(
    postId: _read<int>(row, 'id', 0),
    title: _read<String>(row, 'title', ''),
  );

  final int postId;
  final String title;

  @override
  Object get id => postId;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': postId,
    'title': title,
  };
}

/// Video model — another possible morph target.
final class Video extends Model {
  Video({required this.videoId, required this.title});

  factory Video.fromRow(Map<String, Object?> row) => Video(
    videoId: _read<int>(row, 'id', 0),
    title: _read<String>(row, 'title', ''),
  );

  final int videoId;
  final String title;

  @override
  Object get id => videoId;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': videoId,
    'title': title,
  };
}

/// User-defined sealed union representing what a
/// comment may be attached to. Used to assert sealed
/// completeness on the MorphTo result.
sealed class Commentable {
  const Commentable();
}

final class PostMorphable extends Commentable {
  const PostMorphable(this.post);
  final Post post;
}

final class VideoMorphable extends Commentable {
  const VideoMorphable(this.video);
  final Video video;
}

/// Comment carrying morph columns (commentable_type /
/// commentable_id).
final class Comment extends Model {
  Comment({
    required this.commentId,
    required this.commentableType,
    required this.commentableId,
    required this.body,
  });

  factory Comment.fromRow(Map<String, Object?> row) => Comment(
    commentId: _read<int>(row, 'id', 0),
    commentableType: _readNullable<String>(row, 'commentable_type'),
    commentableId: _readNullable<int>(row, 'commentable_id'),
    body: _read<String>(row, 'body', ''),
  );

  final int commentId;
  final String? commentableType;
  final int? commentableId;
  final String body;

  @override
  Object get id => commentId;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': commentId,
    'commentable_type': commentableType,
    'commentable_id': commentableId,
    'body': body,
  };
}

Future<InMemoryAdapter> _seedAdapter() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'posts'),
  );
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'videos'),
  );
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'comments'),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'posts',
      rows: <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'title': 'Hello Post'},
        <String, Object?>{'id': 2, 'title': 'Another Post'},
      ],
    ),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'videos',
      rows: <Map<String, Object?>>[
        <String, Object?>{'id': 10, 'title': 'Funny Video'},
      ],
    ),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'comments',
      rows: <Map<String, Object?>>[
        <String, Object?>{
          'id': 100,
          'commentable_type': 'Post',
          'commentable_id': 1,
          'body': 'Nice post!',
        },
        <String, Object?>{
          'id': 101,
          'commentable_type': 'Video',
          'commentable_id': 10,
          'body': 'LOL',
        },
        <String, Object?>{
          'id': 102,
          'commentable_type': 'Post',
          'commentable_id': 2,
          'body': 'Cool!',
        },
        <String, Object?>{
          'id': 103,
          'commentable_type': null,
          'commentable_id': null,
          'body': 'Orphaned',
        },
        <String, Object?>{
          'id': 104,
          'commentable_type': 'Audio',
          'commentable_id': 999,
          'body': 'Unknown type',
        },
      ],
    ),
  );
  return adapter;
}

MorphToDefinition<Comment, Commentable> _morphTo() =>
    MorphToDefinition<Comment, Commentable>(
      name: 'commentable',
      morphTypeColumn: 'commentable_type',
      morphIdColumn: 'commentable_id',
      hydrateMap: <String, MorphBinding<Commentable>>{
        'Post': MorphBinding<Commentable>(
          table: 'posts',
          hydrate: Post.fromRow,
          wrap: (m) {
            if (m case final Post p) return PostMorphable(p);
            throw StateError('Expected Post');
          },
        ),
        'Video': MorphBinding<Commentable>(
          table: 'videos',
          hydrate: Video.fromRow,
          wrap: (m) {
            if (m case final Video v) return VideoMorphable(v);
            throw StateError('Expected Video');
          },
        ),
      },
    );

/// Image child for the polymorphic MorphOne / MorphMany
/// scenarios.
final class Image extends Model {
  Image({required this.imageId, required this.url});

  factory Image.fromRow(Map<String, Object?> row) => Image(
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

Future<InMemoryAdapter> _seedImageAdapter() async {
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
          'imageable_type': 'Post',
          'imageable_id': 1,
          'url': 'a.png',
        },
        <String, Object?>{
          'id': 2,
          'imageable_type': 'Post',
          'imageable_id': 1,
          'url': 'b.png',
        },
        <String, Object?>{
          'id': 3,
          'imageable_type': 'Post',
          'imageable_id': 2,
          'url': 'c.png',
        },
        <String, Object?>{
          'id': 4,
          'imageable_type': 'Video',
          'imageable_id': 1,
          'url': 'ignored.png',
        },
      ],
    ),
  );
  return adapter;
}

/// Renders a label using exhaustive pattern matching
/// over [Commentable]. The absence of a `_` arm is a
/// compile-time exhaustiveness check.
String _labelFor(Commentable? c) => switch (c) {
  PostMorphable(:final post) => 'post:${post.title}',
  VideoMorphable(:final video) => 'video:${video.title}',
  null => 'null',
};

void main() {
  group('MorphTo.load (sealed-union per-child loader)', () {
    test('commentable_type=Post returns PostMorphable(Post)', () async {
      final adapter = await _seedAdapter();
      final morphTo = _morphTo();
      final comment = Comment(
        commentId: 100,
        commentableType: 'Post',
        commentableId: 1,
        body: 'Nice post!',
      );
      // ignore: omit_local_variable_types — prove typed return.
      final Commentable? result = await morphTo.load(adapter, comment);
      expect(result, isA<PostMorphable>());
      expect(_labelFor(result), 'post:Hello Post');
    });

    test('commentable_type=Video returns VideoMorphable(Video)', () async {
      final adapter = await _seedAdapter();
      final morphTo = _morphTo();
      final comment = Comment(
        commentId: 101,
        commentableType: 'Video',
        commentableId: 10,
        body: 'LOL',
      );
      // ignore: omit_local_variable_types — prove typed return.
      final Commentable? result = await morphTo.load(adapter, comment);
      expect(result, isA<VideoMorphable>());
      expect(_labelFor(result), 'video:Funny Video');
    });

    test('null commentable_type returns null without throwing', () async {
      final adapter = await _seedAdapter();
      final morphTo = _morphTo();
      final comment = Comment(
        commentId: 103,
        commentableType: null,
        commentableId: null,
        body: 'Orphaned',
      );
      // ignore: omit_local_variable_types — prove typed return.
      final Commentable? result = await morphTo.load(adapter, comment);
      expect(result, isNull);
    });

    test('unknown type string returns null', () async {
      final adapter = await _seedAdapter();
      final morphTo = _morphTo();
      final comment = Comment(
        commentId: 104,
        commentableType: 'Audio',
        commentableId: 999,
        body: 'Unknown type',
      );
      // ignore: omit_local_variable_types — prove typed return.
      final Commentable? result = await morphTo.load(adapter, comment);
      expect(result, isNull);
    });

    test('return type is Future<S?> (sealed Commentable)', () async {
      final adapter = await _seedAdapter();
      final morphTo = _morphTo();
      final comment = Comment(
        commentId: 100,
        commentableType: 'Post',
        commentableId: 1,
        body: 'Nice post!',
      );
      // Static type check via assignment — must succeed
      // without any cast.
      // ignore: omit_local_variable_types — prove typed return.
      final Future<Commentable?> future = morphTo.load(adapter, comment);
      // ignore: omit_local_variable_types — prove typed return.
      final Commentable? value = await future;
      expect(value, isA<Commentable>());
    });

    test('exhaustive pattern match compiles without default arm', () async {
      final adapter = await _seedAdapter();
      final morphTo = _morphTo();
      final inputs = <Comment>[
        Comment(
          commentId: 100,
          commentableType: 'Post',
          commentableId: 1,
          body: '',
        ),
        Comment(
          commentId: 101,
          commentableType: 'Video',
          commentableId: 10,
          body: '',
        ),
        Comment(
          commentId: 103,
          commentableType: null,
          commentableId: null,
          body: '',
        ),
      ];
      final labels = <String>[
        for (final c in inputs) _labelFor(await morphTo.load(adapter, c)),
      ];
      expect(labels, <String>['post:Hello Post', 'video:Funny Video', 'null']);
    });
  });

  group('EagerLoader.loadMorphTo (batched dispatch)', () {
    test(
      'batches one query per distinct morph type and wraps results',
      () async {
        final adapter = await _seedAdapter();
        final comments = <Comment>[
          Comment(
            commentId: 100,
            commentableType: 'Post',
            commentableId: 1,
            body: 'a',
          ),
          Comment(
            commentId: 101,
            commentableType: 'Video',
            commentableId: 10,
            body: 'b',
          ),
          Comment(
            commentId: 102,
            commentableType: 'Post',
            commentableId: 2,
            body: 'c',
          ),
          Comment(
            commentId: 103,
            commentableType: null,
            commentableId: null,
            body: 'd',
          ),
          Comment(
            commentId: 104,
            commentableType: 'Audio',
            commentableId: 999,
            body: 'e',
          ),
        ];
        final definition = MorphToDefinition<Comment, Commentable>(
          name: 'commentable',
          morphTypeColumn: 'commentable_type',
          morphIdColumn: 'commentable_id',
          hydrateMap: <String, MorphBinding<Commentable>>{
            'Post': MorphBinding<Commentable>(
              table: 'posts',
              hydrate: Post.fromRow,
              wrap: (m) {
                if (m case final Post p) return PostMorphable(p);
                throw StateError('Expected Post');
              },
            ),
            'Video': MorphBinding<Commentable>(
              table: 'videos',
              hydrate: Video.fromRow,
              wrap: (m) {
                if (m case final Video v) return VideoMorphable(v);
                throw StateError('Expected Video');
              },
            ),
          },
        );
        final queries = await EagerLoader.loadMorphTo<Comment, Commentable>(
          adapter: adapter,
          children: comments,
          definition: definition,
        );
        // One query per known morph type observed
        // (Post and Video — Audio is skipped).
        expect(queries, 2);
        final postComment = comments.firstWhere((c) => c.commentId == 100);
        expect(
          _labelFor(postComment.relations['commentable'] as Commentable?),
          'post:Hello Post',
        );
        final videoComment = comments.firstWhere((c) => c.commentId == 101);
        expect(
          _labelFor(videoComment.relations['commentable'] as Commentable?),
          'video:Funny Video',
        );
        final orphan = comments.firstWhere((c) => c.commentId == 103);
        expect(orphan.relations['commentable'], isNull);
        final unknown = comments.firstWhere((c) => c.commentId == 104);
        expect(unknown.relations['commentable'], isNull);
      },
    );
  });

  group('MorphTargetMap.toMorphTarget extension', () {
    test('returns GenericMorph for known types', () {
      const allowed = <String, String>{'Post': 'posts', 'Video': 'videos'};
      final row = <String, Object?>{morphTypeKey: 'Post', morphIdKey: 1};
      final result = row.toMorphTarget(allowed);
      final label = switch (result) {
        GenericMorph(:final type, :final table, :final id) =>
          '$type:$table:$id',
        UnresolvedMorph(:final rawType) => 'unresolved:$rawType',
      };
      expect(label, 'Post:posts:1');
    });

    test('returns UnresolvedMorph for unknown types', () {
      const allowed = <String, String>{'Post': 'posts'};
      final row = <String, Object?>{morphTypeKey: 'Audio', morphIdKey: 9};
      final result = row.toMorphTarget(allowed);
      switch (result) {
        case GenericMorph():
          fail('Expected UnresolvedMorph for unknown type');
        case UnresolvedMorph(:final rawType):
          expect(rawType, 'Audio');
      }
    });

    test('returns UnresolvedMorph when _morphType is missing', () {
      const allowed = <String, String>{'Post': 'posts'};
      final row = <String, Object?>{morphIdKey: 1};
      final result = row.toMorphTarget(allowed);
      switch (result) {
        case GenericMorph():
          fail('Expected UnresolvedMorph when _morphType absent');
        case UnresolvedMorph(:final rawType):
          expect(rawType, isNull);
      }
    });

    test('returns UnresolvedMorph when _morphId is null', () {
      const allowed = <String, String>{'Post': 'posts'};
      final row = <String, Object?>{morphTypeKey: 'Post', morphIdKey: null};
      final result = row.toMorphTarget(allowed);
      switch (result) {
        case GenericMorph():
          fail('Expected UnresolvedMorph when id absent');
        case UnresolvedMorph(:final rawType):
          expect(rawType, 'Post');
      }
    });
  });

  group('MorphOne loading', () {
    test('returns the first child where parent type+id match', () async {
      final adapter = await _seedImageAdapter();
      const relation = MorphOneRelation<Post, Image>(
        name: 'image',
        childTable: 'images',
        morphType: 'Post',
        parentMorphName: 'imageable',
        hydrateChild: Image.fromRow,
      );
      final parents = <Post>[
        Post(postId: 1, title: 'A'),
        Post(postId: 2, title: 'B'),
      ];
      final result = await relation.load(adapter, parents);
      expect(result.stats.queriesExecuted, 1);
      for (final p in parents) {
        result.setOnParent(p);
      }
      expect(parents.first.relations['image'], isA<Image>());
      expect(parents.last.relations['image'], isA<Image>());
    });

    test('returns null when no matching child exists', () async {
      final adapter = await _seedImageAdapter();
      const relation = MorphOneRelation<Post, Image>(
        name: 'image',
        childTable: 'images',
        morphType: 'Audio',
        parentMorphName: 'imageable',
        hydrateChild: Image.fromRow,
      );
      final parents = <Post>[Post(postId: 1, title: 'A')];
      final result = await relation.load(adapter, parents);
      for (final p in parents) {
        result.setOnParent(p);
      }
      expect(parents.first.relations['image'], isNull);
    });
  });

  group('MorphMany loading', () {
    test('returns all matching children grouped by parent id', () async {
      final adapter = await _seedImageAdapter();
      const relation = MorphManyRelation<Post, Image>(
        name: 'images',
        childTable: 'images',
        morphType: 'Post',
        parentMorphName: 'imageable',
        hydrateChild: Image.fromRow,
      );
      final parents = <Post>[
        Post(postId: 1, title: 'A'),
        Post(postId: 2, title: 'B'),
      ];
      final result = await relation.load(adapter, parents);
      expect(result.stats.queriesExecuted, 1);
      for (final p in parents) {
        result.setOnParent(p);
      }
      if (parents.first.relations['images'] case final List<Image> list) {
        expect(list, hasLength(2));
      } else {
        fail('Expected List<Image> for post 1');
      }
      if (parents.last.relations['images'] case final List<Image> list) {
        expect(list, hasLength(1));
      } else {
        fail('Expected List<Image> for post 2');
      }
    });

    test('ignores rows of a different morph type', () async {
      final adapter = await _seedImageAdapter();
      const relation = MorphManyRelation<Post, Image>(
        name: 'images',
        childTable: 'images',
        morphType: 'Video',
        parentMorphName: 'imageable',
        hydrateChild: Image.fromRow,
      );
      final parents = <Post>[Post(postId: 1, title: 'A')];
      final result = await relation.load(adapter, parents);
      for (final p in parents) {
        result.setOnParent(p);
      }
      if (parents.first.relations['images'] case final List<Image> list) {
        expect(list, hasLength(1));
        expect(list.first.url, 'ignored.png');
      } else {
        fail('Expected List<Image>');
      }
    });
  });

  group('MorphToMany loading', () {
    test('loads related rows through a morph-pivot', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'tags'),
      );
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'taggables'),
      );
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'tags',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 1, 'label': 'red'},
            <String, Object?>{'id': 2, 'label': 'blue'},
          ],
        ),
      );
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'taggables',
          rows: <Map<String, Object?>>[
            <String, Object?>{
              'taggable_type': 'Post',
              'taggable_id': 1,
              'tag_id': 1,
            },
            <String, Object?>{
              'taggable_type': 'Post',
              'taggable_id': 1,
              'tag_id': 2,
            },
            <String, Object?>{
              'taggable_type': 'Video',
              'taggable_id': 1,
              'tag_id': 1,
            },
          ],
        ),
      );
      const relation = MorphToManyRelation<Post, _Tag>(
        name: 'tags',
        relatedTable: 'tags',
        pivotTable: 'taggables',
        parentMorphName: 'taggable',
        morphType: 'Post',
        relatedPivotKey: 'tag_id',
        hydrateRelated: _Tag.fromRow,
      );
      final parents = <Post>[Post(postId: 1, title: 'A')];
      final result = await relation.load(adapter, parents);
      expect(result.stats.queriesExecuted, 2);
      for (final p in parents) {
        result.setOnParent(p);
      }
      if (parents.first.relations['tags'] case final List<_Tag> list) {
        expect(list.map((t) => t.label).toList(), <String>['red', 'blue']);
      } else {
        fail('Expected List<_Tag>');
      }
    });
  });
}

final class _Tag extends Model {
  _Tag({required this.tagId, required this.label});

  factory _Tag.fromRow(Map<String, Object?> row) => _Tag(
    tagId: _read<int>(row, 'id', 0),
    label: _read<String>(row, 'label', ''),
  );

  final int tagId;
  final String label;

  @override
  Object get id => tagId;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': tagId,
    'label': label,
  };
}
