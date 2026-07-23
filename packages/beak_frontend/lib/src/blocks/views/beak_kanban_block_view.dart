part of '../beak_block_host.dart';

/// Fetches a [BeakKanbanBlock]'s records, groups them into one `OiKanban`
/// column per enum value, and persists a card's new group on drop.
class _BeakKanbanBlockView extends HookWidget {
  const _BeakKanbanBlockView({required this.block});

  final BeakKanbanBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakLocator<BeakDataSource>();
    final records = useState(const <BeakRecord>[]);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final result = await BeakResourceRepository(dataSource).query(
          BeakQuerySpec(
            table: block.model.table,
            sorts: [
              if (block.sortField case final BeakColumn column)
                BeakSort(column.key, descending: block.sortDescending),
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

    final BeakEnumColumn<Enum> groupField = block.groupField;
    final columns = <OiKanbanColumn<BeakRecord>>[
      for (final value in groupField.values)
        OiKanbanColumn<BeakRecord>(
          key: value.name,
          title: groupField.labelFor(value),
          color: _resolveBeakColor(context, groupField.badgeColorFor(value)),
          items: [
            for (final record in records.value)
              if (_readString(record, groupField) == value.name) record,
          ],
        ),
    ];

    return OiKanban<BeakRecord>(
      label: block.label,
      columns: columns,
      cardKey: (record) =>
          block.model.primaryKeyOf(record) ?? identityHashCode(record),
      cardBuilder: (record) => _card(context, record),
      onCardMove: (record, from, to, index) async {
        final Enum? target = groupField.valueByName(to.toString());
        final Object? id = block.model.primaryKeyOf(record);
        if (target != null && id != null) {
          final result = await BeakResourceRepository(dataSource).update(
            block.model.table,
            id,
            BeakRecord(values: {groupField.key: BeakStringValue(target.name)}),
          );
          // Mirror a successful write into the rendered records so the card
          // stays in its new column; on failure it visibly snaps back.
          if (result case BeakOk()) {
            records.value = [
              for (final row in records.value)
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
            ];
          }
        }
        block.onCardMove?.call(record);
      },
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
