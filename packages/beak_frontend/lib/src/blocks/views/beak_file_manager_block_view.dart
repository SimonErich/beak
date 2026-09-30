part of '../beak_block_host.dart';

/// Fetches a [BeakFileManagerBlock]'s records, maps each to an [OiFileNode],
/// and renders them on `OiFileManager` — resolving opens back to the record.
class _BeakFileManagerBlockView extends HookWidget {
  const _BeakFileManagerBlockView({required this.block});

  final BeakFileManagerBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final rows = _useModuleRows(
      dataSource,
      BeakQuerySpec(
        table: block.model.table,
        filter: block.filter,
        pagination: _modulePage,
      ),
    );

    final byKey = <Object, BeakRecord>{
      for (final record in rows.value.records)
        if (block.model.primaryKeyOf(record) case final Object id) id: record,
    };

    return _withTruncationNote(
      context,
      rows.value,
      OiFileManager(
        label: block.label,
        items: [
          for (final MapEntry(key: id, value: record) in byKey.entries)
            OiFileNode(
              key: id,
              name: _readString(record, block.nameField) ?? '',
              folder: _readBool(record, block.isFolderField),
              size: _readInt(record, block.sizeField),
              modified: _readDateTime(record, block.modifiedField),
              thumbnailUrl: _readString(record, block.thumbnailField),
            ),
        ],
        onOpen: block.onOpen == null
            ? null
            : (node) {
                if (byKey[node.key] case final BeakRecord record) {
                  block.onOpen!(record);
                }
              },
      ),
    );
  }
}
