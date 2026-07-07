part of '../beak_block_host.dart';

/// Fetches a [BeakFileManagerBlock]'s records, maps each to an [OiFileNode],
/// and renders them on `OiFileManager` — resolving opens back to the record.
class _BeakFileManagerBlockView extends HookWidget {
  const _BeakFileManagerBlockView({required this.block});

  final BeakFileManagerBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakLocator<BeakDataSource>();
    final records = useState(const <BeakRecord>[]);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final result = await BeakResourceRepository(
          dataSource,
        ).query(BeakQuerySpec(table: block.model.table));
        if (cancelled) {
          return;
        }
        if (result case BeakOk(:final value)) {
          records.value = value.items;
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, block]);

    final byKey = <Object, BeakRecord>{
      for (final record in records.value)
        if (block.model.primaryKeyOf(record) case final Object id) id: record,
    };

    return OiFileManager(
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
    );
  }
}
