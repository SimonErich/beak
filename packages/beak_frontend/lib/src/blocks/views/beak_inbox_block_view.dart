part of '../beak_block_host.dart';

/// Fetches a [BeakInboxBlock]'s records and lays them out as a folder rail, a
/// message list (`OiListView` of `OiListTile`s), and a detail pane bound to
/// the selected row — all inside `OiThreeColumnLayout`.
class _BeakInboxBlockView extends HookWidget {
  const _BeakInboxBlockView({required this.block});

  final BeakInboxBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakLocator<BeakDataSource>();
    final records = useState(const <BeakRecord>[]);
    final selectedRow = useState<BeakRecord?>(null);
    final selectedFolder = useState(block.folders.first);

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

    return OiThreeColumnLayout(
      label: block.label,
      leftColumnWidth: block.leftWidthInPixels,
      rightColumnWidth: block.rightWidthInPixels,
      leftColumn: _folders(context, selectedFolder),
      middleColumn: _messages(records.value, selectedRow),
      rightColumn: _detail(context, selectedRow.value),
    );
  }

  Widget _folders(BuildContext context, ValueNotifier<String> selected) =>
      SingleChildScrollView(
        child: OiColumn(
          breakpoint: context.breakpoint,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final folder in block.folders)
              OiListTile(
                title: folder,
                selected: folder == selected.value,
                onTap: () => selected.value = folder,
              ),
          ],
        ),
      );

  Widget _messages(
    List<BeakRecord> records,
    ValueNotifier<BeakRecord?> selected,
  ) => OiListView<BeakRecord>(
    label: '${block.label} messages',
    items: records,
    itemKey: (record) =>
        block.model.primaryKeyOf(record) ?? identityHashCode(record),
    itemBuilder: (record) => OiListTile(
      title: _readString(record, block.subjectField) ?? '',
      subtitle:
          _readString(record, block.previewField) ??
          _readString(record, block.senderField),
      trailing: _timeLabel(record),
      selected: identical(record, selected.value),
      onTap: () => selected.value = record,
    ),
  );

  Widget? _timeLabel(BeakRecord record) {
    final String? time = _readString(record, block.timeField);
    return time == null ? null : OiLabel.small(time);
  }

  Widget _detail(BuildContext context, BeakRecord? record) {
    if (record == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: OiLabel.body('Select a message'),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OiKeyValue.group(
        title: _readString(record, block.subjectField),
        children: [
          OiKeyValue(
            label: block.senderField.label,
            value: _readString(record, block.senderField),
          ),
          if (block.previewField case final BeakColumn column)
            OiKeyValue(label: column.label, value: _readString(record, column)),
          if (block.timeField case final BeakColumn column)
            OiKeyValue(label: column.label, value: _readString(record, column)),
        ],
      ),
    );
  }
}
