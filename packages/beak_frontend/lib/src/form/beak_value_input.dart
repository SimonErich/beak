import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../formatting/beak_formatting.dart';
import 'beak_form_controller_builder.dart';
import 'beak_input_codec.dart';
import 'beak_input_presentation.dart';

enum _BooleanValue { unset, yes, no }

/// Binds specialized semantic controls to the same automatic form controller.
class BeakBoundValueInput extends HookWidget {
  /// Creates a model-driven editor without a second source of form state.
  const BeakBoundValueInput({
    required this.controller,
    required this.column,
    this.label,
    this.description,
    this.enabled = true,
    this.error,
    this.presentation = BeakInputPresentation.automatic,
    this.choices,
    this.choiceMinWidth,
    this.choiceCardPadding,
    this.groupLabelAsField = false,
    this.controlWidth,
    this.allowCustom = false,
    this.maxLines,
    this.placeholder,
    this.showCounter,
    this.dateShortcuts = const [],
    super.key,
  });

  /// Controller owning the draft value.
  final BeakFormController controller;

  /// Storage and semantic metadata.
  final BeakColumn column;

  /// Optional placement label.
  final String? label;

  /// Optional placement guidance.
  final String? description;

  /// Whether edits are allowed.
  final bool enabled;

  /// Session or server validation feedback.
  final String? error;

  /// Optional control style.
  final BeakInputPresentation presentation;

  /// Current typed options, if constrained.
  final List<BeakInputOption<Object>>? choices;

  /// Minimum wrapping radio-card width; null keeps the vertical group.
  final double? choiceMinWidth;

  /// Optional padding for description-bearing choice cards.
  final EdgeInsetsGeometry? choiceCardPadding;

  /// Uses the input field label role instead of the radio section heading.
  final bool groupLabelAsField;

  /// Optional width of a quantity control.
  final double? controlWidth;

  /// Visible text lines, or the model default.
  final int? maxLines;

  /// Text prompt without replacing the label.
  final String? placeholder;

  /// Optional character counter visibility override.
  final bool? showCounter;

  /// Suggested dates without restricting the calendar.
  final List<BeakInputOption<BeakDate>> dateShortcuts;

  /// Whether tag suggestions are nonexclusive.
  final bool allowCustom;

  @override
  Widget build(BuildContext context) {
    useListenable(controller);
    return BeakValueInput(
      column: column,
      value: controller.valueOf<Object>(column),
      record: controller.buildData(),
      label: label,
      description: description,
      enabled: enabled,
      error: controller.inputErrors[column.key] ?? error,
      presentation: presentation,
      choices: choices,
      choiceMinWidth: choiceMinWidth,
      choiceCardPadding: choiceCardPadding,
      groupLabelAsField: groupLabelAsField,
      controlWidth: controlWidth,
      allowCustom: allowCustom,
      maxLines: maxLines,
      placeholder: placeholder,
      showCounter: showCounter,
      dateShortcuts: dateShortcuts,
      onChanged: (value) => controller.setValue<Object>(column, value),
      onError: (error) => controller.setInputError(column, error),
    );
  }
}

/// One reusable semantic editor, also used recursively for embedded objects.
class BeakValueInput extends HookWidget {
  /// Edits a typed value using metadata and reports incomplete text separately.
  const BeakValueInput({
    required this.column,
    required this.value,
    required this.onChanged,
    required this.onError,
    this.record = const BeakRecord(values: {}),
    this.label,
    this.description,
    this.enabled = true,
    this.error,
    this.presentation = BeakInputPresentation.automatic,
    this.choices,
    this.choiceMinWidth,
    this.choiceCardPadding,
    this.groupLabelAsField = false,
    this.controlWidth,
    this.allowCustom = false,
    this.maxLines,
    this.placeholder,
    this.showCounter,
    this.dateShortcuts = const [],
    super.key,
  });

  /// Storage and semantic metadata.
  final BeakColumn column;

  /// Current typed draft value.
  final Object? value;

  /// Owning record, used for per-record currency selection.
  final BeakRecord record;

  /// Receives successfully parsed values only.
  final ValueChanged<Object?> onChanged;

  /// Receives parser errors that must block submission.
  final ValueChanged<String?> onError;

  /// Optional placement label.
  final String? label;

  /// Optional guidance.
  final String? description;

  /// Whether editing is permitted.
  final bool enabled;

  /// Validation feedback from the enclosing form.
  final String? error;

