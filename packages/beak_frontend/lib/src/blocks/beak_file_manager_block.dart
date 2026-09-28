part of 'beak_block.dart';

/// A data-bound file manager: a model's folder and file records rendered on
/// `OiFileManager`, via typed field bindings.
///
/// [nameField] names each entry. [isFolderField] separates folders from
/// files where a table stores both; leave it unbound for a table that stores
/// only files, and every entry lists as a file. [sizeField], [modifiedField],
/// and [thumbnailField] enrich the file rows when bound. Opening an entry
/// calls [onOpen] with its [BeakRecord].
///
/// ```dart
/// BeakFileManagerBlock(
///   model: const AssetModel(),
///   nameField: AssetModel.name.column,
///   isFolderField: AssetModel.isFolder.column,
///   sizeField: AssetModel.sizeInBytes.column,
///   modifiedField: AssetModel.updatedAt.column,
///   onOpen: (record) => openedAsset.value = AssetModel.id.readFrom(record),
/// );
/// ```
final class BeakFileManagerBlock extends BeakBlock {
  /// Creates a file-manager block over [model].
  const BeakFileManagerBlock({
    required this.model,
    required this.nameField,
    this.isFolderField,
    this.sizeField,
    this.modifiedField,
    this.thumbnailField,
    this.label = 'Files',
    this.onOpen,
    super.span,
  });

  /// The model whose records become file/folder entries.
  final BeakModel model;

  /// Column supplying each entry's name.
  final BeakColumn nameField;

  /// Boolean column marking folder entries, when the table has both.
  final BeakColumn? isFolderField;

  /// Integer column supplying each file's size in bytes, when bound.
  final BeakColumn? sizeField;

  /// Column supplying each entry's last-modified instant, when bound.
  final BeakColumn? modifiedField;

  /// Column supplying each file's thumbnail URL, when bound.
  final BeakColumn? thumbnailField;

  /// Accessibility label for the manager.
  final String label;

  /// Invoked with the opened entry's record.
  final void Function(BeakRecord record)? onOpen;
}
