import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../shared/enums.dart';
import 'user.dart';

part 'user_attachment.beak.dart';

/// The user-attachments resource — downloadable files on a profile.
@Resource(timestamps: true)
final class UserAttachment extends BeakSchema {
  /// The owning user.
  @BelongsTo()
  late final User? user;

  /// File name.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(160)])
  late final String name;

  /// The kind of file.
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
  @FileField(storagePath: 'users/files')
  late final BeakFileRef? file;
}
