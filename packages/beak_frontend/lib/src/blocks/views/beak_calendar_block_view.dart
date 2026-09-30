part of '../beak_block_host.dart';

/// Fetches a [BeakCalendarBlock]'s records, maps each to an [OiCalendarEvent],
/// and renders them on an `OiCalendar` — resolving taps and drags back to the
/// originating [BeakRecord].
class _BeakCalendarBlockView extends HookWidget {
  const _BeakCalendarBlockView({required this.block});

  final BeakCalendarBlock block;

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

    final formatting = BeakFormatting.of(context);
    final byKey = <Object, BeakRecord>{
      for (final record in rows.value.records)
        if (block.model.primaryKeyOf(record) case final Object id) id: record,
    };
    // A calendar places events by their start: a row with no start has no
    // place on it, and is left out rather than given an invented date.
    final events = <OiCalendarEvent>[
      for (final MapEntry(key: id, value: record) in byKey.entries)
        if (_readDateTime(record, block.startField) case final DateTime start)
          _eventOf(context, formatting, id, record, start),
    ];

    return _withTruncationNote(
      context,
      rows.value,
      OiCalendar(
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
        onEventMove: (event, shownStart, shownEnd) async {
          final BeakRecord? record = byKey[event.key];
          if (record == null) {
            return;
          }
          // The calendar reports wall-clock components in the zone it was
          // shown in; the record stores the instant they name.
          final DateTime start = formatting.fromEditorDateTime(shownStart);
          final DateTime end = formatting.fromEditorDateTime(shownEnd);
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
          switch (result) {
            case BeakOk():
              // Mirror the confirmed write into the rendered records so the
              // event stays on its new day until the refetch lands.
              rows.value = _ModuleRows([
                for (final row in rows.value.records)
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
              ], rows.value.total);
              block.onEventMove?.call(record, start, end);
            case BeakErr(:final error):
              // A refused move leaves the event where it was.
              if (context.mounted) _reportWriteFailure(context, error);
          }
        },
      ),
    );
  }

  OiCalendarEvent _eventOf(
    BuildContext context,
    BeakFormatting formatting,
    Object id,
    BeakRecord record,
    DateTime start,
  ) {
    final DateTime end = _readDateTime(record, block.endField) ?? start;
    return OiCalendarEvent(
      key: id,
      title: _readString(record, block.titleField) ?? '',
      start: formatting.toEditorDateTime(start),
      end: formatting.toEditorDateTime(end),
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
