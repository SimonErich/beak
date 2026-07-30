import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

/// A typed filter control declared once per resource — the sealed family
/// fixes how each renders and which predicate it contributes, so the bar
/// switches exhaustively and no `Map<String, dynamic>` ever appears.
///
/// Each variant binds to a [BeakColumn] and produces a specific control and
/// [BeakOperator]: [BeakSelectFilter] (enum equality), [BeakBoolFilter]
/// (on/off), [BeakTextFilter] (contains), [BeakDateRangeFilter] (between).
/// List them on a [BeakResource] to add the list page's filter bar:
///
/// ```dart
/// BeakResource(
///   model: const ProductModel(),
///   icon: const BeakIconToken(OiIcons.package),
///   filters: const [
///     BeakSelectFilter(column: ProductColumns.status, label: 'Status'),
///     BeakTextFilter(column: ProductColumns.name, label: 'Name'),
///   ],
/// );
/// ```
// --8<-- [start:BeakFilterDef]
sealed class BeakFilterDef {
  /// Creates a filter over [column] labelled [label].
  const BeakFilterDef({required this.column, required this.label});

  /// The column the filter constrains.
  final BeakColumn column;

  /// The control label.
  final String label;
}
// --8<-- [end:BeakFilterDef]

/// An equality filter over a [BeakEnumColumn], rendered as an `OiSelect`.
///
/// The [BeakFilterDef.column] must be a [BeakEnumColumn]; its options
/// populate the dropdown. Selecting a value constrains the column to it
/// (`eq`); clearing it removes the predicate.
final class BeakSelectFilter extends BeakFilterDef {
  /// Creates the select filter.
  const BeakSelectFilter({required super.column, required super.label});
}

/// An on/off filter rendered as an `OiSwitch`.
///
/// Enabled, it constrains the column to `true` (`eq`); disabled, it
/// contributes no predicate at all (rather than constraining to `false`).
final class BeakBoolFilter extends BeakFilterDef {
  /// Creates the boolean filter.
  const BeakBoolFilter({required super.column, required super.label});
}

/// A substring filter rendered as a text input.
///
/// A non-empty, trimmed value constrains the column with `contains`; an
/// empty value contributes no predicate.
final class BeakTextFilter extends BeakFilterDef {
  /// Creates the text filter.
  const BeakTextFilter({required super.column, required super.label});
}

/// A `between` filter over a date column, rendered as an
/// `OiDateRangePickerField`.
///
/// Picking a start/end range constrains the column to it; clearing the
/// field removes the predicate.
final class BeakDateRangeFilter extends BeakFilterDef {
  /// Creates the date-range filter.
  const BeakDateRangeFilter({required super.column, required super.label});
}

/// Renders a resource's filters and emits the combined predicate: each
/// active control contributes one typed [BeakFilter], AND-ed together
/// (`null` when nothing is active).
///
/// The list page builds this from `resource.effectiveFilters` — the declared
/// ones, or the ones the model's `filterable` columns imply — and re-queries
/// on every [onChanged]; hand-composing a page you wire it the same way:
///
/// ```dart
/// BeakFilterBar(
///   filters: resource.effectiveFilters,
///   onChanged: (combined) => filter.value = combined,
/// );
/// ```
class BeakFilterBar extends HookWidget {
  /// Creates the bar over [filters], reporting changes through
  /// [onChanged].
  const BeakFilterBar({
    required this.filters,
    required this.onChanged,
    super.key,
  });

  /// The filter controls, in order.
  final List<BeakFilterDef> filters;

  /// Fires with the combined predicate on every change (`null` when no
  /// filter is active).
  final ValueChanged<BeakFilter?> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = useState(const <String, BeakFilter>{});
    final controls = useState(const <String, Object>{});

    void apply(BeakFilterDef def, {BeakFilter? filter, Object? controlValue}) {
      final nextActive = {...active.value}..remove(def.column.key);
      if (filter != null) {
        nextActive[def.column.key] = filter;
      }
      active.value = nextActive;
      final nextControls = {...controls.value}..remove(def.column.key);
      if (controlValue != null) {
        nextControls[def.column.key] = controlValue;
      }
      controls.value = nextControls;
      onChanged(BeakFilter.allOf(nextActive.values.toList()));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        for (final def in filters)
          SizedBox(
            width: 220,
            child: _control(def, controls.value[def.column.key], apply),
          ),
      ],
    );
  }

  Widget _control(
    BeakFilterDef def,
    Object? controlValue,
    void Function(BeakFilterDef def, {BeakFilter? filter, Object? controlValue})
    apply,
  ) => switch (def) {
    BeakSelectFilter() => _select(def, controlValue, apply),
    BeakBoolFilter() => OiSwitch(
      label: def.label,
      value: controlValue == true,
      onChanged: (enabled) => apply(
        def,
        controlValue: enabled,
        filter: enabled
            ? BeakFieldFilter.forKey(
                def.column.key,
                BeakOperator.eq,
                const BeakBoolValue(true),
              )
            : null,
      ),
    ),
    BeakTextFilter() => OiTextInput(
      label: def.label,
      onChanged: (text) {
        final String trimmed = text.trim();
        apply(
          def,
          controlValue: trimmed.isEmpty ? null : trimmed,
          filter: trimmed.isEmpty
              ? null
              : BeakFieldFilter.forKey(
                  def.column.key,
                  BeakOperator.contains,
                  BeakStringValue(trimmed),
                ),
        );
      },
    ),
    BeakDateRangeFilter() => OiDateRangePickerField(
      label: def.label,
      clearable: true,
      startDate: switch (controlValue) {
        (final DateTime start, DateTime _) => start,
        _ => null,
      },
      endDate: switch (controlValue) {
        (DateTime _, final DateTime end) => end,
        _ => null,
      },
      onChanged: (start, end) => apply(
        def,
        controlValue: (start, end),
        filter: BeakFieldFilter.forKey(
          def.column.key,
          BeakOperator.between,
          BeakListValue([BeakDateTimeValue(start), BeakDateTimeValue(end)]),
        ),
      ),
      onCleared: () => apply(def),
    ),
  };

  Widget _select(
    BeakSelectFilter def,
    Object? controlValue,
    void Function(BeakFilterDef def, {BeakFilter? filter, Object? controlValue})
    apply,
  ) {
    if (def.column case final BeakEnumColumn<Enum> enumColumn) {
      return OiSelect<Enum>(
        label: def.label,
        value: switch (controlValue) {
          final Enum option => option,
          _ => null,
        },
        options: [
          for (final option in enumColumn.values)
            OiSelectOption(value: option, label: enumColumn.labelFor(option)),
        ],
        onChanged: (option) => apply(
          def,
          controlValue: option,
          filter: option == null
              ? null
              : BeakFieldFilter.forKey(
                  def.column.key,
                  BeakOperator.eq,
                  BeakStringValue(option.name),
                ),
        ),
      );
    }
    return OiLabel.caption(
      'Select filters need an enum column ("${def.column.key}").',
    );
  }
}
