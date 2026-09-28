import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../form/beak_value_input.dart';
import '../formatting/beak_formatting.dart';
import 'beak_filter_widget.dart';

/// Inclusive range control preserving semantic wire types and storage scale.
class BeakSemanticRangeControl extends HookWidget {
  /// Creates a pair of optional, independently editable endpoints.
  const BeakSemanticRangeControl({
    required this.definition,
    required this.onChanged,
    this.initial,
    this.onValidityChanged,
    super.key,
  });

  /// Range metadata and optional related field path.
  final BeakSemanticRangeFilter definition;

  /// Restored inclusive bounds from a bookmark or saved view.
  final BeakFilter? initial;

  /// Reports local parse failures so the enclosing drawer cannot apply stale bounds.
  final ValueChanged<bool>? onValidityChanged;

  /// Receives predicates only after both editors parse successfully.
  final ValueChanged<BeakFilter?> onChanged;

  @override
  Widget build(BuildContext context) {
    final bounds = beakFilterRange(initial);
    final lower = useState<Object?>(
      definition.column.semantic.tryDecode(bounds.$1),
    );
    final upper = useState<Object?>(
      definition.column.semantic.tryDecode(bounds.$2),
    );
    final errors = useState(const <int, String>{});
    final revision = useState(0);
    final custom = useState(false);
    void emit() {
      if (errors.value.isNotEmpty) return;
      onChanged(
        BeakFilter.allOf([
          if (lower.value != null)
            BeakFieldFilter.forKey(
              definition.key,
              BeakOperator.gte,
              definition.column.semantic.encode(lower.value),
            ),
          if (upper.value != null)
            BeakFieldFilter.forKey(
              definition.key,
              BeakOperator.lte,
              definition.column.semantic.encode(upper.value),
            ),
        ]),
      );
    }

    final inputs = [
      for (final entry in [(0, lower, '≥'), (1, upper, '≤')])
        if (definition.inline &&
            definition.column.semantic.kind == BeakSemanticKind.calendarDate)
          OiDateInput(
            key: ValueKey('${entry.$1}:${revision.value}'),
            semanticLabel: '${definition.label} ${entry.$3}',
            leadingIcon: true,
            dateFormat: BeakFormatting.of(context).dateInputPattern,
            locale: BeakFormatting.of(context).locale,
            value: (entry.$2.value as BeakDate?)?.toDateTime(),
            onChanged: (date) {
              custom.value = false;
              entry.$2.value = date == null
                  ? null
                  : BeakDate(date.year, date.month, date.day);
              emit();
            },
          )
        else
          BeakValueInput(
            key: ValueKey('${entry.$1}:${revision.value}'),
            column: definition.column,
            value: entry.$2.value,
            label: '${definition.label} ${entry.$3}',
            error: errors.value[entry.$1],
            onError: (message) {
              final next = {...errors.value}..remove(entry.$1);
              if (message != null) next[entry.$1] = message;
              errors.value = next;
              onValidityChanged?.call(next.isEmpty);
            },
            onChanged: (value) {
              custom.value = false;
              entry.$2.value = value;
              emit();
            },
          ),
    ];
    final matched = definition.presets.indexWhere(
      (preset) => preset.lower == lower.value && preset.upper == upper.value,
    );
    void choosePreset(int index) {
      custom.value = index == definition.presets.length;
      if (custom.value) return;
      final preset = definition.presets[index];
      lower.value = preset.lower;
      upper.value = preset.upper;
      errors.value = const {};
      revision.value++;
      onValidityChanged?.call(true);
      emit();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (definition.presets.isNotEmpty) ...[
          OiLabel.bodyStrong(definition.label),
          const SizedBox(height: 8),
          if (definition.presets.length <= 4)
            Align(
              alignment: Alignment.centerLeft,
              child: OiSegmentedControl<int>(
                selected: custom.value || matched < 0
                    ? definition.presets.length
                    : matched,
                segments: [
                  for (
                    var index = 0;
                    index <= definition.presets.length;
                    index++
                  )
                    OiSegment(
                      value: index,
                      label: index == definition.presets.length
                          ? 'Custom'
                          : definition.presets[index].label,
                      semanticLabel:
                          '${definition.label}: ${index == definition.presets.length ? 'Custom' : definition.presets[index].label}',
                    ),
                ],
                onChanged: choosePreset,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var index = 0; index <= definition.presets.length; index++)
                  OiToggleButton(
                    label: index == definition.presets.length
                        ? 'Custom'
                        : definition.presets[index].label,
                    semanticLabel:
                        '${definition.label}: ${index == definition.presets.length ? 'Custom' : definition.presets[index].label}',
                    size: OiButtonSize.small,
                    selected: index == definition.presets.length
                        ? custom.value || matched < 0
                        : !custom.value && matched == index,
                    onChanged: (_) => choosePreset(index),
                  ),
              ],
            ),
          const SizedBox(height: 8),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            if (definition.inline && constraints.maxWidth >= 320) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: inputs.first),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: OiLabel.body('–'),
                  ),
                  Expanded(child: inputs.last),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [inputs.first, const SizedBox(height: 8), inputs.last],
            );
          },
        ),
      ],
    );
  }
}

/// Extracts independently optional inclusive endpoints from a typed predicate.
(BeakValue?, BeakValue?) beakFilterRange(BeakFilter? filter) {
  final parts = filter is BeakAndFilter ? filter.filters : [?filter];
  BeakValue? lower;
  BeakValue? upper;
  for (final part in parts.whereType<BeakFieldFilter>()) {
    if (part.operator == BeakOperator.gte) lower = part.value;
    if (part.operator == BeakOperator.lte) upper = part.value;
  }
  return (lower, upper);
}
