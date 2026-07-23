import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_superdashboard/models/models.dart';
import 'package:obers_ui/obers_ui.dart';

/// The email inbox — a three-pane mailbox (folders, message list, preview)
/// built from the seeded `emails`. The folder rail is data-driven through the
/// `folder` relation (selecting one filters the list), and unread mail is
/// marked via the read flag.
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
    readField: EmailColumns.isRead,
    folderRelation: EmailRelations.folder,
    folderLabelField: MailFolderColumns.label,
    folders: ['Inbox', 'Starred', 'Sent', 'Drafts', 'Spam', 'Trash'],
  ),
);
