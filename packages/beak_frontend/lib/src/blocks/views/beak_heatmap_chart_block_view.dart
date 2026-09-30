part of '../beak_block_host.dart';

/// Fetches a [BeakHeatmapChartBlock]'s records and draws them on `OiHeatmap`.
class _BeakHeatmapChartBlockView extends HookWidget {
  const _BeakHeatmapChartBlockView({required this.block});

  final BeakHeatmapChartBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final cells = _useBlockRead(
      dataSource,
      block.query,
      initial: const <BeakMatrixCell>[],
      map: (page) => block.map(page.items),
    );

    // OiHeatmap indexes cells by integer row/column with parallel label
    // lists. Derive the label order from the block (or first-seen order) and
    // resolve each string key to its index.
    final rows = block.rowLabels ?? _distinct(cells.data, (c) => c.row);
    final columns =
        block.columnLabels ?? _distinct(cells.data, (c) => c.column);

    return _withReadFailure(
      context,
      cells,
      OiCard(
        title: OiLabel.smallStrong(block.title),
        child: SizedBox(
          height: block.heightInPixels,
          child: OiHeatmap(
            label: block.title,
            rowLabels: rows,
            columnLabels: columns,
            cells: [
              for (final cell in cells.data)
                if (rows.indexOf(cell.row) case final int r when r >= 0)
                  if (columns.indexOf(cell.column) case final int c when c >= 0)
                    OiHeatmapCell(row: r, column: c, value: cell.value),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _distinct(
    List<BeakMatrixCell> cells,
    String Function(BeakMatrixCell) key,
  ) {
    final seen = <String>[];
    for (final cell in cells) {
      final value = key(cell);
      if (!seen.contains(value)) {
        seen.add(value);
      }
    }
    return seen;
  }
}
