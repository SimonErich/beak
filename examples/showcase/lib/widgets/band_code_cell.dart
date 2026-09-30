import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import '../resources/specimens/models/specimen.dart';

/// Registers the renderers the app's custom columns need.
///
/// A custom column stores whatever the API hands back and draws it with a
/// builder registered under the column's tag. The tag comes from the generated
/// column, so the schema class is the only place that spells it.
// --8<-- [start:registerAviaryRenderers]
void registerAviaryRenderers() {
  BeakCustomRenderers.register(SpecimenColumns.bandCode.tag, bandCodeCell);
}
// --8<-- [end:registerAviaryRenderers]

/// Draws a leg band: the code in a monospaced chip.
// --8<-- [start:bandCodeCell]
Widget bandCodeCell(
  BuildContext context,
  BeakColumn column,
  BeakRecord record,
) => switch (record[column.key]?.raw) {
  final Object code => OiBadge.soft(label: '$code', color: OiBadgeColor.info),
  null => const OiLabel.caption('No band'),
};
// --8<-- [end:bandCodeCell]
