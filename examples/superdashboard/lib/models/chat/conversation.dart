import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Whether a conversation is one-to-one or a group.
enum ConversationType {
  /// A one-to-one conversation.
  direct,

  /// A multi-participant group.
  group,
}

/// Typed columns of the conversations resource.
abstract final class ConversationColumns {
  /// Direct or group.
  static const type = BeakEnumColumn<ConversationType>(
    key: 'type',
    label: 'Type',
    values: ConversationType.values,
    defaultValue: ConversationType.direct,
    filterable: true,
    badgeColors: {
      ConversationType.direct: BeakColor.primary,
      ConversationType.group: BeakColor.info,
    },
  );

  /// Group title (null for direct conversations).
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    searchable: true,
    rules: [BeakMaxLength(120)],
  );

  /// Group description.
  static const description = BeakTextColumn(
    key: 'description',
    label: 'Description',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Group avatar image.
  static const avatar = BeakImageColumn(
    key: 'avatar',
    label: 'Avatar',
    storagePath: 'chat/avatars',
    maxSizeInBytes: 5 * 1024 * 1024,
    allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Timestamp of the most recent message.
  static const lastMessageAt = BeakDateTimeColumn(
    key: 'last_message_at',
    label: 'Last message',
    format: BeakDateFormat.relative,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    type,
    title,
    description,
    avatar,
    lastMessageAt,
    SharedColumns.createdAt,
  ];
}

/// Typed relationships of the conversations resource.
abstract final class ConversationRelations {
  /// The messages in this conversation.
  static const messages = BeakHasMany(
    key: 'messages',
    label: 'Messages',
    relatedTable: 'chat_messages',
    displayColumnKey: 'body',
    foreignKey: 'conversation_id',
  );

  /// The participants (as first-class membership records carrying role and
  /// unread state).
  static const participants = BeakHasMany(
    key: 'participants',
    label: 'Participants',
    relatedTable: 'conversation_participants',
    displayColumnKey: 'role',
    foreignKey: 'conversation_id',
  );
}

/// The conversations resource — a direct or group chat thread.
final class ConversationModel extends BeakModel {
  /// Creates the conversations model.
  const ConversationModel();

  @override
  String get table => 'conversations';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => ConversationColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    ConversationRelations.messages,
    ConversationRelations.participants,
  ];
}
