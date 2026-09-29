import 'dart:convert';
import 'dart:math' as math;

import '../formatting/beak_field_format.dart';
import '../formatting/beak_formatting.dart';

import 'beak_semantic_range_control.dart';
import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../localization/beak_localizations.dart';
import '../di/beak_locator.dart';
import '../data/beak_data_changes.dart';
import '../data/beak_resource_repository.dart';

/// A typed filter control declared once per resource — the sealed family
/// fixes how each renders and which predicate it contributes, so the bar
/// switches exhaustively and no `Map<String, dynamic>` ever appears.
///
/// Each variant binds to a typed [BeakScalarField] of the model and produces a
/// specific control and [BeakOperator]: [BeakSelectFilter] (enum equality),
/// [BeakBoolFilter] (on/off), [BeakTextFilter] (contains),
/// [BeakDateRangeFilter] (between). Build them from the model's field
/// references and list them on a [BeakResource] to add the list page's filter
/// bar:
///
/// ```dart
/// BeakResource(
///   model: const ProductModel(),
///   icon: const BeakIconToken(OiIcons.package),
///   filters: [
///     ProductModel.status.selectFilter(label: 'Status'),
///     ProductModel.name.textFilter(label: 'Name'),
///   ],
/// );
/// ```
// --8<-- [start:BeakFilterDef]
sealed class BeakFilterDef {
  /// Creates a filter over [field] labelled [label].
  const BeakFilterDef({
    required this.column,
    required this.label,
    required this.field,
    this.advanced = false,
  });

  /// The column the filter constrains.
  final BeakColumn column;

  /// The control label.
  final String label;

  /// Keeps a less frequent filter in the expandable section of a stacked editor.
  final bool advanced;

  /// The typed field the filter addresses, including related paths.
  final BeakFieldRef<Object> field;

  /// Root-qualified identity used for predicates and independent filter state.
  String get key => field.qualifiedKey;
}
// --8<-- [end:BeakFilterDef]

/// One named, typed predicate in a multiple-choice filter.
final class BeakFilterChoice {
  /// Choices may describe a single value or a compound domain predicate.
  const BeakFilterChoice({
    required this.key,
    required this.label,
    required this.filter,
  });

  /// Stable UI identity.
  final String key;

  /// Human-readable label.
  final String label;

  /// Predicate OR-ed with the other selected choices.
  final BeakFilter filter;
}

/// Visual treatment for named predicates, independent of their query semantics.
enum BeakChoiceFilterPresentation {
  /// Accessible checkboxes, optionally arranged in columns.
  checkboxes,

  /// Compact toggle chips for short option labels.
  chips,

  /// A searchable multi-select with removable selected chips.
  combobox,

  /// One choice at a time, with an explicit unconstrained option.
  radio,

  /// One named predicate in a compact dropdown, including an unconstrained choice.
  select,
}

/// Multiple named predicates combined with OR; other filters still use AND.
final class BeakChoiceFilter extends BeakFilterDef {
  /// [field] identifies the filter without user-authored storage keys.
  BeakChoiceFilter({
    required BeakScalarField<Object> field,
    required super.label,
    required this.options,
    this.presentation = BeakChoiceFilterPresentation.checkboxes,
    this.columns = 1,
    this.allLabel = 'All',
    this.showCounts = false,
    this.addItemLabel,
    this.showLabel = true,
    super.advanced,
  }) : assert(columns > 0),
       super(column: field.column, field: field);

  /// Available choices, including compound predicates when useful.
  final List<BeakFilterChoice> options;

  /// Reuses Obers checkbox, chip, combobox, or radio controls.
  final BeakChoiceFilterPresentation presentation;

  /// Maximum checkbox columns; narrow containers fall back to one column.
  final int columns;

  /// Label of the unconstrained option in the radio presentation.
  final String allLabel;

  /// Shows authoritative option counts for the applied query population.
  final bool showCounts;

  /// Shows the group heading; a single self-labelled checkbox may omit it.
  final bool showLabel;

  /// Optional prompt below removable selected values in a combobox.
  final String? addItemLabel;
}

/// An equality filter over a [BeakEnumColumn], rendered as an `OiSelect`.
///
/// The filter's field must address a [BeakEnumColumn]; its options populate
/// the dropdown. Selecting a value constrains the field to it (`eq`);
/// clearing it removes the predicate.
final class BeakSelectFilter extends BeakFilterDef {
  /// Creates the select filter.
  BeakSelectFilter({
    required BeakScalarField<Object> field,
    required super.label,
    super.advanced,
  }) : super(column: field.column, field: field);
}

/// A three-state boolean select: true, false, or every record when cleared.
final class BeakBoolFilter extends BeakFilterDef {
  /// Creates the boolean filter.
  BeakBoolFilter({
    required BeakScalarField<Object> field,
    required super.label,
    super.advanced,
  }) : super(column: field.column, field: field);
}

