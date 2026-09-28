import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../table/column_cell_renderer.dart';
import '../localization/beak_localizations.dart';

/// The generated read-only record view: a model's detail-context columns
/// rendered as labelled rows, with every value formatted by the shared
/// intent renderer — badges, images, dates, swatches, and custom cells all
/// match the table exactly.
///
/// Only columns whose `visibleOn` includes [BeakContext.detail] render, each
/// drawn by [renderBeakCell] with the detail render context. The caller
/// supplies an already-loaded [record]; this widget performs no fetching.
///
/// ```dart
/// final BeakRecord? record = await dataSource.getOne('products', id);
/// if (record == null) {
///   return const OiEmptyState(title: 'Not found');
/// }
/// return BeakDetailView(model: const ProductModel(), record: record);
/// ```
class BeakDetailView extends HookWidget {
  /// Creates the detail view of [record] described by [model].
  const BeakDetailView({required this.model, required this.record, super.key});

  /// The model describing the record's columns.
  final BeakModel model;

  /// The record on display.
  final BeakRecord record;

  @override
  Widget build(BuildContext context) {
    final detailColumns = [
      for (final column in model.columns)
        if (column.visibleOn.contains(BeakContext.detail)) column,
    ];
    return OiCard(
      title: OiLabel.h4(BeakLocalizations.of(context).details),
      child: OiGrid(
        breakpoint: context.breakpoint,
        minColumnWidth: const OiResponsive<double>(240),
        gap: const OiResponsive<double>(16),
        children: [
          for (final column in detailColumns)
            OiColumn(
              breakpoint: context.breakpoint,
              gap: const OiResponsive<double>(4),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OiLabel.caption(column.label),
                renderBeakCell(
                  context,
                  column: column,
                  record: record,
                  renderContext: BeakContext.detail,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
