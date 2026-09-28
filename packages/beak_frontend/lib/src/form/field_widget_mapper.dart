import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui_autoforms/obers_ui_autoforms.dart';

import 'beak_form_controller_builder.dart';
import 'beak_form_field.dart';
import 'beak_choice_field.dart';
import 'upload_field.dart';
import 'beak_value_input.dart';

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
  String? label,
  String? description,
  bool enabled = true,
  bool? obscureText,
}) {
  Enum slot() => controller.slotOf(column);
  switch (controller.fieldFor(column)) {
    case final BeakFormChoiceField field:
      return BeakChoiceField(
        field: field,
        controller: controller,
        label: label,
        enabled: enabled,
      );
    case final BeakFormTextField field:
      return OiAfTextInput<Enum>(
        field: slot(),
        label: label ?? column.label,
        enabled: enabled,
        obscureText: obscureText ?? field.obscureText,
        hint: description,
      );
    case null:
      break;
  }
  if (column.semantic.kind != BeakSemanticKind.none ||
      column is BeakJsonColumn ||
      (column is BeakBoolColumn && column.tristate)) {
    return BeakBoundValueInput(
      controller: controller,
      column: column,
      label: label,
      description: description,
      enabled: enabled,
    );
  }
  return switch (column) {
    BeakCustomColumn() => null,
    BeakStringColumn(:final placeholder, :final maxLength) => OiAfTextInput(
      field: slot(),
      label: label ?? column.label,
      enabled: enabled,
      placeholder: placeholder.isEmpty ? null : placeholder,
      maxLength: maxLength,
      obscureText: obscureText ?? false,
      hint: description,
    ),
    BeakTextColumn() || BeakJsonColumn() => OiAfTextInput.multiline(
      field: slot(),
      label: label ?? column.label,
      enabled: enabled,
      hint: description,
    ),
    BeakIntColumn(:final min, :final max) => OiAfNumberInput(
      field: slot(),
      label: label ?? column.label,
      enabled: enabled,
      min: min?.toDouble(),
      max: max?.toDouble(),
      decimalPlaces: 0,
      hint: description,
    ),
    BeakDecimalColumn(:final precision) => OiAfNumberInput(
      field: slot(),
      label: label ?? column.label,
      enabled: enabled,
      decimalPlaces: precision,
      hint: description,
    ),
    BeakBoolColumn() => OiAfSwitch(
      field: slot(),
      label: label ?? column.label,
      enabled: enabled,
    ),
    final BeakEnumColumn<Enum> enumColumn => OiAfSelect<Enum, Enum>(
      field: slot(),
      label: label ?? column.label,
      enabled: enabled,
      hint: description,
      options: [
        for (final option in enumColumn.values)
          OiAfOption(value: option, label: enumColumn.labelFor(option)),
      ],
    ),
    BeakDateTimeColumn() => OiAfDateTimeInput(
      field: slot(),
      label: label ?? column.label,
      enabled: enabled,
      hint: description,
    ),
    BeakColorColumn() => OiAfColorInput(
      field: slot(),
      label: label ?? column.label,
      hint: description,
      enabled: enabled,
    ),
    BeakRichTextColumn() => OiAfRichEditor(
      field: slot(),
      label: label ?? column.label,
      enabled: enabled,
    ),
    BeakUploadColumn() => BeakUploadField(
      controller: controller,
      column: column,
      uploader: uploader,
      filePicker: filePicker,
      label: label,
      enabled: enabled,
    ),
  };
}