  /// Optional control style.
  final BeakInputPresentation presentation;

  /// Current constrained choices.
  final List<BeakInputOption<Object>>? choices;

  /// Minimum wrapping radio-card width; null keeps the vertical group.
  final double? choiceMinWidth;

  /// Optional padding for description-bearing choice cards.
  final EdgeInsetsGeometry? choiceCardPadding;

  /// Uses the input field label role instead of the radio section heading.
  final bool groupLabelAsField;

  /// Optional width of a quantity control.
  final double? controlWidth;

  /// Visible text lines, or the model default.
  final int? maxLines;

  /// Text prompt without replacing the label.
  final String? placeholder;

  /// Optional character counter visibility override.
  final bool? showCounter;

  /// Suggested dates without restricting the calendar.
  final List<BeakInputOption<BeakDate>> dateShortcuts;

  /// Whether tags may fall outside the suggestions.
  final bool allowCustom;

  @override
  Widget build(BuildContext context) {
    final title = label ?? column.label;
    final formatting = BeakFormatting.of(context);
    final semantic = column.semantic;
    final kind = semantic.kind;
    final childErrors = useRef(<String, String>{});
    final query = useState('');
    final initialText = BeakInputCodec.text(column, value, formatting);
    final controller = useTextEditingController(text: initialText);
    final accepted = useRef(value);
    useEffect(() {
      if (value != accepted.value) {
        controller.text = initialText;
        accepted.value = value;
      }
      return null;
    }, [value, formatting]);
    Widget group(List<Widget> children, {bool showLabel = true}) {
      final radio =
          presentation == BeakInputPresentation.radio ||
          presentation == BeakInputPresentation.radioCards;
      final headingGap = radio
          ? groupLabelAsField
                ? (context.components.textInput?.labelGap ?? 8)
                : (context.components.radio?.groupLabelSpacing ?? 8)
          : 8.0;
      final headingStyle = radio
          ? groupLabelAsField
                ? context.components.textInput?.labelStyle ??
                      context.textTheme.body
                : context.components.radio?.groupLabelStyle ??
                      context.textTheme.body
          : context.textTheme.body;
      return OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        gap: OiResponsive<double>(headingGap),
        children: [
          if (showLabel && title.isNotEmpty)
            OiFieldLabel(
              title,
              excludeLabelSemantics: false,
              style: headingStyle,
            ),
          OiColumn(
            breakpoint: context.breakpoint,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            gap: const OiResponsive<double>(8),
            children: [
              ...children,
              if (description != null) OiLabel.caption(description!),
              if (error != null)
                OiLabel.caption(error!, color: context.colors.error.base),
            ],
          ),
        ],
      );
    }

    void change(Object? next) {
      onError(null);
      onChanged(next);
    }

