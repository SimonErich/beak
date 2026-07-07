import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// The access a file share grants.
enum SharePermission {
  /// Read only.
  view,

  /// Read and comment.
  comment,

  /// Read and edit.
  edit,
}

/// Typed columns of the file-shares resource — who a file is shared with,
/// carrying the granted permission.
abstract final class FileShareColumns {
  /// The shared file.
  static const fileId = BeakStringColumn(
    key: 'file_id',
    label: 'File',
    visibleOn: {BeakContext.form},
  );

  /// The user the file is shared with.
  static const sharedWithId = BeakStringColumn(
    key: 'shared_with_id',
    label: 'Shared with',
    visibleOn: {BeakContext.form},
  );

  /// The granted permission.
  static const permission = BeakEnumColumn<SharePermission>(
    key: 'permission',
    label: 'Permission',
    values: SharePermission.values,
    defaultValue: SharePermission.view,
    filterable: true,
    badgeColors: {
      SharePermission.view: BeakColor.muted,
      SharePermission.comment: BeakColor.info,
      SharePermission.edit: BeakColor.success,
    },
  );

  /// When the file was shared.
  static const sharedAt = BeakDateTimeColumn(
    key: 'shared_at',
    label: 'Shared',
    format: BeakDateFormat.relative,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    fileId,
    sharedWithId,
    permission,
    sharedAt,
  ];
}

/// Typed relationships of the file-shares resource.
abstract final class FileShareRelations {
  /// The shared file.
  static const file = BeakBelongsTo(
    key: 'file',
    label: 'File',
    relatedTable: 'files',
    displayColumnKey: 'name',
    foreignKey: 'file_id',
    searchColumnKeys: ['name'],
  );

  /// The user the file is shared with.
  static const sharedWith = BeakBelongsTo(
    key: 'shared_with',
    label: 'Shared with',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'shared_with_id',
    searchColumnKeys: ['name'],
  );
}

/// The file-shares resource — a file granted to a user with a permission.
final class FileShareModel extends BeakModel {
  /// Creates the file-shares model.
  const FileShareModel();

  @override
  String get table => 'file_shares';

  @override
  String get displayColumnKey => 'permission';

  @override
  List<BeakColumn> get columns => FileShareColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    FileShareRelations.file,
    FileShareRelations.sharedWith,
  ];
}
