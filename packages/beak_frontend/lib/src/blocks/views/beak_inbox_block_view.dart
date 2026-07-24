part of '../beak_block_host.dart';

/// Fetches a [BeakInboxBlock]'s records and lays them out as a folder rail, a
/// message list (`OiListView` of `OiListTile`s), and a detail pane bound to
/// the selected row — all inside `OiThreeColumnLayout`.
///
/// With [BeakInboxBlock.folderRelation] bound the rail is data-driven — one
/// entry per distinct related folder label — and selecting an entry filters
/// the list to that folder's rows. Unread rows (per `unreadField`/`readField`)
/// carry a leading dot marker.
class _BeakInboxBlockView extends HookWidget {
  const _BeakInboxBlockView({required this.block});

  final BeakInboxBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakLocator<BeakDataSource>();
    final records = useState(const <BeakRecord>[]);
    final selectedRow = useState<BeakRecord?>(null);
    final selectedFolder = useState<String?>(null);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        // Newest-first so that if the mailbox ever exceeds the page, it is
        // the oldest mail that falls off — never the latest.
        final result = await BeakResourceRepository(dataSource).query(
          BeakQuerySpec(
            table: block.model.table,
            sorts: [
              if (block.timeField case final BeakColumn column)
                BeakSort(column.key, descending: true),
            ],
            relationLoads: [
              if (block.folderRelation case final BeakBelongsTo relation)
                BeakRelationLoad(relation.key),
            ],
            pagination: _modulePage,
          ),
        );
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

    final List<String> folders = _folderLabels(records.value);
    final List<BeakRecord> visible = [
      for (final record in records.value)
        if (selectedFolder.value == null ||
            _folderOf(record) == selectedFolder.value)
          record,
    ];

    return OiThreeColumnLayout(
      label: block.label,
      leftColumnWidth: block.leftWidthInPixels,
      rightColumnWidth: block.rightWidthInPixels,
      leftColumn: _folders(context, folders, selectedFolder),
      middleColumn: _messages(visible, selectedRow),
      rightColumn: _detail(context, selectedRow.value),
    );
  }

  /// Whether the rail filters (a folder relation is bound) or is static.
  bool get _railFilters =>
      block.folderRelation != null && block.folderLabelField != null;

  /// The related folder label of [record], or `null` when unbound/unloaded.
  String? _folderOf(BeakRecord record) {
    final BeakBelongsTo? relation = block.folderRelation;
    final BeakColumn? label = block.folderLabelField;
    if (relation == null || label == null) {
      return null;
    }
    final related = record.relations[relation.key] ?? const <BeakRecord>[];
    return related.isEmpty ? null : _readString(related.first, label);
  }

  /// The rail entries: the distinct folder labels present in the data when
  /// the relation is bound (ordered by [BeakInboxBlock.folders] first, then
  /// first-seen), else the static [BeakInboxBlock.folders].
  List<String> _folderLabels(List<BeakRecord> records) {
    if (!_railFilters) {
      return block.folders;
    }
    final seen = <String>[];
    for (final record in records) {
      final String? label = _folderOf(record);
      if (label != null && !seen.contains(label)) {
        seen.add(label);
      }
    }
    return [
      for (final preferred in block.folders)
        if (seen.contains(preferred)) preferred,
      for (final label in seen)
        if (!block.folders.contains(label)) label,
    ];
  }

  Widget _folders(
    BuildContext context,
    List<String> folders,
    ValueNotifier<String?> selected,
  ) => SingleChildScrollView(
    child: OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final folder in folders)
          OiListTile(
            title: folder,
            selected: folder == selected.value,
            onTap: () => selected.value = _railFilters
                ? (selected.value == folder ? null : folder)
                : folder,
          ),
      ],
    ),
  );

  /// Whether [record] is unread, honoring whichever convention is bound.
  bool _isUnread(BeakRecord record) {
    if (block.unreadField case final BeakColumn column) {
      return _readBool(record, column);
    }
    if (block.readField case final BeakColumn column) {
      return !_readBool(record, column);
    }
    return false;
  }

  Widget _messages(
    List<BeakRecord> records,
    ValueNotifier<BeakRecord?> selected,
  ) => OiListView<BeakRecord>(
    label: '${block.label} messages',
    items: records,
    itemKey: (record) =>
        block.model.primaryKeyOf(record) ?? identityHashCode(record),
    itemBuilder: (record) => OiListTile(
      leading: _isUnread(record)
          ? const OiIcon.decorative(icon: OiIcons.circleSmall, size: 10)
          : null,
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
    final BeakColumn? column = block.timeField;
    if (column == null) {
      return null;
    }
    final Object? raw = record[column.key]?.raw;
    return raw == null ? null : OiLabel.small(beakCellText(column, raw));
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
            OiKeyValue(
              label: column.label,
              value: beakCellText(column, record[column.key]?.raw),
            ),
        ],
      ),
    );
  }
}