    final options =
        choices ??
        switch (column) {
          final BeakEnumColumn<Enum> enumeration => [
            for (final option in enumeration.values)
              BeakInputOption<Object>(option, enumeration.labelFor(option)),
          ],
          _ => null,
        };
    if (column case BeakBoolColumn(
      tristate: true,
      :final trueLabel,
      :final falseLabel,
    )) {
      return group([
        OiRadio<_BooleanValue>(
          enabled: enabled,
          value: switch (value) {
            true => _BooleanValue.yes,
            false => _BooleanValue.no,
            _ => _BooleanValue.unset,
          },
          options: [
            const OiRadioOption(value: _BooleanValue.unset, label: 'Not set'),
            OiRadioOption(value: _BooleanValue.yes, label: trueLabel ?? 'Yes'),
            OiRadioOption(value: _BooleanValue.no, label: falseLabel ?? 'No'),
          ],
          onChanged: (next) => change(switch (next) {
            _BooleanValue.yes => true,
            _BooleanValue.no => false,
            _BooleanValue.unset => null,
          }),
        ),
      ]);
    }
    if (presentation == BeakInputPresentation.tags ||
        (kind == BeakSemanticKind.primitiveList &&
            semantic.listItemType == BeakPrimitiveType.string &&
            options == null &&
            presentation == BeakInputPresentation.automatic)) {
      return OiTagInput(
        label: title,
        hint: description,
        error: error,
        enabled: enabled,
        tags: switch (value) {
          final List<String> values => values,
          _ => const [],
        },
        maxTags: semantic.maxItems,
        suggestions: options
            ?.where((option) => option.enabled)
            .map((option) => option.value)
            .whereType<String>()
            .toList(),
        allowCustomTags: options == null || allowCustom,
        onChanged: change,
      );
    }
    if (options != null) {
      if (presentation == BeakInputPresentation.multiSelect ||
          presentation == BeakInputPresentation.checkboxGroup) {
        final selected = switch (value) {
          final List<Object> items => items,
          _ => const <Object>[],
        };
        return group([
          if (presentation == BeakInputPresentation.multiSelect)
            OiTextInput.search(
              onChanged: (text) => query.value = text,
              enabled: enabled,
            ),
          for (final option in options.where(
            (option) =>
                option.label.toLowerCase().contains(query.value.toLowerCase()),
          ))
            OiCheckbox(
              label: option.label,
              enabled: enabled && option.enabled,
              value: selected.contains(option.value),
              onChanged: (checked) => change(
                _typedList([
                  for (final item in selected)
                    if (item != option.value) item,
                  if (checked) option.value,
                ], semantic.listItemType),
              ),
            ),
        ]);
      }
      if (presentation == BeakInputPresentation.radioCards) {
        if (options.isEmpty) return group(const []);
        final cards = <Widget>[
          for (final option in options)
            OiRadioTile<Object>.card(
              title: option.label,
              titleWidget: choiceMinWidth == null
                  ? Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OiLabel.variant(
                          option.label,
                          variant: OiLabelVariant.bodyStrong,
                          style: context.components.radioTile?.titleStyle,
                        ),
                        if (option.description case final description?)
                          OiLabel.caption(description),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OiLabel.variant(
                          option.label,
                          variant: OiLabelVariant.bodyStrong,
                          style: context.components.radioTile?.titleStyle,
                        ),
                        if (option.description case final description?)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: OiLabel.caption(description),
                          ),
                      ],
                    ),
              leading: option.icon == null
                  ? null
                  : OiIcon.decorative(icon: option.icon, size: 16),
              value: option.value,
              groupValue: value,
              onChanged: change,
              enabled: enabled && option.enabled,
              controlLeading: true,
              contentPadding: choiceCardPadding,
            ),
        ];
        return group([
          if (choiceMinWidth == null)
            ...cards
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    ((constraints.maxWidth + 12) / (choiceMinWidth! + 12))
                        .floor()
                        .clamp(1, cards.length);
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final card in cards)
                      SizedBox(width: width, child: card),
                  ],
                );
              },
            ),
        ]);
      }
      if (presentation == BeakInputPresentation.radio) {
        return group([
          OiRadio<Object>(
            value: value,
            enabled: enabled,
            options: [
              for (final option in options)
                OiRadioOption(
                  value: option.value,
                  label: option.label,
                  enabled: option.enabled,
                ),
            ],
            onChanged: change,
          ),
        ]);
      }
      return OiSelect<Object>(
        label: title,
        hint: description,
        error: error,
        value: value,
        enabled: enabled,
        searchable: true,
        options: [
          for (final option in options)
            OiSelectOption(
              value: option.value,
              label: option.label,
              enabled: option.enabled,
            ),
        ],
        onChanged: change,
      );
    }
    if (kind == BeakSemanticKind.calendarDate) {
      if (dateShortcuts.isNotEmpty && dateShortcuts.length <= 4) {
        return group([
          OiDateInput(
            semanticLabel: title.isEmpty ? column.label : title,
            enabled: enabled,
            dateFormat: formatting.dateInputPattern,
            locale: formatting.locale,
            value: value is BeakDate ? (value as BeakDate).toDateTime() : null,
            presets: [
              for (final shortcut in dateShortcuts)
                OiDatePreset(
                  date: shortcut.value.toDateTime(),
                  label: shortcut.label,
                  enabled: shortcut.enabled,
                ),
            ],
            onChanged: (date) => change(
              date == null ? null : BeakDate(date.year, date.month, date.day),
            ),
          ),
        ]);
      }
      final picker = OiDateInput(
        label: dateShortcuts.isEmpty ? title : null,
        hint: dateShortcuts.isEmpty ? description : null,
        error: dateShortcuts.isEmpty ? error : null,
        enabled: enabled,
        dateFormat: formatting.dateInputPattern,
        locale: formatting.locale,
        value: switch (value) {
          final BeakDate date => date.toDateTime(),
          _ => null,
        },
        onChanged: (date) => change(
          date == null ? null : BeakDate(date.year, date.month, date.day),
        ),
      );
      if (dateShortcuts.isEmpty) return picker;
      return group([
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (dateShortcuts.length <= 5)
              OiSegmentedControl<BeakDate?>(
                semanticLabel: '$title shortcuts',
                segments: [
                  for (final shortcut in dateShortcuts)
                    OiSegment(
                      value: shortcut.value,
                      label: shortcut.label,
                      enabled: shortcut.enabled,
                    ),
                ],
                selected: value is BeakDate ? value as BeakDate : null,
                enabled: enabled,
                onChanged: change,
              )
            else
              for (final shortcut in dateShortcuts)
                OiToggleButton(
                  label: shortcut.label,
                  semanticLabel: shortcut.label,
                  selected: value == shortcut.value,
                  enabled: enabled && shortcut.enabled,
                  onChanged: (_) => change(shortcut.value),
                ),
            Semantics(
              label: 'Pick a date',
              child: SizedBox(width: 180, child: picker),
            ),
          ],
        ),
      ]);
    }
    if ((kind, presentation, semantic.objectSchema) case (
      BeakSemanticKind.object,
      final style,
      final BeakObjectSchema schema,
    ) when style != BeakInputPresentation.json) {
      final object = switch (value) {
        final BeakJsonObject item => item,
        _ => const BeakJsonObject({}),
      };
      return group([
        for (final child in schema.columns)
          BeakValueInput(
            key: ValueKey(child.key),
            column: child,
            value: schema.readValue<Object>(child, object),
            record: schema.toRecord(object),
            enabled: enabled,
            onChanged: (next) => onChanged(schema.write(child, object, next)),
            onError: (message) {
              if (message == null) {
                childErrors.value.remove(child.key);
              } else {
                childErrors.value[child.key] = '${child.label}: $message';
              }
              onError(
                childErrors.value.isEmpty
                    ? null
                    : childErrors.value.values.join(' '),
              );
            },
          ),
      ]);
    }
    if (kind == BeakSemanticKind.primitiveList &&
        presentation != BeakInputPresentation.json) {
      final values = switch (value) {
        final List<Object> items => items,
        _ => const <Object>[],
      };
      final childColumn = _primitiveColumn(semantic.listItemType);
      return OiArrayInput<Object>(
        label: title,
        error: error,
        items: values,
        minItems: semantic.minItems,
        maxItems: semantic.maxItems,
        addable: enabled,
        removable: enabled,
        reorderable: enabled,
        createEmpty: () => switch (semantic.listItemType) {
          BeakPrimitiveType.integer => 0,
          BeakPrimitiveType.decimal => 0.0,
          BeakPrimitiveType.boolean => false,
          _ => '',
        },
        onChanged: (next) => change(_typedList(next, semantic.listItemType)),
        itemBuilder: (context, index, item, update) => BeakValueInput(
          column: childColumn,
          value: item,
          enabled: enabled,
          onChanged: (next) {
            if (next != null) update(next);
          },
          onError: onError,
        ),
      );
    }
    if (column is BeakDateTimeColumn) {
      return OiDateTimeInput(
        label: title,
        hint: description,
        error: error,
        enabled: enabled,
        dateFormat: formatting.dateInputPattern,
        locale: formatting.locale,
        value: switch (value) {
          final DateTime instant => formatting.toEditorDateTime(instant),
          _ => null,
        },
        onChanged: (edited) => change(
          edited == null ? null : formatting.fromEditorDateTime(edited),
        ),
      );
    }
    if (column is BeakBoolColumn) {
      return group([
        OiCheckbox(
          label: title,
          enabled: enabled,
          value: value == true,
          onChanged: change,
        ),
      ], showLabel: false);
    }
    if ((column is BeakIntColumn || column is BeakDecimalColumn) &&
        !semantic.hasCodec &&
        kind != BeakSemanticKind.percentage) {
      if (column case final BeakIntColumn integer
          when presentation == BeakInputPresentation.quantity) {
        final minimum =
            [
              if (integer.min != null) integer.min!,
              for (final rule in column.rules.whereType<BeakMin>())
                rule.min.ceil(),
            ].fold<int?>(
              null,
              (bound, next) => bound == null || next > bound ? next : bound,
            ) ??
            0;
        final maximum =
            [
              if (integer.max != null) integer.max!,
              for (final rule in column.rules.whereType<BeakMax>())
                rule.max.floor(),
            ].fold<int?>(
              null,
              (bound, next) => bound == null || next < bound ? next : bound,
            ) ??
            0x7fffffff;
        return group([
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OiQuantitySelector(
              width: controlWidth,
              value: value is int ? value as int : 0,
              label: title.isEmpty ? column.label : title,
              min: minimum,
              max: maximum,
              compact: true,
              disabled: !enabled,
              onChange: (next) => change(next.clamp(minimum, maximum)),
            ),
          ),
        ]);
      }
      return OiNumberInput(
        label: title,
        hint:
            description ??
            (kind == BeakSemanticKind.fileSize ? 'Bytes' : semantic.unit),
        error: error,
        value: switch (value) {
          final num number => number.toDouble(),
          _ => null,
        },
        enabled: enabled,
        decimalPlaces: column is BeakIntColumn
            ? 0
            : switch (column) {
                BeakDecimalColumn(:final precision) => precision,
                _ => null,
              },
        onChanged: (next) =>
            change(column is BeakIntColumn ? next?.toInt() : next),
      );
    }
    void textChanged(String text) {
      final parsed = BeakInputCodec.parse(column, text, formatting);
      onError(parsed.error);
      if (parsed.error == null) {
        accepted.value = parsed.value;
        onChanged(parsed.value);
      }
    }

    if (kind == BeakSemanticKind.password) {
      return OiTextInput.password(
        controller: controller,
        label: title,
        hint: description,
        error: error,
        enabled: enabled,
        onChanged: textChanged,
      );
    }
    final multiline = maxLines != null
        ? maxLines! > 1
        : column is BeakJsonColumn || column is BeakTextColumn;
    final suffix = switch (kind) {
      BeakSemanticKind.money =>
        semantic.currencyFor(record) ?? formatting.currencyCode,
      BeakSemanticKind.percentage => '%',
      BeakSemanticKind.quantity => semantic.unit,
      _ => null,
    };
    return OiTextInput(
      controller: controller,
      label: title,
      semanticLabel: title.isEmpty ? column.label : title,
      hint: description,
      error: error,
      enabled: enabled,
      maxLines: maxLines ?? (multiline ? 6 : 1),
      minLines: maxLines != null && maxLines! > 1 ? maxLines : null,
      maxLength: column.rules.whereType<BeakMaxLength>().firstOrNull?.maxLength,
      showCounter: showCounter ?? (maxLines != null && maxLines! > 1),
      trailing: suffix == null ? null : OiLabel.caption(suffix),
      placeholder:
          placeholder ??
          switch (kind) {
            BeakSemanticKind.time => 'HH:mm:ss',
            BeakSemanticKind.duration => '0:00:00',
            BeakSemanticKind.money || BeakSemanticKind.exactDecimal =>
              '0${formatting.decimalSeparator}${'0' * semantic.scale}',
            _ => null,
          },
      textInputAction: multiline ? TextInputAction.newline : null,
      keyboardType: switch (kind) {
        BeakSemanticKind.email => TextInputType.emailAddress,
        BeakSemanticKind.url => TextInputType.url,
        BeakSemanticKind.phone => TextInputType.phone,
        BeakSemanticKind.money ||
        BeakSemanticKind.exactDecimal ||
        BeakSemanticKind.percentage => const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        _ => multiline ? TextInputType.multiline : null,
      },
      onChanged: textChanged,
    );
  }
}

Object _typedList(List<Object> items, BeakPrimitiveType? type) =>
    switch (type) {
      BeakPrimitiveType.string when items.every((item) => item is String) =>
        items.whereType<String>().toList(),
      BeakPrimitiveType.integer when items.every((item) => item is int) =>
        items.whereType<int>().toList(),
      BeakPrimitiveType.decimal when items.every((item) => item is num) =>
        items.whereType<num>().map((value) => value.toDouble()).toList(),
      BeakPrimitiveType.boolean when items.every((item) => item is bool) =>
        items.whereType<bool>().toList(),
      null => items,
      _ => throw const BeakConfigurationException(
        'Choice values must match the declared primitive list type.',
      ),
    };

BeakColumn _primitiveColumn(BeakPrimitiveType? type) => switch (type) {
  BeakPrimitiveType.integer => const BeakIntColumn(
    key: 'value',
    label: 'Value',
  ),
  BeakPrimitiveType.decimal => const BeakDecimalColumn(
    key: 'value',
    label: 'Value',
  ),
  BeakPrimitiveType.boolean => const BeakBoolColumn(
    key: 'value',
    label: 'Value',
  ),
  _ => const BeakStringColumn(key: 'value', label: 'Value'),
};
