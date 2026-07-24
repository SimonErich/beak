part of '../beak_block_host.dart';

/// Fetches a [BeakCalendarBlock]'s records, maps each to an [OiCalendarEvent],
/// and renders them on an `OiCalendar` — resolving taps and drags back to the
/// originating [BeakRecord].
class _BeakCalendarBlockView extends HookWidget {
  const _BeakCalendarBlockView({required this.block});

  final BeakCalendarBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakLocator<BeakDataSource>();
    final records = useState(const <BeakRecord>[]);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final result = await BeakResourceRepository(dataSource).query(
          BeakQuerySpec(table: block.model.table, pagination: _modulePage),
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

    final byKey = <Object, BeakRecord>{
      for (final record in records.value)
        if (block.model.primaryKeyOf(record) case final Object id) id: record,
    };
    final events = <OiCalendarEvent>[
      for (final MapEntry(key: id, value: record) in byKey.entries)
        _eventOf(context, id, record),
    ];

    return OiCalendar(
      label: block.label,
      mode: block.mode,
      events: events,
      onEventTap: block.onEventTap == null
          ? null
          : (event) {
              if (byKey[event.key] case final BeakRecord record) {
                block.onEventTap!(record);
              }
            },
      onEventMove: (event, start, end) async {
        final BeakRecord? record = byKey[event.key];
        if (record == null) {
          return;
        }
        final result = await BeakResourceRepository(dataSource).update(
          block.model.table,
          event.key,
          BeakRecord(
            values: {
              block.startField.key: BeakDateTimeValue(start),
              if (block.endField case final BeakColumn column)
                column.key: BeakDateTimeValue(end),
            },
          ),
        );
        // Mirror a successful write into the rendered records so the event
        // stays on its new day; on failure it visibly snaps back.
        if (result case BeakOk()) {
          records.value = [
            for (final row in records.value)
              if (identical(row, record))
                BeakRecord(
                  values: {
                    ...row.values,
                    block.startField.key: BeakDateTimeValue(start),
                    if (block.endField case final BeakColumn column)
                      column.key: BeakDateTimeValue(end),
                  },
                  relations: row.relations,
                )
              else
                row,
          ];
        }
        block.onEventMove?.call(record, start, end);
      },
    );
  }

  OiCalendarEvent _eventOf(BuildContext context, Object id, BeakRecord record) {
    final DateTime start =
        _readDateTime(record, block.startField) ?? DateTime.now();
    final DateTime end = _readDateTime(record, block.endField) ?? start;
    return OiCalendarEvent(
      key: id,
      title: _readString(record, block.titleField) ?? '',
      start: start,
      end: end,
      allDay: _readBool(record, block.allDayField),
      color: _categoryColor(context, record),
    );
  }

  Color? _categoryColor(BuildContext context, BeakRecord record) {
    if (block.categoryField case final BeakEnumColumn<Enum> column) {
      final String? name = _readString(record, column);
      final Enum? value = name == null ? null : column.valueByName(name);
      if (value != null) {
        return _resolveBeakColor(context, column.badgeColorFor(value));
      }
    }
    return null;
  }
}
