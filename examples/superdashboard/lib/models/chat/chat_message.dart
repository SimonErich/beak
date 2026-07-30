import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../people/user.dart';
import 'chat_attachment.dart';
import 'conversation.dart';

part 'chat_message.beak.dart';

/// The chat-messages resource — one message in a conversation.
@Resource()
final class ChatMessage extends BeakSchema {
  /// The owning conversation.
  @BelongsTo()
  late final Conversation? conversation;

  /// The sender.
  @BelongsTo()
  late final User? sender;

  /// Denormalized sender name, for rendering message bubbles without an
  /// extra lookup.
  @Column(
    label: 'From',
    searchable: true,
    visibleOn: {BeakContext.table, BeakContext.detail},
  )
  late final String? senderName;

  /// Message text.
  @Display()
  @Column(label: 'Message', searchable: true)
  late final BeakText body;

  /// When the message was sent.
  @Column(label: 'Sent', format: BeakDateFormat.relative, sortable: true)
  late final DateTime? sentAt;

  /// Whether the message has been read.
  @Column(label: 'Read', filterable: true)
  late final bool? isRead;

  /// The message's attachments.
  @HasMany(foreignKey: 'message_id')
  late final List<ChatAttachment> attachments;
}
