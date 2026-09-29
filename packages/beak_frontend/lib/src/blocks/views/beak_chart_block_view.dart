part of '../beak_block_host.dart';

/// Runs a [BeakChartBlock]'s query through the data source, maps the records
/// to typed points, and draws the configured chart family inside a card.
class _BeakChartBlockView extends HookWidget {
  const _BeakChartBlockView({required this.block});

  final BeakChartBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final revision = useBeakDataRevision(dataSource, table: block.query.table);
    final points = useState(const <BeakChartPoint>[]);

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
          points.value = block.map(value.items);
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, block, revision]);

    return OiCard(
      title: OiLabel.smallStrong(block.title),
      child: SizedBox(
        height: block.heightInPixels,
        child: beakChartWidget(block.type, block.title, points.value),
      ),
    );
  }
}
