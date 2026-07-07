import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_superdashboard/models/models.dart';
import 'package:obers_ui/obers_ui.dart';

/// The email inbox — a three-pane mailbox (folders, message list, preview)
/// built from the seeded `emails`.
BeakScreen buildEmailScreen() => const BeakScreen(
  path: '/email',
  title: 'Email',
  icon: BeakIconToken(OiIcons.mail),
  section: 'Apps',
  framed: false,
  body: BeakInboxBlock(
    model: EmailModel(),
    senderField: EmailColumns.senderName,
    subjectField: EmailColumns.subject,
    previewField: EmailColumns.preview,
    timeField: EmailColumns.sentAt,
    unreadField: EmailColumns.isRead,
    folders: ['Inbox', 'Starred', 'Sent', 'Drafts', 'Spam', 'Trash'],
  ),
);
