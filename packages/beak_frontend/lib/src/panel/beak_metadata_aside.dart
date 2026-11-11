import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';

import '../form/beak_form_layout.dart';
import '../localization/beak_localizations.dart';

/// The read-only timestamps a detail page shows beside the record.
///
/// Uses the model's own lifecycle keys, so a table without a soft-delete or
/// update column shows only the timestamps it has. A resource that wants
/// another aside passes one on its `BeakFormScreen`.
BeakCard beakMetadataAside(BuildContext context, BeakModel model) {
  final strings = BeakLocalizations.of(context);
  return BeakCard(
    title: strings.metadata,
    children: [
      for (final (key, label) in [
        (model.createdAtColumnKey, strings.createdAt),
        (model.updatedAtColumnKey, strings.updatedAt),
        (model.deletedAtColumnKey, strings.deletedAt),
      ])
        if (model.columnByKey(key) case final BeakColumn column)
          _timestamp(model, column, label),
    ],
  );
}

BeakFormNode _timestamp(BeakModel model, BeakColumn column, String label) {
  final field = BeakScalarField<Object>(model: model, column: column);
  return BeakCalculated(
    label: label,
    dependencies: [field],
    format: BeakValueFormat.dateTime,
    value: (state) => state.read(field),
  );
}
