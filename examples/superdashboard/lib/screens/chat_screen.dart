import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';
import 'package:beak/ui.dart';

/// The chat app — a message thread built from the seeded `chat_messages`,
/// each bubble labelled with its denormalized sender name. The composer
/// persists sent messages back into the same table, so they survive a
/// reload.
// --8<-- [start:buildChatScreen]
BeakScreen buildChatScreen() => const BeakScreen(
  path: '/chat',
  title: 'Chat',
  icon: BeakIconToken(OiIcons.messageCircle),
  section: 'Apps',
  framed: false,
  body: BeakChatBlock(
    model: ChatMessageModel(),
    authorField: ChatMessageColumns.senderName,
    bodyField: ChatMessageColumns.body,
    timeField: ChatMessageColumns.sentAt,
    composeRecord: _composeMessage,
  ),
);
// --8<-- [end:buildChatScreen]

/// Builds the record persisted when the demo user sends [body] from the
/// chat composer.
BeakRecord _composeMessage(String body) => BeakRecord.fromRow({
  'sender_name': 'You',
  'body': body,
  'sent_at': DateTime.now().toUtc(),
  'is_read': true,
});
