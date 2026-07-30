import 'package:superdashboard/models/models.dart';

import 'seed_context.dart';
import 'seed_ids.dart';

/// One mail folder definition.
typedef _Folder = ({String key, String label, String icon, String color});

/// Seeds the Email domain: folders (with unread counts derived from the
/// seeded messages), labels, ~50 emails, and their attachments.
final class EmailSeeder {
  /// Creates the seeder.
  const EmailSeeder();

  static const List<_Folder> _folders = [
    (key: 'inbox', label: 'Inbox', icon: 'inbox', color: '#4f46e5'),
    (key: 'starred', label: 'Starred', icon: 'star', color: '#f59e0b'),
    (key: 'sent', label: 'Sent', icon: 'send', color: '#0ea5e9'),
    (key: 'draft', label: 'Drafts', icon: 'file', color: '#8b5cf6'),
    (key: 'spam', label: 'Spam', icon: 'shield', color: '#ef4444'),
    (key: 'trash', label: 'Trash', icon: 'trash', color: '#6b7280'),
  ];

  static const List<String> _labelNames = [
    'Theme Support',
    'Freelance',
    'Social',
    'Work',
  ];

  static const List<String> _subjects = [
    'Your invoice is ready',
    'Weekly design review',
    'Re: Project kickoff',
    'New comment on your file',
    'Payment received — thank you',
    'Meeting notes and next steps',
    'Feature request from a customer',
    'Reminder: subscription renews soon',
    'Welcome to the team!',
    'Your export has finished',
  ];

  /// Seeds all Email-domain rows through [ctx].
  Future<void> seed(SeedContext ctx) async {
    final folderIdByKey = <String, String>{
      for (final folder in _folders) folder.key: ctx.uuid(),
    };
    final labelIds = <String>[];
    final labelRows = <Map<String, Object?>>[];
    for (var index = 0; index < _labelNames.length; index++) {
      final id = ctx.uuid();
      labelIds.add(id);
      labelRows.add({
        'id': id,
        'name': _labelNames[index],
        'color': ctx.faker.hexColor(),
      });
    }
    await ctx.insertMany('mail_labels', labelRows);

    final emailRows = <Map<String, Object?>>[];
    final attachmentRows = <Map<String, Object?>>[];
    final pivotRows = <Map<String, Object?>>[];
    final unreadByFolder = <String, int>{
      for (final folder in _folders) folder.key: 0,
    };

    for (var index = 0; index < 50; index++) {
      final id = ctx.uuid();
      final folderKey = ctx.weighted({
        'inbox': 10,
        'sent': 3,
        'starred': 2,
        'draft': 2,
        'spam': 1,
        'trash': 1,
      });
      final isRead = ctx.chance(0.6);
      if (!isRead) {
        unreadByFolder[folderKey] = unreadByFolder[folderKey]! + 1;
      }
      final hasAttachments = ctx.chance(0.35);
      final senderName = ctx.faker.name();

      emailRows.add({
        'id': id,
        'folder_id': folderIdByKey[folderKey],
        'sender_id': ctx.chance(0.4) ? ctx.pick(SeedIds.heroUsers) : null,
        'sender_name': senderName,
        'sender_email': ctx.faker.email(),
        'sender_avatar': ctx.faker.avatarUrl(),
        'subject': ctx.pick(_subjects),
        'preview': ctx.faker.sentence(wordCount: ctx.between(8, 16)),
        'body': ctx.faker.paragraph(sentenceCount: ctx.between(2, 5)),
        'sent_at': ctx.daysAgo(40),
        'is_read': isRead,
        'is_starred': folderKey == 'starred' || ctx.chance(0.2),
        'is_important': ctx.chance(0.25),
        'has_attachments': hasAttachments,
      });

      if (hasAttachments) {
        attachmentRows.add({
          'id': ctx.uuid(),
          'email_id': id,
          'name': ctx.pick(const ['brief.pdf', 'assets.zip', 'report.xlsx']),
          'kind': ctx.pick([
            AttachmentKind.pdf,
            AttachmentKind.archive,
            AttachmentKind.spreadsheet,
          ]).name,
          'size': ctx.between(120_000, 4_800_000),
          'file': 'email/files/$id',
        });
      }
      if (ctx.chance(0.4)) {
        pivotRows.add({'email_id': id, 'mail_label_id': ctx.pick(labelIds)});
      }
    }

    final folderRows = <Map<String, Object?>>[
      for (var index = 0; index < _folders.length; index++)
        {
          'id': folderIdByKey[_folders[index].key],
          'key': _folders[index].key,
          'label': _folders[index].label,
          'icon': _folders[index].icon,
          'color': _folders[index].color,
          'unread_count': unreadByFolder[_folders[index].key],
          'sort_index': index,
        },
    ];

    await ctx.insertMany('mail_folders', folderRows);
    await ctx.insertMany('emails', emailRows);
    await ctx.insertMany('email_attachments', attachmentRows);
    await ctx.insertMany('email_mail_label', pivotRows);
  }
}
