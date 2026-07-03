import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui_autoforms/obers_ui_autoforms.dart';

import 'beak_form_controller_builder.dart';
import 'upload_field.dart';

/// Maps [column]'s form render intent onto the matching `OiAf*` field
/// widget bound to [controller] — the single place column types become
/// form inputs.
///
/// Returns `null` for [BeakCustomColumn]s (rendered through the custom
/// escape hatch, never auto-formed). Image and file columns render a
/// [BeakUploadField] wired to [uploader]/[filePicker].
Widget? beakFormFieldFor({
  required BeakFormController controller,
  required BeakColumn column,
  BeakUploadClient? uploader,
  BeakFilePicker? filePicker,
}) {
  BeakFormSlot slot() => controller.slotOf(column);
  return switch (column) {
    BeakCustomColumn() => null,
    BeakStringColumn(:final placeholder, :final maxLength) => OiAfTextInput(
      field: slot(),
      label: column.label,
      placeholder: placeholder.isEmpty ? null : placeholder,
      maxLength: maxLength,
    ),
    BeakTextColumn() || BeakJsonColumn() => OiAfTextInput.multiline(
      field: slot(),
      label: column.label,
    ),
    BeakIntColumn(:final min, :final max) => OiAfNumberInput(
      field: slot(),
      label: column.label,
      min: min?.toDouble(),
      max: max?.toDouble(),
      decimalPlaces: 0,
    ),
    BeakDecimalColumn(:final precision) => OiAfNumberInput(
      field: slot(),
      label: column.label,
      decimalPlaces: precision,
    ),
    BeakBoolColumn() => OiAfSwitch(field: slot(), label: column.label),
    final BeakEnumColumn<Enum> enumColumn => OiAfSelect<BeakFormSlot, Enum>(
      field: slot(),
      label: column.label,
      options: [
        for (final option in enumColumn.values)
          OiAfOption(value: option, label: enumColumn.labelFor(option)),
      ],
    ),
    BeakDateTimeColumn() => OiAfDateTimeInput(
      field: slot(),
      label: column.label,
    ),
    BeakColorColumn() => OiAfColorInput(field: slot(), label: column.label),
    BeakRichTextColumn() => OiAfRichEditor(field: slot(), label: column.label),
    BeakImageColumn() || BeakFileColumn() => BeakUploadField(
      controller: controller,
      column: column,
      uploader: uploader,
      filePicker: filePicker,
    ),
  };
}
