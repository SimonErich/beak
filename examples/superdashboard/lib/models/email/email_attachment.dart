import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../shared/enums.dart';
import 'email.dart';

part 'email_attachment.beak.dart';

/// The email-attachments resource — a file on an email.
@Resource()
final class EmailAttachment extends BeakSchema {
  /// The owning email.
  @BelongsTo()
  late final Email? email;

  /// File name.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(160)])
  late final String name;

  /// File kind.
  @Column(filterable: true, defaultValue: AttachmentKind.document)
  @Badges({
    AttachmentKind.image: BeakColor.success,
    AttachmentKind.document: BeakColor.primary,
    AttachmentKind.pdf: BeakColor.error,
    AttachmentKind.video: BeakColor.info,
    AttachmentKind.audio: BeakColor.warning,
    AttachmentKind.archive: BeakColor.muted,
    AttachmentKind.spreadsheet: BeakColor.success,
    AttachmentKind.code: BeakColor.secondary,
  })
  late final AttachmentKind? kind;

  /// File size in bytes.
  @Column(sortable: true, min: 0)
  late final int? size;

  /// The stored file.
  @FileField(storagePath: 'email/files')
  late final BeakFileRef? file;
}
