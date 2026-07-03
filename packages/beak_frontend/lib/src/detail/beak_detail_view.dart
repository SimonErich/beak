import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../table/column_cell_renderer.dart';

/// The generated read-only record view: a model's detail-context columns
/// rendered as labelled rows, with every value formatted by the shared
/// intent renderer — badges, images, dates, swatches, and custom cells all
/// match the table exactly.
class BeakDetailView extends HookWidget {
  /// Creates the detail view of [record] described by [model].
  const BeakDetailView({required this.model, required this.record, super.key});

  /// The model describing the record's columns.
  final BeakModel model;

  /// The record on display.
  final BeakRecord record;

  @override
  Widget build(BuildContext context) => OiCard(
    child: OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final column in model.columns)
          if (column.visibleOn.contains(BeakContext.detail))
            OiRow(
              breakpoint: context.breakpoint,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 160, child: OiLabel.smallStrong(column.label)),
                Expanded(
                  child: renderBeakCell(
                    context,
                    column: column,
                    record: record,
                    renderContext: BeakContext.detail,
                  ),
                ),
              ],
            ),
      ],
    ),
  );
}
