import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../table/column_cell_renderer.dart';

/// A structured read view that shares the declared object's field formatting.
class BeakObjectView extends HookWidget {
  /// Displays each declared property, recursively expanding nested objects.
  const BeakObjectView({required this.schema, required this.value, super.key});

  /// The schema that supplies property labels, types and formatting.
  final BeakObjectSchema schema;

  /// The saved or draft object to display.
  final BeakJsonObject value;

  @override
  Widget build(BuildContext context) {
    final record = schema.toRecord(value);
    return OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      gap: const OiResponsive<double>(12),
      children: [
        for (final column in schema.columns)
          OiColumn(
            breakpoint: context.breakpoint,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            gap: const OiResponsive<double>(4),
            children: [
              OiLabel.caption(column.label),
              if ((
                    column.semantic.objectSchema,
                    schema.readValue<BeakJsonObject>(column, value),
                  )
                  case (
                    final BeakObjectSchema nested,
                    final BeakJsonObject object,
                  ))
                BeakObjectView(schema: nested, value: object)
              else
                renderBeakCell(
                  context,
                  column: column,
                  record: record,
                  renderContext: BeakContext.detail,
                ),
            ],
          ),
      ],
    );
  }
}
