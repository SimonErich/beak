part of '../beak_block_host.dart';

/// Fetches a [BeakTimelineBlock]'s rows and renders each as an event on
/// `OiTimeline`, ordered newest-first by the bound time field.
class _BeakTimelineBlockView extends HookWidget {
  const _BeakTimelineBlockView({required this.block});

  final BeakTimelineBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final revision = useBeakDataRevision(dataSource, table: block.query.table);
    final records = useState(const <BeakRecord>[]);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final result = await BeakResourceRepository(
          dataSource,
        ).query(block.query);
        if (cancelled) {
          return;
        }
        if (result case BeakOk(:final value)) {
          records.value = value.items;
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, block, revision]);

    // A timeline places events by time: a row with no time has no place on
    // it, and is left out rather than given an invented date.
    final events = <OiTimelineEvent>[
      for (final record in records.value)
        if (_readDateTime(record, block.timeField) case final DateTime time)
          OiTimelineEvent(
            timestamp: time,
            title: _readString(record, block.titleField) ?? '',
          ),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return OiTimeline(label: 'Timeline', events: events);
  }
}
