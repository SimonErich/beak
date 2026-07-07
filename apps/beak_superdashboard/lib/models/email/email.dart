import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the emails resource.
abstract final class EmailColumns {
  /// The owning folder.
  static const folderId = BeakStringColumn(
    key: 'folder_id',
    label: 'Folder',
    visibleOn: {BeakContext.form},
  );

  /// The sender user, when internal.
  static const senderId = BeakStringColumn(
    key: 'sender_id',
    label: 'Sender',
    visibleOn: {BeakContext.form},
  );

  /// Sender display name.
  static const senderName = BeakStringColumn(
    key: 'sender_name',
    label: 'From',
    searchable: true,
    rules: [BeakMaxLength(120)],
  );

  /// Sender email address.
  static const senderEmail = BeakStringColumn(
    key: 'sender_email',
    label: 'From email',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Sender avatar URL.
  static const senderAvatar = BeakStringColumn(
    key: 'sender_avatar',
    label: 'Avatar',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Subject line.
  static const subject = BeakStringColumn(
    key: 'subject',
    label: 'Subject',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(200)],
  );

  /// Snippet preview.
  static const preview = BeakStringColumn(
    key: 'preview',
    label: 'Preview',
    visibleOn: {BeakContext.table},
    rules: [BeakMaxLength(255)],
  );

  /// Full body (rich text).
  static const body = BeakRichTextColumn(
    key: 'body',
    label: 'Body',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// When the email was sent.
  static const sentAt = BeakDateTimeColumn(
    key: 'sent_at',
    label: 'Sent',
    format: BeakDateFormat.relative,
    sortable: true,
  );

  /// Whether the email has been read.
  static const isRead = BeakBoolColumn(
    key: 'is_read',
    label: 'Read',
    filterable: true,
    trueLabel: 'Read',
    falseLabel: 'Unread',
  );

  /// Whether the email is starred.
  static const isStarred = BeakBoolColumn(
    key: 'is_starred',
    label: 'Starred',
    filterable: true,
  );

  /// Whether the email is flagged important.
  static const isImportant = BeakBoolColumn(
    key: 'is_important',
    label: 'Important',
    filterable: true,
  );

  /// Whether the email carries attachments.
  static const hasAttachments = BeakBoolColumn(
    key: 'has_attachments',
    label: 'Attachments',
    filterable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    folderId,
    senderId,
    senderName,
    senderEmail,
    senderAvatar,
    subject,
    preview,
    body,
    sentAt,
    isRead,
    isStarred,
    isImportant,
    hasAttachments,
  ];
}

/// Typed relationships of the emails resource.
abstract final class EmailRelations {
  /// The owning folder.
  static const folder = BeakBelongsTo(
    key: 'folder',
    label: 'Folder',
    relatedTable: 'mail_folders',
    displayColumnKey: 'label',
    foreignKey: 'folder_id',
  );

  /// The sender user, when internal.
  static const sender = BeakBelongsTo(
    key: 'sender',
    label: 'Sender',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'sender_id',
    searchColumnKeys: ['name', 'email'],
  );

  /// The labels applied to this email.
  static const labels = BeakBelongsToMany(
    key: 'labels',
    label: 'Labels',
    relatedTable: 'mail_labels',
    displayColumnKey: 'name',
    pivotTable: 'email_mail_label',
    foreignPivotKey: 'email_id',
    relatedPivotKey: 'mail_label_id',
  );

  /// The email's attachments.
  static const attachments = BeakHasMany(
    key: 'attachments',
    label: 'Attachments',
    relatedTable: 'email_attachments',
    displayColumnKey: 'name',
    foreignKey: 'email_id',
  );
}

/// The emails resource — a single message.
final class EmailModel extends BeakModel {
  /// Creates the emails model.
  const EmailModel();

  @override
  String get table => 'emails';

  @override
  String get displayColumnKey => 'subject';

  @override
  List<BeakColumn> get columns => EmailColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    EmailRelations.folder,
    EmailRelations.sender,
    EmailRelations.labels,
    EmailRelations.attachments,
  ];
}