/// A substring filter rendered as a text input.
///
/// A non-empty, trimmed value constrains the column with `contains`; an
/// empty value contributes no predicate.
final class BeakTextFilter extends BeakFilterDef {
  /// Creates the text filter.
  BeakTextFilter({
    required BeakScalarField<Object> field,
    required super.label,
    super.advanced,
  }) : super(column: field.column, field: field);
}

/// A `between` filter over a date column, rendered as an
/// `OiDateRangePickerField`.
///
/// Picking a start/end range constrains the column to it; clearing the
/// field removes the predicate.
final class BeakDateRangeFilter extends BeakFilterDef {
  /// Creates the date-range filter.
  BeakDateRangeFilter({
    required BeakScalarField<Object> field,
    required super.label,
    super.advanced,
  }) : super(column: field.column, field: field);
}

/// Default arrangement for a filter bar.
enum BeakFilterBarPresentation {
  /// Compact filter chips that reveal their editor when opened.
  chips,

  /// Keep every filter editor visible in the bar.
  controls,
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
    this.dataSource,
    this.initialValues = const {},
    this.onFiltersChanged,
    this.onValidityChanged,
    this.presentation = BeakFilterBarPresentation.chips,
    this.stacked = false,
    this.countQuery,
    this.countQueryFor,
    this.advancedDescription,
    this.advancedColumns = 1,
    super.key,
  });

  /// The filter controls, in order.
  final List<BeakFilterDef> filters;

  /// Fires with the combined predicate on every change (`null` when no
  /// filter is active).
  final ValueChanged<BeakFilter?> onChanged;

  /// Source for relation choices; the containing panel supplies it by default.
  final BeakDataSource? dataSource;

  /// Applied predicates restored when opening a staged filter editor.
  final Map<String, BeakFilter> initialValues;

  /// Reports individual controls so a containing query can persist them.
  final ValueChanged<Map<String, BeakFilter>>? onFiltersChanged;

  /// Whether all typed filter editors currently parse successfully.
  final ValueChanged<bool>? onValidityChanged;

  /// Shows compact chips by default; choose [BeakFilterBarPresentation.controls]
  /// when the editors should stay visible without opening a chip.
  final BeakFilterBarPresentation presentation;

  /// Uses the available width in a vertically scrolling filter drawer.
  final bool stacked;

  /// Applied list scope used for option counts; draft choices remain staged.
  final BeakQuerySpec? countQuery;

  /// Number of advanced-filter columns when the drawer is wide enough.
  final int advancedColumns;

  /// Optional per-facet population, excluding its own editable predicate.
  final BeakQuerySpec Function(BeakFilterDef filter)? countQueryFor;

  /// Optional explanation beside the expandable advanced-filter heading.
  final String? advancedDescription;

  @override
  Widget build(BuildContext context) {
    final invalid = useState(const <String>{});
    final advancedOpen = useState(false);
    final editing = useState<String?>(null);
    final active = useState(initialValues);
    final controls = useState(<String, Object>{
      for (final def in filters)
        if (_initialControl(def, initialValues[def.key])
            case final Object value)
          def.key: value,
    });

    void apply(BeakFilterDef def, {BeakFilter? filter, Object? controlValue}) {
      final nextActive = {...active.value}..remove(def.key);
      if (filter != null) {
        nextActive[def.key] = filter;
      }
      active.value = nextActive;
      final nextControls = {...controls.value}..remove(def.key);
      if (controlValue != null) {
        nextControls[def.key] = controlValue;
      }
      controls.value = nextControls;
      onChanged(BeakFilter.allOf(nextActive.values.toList()));
      onFiltersChanged?.call(Map.unmodifiable(nextActive));
    }

    final children = <Widget>[
      for (final def in filters)
        SizedBox(
          width: stacked ? null : (def is BeakNumberRangeFilter ? 292 : 220),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _control(context, def, controls.value[def.key], apply, (valid) {
                final next = {...invalid.value};
                if (valid) {
                  next.remove(def.key);
                } else {
                  next.add(def.key);
                }
                invalid.value = next;
                onValidityChanged?.call(next.isEmpty);
              }),
              if ((def is BeakBoolFilter || def is BeakSelectFilter) &&
                  controls.value.containsKey(def.key))
                OiButton.ghost(
                  label: BeakLocalizations.of(context).clear,
                  onTap: () => apply(def),
                ),
            ],
          ),
        ),
    ];
    if (!stacked && presentation == BeakFilterBarPresentation.chips) {
      Widget chip(BeakFilterDef def) {
        final current = active.value[def.key];
        return OiPopover(
          label: '${def.label} filter',
          open: editing.value == def.key,
          onClose: () => editing.value = null,
          anchor: OiFilterChip(
            label: def.label,
            value: current == null
                ? null
                : beakFilterSummary(context, def, current),
            selected: current != null,
            onTap: () =>
                editing.value = editing.value == def.key ? null : def.key,
            onRemove: current == null
                ? null
                : () {
                    editing.value = null;
                    final nextInvalid = {...invalid.value}..remove(def.key);
                    invalid.value = nextInvalid;
                    onValidityChanged?.call(nextInvalid.isEmpty);
                    apply(def);
                  },
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _control(context, def, controls.value[def.key], apply, (
                valid,
              ) {
                final next = {...invalid.value};
                if (valid) {
                  next.remove(def.key);
                } else {
                  next.add(def.key);
                }
                invalid.value = next;
                onValidityChanged?.call(next.isEmpty);
              }),
            ),
          ),
        );
      }

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final def in filters) chip(def),
          if (active.value.isNotEmpty)
            OiButton.ghost(
              size: OiButtonSize.small,
              label: 'Clear all',
              onTap: () {
                active.value = const {};
                controls.value = const {};
                invalid.value = const {};
                editing.value = null;
                onValidityChanged?.call(true);
                onChanged(null);
                onFiltersChanged?.call(const {});
              },
            ),
        ],
      );
    }
    if (!stacked) {
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: children,
      );
    }
    final primary = <Widget>[];
    final advanced = <Widget>[];
    for (var index = 0; index < filters.length; index++) {
      (filters[index].advanced ? advanced : primary).add(children[index]);
    }
    Widget sections(List<Widget> fields) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < fields.length; index++) ...[
          if (index > 0) ...[
            const SizedBox(height: 16),
            OiDivider(color: context.colors.borderSubtle),
            const SizedBox(height: 16),
          ],
          fields[index],
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sections(primary),
        if (advanced.isNotEmpty) ...[
          const SizedBox(height: 16),
          OiDivider(color: context.colors.borderSubtle),
          OiTappable(
            semanticLabel: 'More filters',
            onTap: () => advancedOpen.value = !advancedOpen.value,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  OiIcon.decorative(
                    icon: advancedOpen.value
                        ? OiIcons.chevronDown
                        : OiIcons.chevronRight,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const OiLabel.body('More filters'),
                  if (advancedDescription case final String text) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: OiLabel.caption(
                        text,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Keep mounted so collapsing never drops draft values or parse errors.
          Offstage(
            offstage: !advancedOpen.value,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 360
                    ? 1
                    : advancedColumns;
                if (columns == 1) return sections(advanced);
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    for (final field in advanced)
                      SizedBox(
                        width:
                            (constraints.maxWidth - 16 * (columns - 1)) /
                            columns,
                        child: field,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  static Object? _initialControl(BeakFilterDef def, BeakFilter? filter) {
    if (def is BeakChoiceFilter) {
      final predicates = filter is BeakOrFilter ? filter.filters : [?filter];
      return <String>{
        for (final option in def.options)
          if (predicates.any(
            (value) =>
                jsonEncode(value.toJson()) ==
                jsonEncode(option.filter.toJson()),
          ))
            option.key,
      };
    }
    if (filter case BeakAndFilter(:final filters)) {
      final lower = filters
          .whereType<BeakFieldFilter>()
          .where((f) => f.operator == BeakOperator.gte)
          .firstOrNull;
      final upper = filters
          .whereType<BeakFieldFilter>()
          .where(
            (f) =>
                f.operator == BeakOperator.lte || f.operator == BeakOperator.lt,
          )
          .firstOrNull;
      if (def is BeakDateRangeFilter) {
        if ((lower?.value.raw, upper?.value.raw) case (
          final DateTime start,
          final DateTime end,
        )) {
          return (
            start,
            upper?.operator == BeakOperator.lt
                ? end.subtract(const Duration(days: 1))
                : end,
          );
        }
      }
      return (lower?.value, upper?.value);
    }
    if (filter case BeakFieldFilter(:final value)) {
      if (def.column case final BeakEnumColumn<Enum> column) {
        return column.values
            .where((item) => item.name == value.raw)
            .firstOrNull;
      }
      return value.raw;
    }
    return null;
  }

  Widget _control(
    BuildContext context,
    BeakFilterDef def,
    Object? controlValue,
    void Function(BeakFilterDef def, {BeakFilter? filter, Object? controlValue})
    apply,
    ValueChanged<bool> validity,
  ) => switch (def) {
    BeakChoiceFilter() => _ChoiceFilterControl(
      def: def,
      source: dataSource,
      countQuery: countQueryFor?.call(def) ?? countQuery,
      selected: controlValue is Set<String> ? controlValue : const {},
      onChanged: (keys) => apply(
        def,
        controlValue: keys,
        filter: keys.isEmpty
            ? null
            : BeakOrFilter([
                for (final option in def.options)
                  if (keys.contains(option.key)) option.filter,
              ]),
      ),
    ),
    BeakSemanticRangeFilter() => BeakSemanticRangeControl(
      definition: def,
      initial: initialValues[def.key],
      onValidityChanged: validity,
      onChanged: (filter) => apply(def, filter: filter),
    ),
    BeakSelectFilter() => _select(def, controlValue, apply),
    BeakBoolFilter() => OiSelect<bool>(
      label: def.label,
      value: controlValue is bool ? controlValue : null,
      options: [
        OiSelectOption(value: true, label: BeakLocalizations.of(context).yes),
        OiSelectOption(value: false, label: BeakLocalizations.of(context).no),
      ],
      onChanged: (value) => apply(
        def,
        controlValue: value,
        filter: value == null
            ? null
            : BeakFieldFilter.forKey(
                def.key,
                BeakOperator.eq,
                BeakBoolValue(value),
              ),
      ),
    ),
    BeakNumberRangeFilter() => _NumberRangeControl(
      def: def,
      initial: initialValues[def.key],
      onChanged: (minimum, maximum) => apply(
        def,
        filter: BeakFilter.allOf([
          if (minimum != null)
            BeakFieldFilter.forKey(
              def.key,
              BeakOperator.gte,
              BeakValue.of(
                def.column is BeakIntColumn ? minimum.toInt() : minimum,
              ),
            ),
          if (maximum != null)
            BeakFieldFilter.forKey(
              def.key,
              BeakOperator.lte,
              BeakValue.of(
                def.column is BeakIntColumn ? maximum.toInt() : maximum,
              ),
            ),
        ]),
      ),
    ),
    BeakRelationSelectFilter() => _RelationFilterControl(
      def: def,
      dataSource: dataSource,
      initial: initialValues[def.key],
      onChanged: (record) => apply(
        def,
        controlValue: record,
        filter: record == null
            ? null
            : def.relationField.matches(
                BeakFieldFilter(
                  column: def.relationField.target.primaryKey,
                  operator: BeakOperator.eq,
                  value: BeakValue.of(
                    def.relationField.target.primaryKeyOf(record),
                  ),
                ),
              ),
      ),
    ),
    BeakTextFilter() => _TextFilterControl(
      label: def.label,
      initial: controlValue is String ? controlValue : '',
      onChanged: (text) {
        final String trimmed = text.trim();
        apply(
          def,
          controlValue: trimmed.isEmpty ? null : trimmed,
          filter: trimmed.isEmpty
              ? null
              : BeakFieldFilter.forKey(
                  def.key,
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
        filter: BeakAndFilter([
          BeakFieldFilter.forKey(
            def.key,
            BeakOperator.gte,
            BeakDateTimeValue(DateTime(start.year, start.month, start.day)),
          ),
          BeakFieldFilter.forKey(
            def.key,
            BeakOperator.lt,
            BeakDateTimeValue(DateTime(end.year, end.month, end.day + 1)),
          ),
        ]),
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
                  def.key,
                  BeakOperator.eq,
                  BeakStringValue(option.name),
                ),
        ),
      );
    }
    return Builder(
      builder: (context) =>
          OiLabel.caption(BeakLocalizations.of(context).unavailable),
    );
  }
}

/// A concise, localized label for the predicate currently shown by a filter
/// chip. Shared by ordinary resource filters and the composed list toolbar.
String beakFilterSummary(
  BuildContext context,
  BeakFilterDef definition,
  BeakFilter filter,
) {
  if (definition is BeakChoiceFilter) {
    final clauses = filter is BeakOrFilter ? filter.filters : [filter];
    final labels = [
      for (final choice in definition.options)
        if (clauses.any(
          (clause) =>
              jsonEncode(clause.toJson()) == jsonEncode(choice.filter.toJson()),
        ))
          choice.label,
    ];
    return labels.join(', ');
  }
  final formatting = BeakFormatting.of(context);
  String display(BeakValue? value) => value == null
      ? '…'
      : formatting.formatCell(
          definition.column,
          BeakRecord(values: {definition.column.key: value}),
        );
  if (definition is BeakSemanticRangeFilter) {
    final bounds = beakFilterRange(filter);
    for (final preset in definition.presets) {
      if (preset.lower == definition.column.semantic.tryDecode(bounds.$1) &&
          preset.upper == definition.column.semantic.tryDecode(bounds.$2)) {
        return preset.label;
      }
    }
    final lower = definition.column.semantic.tryDecode(bounds.$1);
    final lowerLabel = definition.presets
        .where(
          (preset) => preset.lower == lower && preset.lower == preset.upper,
        )
        .firstOrNull
        ?.label;
    return '${lowerLabel ?? display(bounds.$1)} – ${display(bounds.$2)}';
  }
  if (definition is BeakDateRangeFilter && filter is BeakAndFilter) {
    final lower = filter.filters
        .whereType<BeakFieldFilter>()
        .where((clause) => clause.operator == BeakOperator.gte)
        .firstOrNull;
    final upper = filter.filters
        .whereType<BeakFieldFilter>()
        .where(
          (clause) =>
              clause.operator == BeakOperator.lt ||
              clause.operator == BeakOperator.lte,
        )
        .firstOrNull;
    final upperValue = upper?.value;
    final inclusiveUpper = switch (upperValue?.raw) {
      final DateTime end when upper?.operator == BeakOperator.lt =>
        BeakDateTimeValue(end.subtract(const Duration(days: 1))),
      _ => upperValue,
    };
    if (lower == null) return 'Through ${display(inclusiveUpper)}';
    if (inclusiveUpper == null) return 'From ${display(lower.value)}';
    return '${display(lower.value)} – ${display(inclusiveUpper)}';
  }
  if (filter case BeakFieldFilter(:final value)) return display(value);
  return 'Active';
}

/// An inclusive numeric range; either endpoint can be left open.
final class BeakNumberRangeFilter extends BeakFilterDef {
  /// Creates a numeric range over a typed field, including related paths.
  BeakNumberRangeFilter({
    required BeakScalarField<Object> field,
    required super.label,
    super.advanced,
    this.showMinimum = true,
    this.showMaximum = true,
    this.minimumLabel,
    this.maximumLabel,
    this.placeholder,
  }) : assert(showMinimum || showMaximum),
       super(column: field.column, field: field);

  /// Whether the lower bound is editable.
  final bool showMinimum;

  /// Whether the upper bound is editable.
  final bool showMaximum;

  /// Example shown when either bound is empty.
  final String? placeholder;

  /// Optional full label of a lower-bound-only input.
  final String? minimumLabel;

  /// Optional full label of an upper-bound-only input.
  final String? maximumLabel;
}

/// A searchable related-record filter using a typed to-one relationship.
final class BeakRelationSelectFilter extends BeakFilterDef {
  /// Derives target identity, labels and option searches from [relationField].
  BeakRelationSelectFilter({
    required this.relationField,
    String? label,
    this.options,
    super.advanced,
  }) : super(
         column: relationField.target.primaryKey,
         label: label ?? relationField.label,
         field: relationField,
       );

  /// Relationship whose selected target must match.
  final BeakToOneField relationField;

  /// Optional permanent constraint and includes for the option query.
  final BeakOptionQuery? options;
}

/// Text filters from generated string fields, including related paths.
extension BeakTextFieldFilters on BeakScalarField<String> {
  /// Matches a case-insensitive substring.
  BeakTextFilter textFilter({String? label, bool advanced = false}) =>
      BeakTextFilter(
        field: this,
        label: label ?? this.label,
        advanced: advanced,
      );
}

/// Numeric range filters from generated numeric fields.
extension BeakNumberFieldFilters<T extends num> on BeakScalarField<T> {
  /// Constrains the value between independently optional endpoints.
  BeakNumberRangeFilter numberRangeFilter({
    String? label,
    bool advanced = false,
    bool showMinimum = true,
    bool showMaximum = true,
    String? minimumLabel,
    String? maximumLabel,
    String? placeholder,
  }) => BeakNumberRangeFilter(
    field: this,
    label: label ?? this.label,
    advanced: advanced,
    showMinimum: showMinimum,
    showMaximum: showMaximum,
    minimumLabel: minimumLabel,
    maximumLabel: maximumLabel,
    placeholder: placeholder,
  );
}

/// Three-state filters for generated boolean fields.
extension BeakBooleanFieldFilters on BeakScalarField<bool> {
  /// Offers yes, no, and clearing back to every record.
  BeakBoolFilter boolFilter({String? label, bool advanced = false}) =>
      BeakBoolFilter(
        field: this,
        label: label ?? this.label,
        advanced: advanced,
      );
}

/// Enum filters from generated enum fields.
extension BeakEnumFieldFilters<T extends Enum> on BeakScalarField<T> {
  /// Offers the model enum's labels and serialized values.
  BeakSelectFilter selectFilter({String? label, bool advanced = false}) =>
      BeakSelectFilter(
        field: this,
        label: label ?? this.label,
        advanced: advanced,
      );
}

/// Calendar ranges from generated date fields.
extension BeakDateFieldFilters on BeakScalarField<DateTime> {
  /// Includes the whole selected final calendar day.
  BeakDateRangeFilter dateRangeFilter({String? label, bool advanced = false}) =>
      BeakDateRangeFilter(
        field: this,
        label: label ?? this.label,
        advanced: advanced,
      );
}

/// Calendar-date ranges preserve the date without timezone conversion.
extension BeakCalendarDateFieldFilters on BeakScalarField<BeakDate> {
  /// Includes both supplied calendar endpoints.
  BeakSemanticRangeFilter dateRangeFilter({
    String? label,
    bool advanced = false,
    bool inline = false,
    List<BeakRangePreset<BeakDate>> presets = const [],
  }) => rangeFilter(
    label: label,
    advanced: advanced,
    inline: inline,
    presets: presets,
  );
}

/// Searchable relationship filters from generated to-one fields.
extension BeakRelationFieldFilters on BeakToOneField {
  /// Filters by a selected related record without manually naming keys.
  BeakRelationSelectFilter relationFilter({
    String? label,
    BeakOptionQuery? options,
    bool advanced = false,
  }) => BeakRelationSelectFilter(
    relationField: this,
    label: label,
    options: options,
    advanced: advanced,
  );
}

double? _doubleOf(Object? raw) => switch (raw) {
  final num number => number.toDouble(),
  _ => null,
};

class _NumberRangeControl extends HookWidget {
  const _NumberRangeControl({
    required this.def,
    required this.onChanged,
    this.initial,
  });
  final BeakFilter? initial;
  final BeakNumberRangeFilter def;
  final void Function(double? minimum, double? maximum) onChanged;
  @override
  Widget build(BuildContext context) {
    final bounds = beakFilterRange(initial);
    final formatted = switch (def.field) {
      final BeakFormattedField<num> field => field,
      _ => null,
    };
    final currency = formatted?.format == BeakValueFormat.currency;
    final scale = formatted?.minorUnits == true
        ? math.pow(10, formatted!.scale).toDouble()
        : 1.0;
    final minimum = useState<double?>(_doubleOf(bounds.$1?.raw));
    final maximum = useState<double?>(_doubleOf(bounds.$2?.raw));
    final digits = currency
        ? formatted?.scale ?? 2
        : def.column is BeakIntColumn
        ? 0
        : null;
    Widget input({required bool lower}) => OiNumberInput(
      label: lower
          ? def.minimumLabel ?? '${def.label} ≥'
          : def.maximumLabel ?? '${def.label} ≤',
      value: (lower ? minimum.value : maximum.value) == null
          ? null
          : (lower ? minimum.value! : maximum.value!) / scale,
      decimalPlaces: digits,
      showSteppers: !currency,
      placeholder: def.placeholder,
      suffix: currency
          ? OiLabel.body(
              BeakFormatting.of(context).currencySymbol,
              color: context.colors.textMuted,
            )
          : null,
      onChanged: (value) {
        final stored = value == null
            ? null
            : formatted?.minorUnits == true
            ? (value * scale).roundToDouble()
            : value;
        if (lower) {
          minimum.value = stored;
        } else {
          maximum.value = stored;
        }
        onChanged(minimum.value, maximum.value);
      },
    );
    if (!def.showMinimum) return input(lower: false);
    if (!def.showMaximum) return input(lower: true);
    return Wrap(
      spacing: 12,
      children: [
        SizedBox(width: 140, child: input(lower: true)),
        SizedBox(width: 140, child: input(lower: false)),
      ],
    );
  }
}

class _RelationFilterControl extends HookWidget {
  const _RelationFilterControl({
    required this.def,
    required this.dataSource,
    required this.onChanged,
    this.initial,
  });
  final BeakFilter? initial;
  final BeakRelationSelectFilter def;
  final BeakDataSource? dataSource;
  final ValueChanged<BeakRecord?> onChanged;
  @override
  Widget build(BuildContext context) {
    final container = beakDependencies(context);
    final source =
        dataSource ??
        (container.isRegistered<BeakDataSource>()
            ? container<BeakDataSource>()
            : null);
    final initialId = _relationIdentity(initial);
    final selected = useState<BeakRecord?>(
      initialId == null
          ? null
          : BeakRecord(
              values: {def.relationField.target.primaryKey.key: initialId},
            ),
    );
    final error = useState<BeakException?>(null);
    final requests = useRef(0);
    final latest = useRef<Future<List<BeakRecord>>?>(null);
    if (source == null) {
      return OiLabel.caption(BeakLocalizations.of(context).unavailable);
    }
    return _RelatedChoices(
      source: source,
      def: def,
      selected: selected.value,
      error: error.value,
      search: (term) async {
        Future<List<BeakRecord>> run() async {
          final request = ++requests.value;
          final base = def.options?.query ?? def.relationField.options().query;
          final result = await BeakResourceRepository(source).query(
            BeakQuerySpec(
              table: base.table,
              filter: base.filter,
              relationLoads: base.relationLoads,
              sorts: base.sorts,
              pagination: base.pagination,
              search: term.trim().isEmpty
                  ? null
                  : BeakSearch(
                      term.trim(),
                      def.relationField.relation.effectiveSearchColumnKeys,
                    ),
            ),
          );
          if (!context.mounted || request != requests.value) return const [];
          return switch (result) {
            BeakOk(:final value) => () {
              error.value = null;
              return value.items;
            }(),
            BeakErr(error: final failure) => () {
              error.value = failure;
              return <BeakRecord>[];
            }(),
          };
        }

        var pending = run();
        latest.value = pending;
        while (context.mounted) {
          final records = await pending;
          if (identical(pending, latest.value)) return records;
          pending = latest.value!;
        }
        return const [];
      },
      onSelect: (record) {
        selected.value = record;
        onChanged(record);
      },
      onResolved: (record) => selected.value = record,
      onFailure: (failure) => error.value = failure,
    );
  }
}

class _RelatedChoices extends HookWidget {
  const _RelatedChoices({
    required this.source,
    required this.def,
    required this.selected,
    required this.error,
    required this.search,
    required this.onSelect,
    required this.onResolved,
    required this.onFailure,
  });
  final BeakDataSource source;
  final BeakRelationSelectFilter def;
  final BeakRecord? selected;
  final BeakException? error;
  final Future<List<BeakRecord>> Function(String) search;
  final ValueChanged<BeakRecord?> onSelect;
  final ValueChanged<BeakRecord> onResolved;
  final ValueChanged<BeakException?> onFailure;
  @override
  Widget build(BuildContext context) {
    final revision = useBeakDataRevision(
      source,
      table: def.relationField.target.table,
    );
    final retry = useState(0);
    final selectedId = selected == null
        ? null
        : def.relationField.target.primaryKeyOf(selected!);
    useEffect(() {
      if (selectedId == null) return null;
      var active = true;
      Future<void> resolve() async {
        final result = await BeakResourceRepository(
          source,
        ).getOne(def.relationField.target.table, selectedId);
        if (!active) return;
        switch (result) {
          case BeakOk(:final value):
            onResolved(value);
          case BeakErr(:final error):
            onFailure(error);
        }
      }

      resolve();
      return () => active = false;
    }, [source, selectedId, revision]);
    final items = useMemoized(() => <BeakRecord>[], [revision, retry.value]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OiComboBox<BeakRecord>(
          label: def.label,
          items: items,
          labelOf: def.relationField.relation.displayLabelOf,
          value: selected,
          error: error?.message,
          search: search,
          onSelect: onSelect,
        ),
        if (error != null)
          OiButton.ghost(
            label: BeakLocalizations.of(context).retry,
            onTap: () => retry.value++,
          ),
      ],
    );
  }
}

/// Named endpoints in the field's semantic type, such as a calendar date or money.
final class BeakRangePreset<T extends Object> {
  /// Either endpoint may be omitted for an open range.
  const BeakRangePreset({required this.label, this.lower, this.upper});

  /// Visible preset label.
  final String label;

  /// Inclusive start of the range.
  final T? lower;

  /// Inclusive end of the range.
  final T? upper;
}

/// An inclusive range over exact money, calendar dates, time or durations.
final class BeakSemanticRangeFilter extends BeakFilterDef {
  /// Creates a range whose endpoints use the model's semantic codec.
  BeakSemanticRangeFilter({
    required BeakScalarField<Object> field,
    required super.label,
    super.advanced,
    this.inline = false,
    this.presets = const [],
  }) : super(column: field.column, field: field);

  /// Places endpoints side by side when the available width permits.
  final bool inline;

  /// Optional named ranges, followed by an editable Custom choice.
  final List<BeakRangePreset<Object>> presets;
}

/// Semantic range filters over generated fields, including related paths.
extension BeakSemanticFieldFilters<T extends Object> on BeakScalarField<T> {
  /// Preserves exact storage units while editing human-readable endpoints.
  BeakSemanticRangeFilter rangeFilter({
    String? label,
    bool advanced = false,
    bool inline = false,
    List<BeakRangePreset<T>> presets = const [],
  }) => BeakSemanticRangeFilter(
    field: this,
    label: label ?? this.label,
    advanced: advanced,
    inline: inline,
    presets: presets,
  );
}

BeakValue? _relationIdentity(BeakFilter? filter) => switch (filter) {
  BeakRelationFilter(:final filter) => _relationIdentity(filter),
  BeakFieldFilter(operator: BeakOperator.eq, :final value) => value,
  _ => null,
};

class _TextFilterControl extends HookWidget {
  const _TextFilterControl({
    required this.label,
    required this.initial,
    required this.onChanged,
  });
  final String label;
  final String initial;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final text = useTextEditingController(text: initial);
    return OiTextInput(label: label, controller: text, onChanged: onChanged);
  }
}

class _ChoiceFilterControl extends HookWidget {
  const _ChoiceFilterControl({
    required this.def,
    required this.selected,
    required this.onChanged,
    this.source,
    this.countQuery,
  });
  final BeakChoiceFilter def;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final BeakDataSource? source;
  final BeakQuerySpec? countQuery;
  void _change(String key, bool value) {
    final next = {...selected};
    if (value) {
      next.add(key);
    } else {
      next.remove(key);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final counts = useState<Map<String, num>>(const {});
    final query = countQuery ?? def.field.model.query();
    final revision = useBeakDataRevision(source, table: query.table);
    useEffect(
      () {
        counts.value = const {};
        final data = source;
        final summaries = switch (data) {
          final BeakSummaryDataSource summaries => summaries,
          _ => null,
        };
        if (!def.showCounts || data == null || summaries == null) {
          return null;
        }
        var current = true;
        Future<void> load() async {
          final loaded = <String, num>{};
          for (var start = 0; start < def.options.length; start += 8) {
            final choices = def.options.skip(start).take(8).toList();
            final measures = [
              for (var i = 0; i < choices.length; i++)
                BeakSummaryMeasure.count(
                  'facet_${start + i}',
                  filter: choices[i].filter,
                ),
            ];
            final result = await BeakResourceRepository(data).run(
              () => summaries.summary(
                def.field.model.summary(measures: measures).withQuery(query),
              ),
            );
            if (!current) return;
            if (result case BeakOk(:final value)) {
              if (value.rows.isNotEmpty) {
                for (var i = 0; i < choices.length; i++) {
                  final count = value.rows.first.valueOf(measures[i]);
                  if (count != null) loaded[choices[i].key] = count;
                }
              }
            }
          }
          if (current) counts.value = loaded;
        }

        load();
        return () => current = false;
      },
      [
        source,
        jsonEncode(query.toJson()),
        def.showCounts,
        revision,
        jsonEncode([
          for (final choice in def.options)
            [choice.key, choice.filter.toJson()],
        ]),
      ],
    );
    if (def.presentation == BeakChoiceFilterPresentation.select) {
      return OiSelect<String>(
        label: def.showLabel ? def.label : null,
        value: selected.firstOrNull ?? '',
        options: [
          OiSelectOption(value: '', label: def.allLabel),
          for (final option in def.options)
            OiSelectOption(value: option.key, label: option.label),
        ],
        onChanged: (value) =>
            onChanged(value == null || value.isEmpty ? {} : {value}),
      );
    }
    if (def.presentation == BeakChoiceFilterPresentation.combobox) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          OiLabel.bodyStrong(def.label),
          const SizedBox(height: 8),
          OiComboBox<BeakFilterChoice>(
            label: def.label,
            showLabel: false,
            addItemLabel: def.addItemLabel,
            placeholder: def.addItemLabel,
            labelOf: (choice) => choice.label,
            items: def.options,
            multiSelect: true,
            selectedValues: [
              for (final option in def.options)
                if (selected.contains(option.key)) option,
            ],
            onMultiSelect: (choices) =>
                onChanged({for (final choice in choices) choice.key}),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (def.showLabel) ...[
          OiLabel.bodyStrong(def.label),
          const SizedBox(height: 8),
        ],
        switch (def.presentation) {
          BeakChoiceFilterPresentation.radio => OiRadio<String>(
            direction: Axis.horizontal,
            value: selected.firstOrNull ?? '',
            options: [
              OiRadioOption(value: '', label: def.allLabel),
              for (final option in def.options)
                OiRadioOption(value: option.key, label: option.label),
            ],
            onChanged: (value) => onChanged(value.isEmpty ? {} : {value}),
          ),
          BeakChoiceFilterPresentation.chips => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in def.options)
                OiFilterChip(
                  label: option.label,
                  semanticLabel: option.label,
                  selected: selected.contains(option.key),
                  dashed: false,
                  showAddIcon: false,
                  onTap: () =>
                      _change(option.key, !selected.contains(option.key)),
                ),
            ],
          ),
          _ => LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 360 ? 1 : def.columns;
              final width =
                  (constraints.maxWidth - 24 * (columns - 1)) / columns;
              return Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  for (final option in def.options)
                    SizedBox(
                      width: width,
                      child: Row(
                        children: [
                          Expanded(
                            child: OiCheckbox(
                              label: option.label,
                              value: selected.contains(option.key),
                              onChanged: (value) => _change(option.key, value),
                            ),
                          ),
                          if (def.showCounts)
                            OiLabel.body(
                              counts.value[option.key]?.toString() ?? '—',
                              color: context.colors.textMuted,
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        },
      ],
    );
  }
}
