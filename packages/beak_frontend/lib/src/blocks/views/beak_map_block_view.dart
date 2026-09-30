part of '../beak_block_host.dart';

/// Runs a [BeakMapBlock]'s query, folds the records into a region-code →
/// value map, and shades an `OiVectorMap`.
class _BeakMapBlockView extends HookWidget {
  const _BeakMapBlockView({required this.block});

  final BeakMapBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final values = _useBlockRead(
      dataSource,
      block.query,
      initial: const <String, num>{},
      map: (page) => {
        for (final record in page.items)
          if (record[block.regionCodeField.key]?.raw?.toString()
              case final String code when code.isNotEmpty)
            code: _numberOf(record[block.valueField.key]?.raw),
      },
    );

    return _withReadFailure(
      context,
      values,
      OiCard(
        title: OiLabel.smallStrong(block.title),
        child: SizedBox(
          height: block.heightInPixels,
          child: OiVectorMap(
            label: block.title,
            values: values.data,
            valueLabel: block.valueLabel,
            showLegend: true,
          ),
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
