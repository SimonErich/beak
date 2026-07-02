/// Shared fixtures for EPIC-003 acceptance-criteria tests.
library;

import 'package:worm/worm.dart';

/// Test user; lives in the `users` table.
final class TUser extends Model {
  /// Creates a [TUser].
  TUser({required this.userId, required this.name});

  /// Hydrates from a raw row.
  factory TUser.fromRow(Map<String, Object?> row) {
    final id = row['id'];
    final name = row['name'];
    return TUser(userId: id is int ? id : 0, name: name is String ? name : '');
  }

  /// Integer primary key.
  final int userId;

  /// User display name.
  final String name;

  @override
  Object get id => userId;

  @override
  String? get tableName => 'users';

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{'id': userId, 'name': name};
}

/// Test post; FK `user_id` references `users.id`.
final class TPost extends Model {
  /// Creates a [TPost].
  TPost({
    required this.postId,
    required this.userId,
    required this.title,
    this.published = false,
  });

  /// Hydrates from a raw row.
  factory TPost.fromRow(Map<String, Object?> row) {
    final id = row['id'];
    final uid = row['user_id'];
    final title = row['title'];
    final published = row['published'];
    return TPost(
      postId: id is int ? id : 0,
      userId: uid is int ? uid : 0,
      title: title is String ? title : '',
      published: published is bool ? published : false,
    );
  }

  /// Integer primary key.
  final int postId;

  /// Foreign key to [TUser.userId].
  int userId;

  /// Post title.
  final String title;

  /// Whether the post is published.
  final bool published;

  @override
  Object get id => postId;

  @override
  String? get tableName => 'posts';

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': postId,
    'user_id': getAttribute('user_id') ?? userId,
    'title': title,
    'published': published,
  };

  @override
  void setAttribute(String name, Object? value) {
    if (name == 'user_id' && value is int) userId = value;
    super.setAttribute(name, value);
  }
}

/// Test article owned by an author (`author_id` is a nullable FK
/// to [TUser.userId]). Designed so accessor tests can null the FK
/// without an in-memory fallback masking the change.
final class TArticle extends Model {
  /// Creates a [TArticle].
  TArticle({required this.articleId, required this.title, this.authorId});

  /// Hydrates from a raw row.
  factory TArticle.fromRow(Map<String, Object?> row) {
    final id = row['id'];
    final aid = row['author_id'];
    final title = row['title'];
    return TArticle(
      articleId: id is int ? id : 0,
      authorId: aid is int ? aid : null,
      title: title is String ? title : '',
    );
  }

  /// Integer primary key.
  final int articleId;

  /// Nullable foreign key to [TUser.userId].
  int? authorId;

  /// Article title.
  final String title;

  @override
  Object get id => articleId;

  @override
  String? get tableName => 'articles';

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': articleId,
    'author_id': state.attributes.containsKey('author_id')
        ? getAttribute('author_id')
        : authorId,
    'title': title,
  };

  @override
  void setAttribute(String name, Object? value) {
    if (name == 'author_id') {
      authorId = value is int ? value : null;
    }
    super.setAttribute(name, value);
  }
}

/// Test role; many-to-many with [TUser] via `role_user`.
final class TRole extends Model {
  /// Creates a [TRole].
  TRole({required this.roleId, required this.name});

  /// Hydrates from a raw row.
  factory TRole.fromRow(Map<String, Object?> row) {
    final id = row['id'];
    final name = row['name'];
    return TRole(roleId: id is int ? id : 0, name: name is String ? name : '');
  }

  /// Integer primary key.
  final int roleId;

  /// Role name.
  final String name;

  @override
  Object get id => roleId;

  @override
  String? get tableName => 'roles';

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{'id': roleId, 'name': name};
}

/// Test video; minimal morph-target fixture used by polymorphic
/// registry tests where only the model `Type` matters.
final class TVideo extends Model {
  /// Creates a [TVideo].
  TVideo({required this.videoId});

  /// Integer primary key.
  final int videoId;

  @override
  Object get id => videoId;

  @override
  String? get tableName => 'videos';

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{'id': videoId};
}

/// Test model intentionally never registered with the morph registry,
/// for asserting "unknown type" error paths.
final class TUnregistered extends Model {
  /// Creates a [TUnregistered].
  TUnregistered({required this.recordId});

  /// Integer primary key.
  final int recordId;

  @override
  Object get id => recordId;

  @override
  String? get tableName => 'unregistered';

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{'id': recordId};
}

/// Test comment owned by a post.
final class TComment extends Model {
  /// Creates a [TComment].
  TComment({required this.commentId, required this.postId, required this.body});

  /// Hydrates from a raw row.
  factory TComment.fromRow(Map<String, Object?> row) {
    final id = row['id'];
    final pid = row['post_id'];
    final body = row['body'];
    return TComment(
      commentId: id is int ? id : 0,
      postId: pid is int ? pid : 0,
      body: body is String ? body : '',
    );
  }

  /// Integer primary key.
  final int commentId;

  /// Foreign key to [TPost.postId].
  final int postId;

  /// Comment body.
  final String body;

  @override
  Object get id => commentId;

  @override
  String? get tableName => 'comments';

  @override
  bool get usesTimestamps => false;

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': commentId,
    'post_id': postId,
    'body': body,
  };
}
