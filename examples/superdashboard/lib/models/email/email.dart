import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../people/user.dart';
import 'email_attachment.dart';
import 'mail_folder.dart';
import 'mail_label.dart';

part 'email.beak.dart';

/// The emails resource — a single message.
@Resource()
final class Email extends BeakSchema {
  /// The owning folder.
  @BelongsTo()
  late final MailFolder? folder;

  /// The sender user, when internal.
  @BelongsTo(searchOn: ['name', 'email'])
  late final User? sender;

  /// Sender display name.
  @Column(label: 'From', searchable: true, rules: [BeakMaxLength(120)])
  late final String? senderName;

  /// Sender email address.
  @Column(
    label: 'From email',
    visibleOn: {BeakContext.form, BeakContext.detail},
  )
  late final String? senderEmail;

  /// Sender avatar URL.
  @Column(label: 'Avatar', visibleOn: {BeakContext.form, BeakContext.detail})
  late final String? senderAvatar;

  /// Subject line.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(200)])
  late final String subject;

  /// Snippet preview.
  @Column(visibleOn: {BeakContext.table}, rules: [BeakMaxLength(255)])
  late final String? preview;

  /// Full body (rich text).
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakRichText? body;

  /// When the email was sent.
  @Column(label: 'Sent', sortable: true, format: BeakDateFormat.relative)
  late final DateTime? sentAt;

  /// Whether the email has been read.
  @Column(
    label: 'Read',
    filterable: true,
    trueLabel: 'Read',
    falseLabel: 'Unread',
  )
  late final bool? isRead;

  /// Whether the email is starred.
  @Column(label: 'Starred', filterable: true)
  late final bool? isStarred;

  /// Whether the email is flagged important.
  @Column(label: 'Important', filterable: true)
  late final bool? isImportant;

  /// Whether the email carries attachments.
  @Column(label: 'Attachments', filterable: true)
  late final bool? hasAttachments;

  /// The labels applied to this email.
  @BelongsToMany()
  late final List<MailLabel> labels;

  /// The email's attachments.
  @HasMany()
  late final List<EmailAttachment> attachments;
}
