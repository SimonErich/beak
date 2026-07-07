import 'package:beak_superdashboard/models/models.dart';

import 'seed_context.dart';
import 'seed_ids.dart';

/// Seeds the Chat domain: group and direct conversations, their memberships,
/// and message threads (with each conversation's last-message time derived
/// from its messages).
final class ChatSeeder {
  /// Creates the seeder.
  const ChatSeeder();

  static const List<String> _groupTitles = [
    'General',
    'Reporting',
    'Project A',
    'Design Guild',
  ];

  static const List<String> _snippets = [
    'Just pushed the latest changes.',
    'Can you review the mockups?',
    'The numbers look great this week.',
    'Let us sync tomorrow morning.',
    'Thanks, that fixed it!',
    'I will send the report shortly.',
    'Great work on the release.',
    'Any blockers on your side?',
  ];

  /// Seeds all Chat-domain rows through [ctx].
  Future<void> seed(SeedContext ctx) async {
    final conversationRows = <Map<String, Object?>>[];
    final participantRows = <Map<String, Object?>>[];
    final messageRows = <Map<String, Object?>>[];
    final attachmentRows = <Map<String, Object?>>[];

    // Read the seeded users so each message carries a denormalized sender
    // name (chat bubbles render without a per-message lookup).
    final users = await ctx.selectAll('users');
    final nameById = <Object?, String>{
      for (final user in users) user['id']: user['name']! as String,
    };

    void seedConversation({
      required String id,
      required ConversationType type,
      required String? title,
      required List<String> members,
    }) {
      DateTime lastAt = ctx.daysAgo(20);
      final messageCount = ctx.between(6, 16);
      for (var index = 0; index < messageCount; index++) {
        final sentAt = ctx.daysAgo(18 - (index ~/ 2).clamp(0, 17));
        if (sentAt.isAfter(lastAt)) {
          lastAt = sentAt;
        }
        final messageId = ctx.uuid();
        final senderId = ctx.pick(members);
        messageRows.add({
          'id': messageId,
          'conversation_id': id,
          'sender_id': senderId,
          'sender_name': nameById[senderId],
          'body': ctx.pick(_snippets),
          'sent_at': sentAt,
          'is_read': ctx.chance(0.7),
        });
        if (ctx.chance(0.15)) {
          attachmentRows.add({
            'id': ctx.uuid(),
            'message_id': messageId,
            'name': ctx.pick(const ['photo.png', 'draft.pdf', 'clip.mp4']),
            'kind': ctx.pick([
              AttachmentKind.image,
              AttachmentKind.pdf,
              AttachmentKind.video,
            ]).name,
            'size': ctx.between(80_000, 3_200_000),
            'url': 'chat/files/$messageId',
          });
        }
      }
      for (var index = 0; index < members.length; index++) {
        participantRows.add({
          'id': ctx.uuid(),
          'conversation_id': id,
          'user_id': members[index],
          'role': index == 0 ? 'owner' : 'member',
          'unread_count': ctx.between(0, 4),
          'last_read_at': ctx.daysAgo(5),
        });
      }
      conversationRows.add({
        'id': id,
        'type': type.name,
        'title': title,
        'description': type == ConversationType.group
            ? ctx.faker.sentence(wordCount: 6)
            : null,
        'avatar': type == ConversationType.group
            ? ctx.faker.imageUrl(width: 96, height: 96)
            : null,
        'last_message_at': lastAt,
        'created_at': ctx.daysAgo(120),
      });
    }

    for (final title in _groupTitles) {
      final members = [...SeedIds.heroUsers]..shuffle(ctx.faker.random);
      seedConversation(
        id: ctx.uuid(),
        type: ConversationType.group,
        title: title,
        members: members.take(ctx.between(3, 6)).toList(),
      );
    }
    for (var index = 0; index < 6; index++) {
      seedConversation(
        id: ctx.uuid(),
        type: ConversationType.direct,
        title: null,
        members: [
          SeedIds.userAisha,
          SeedIds.heroUsers[ctx.between(1, SeedIds.heroUsers.length - 1)],
        ],
      );
    }

    await ctx.insertMany('conversations', conversationRows);
    await ctx.insertMany('conversation_participants', participantRows);
    await ctx.insertMany('chat_messages', messageRows);
    await ctx.insertMany('chat_attachments', attachmentRows);
  }
}
