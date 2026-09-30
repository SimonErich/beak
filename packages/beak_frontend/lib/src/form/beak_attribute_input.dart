import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../formatting/beak_formatting.dart';
import 'beak_input_presentation.dart';

/// Model-driven editor for configurable attributes stored as canonical strings.
class BeakAttributeInput extends HookWidget {
  /// Adapts a string field without changing its database representation.
  const BeakAttributeInput({
    required this.type,
    required this.value,
    required this.label,
    required this.onChanged,
    required this.onError,
    this.options = const [],
    this.enabled = true,
    this.error,
    this.description,
    super.key,
  });

  /// Current interpretation, usually read from a selected attribute definition.
  final BeakAttributeType type;

  /// Canonical persisted value.
  final String? value;

  /// Human-readable label.
  final String label;

  /// Optional guidance.
  final String? description;

  /// Available string choices.
  final List<BeakInputOption<Object>> options;

  /// Receives canonical strings after successful parsing.
  final ValueChanged<String?> onChanged;

  /// Reports incomplete numeric text separately from the last valid value.
  final ValueChanged<String?> onError;

  /// Whether editing is permitted.
  final bool enabled;

  /// Validation feedback.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final formatting = BeakFormatting.of(context);
    String display(String? raw) => type == BeakAttributeType.number
        ? (raw ?? '').replaceAll('.', formatting.decimalSeparator)
        : raw ?? '';
    final controller = useTextEditingController(text: display(value));
    final accepted = useRef(value);
    useEffect(() {
      if (value != accepted.value) {
        controller.text = display(value);
        accepted.value = value;
      }
      return null;
    }, [value, type]);
    void change(String? next) {
      onError(null);
      accepted.value = next;
      onChanged(next);
    }

    if (type == BeakAttributeType.boolean) {
      return OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OiLabel.body(label),
          OiRadio<String>(
            value: value,
            enabled: enabled,
            options: const [
              OiRadioOption(value: 'true', label: 'Yes'),
              OiRadioOption(value: 'false', label: 'No'),
            ],
            onChanged: change,
          ),
          if (error != null) OiLabel.caption(error!),
        ],
      );
    }
    if (type == BeakAttributeType.choice) {
      return OiSelect<String>(
        label: label,
        hint: description,
        error: error,
        value: value,
        enabled: enabled,
        options: [
          for (final option in options)
            if (option.value case final String value)
              OiSelectOption(
                value: value,
                label: option.label,
                enabled: option.enabled,
              ),
        ],
        onChanged: change,
      );
    }
    return OiTextInput(
      controller: controller,
      label: label,
      hint: description,
      error: error,
      enabled: enabled,
      keyboardType: type == BeakAttributeType.number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      onChanged: (text) {
        if (type == BeakAttributeType.text || text.isEmpty) {
          change(text.isEmpty ? null : text);
          return;
        }
        final number = formatting.parseNumber(text);
        if (number == null || !number.isFinite) {
          onError('Enter a valid number.');
          return;
        }
        change(number.toString());
      },
    );
  }
}
