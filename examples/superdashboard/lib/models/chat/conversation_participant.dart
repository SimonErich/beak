import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../people/user.dart';
import 'conversation.dart';

part 'conversation_participant.beak.dart';

/// The conversation-participants resource — a chat membership.
@Resource()
final class ConversationParticipant extends BeakSchema {
  /// The conversation.
  @BelongsTo()
  late final Conversation? conversation;

  /// The participating user.
  @BelongsTo()
  late final User? user;

  /// Membership role, e.g. `owner` or `member`.
  @Display()
  @Column(rules: [BeakMaxLength(30)])
  late final String? role;

  /// Unread message count for this participant.
  @Column(label: 'Unread', min: 0, sortable: true)
  late final int? unreadCount;

  /// When this participant last read the conversation.
  @Column(
    label: 'Last read',
    format: BeakDateFormat.relative,
    visibleOn: {BeakContext.detail},
  )
  late final DateTime? lastReadAt;
}
