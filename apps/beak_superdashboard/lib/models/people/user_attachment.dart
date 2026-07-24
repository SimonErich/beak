import 'package:beak_core/beak_core.dart';

import '../shared/enums.dart';
import '../shared/shared_columns.dart';

/// Typed columns of the user-attachments resource — files on a profile.
abstract final class UserAttachmentColumns {
  /// The owning user.
  static const userId = BeakStringColumn(
    key: 'user_id',
    label: 'User',
    visibleOn: {BeakContext.form},
  );

  /// File name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(160)],
  );

  /// The kind of file.
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
    storagePath: 'users/files',
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    userId,
    name,
    kind,
    size,
    file,
    SharedColumns.createdAt,
  ];
}

/// Typed relationships of the user-attachments resource.
abstract final class UserAttachmentRelations {
  /// The owning user.
  static const user = BeakBelongsTo(
    key: 'user',
    label: 'User',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'user_id',
  );
}

/// The user-attachments resource — downloadable files on a profile.
final class UserAttachmentModel extends BeakModel {
  /// Creates the user-attachments model.
  const UserAttachmentModel();

  @override
  String get table => 'user_attachments';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => UserAttachmentColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    UserAttachmentRelations.user,
  ];
}
