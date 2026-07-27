import 'package:beak_core/beak_core.dart';

import '../shared/enums.dart';
import '../shared/shared_columns.dart';

/// Typed columns of the email-attachments resource.
abstract final class EmailAttachmentColumns {
  /// The owning email.
  static const emailId = BeakStringColumn(
    key: 'email_id',
    label: 'Email',
    visibleOn: {BeakContext.form},
  );

  /// File name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(160)],
  );

  /// File kind.
  static const kind = BeakEnumColumn<AttachmentKind>(
    key: 'kind',
    label: 'Kind',
    values: AttachmentKind.values,
    defaultValue: AttachmentKind.document,
    filterable: true,
    badgeColors: {
      AttachmentKind.image: BeakColor.success,
      AttachmentKind.document: BeakColor.primary,
      AttachmentKind.pdf: BeakColor.error,
      AttachmentKind.video: BeakColor.info,
      AttachmentKind.audio: BeakColor.warning,
      AttachmentKind.archive: BeakColor.muted,
      AttachmentKind.spreadsheet: BeakColor.success,
      AttachmentKind.code: BeakColor.secondary,
    },
  );

  /// File size in bytes.
  static const size = BeakIntColumn(
    key: 'size',
    label: 'Size',
    min: 0,
    sortable: true,
  );

  /// The stored file.
  static const file = BeakFileColumn(
    key: 'file',
    label: 'File',
    storagePath: 'email/files',
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    emailId,
    name,
    kind,
    size,
    file,
  ];
}

/// Typed relationships of the email-attachments resource.
abstract final class EmailAttachmentRelations {
  /// The owning email.
  static const email = BeakBelongsTo(
    key: 'email',
    label: 'Email',
    relatedTable: 'emails',
    displayColumnKey: 'subject',
    foreignKey: 'email_id',
  );
}

/// The email-attachments resource — a file on an email.
final class EmailAttachmentModel extends BeakModel {
  /// Creates the email-attachments model.
  const EmailAttachmentModel();

  @override
  String get table => 'email_attachments';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => EmailAttachmentColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    EmailAttachmentRelations.email,
  ];
}
