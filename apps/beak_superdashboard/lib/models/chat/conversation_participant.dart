import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the conversation-participants resource — a first-class
/// pivot carrying membership data (role, unread state) a plain
/// belongs-to-many pivot could not.
abstract final class ConversationParticipantColumns {
  /// The conversation.
  static const conversationId = BeakStringColumn(
    key: 'conversation_id',
    label: 'Conversation',
    visibleOn: {BeakContext.form},
  );

  /// The participating user.
  static const userId = BeakStringColumn(
    key: 'user_id',
    label: 'User',
    visibleOn: {BeakContext.form},
  );

  /// Membership role, e.g. `owner` or `member`.
  static const role = BeakStringColumn(
    key: 'role',
    label: 'Role',
    rules: [BeakMaxLength(30)],
  );

  /// Unread message count for this participant.
  static const unreadCount = BeakIntColumn(
    key: 'unread_count',
    label: 'Unread',
    min: 0,
    sortable: true,
  );

  /// When this participant last read the conversation.
  static const lastReadAt = BeakDateTimeColumn(
    key: 'last_read_at',
    label: 'Last read',
    format: BeakDateFormat.relative,
    visibleOn: {BeakContext.detail},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    conversationId,
    userId,
    role,
    unreadCount,
    lastReadAt,
  ];
}

/// Typed relationships of the conversation-participants resource.
abstract final class ConversationParticipantRelations {
  /// The conversation.
  static const conversation = BeakBelongsTo(
    key: 'conversation',
    label: 'Conversation',
    relatedTable: 'conversations',
    displayColumnKey: 'title',
    foreignKey: 'conversation_id',
  );

  /// The participating user.
  static const user = BeakBelongsTo(
    key: 'user',
    label: 'User',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'user_id',
    searchColumnKeys: ['name'],
  );
}

/// The conversation-participants resource — a chat membership.
final class ConversationParticipantModel extends BeakModel {
  /// Creates the conversation-participants model.
  const ConversationParticipantModel();

  @override
  String get table => 'conversation_participants';

  @override
  String get displayColumnKey => 'role';

  @override
  List<BeakColumn> get columns => ConversationParticipantColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    ConversationParticipantRelations.conversation,
    ConversationParticipantRelations.user,
  ];
}
