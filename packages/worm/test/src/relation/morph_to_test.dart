import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/relation/morph_to.dart';

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

/// Test post model (a possible morph target).
final class TestMorphPost extends Model {
  TestMorphPost({required this.postId, required this.title});
  factory TestMorphPost.fromRow(Map<String, Object?> row) => TestMorphPost(
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

/// Test video model (another morph target).
final class TestMorphVideo extends Model {
  TestMorphVideo({required this.videoId, required this.title});
  factory TestMorphVideo.fromRow(Map<String, Object?> row) => TestMorphVideo(
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
/// comment may be attached to.
sealed class Commentable {
  const Commentable();
}

final class PostCommentable extends Commentable {
  const PostCommentable(this.post);
  final TestMorphPost post;
}

final class VideoCommentable extends Commentable {
  const VideoCommentable(this.video);
  final TestMorphVideo video;
}

/// Comment model carrying morph-type / morph-id.
final class _Comment extends Model {
  _Comment({
    required this.commentId,
    required this.commentableType,
    required this.commentableId,
    required this.body,
  });
  factory _Comment.fromRow(Map<String, Object?> row) => _Comment(
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

Future<InMemoryAdapter> morphAdapter() async {
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
          'commentable_type': 'post',
          'commentable_id': 1,
          'body': 'Nice post!',
        },
        <String, Object?>{
          'id': 101,
          'commentable_type': 'video',
          'commentable_id': 10,
          'body': 'LOL',
        },
        <String, Object?>{
          'id': 102,
          'commentable_type': 'post',
          'commentable_id': 2,
          'body': 'Cool!',
        },
      ],
    ),
  );
  return adapter;
}

void main() {
  group('MorphTo (sealed union via pattern matching)', () {
    test('loads each morph type and wraps in sealed cases', () async {
      final adapter = await morphAdapter();
      final relation = MorphToRelation<_Comment, Commentable>(
        name: 'commentable',
        morphTypeColumn: 'commentable_type',
        morphIdColumn: 'commentable_id',
        types: <String, MorphTypeMapping<Commentable>>{
          'post': MorphTypeMapping<Commentable>(
            table: 'posts',
            hydrate: TestMorphPost.fromRow,
            wrap: (m) {
              if (m case final TestMorphPost p) return PostCommentable(p);
              throw StateError('Expected TestMorphPost');
            },
          ),
          'video': MorphTypeMapping<Commentable>(
            table: 'videos',
            hydrate: TestMorphVideo.fromRow,
            wrap: (m) {
              if (m case final TestMorphVideo v) return VideoCommentable(v);
              throw StateError('Expected TestMorphVideo');
            },
          ),
        },
      );
      final rows = await adapter.select(
        const QueryDescriptor(table: 'comments'),
      );
      expect(rows, hasLength(3));
      final comments = <_Comment>[
        for (final row in rows) _Comment.fromRow(row),
      ];
      final result = await relation.load(adapter, comments);
      expect(result.stats.queriesExecuted, 2);
      for (final c in comments) {
        result.setOnParent(c);
      }
      // Pattern match — no `dynamic`, no `as` casts.
      final postComment = comments.firstWhere((c) => c.commentId == 100);
      final target = postComment.relations['commentable'];
      expect(target, isA<Commentable>());
      final label = switch (target) {
        PostCommentable(:final post) => 'post:${post.title}',
        VideoCommentable(:final video) => 'video:${video.title}',
        _ => 'unknown',
      };
      expect(label, 'post:Hello Post');

      final videoComment = comments.firstWhere((c) => c.commentId == 101);
      final t2 = videoComment.relations['commentable'];
      final label2 = switch (t2) {
        PostCommentable(:final post) => 'post:${post.title}',
        VideoCommentable(:final video) => 'video:${video.title}',
        _ => 'unknown',
      };
      expect(label2, 'video:Funny Video');
    });
  });
}
