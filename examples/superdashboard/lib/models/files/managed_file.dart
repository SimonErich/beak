import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../people/user.dart';
import '../shared/enums.dart';
import 'file_folder.dart';
import 'file_share.dart';

part 'managed_file.beak.dart';

/// The files resource — a stored file in the file manager.
@Resource(table: 'files')
final class ManagedFile extends BeakSchema {
  /// File name.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(160)])
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

  /// File extension.
  @Column(label: 'Type', rules: [BeakMaxLength(12)])
  late final String? extension;

  /// Size in bytes.
  @Column(min: 0, sortable: true)
  late final int? size;

  /// The owning folder.
  @BelongsTo()
  late final FileFolder? folder;

  /// The owning user.
  @BelongsTo()
  late final User? owner;

  /// The stored file.
  @FileField(storagePath: 'files/store')
  late final BeakFileRef? file;

  /// Whether the file is starred.
  @Column(filterable: true)
  late final bool? starred;

  /// Last modification time.
  @Column(label: 'Modified', format: BeakDateFormat.relative, sortable: true)
  late final DateTime? modifiedAt;

  /// The shares of this file.
  @HasMany(foreignKey: 'file_id')
  late final List<FileShare> shares;
}
