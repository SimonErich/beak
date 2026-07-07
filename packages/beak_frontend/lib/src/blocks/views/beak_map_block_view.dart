part of '../beak_block_host.dart';

/// Runs a [BeakMapBlock]'s query, folds the records into a region-code →
/// value map, and shades an `OiVectorMap`.
class _BeakMapBlockView extends HookWidget {
  const _BeakMapBlockView({required this.block});

  final BeakMapBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakLocator<BeakDataSource>();
    final values = useState(const <String, num>{});

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
          values.value = {
            for (final record in value.items)
              if (record[block.regionCodeField.key]?.raw?.toString()
                  case final String code when code.isNotEmpty)
                code: _numberOf(record[block.valueField.key]?.raw),
          };
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, block]);

    return OiCard(
      title: OiLabel.smallStrong(block.title),
      child: SizedBox(
        height: block.heightInPixels,
        child: OiVectorMap(
          label: block.title,
          values: values.value,
          valueLabel: block.valueLabel,
          showLegend: true,
        ),
      ),
    );
  }

  static num _numberOf(Object? raw) => switch (raw) {
    final num value => value,
    final String value => num.tryParse(value) ?? 0,
    _ => 0,
  };
}
