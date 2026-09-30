import 'dart:math' as math;

import 'package:beak_core/beak_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../formatting/beak_formatting.dart';
import 'beak_form_layout.dart';
import 'beak_form_session.dart';

/// A locale-aware monetary editor bound to an automatic numeric draft field.
///
/// Intermediate text stays in the input; complete values remain numeric in the
/// shared draft. Minor-unit fields scale using the explicit configured decimal scale.
class BeakCurrencyField extends HookWidget {
  /// Binds one declared currency placement to its owning draft.
  const BeakCurrencyField({
    required this.input,
    required this.draft,
    required this.enabled,
    super.key,
  });

  /// Currency presentation, label and unit configuration.
  final BeakInput<Object> input;

  /// Draft owning the numeric value and validation errors.
  final BeakDraftRecord draft;

  /// Whether the editor currently accepts changes.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final formats = BeakFormatting.of(context);
    final column = input.field.column;
    final scale = input.minorUnits ? math.pow(10, input.currencyScale) : 1;
    final precision = input.minorUnits
        ? input.currencyScale
        : switch (column) {
            BeakIntColumn() => 0,
            BeakDecimalColumn(:final precision) =>
              formats.currencyPrecision ?? precision,
            _ => formats.moneyPrecision,
          };
    final value = draft.controller.valueOf<num>(column);
    String textOf(num? number) => number == null
        ? ''
        : formats.number(number / scale, precision: precision);
    final text = useTextEditingController(text: textOf(value));
    final focus = useFocusNode();
    useEffect(() {
      if (!focus.hasFocus && text.text != textOf(value)) {
        text.text = textOf(value);
      }
      return null;
    }, [value, formats]);
    useEffect(() {
      void blur() {
        if (!focus.hasFocus &&
            !draft.controller.inputErrors.containsKey(column.key)) {
          text.text = textOf(draft.controller.valueOf<num>(column));
        }
      }

      focus.addListener(blur);
      return () => focus.removeListener(blur);
    }, [focus, formats, scale, precision]);
    return OiTextInput(
      controller: text,
      focusNode: focus,
      enabled: enabled,
      label: input.label ?? input.field.label,
      hint: input.description,
      error:
          draft.controller.inputErrors[column.key] ??
          draft.errors[input.field.key]?.join(' '),
      trailing: OiLabel.caption(formats.currencyCode),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        TextInputFormatter.withFunction((oldValue, next) {
          final value = next.text;
          final parts = value.split(formats.decimalSeparator);
          if (parts.length > 2 ||
              (parts.length == 2 &&
                  (precision == 0 || parts.last.length > precision))) {
            return oldValue;
          }
          final incomplete =
              value.isEmpty ||
              value == '-' ||
              (precision > 0 &&
                  (value == formats.decimalSeparator ||
                      value == '-${formats.decimalSeparator}'));
          return incomplete || formats.parseNumber(value) != null
              ? next
              : oldValue;
        }),
      ],
      onChanged: (text) {
        final parsed = formats.parseNumber(text);
        if (text.isNotEmpty && parsed == null) {
          draft.controller.setInputError(column, 'Enter a valid amount.');
          return;
        }
        draft.controller.setInputError(column, null);
        final scaled = parsed == null ? null : parsed * scale;
        draft.set(
          input.field,
          column is BeakIntColumn ? scaled?.round() : scaled?.toDouble(),
        );
      },
    );
  }
}
