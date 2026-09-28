import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_autoforms/obers_ui_autoforms.dart';

import '../localization/beak_localizations.dart';
import 'beak_form_controller_builder.dart';
import 'beak_form_field.dart';

/// Renders a generated scalar/list field using an optional authenticated lookup.
class BeakChoiceField extends HookWidget {
  /// Binds a choice presentation to the form controller's registered field.
  const BeakChoiceField({
    required this.field,
    required this.controller,
    this.label,
    this.enabled = true,
    super.key,
  });

  /// Choice presentation and lookup.
  final BeakFormChoiceField field;

  /// Owner of the submitted value and validation state.
  final BeakFormController controller;

  /// Optional placement label overriding the model label.
  final String? label;

  /// Whether the selection may currently change.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final retry = useState(0);
    final future = useMemoized(
      () => field.loadOptions?.call() ?? Future.value(field.options),
      [field, retry.value],
    );
    final state = useFuture(future);
    final strings = BeakLocalizations.of(context);
    if (state.hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OiLabel.body(switch (state.error) {
            final BeakException error => error.message,
            _ => strings.failedToLoadOptions,
          }),
          OiButton.secondary(label: strings.retry, onTap: () => retry.value++),
        ],
      );
    }
    final options = state.data;
    if (options == null) return OiLabel.body(strings.loading);
    final slot = controller.slotOf(field.column);
    if (!field.multiple) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OiAfSelect<Enum, String>(
            field: slot,
            label: label ?? field.column.label,
            enabled: enabled,
            searchable: true,
            options: [
              for (final option in options)
                OiAfOption(value: option.value, label: option.label),
            ],
          ),
          if (field.clearable)
            OiButton.ghost(
              label: strings.clear,
              onTap: enabled
                  ? () => controller.setValue<String>(field.column, null)
                  : null,
            ),
        ],
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selected = controller.get<List<String>>(slot) ?? const <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OiLabel.smallStrong(label ?? field.column.label),
            for (final option in options)
              OiCheckbox(
                value: selected.contains(option.value),
                enabled: enabled,
                label: option.label,
                onChanged: (checked) => controller.setValue(field.column, [
                  for (final value in selected)
                    if (value != option.value) value,
                  if (checked) option.value,
                ]),
              ),
            for (final error in controller.getErrors(slot)) OiLabel.body(error),
          ],
        );
      },
    );
  }
}
