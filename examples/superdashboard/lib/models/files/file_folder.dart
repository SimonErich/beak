import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../people/user.dart';
import 'managed_file.dart';

part 'file_folder.beak.dart';

/// The file-folders resource — the file-manager folder tree.
@Resource(timestamps: true)
final class FileFolder extends BeakSchema {
  /// Folder name.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(160)])
  late final String name;

  /// The parent folder (self-referential).
  @BelongsTo()
  late final FileFolder? parent;

  /// Owning user.
  @BelongsTo()
  late final User? owner;

  /// Folder accent color.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakHexColor? color;

  /// Sub-folders (self-referential).
  @HasMany(label: 'Sub-folders', foreignKey: 'parent_id')
  late final List<FileFolder> children;

  /// Files directly inside this folder.
  @HasMany(foreignKey: 'folder_id')
  late final List<ManagedFile> files;
}
