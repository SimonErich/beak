import 'package:beak_core/beak_core.dart';

import '../shared/enums.dart';
import '../shared/shared_columns.dart';

/// Typed columns of the files resource — stored files in the file manager.
abstract final class ManagedFileColumns {
  /// File name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
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

  /// File extension.
  static const extension = BeakStringColumn(
    key: 'extension',
    label: 'Type',
    rules: [BeakMaxLength(12)],
  );

  /// Size in bytes.
  static const size = BeakIntColumn(
    key: 'size',
    label: 'Size',
    min: 0,
    sortable: true,
  );

  /// The owning folder.
  static const folderId = BeakStringColumn(
    key: 'folder_id',
    label: 'Folder',
    visibleOn: {BeakContext.form},
  );

  /// The owning user.
  static const ownerId = BeakStringColumn(
    key: 'owner_id',
    label: 'Owner',
    visibleOn: {BeakContext.form},
  );

  /// The stored file.
  static const file = BeakFileColumn(
    key: 'file',
    label: 'File',
    storagePath: 'files/store',
  );

  /// Whether the file is starred.
  static const starred = BeakBoolColumn(
    key: 'starred',
    label: 'Starred',
    filterable: true,
  );

  /// Last modification time.
  static const modifiedAt = BeakDateTimeColumn(
    key: 'modified_at',
    label: 'Modified',
    format: BeakDateFormat.relative,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    name,
    kind,
    extension,
    size,
    folderId,
    ownerId,
    file,
    starred,
    modifiedAt,
  ];
}

/// Typed relationships of the files resource.
abstract final class ManagedFileRelations {
  /// The owning folder.
  static const folder = BeakBelongsTo(
    key: 'folder',
    label: 'Folder',
    relatedTable: 'file_folders',
    displayColumnKey: 'name',
    foreignKey: 'folder_id',
    searchColumnKeys: ['name'],
  );

  /// The owning user.
  static const owner = BeakBelongsTo(
    key: 'owner',
    label: 'Owner',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'owner_id',
    searchColumnKeys: ['name'],
  );

  /// The shares of this file.
  static const shares = BeakHasMany(
    key: 'shares',
    label: 'Shares',
    relatedTable: 'file_shares',
    displayColumnKey: 'permission',
    foreignKey: 'file_id',
  );
}

/// The files resource — a stored file in the file manager.
final class ManagedFileModel extends BeakModel {
  /// Creates the files model.
  const ManagedFileModel();

  @override
  String get table => 'files';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => ManagedFileColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    ManagedFileRelations.folder,
    ManagedFileRelations.owner,
    ManagedFileRelations.shares,
  ];
}
