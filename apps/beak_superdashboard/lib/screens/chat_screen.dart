import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_superdashboard/models/models.dart';
import 'package:obers_ui/obers_ui.dart';

/// The chat app — a message thread built from the seeded `chat_messages`,
/// each bubble labelled with its denormalized sender name.
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
  ),
);
