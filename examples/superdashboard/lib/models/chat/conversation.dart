import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'chat_message.dart';
import 'conversation_participant.dart';

part 'conversation.beak.dart';

/// Whether a conversation is one-to-one or a group.
enum ConversationType {
  /// A one-to-one conversation.
  direct,

  /// A multi-participant group.
  group,
}

/// The conversations resource — a direct or group chat thread.
@Resource(timestamps: true)
final class Conversation extends BeakSchema {
  /// Direct or group.
  @Column(filterable: true, defaultValue: ConversationType.direct)
  @Badges({
    ConversationType.direct: BeakColor.primary,
    ConversationType.group: BeakColor.info,
  })
  late final ConversationType? type;

  /// Group title (null for direct conversations).
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(120)])
  late final String? title;

  /// Group description.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? description;

  /// Group avatar image.
  @Image(
    storagePath: 'chat/avatars',
    maxSizeInBytes: 5 * 1024 * 1024,
    allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
  )
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakImageRef? avatar;

  /// Timestamp of the most recent message.
  @Column(
    label: 'Last message',
    format: BeakDateFormat.relative,
    sortable: true,
  )
  late final DateTime? lastMessageAt;

  /// The messages in this conversation.
  @HasMany()
  late final List<ChatMessage> messages;

  /// The participants (as first-class membership records carrying role and
  /// unread state).
  @HasMany()
  late final List<ConversationParticipant> participants;
}
