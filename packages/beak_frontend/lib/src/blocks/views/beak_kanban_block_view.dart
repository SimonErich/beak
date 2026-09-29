part of '../beak_block_host.dart';

/// Fetches a [BeakKanbanBlock]'s records, groups them into one `OiKanban`
/// column per enum value, and persists a card's new group on drop.
class _BeakKanbanBlockView extends HookWidget {
  const _BeakKanbanBlockView({required this.block});

  final BeakKanbanBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final rows = _useModuleRows(
      dataSource,
      BeakQuerySpec(
        table: block.model.table,
        filter: block.filter,
        sorts: [
          if (block.sortField case final BeakColumn column)
            BeakSort(column.key, descending: block.sortDescending),
        ],
        pagination: _modulePage,
      ),
    );

    final BeakEnumColumn<Enum> groupField = block.groupColumn;
    final columns = <OiKanbanColumn<BeakRecord>>[
      for (final value in groupField.values)
        OiKanbanColumn<BeakRecord>(
          key: value.name,
          title: groupField.labelFor(value),
          color: _resolveBeakColor(context, groupField.badgeColorFor(value)),
          items: [
            for (final record in rows.value.records)
              if (_readString(record, groupField) == value.name) record,
          ],
        ),
    ];

    return _withTruncationNote(
      context,
      rows.value,
      OiKanban<BeakRecord>(
        label: block.label,
        columns: columns,
        cardKey: (record) =>
            block.model.primaryKeyOf(record) ?? identityHashCode(record),
        cardBuilder: (record) => _card(context, record),
        onCardMove: (record, from, to, index) async {
          final Enum? target = groupField.valueByName(to.toString());
          final Object? id = block.model.primaryKeyOf(record);
          if (target == null || id == null) {
            return;
          }
          final result = await BeakResourceRepository(dataSource).update(
            block.model.table,
            id,
            BeakRecord(values: {groupField.key: BeakStringValue(target.name)}),
          );
          switch (result) {
            case BeakOk():
              // Mirror the confirmed write into the rendered records so the
              // card stays in its new column until the refetch lands.
              rows.value = _ModuleRows([
                for (final row in rows.value.records)
                  if (identical(row, record))
                    BeakRecord(
                      values: {
                        ...row.values,
                        groupField.key: BeakStringValue(target.name),
                      },
                      relations: row.relations,
                    )
                  else
                    row,
              ], rows.value.total);
              block.onCardMove?.call(record);
            case BeakErr(:final error):
              // A refused move leaves the card where it was.
              if (context.mounted) _reportWriteFailure(context, error);
          }
        },
      ),
    );
  }

  Widget _card(BuildContext context, BeakRecord record) {
    final String title = _readString(record, block.titleField) ?? '';
    final String? subtitle = _readString(record, block.subtitleField);
    if (subtitle == null) {
      return OiLabel.bodyStrong(title);
    }
    return OiColumn(
      breakpoint: context.breakpoint,
      gap: const OiResponsive<double>(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [OiLabel.bodyStrong(title), OiLabel.caption(subtitle)],
    );
  }
}
