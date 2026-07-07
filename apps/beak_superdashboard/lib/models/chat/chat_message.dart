import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the chat-messages resource.
abstract final class ChatMessageColumns {
  /// The owning conversation.
  static const conversationId = BeakStringColumn(
    key: 'conversation_id',
    label: 'Conversation',
    visibleOn: {BeakContext.form},
  );

  /// The sender.
  static const senderId = BeakStringColumn(
    key: 'sender_id',
    label: 'Sender',
    visibleOn: {BeakContext.form},
  );

  /// Message text.
  static const body = BeakTextColumn(
    key: 'body',
    label: 'Message',
    searchable: true,
    rules: [BeakRequired()],
  );

  /// When the message was sent.
  static const sentAt = BeakDateTimeColumn(
    key: 'sent_at',
    label: 'Sent',
    format: BeakDateFormat.relative,
    sortable: true,
  );

  /// Whether the message has been read.
  static const isRead = BeakBoolColumn(
    key: 'is_read',
    label: 'Read',
    filterable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    conversationId,
    senderId,
    body,
    sentAt,
    isRead,
  ];
}

/// Typed relationships of the chat-messages resource.
abstract final class ChatMessageRelations {
  /// The owning conversation.
  static const conversation = BeakBelongsTo(
    key: 'conversation',
    label: 'Conversation',
    relatedTable: 'conversations',
    displayColumnKey: 'title',
    foreignKey: 'conversation_id',
  );

  /// The sender.
  static const sender = BeakBelongsTo(
    key: 'sender',
    label: 'Sender',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'sender_id',
    searchColumnKeys: ['name'],
  );

  /// The message's attachments.
  static const attachments = BeakHasMany(
    key: 'attachments',
    label: 'Attachments',
    relatedTable: 'chat_attachments',
    displayColumnKey: 'name',
    foreignKey: 'message_id',
  );
}

/// The chat-messages resource — one message in a conversation.
final class ChatMessageModel extends BeakModel {
  /// Creates the chat-messages model.
  const ChatMessageModel();

  @override
  String get table => 'chat_messages';

  @override
  String get displayColumnKey => 'body';

  @override
  List<BeakColumn> get columns => ChatMessageColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    ChatMessageRelations.conversation,
    ChatMessageRelations.sender,
    ChatMessageRelations.attachments,
  ];
}
