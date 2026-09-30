part of '../beak_block_host.dart';

/// Fetches a [BeakTimelineBlock]'s rows and renders each as an event on
/// `OiTimeline`, ordered newest-first by the bound time field.
class _BeakTimelineBlockView extends HookWidget {
  const _BeakTimelineBlockView({required this.block});

  final BeakTimelineBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final records = _useBlockRead(
      dataSource,
      block.query,
      identity: block,
      initial: const <BeakRecord>[],
      map: (page) => page.items,
    );

    // A timeline places events by time: a row with no time has no place on
    // it, and is left out rather than given an invented date.
    final formatting = BeakFormatting.of(context);
    final events = <OiTimelineEvent>[
      for (final record in records.data)
        if (_readDateTime(record, block.timeField) case final DateTime time)
          OiTimelineEvent(
            timestamp: formatting.toEditorDateTime(time),
            title: _readString(record, block.titleField) ?? '',
          ),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return _withReadFailure(
      context,
      records,
      OiTimeline(label: BeakLocalizations.of(context).timeline, events: events),
    );
  }
}
