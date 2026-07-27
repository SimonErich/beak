import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the file-folders resource — a self-referential tree.
abstract final class FileFolderColumns {
  /// Folder name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(160)],
  );

  /// Parent folder (self-referential FK; null at the root).
  static const parentId = BeakStringColumn(
    key: 'parent_id',
    label: 'Parent',
    visibleOn: {BeakContext.form},
  );

  /// Owning user.
  static const ownerId = BeakStringColumn(
    key: 'owner_id',
    label: 'Owner',
    visibleOn: {BeakContext.form},
  );

  /// Folder accent color.
  static const color = BeakColorColumn(
    key: 'color',
    label: 'Color',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    name,
    parentId,
    ownerId,
    color,
    SharedColumns.createdAt,
    SharedColumns.updatedAt,
  ];
}

/// Typed relationships of the file-folders resource.
abstract final class FileFolderRelations {
  /// The parent folder (self-referential).
  static const parent = BeakBelongsTo(
    key: 'parent',
    label: 'Parent',
    relatedTable: 'file_folders',
    displayColumnKey: 'name',
    foreignKey: 'parent_id',
  );

  /// Sub-folders (self-referential).
  static const children = BeakHasMany(
    key: 'children',
    label: 'Sub-folders',
    relatedTable: 'file_folders',
    displayColumnKey: 'name',
    foreignKey: 'parent_id',
  );

  /// Files directly inside this folder.
  static const files = BeakHasMany(
    key: 'files',
    label: 'Files',
    relatedTable: 'files',
    displayColumnKey: 'name',
    foreignKey: 'folder_id',
  );

  /// Owning user.
  static const owner = BeakBelongsTo(
    key: 'owner',
    label: 'Owner',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'owner_id',
    searchColumnKeys: ['name'],
  );
}

/// The file-folders resource — the file-manager folder tree.
final class FileFolderModel extends BeakModel {
  /// Creates the file-folders model.
  const FileFolderModel();

  @override
  String get table => 'file_folders';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => FileFolderColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    FileFolderRelations.parent,
    FileFolderRelations.children,
    FileFolderRelations.files,
    FileFolderRelations.owner,
  ];
}
