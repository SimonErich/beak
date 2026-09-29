import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui_autoforms/obers_ui_autoforms.dart';

import '../common/hex_color.dart';

/// Which registered values a form submits to its command or patch endpoint.
enum BeakFormValueMode {
  /// Populated values and explicit clears; untouched absent fields are omitted.
  populated,

  /// Every field, including untouched nulls, for complete typed commands.
  complete,

  /// Only fields changed since prefill, for partial-update endpoints.
  changes,
}

/// Beak's default pool of autoforms field keys.
///
/// `obers_ui_autoforms` keys fields by a Dart enum for compile-time safety;
/// Beak's columns are runtime values, so [BeakFormController] claims one
/// slot per form field in declaration order. Users never touch slots — they
/// address fields through column constants ([BeakFormController.slotOf],
/// [BeakFormController.valueOf]).
///
/// This pool is used by any model that does not supply its own through
/// [BeakModel.formSlots]. Generated models always do, sized to themselves.
enum BeakFormSlot {
  /// Bridge slot 0.
  s0,

  /// Bridge slot 1.
  s1,

  /// Bridge slot 2.
  s2,

  /// Bridge slot 3.
  s3,

  /// Bridge slot 4.
  s4,

  /// Bridge slot 5.
  s5,

  /// Bridge slot 6.
  s6,

  /// Bridge slot 7.
  s7,

  /// Bridge slot 8.
  s8,

  /// Bridge slot 9.
  s9,

  /// Bridge slot 10.
  s10,

  /// Bridge slot 11.
  s11,

  /// Bridge slot 12.
  s12,

  /// Bridge slot 13.
  s13,

  /// Bridge slot 14.
  s14,

  /// Bridge slot 15.
  s15,

  /// Bridge slot 16.
  s16,

  /// Bridge slot 17.
  s17,

  /// Bridge slot 18.
  s18,

  /// Bridge slot 19.
  s19,

  /// Bridge slot 20.
  s20,

  /// Bridge slot 21.
  s21,

  /// Bridge slot 22.
  s22,

  /// Bridge slot 23.
  s23,

  /// Bridge slot 24.
  s24,

  /// Bridge slot 25.
  s25,

  /// Bridge slot 26.
  s26,

  /// Bridge slot 27.
  s27,

  /// Bridge slot 28.
  s28,

  /// Bridge slot 29.
  s29,

  /// Bridge slot 30.
  s30,

  /// Bridge slot 31.
  s31,
}

/// A typed predicate over the form's current values, used for conditional
/// section visibility — never a `Map<String, dynamic>`.
typedef BeakFormPredicate = bool Function(BeakFormValues values);

/// Read-only, column-addressed access to a form's current values, handed to
/// [BeakFormPredicate]s.
///
/// Reads go through the autoforms reader so dependency tracking sees them —
/// a predicate re-evaluates automatically when a value it read changes.
final class BeakFormValues {
  const BeakFormValues._(this._reader, this._slotByKey);

  final OiAfReader<Enum> _reader;
  final Map<String, Enum> _slotByKey;

  /// The current typed value of [column], or `null` when the field is unset
  /// or the column carries no form field.
  T? valueOf<T>(BeakColumn column) {
    final Enum? slot = _slotByKey[column.key];
    return slot == null ? null : _reader.get<T>(slot);
  }
}

/// A titled group of form fields, optionally shown only while [visibleWhen]
/// holds over the current values.
///
/// When a form declares sections, only the columns they list get fields —
/// sections are the way to subset and order a large model's form. Columns
/// omitted from every section carry no field at all. The [visibleWhen]
/// predicate reads other fields through [BeakFormValues], so the section
/// re-evaluates automatically whenever a value it read changes.
///
/// ```dart
/// BeakFormSection(
///   title: 'Shipping',
///   columns: [OrderModel.address.column, OrderModel.courier.column],
///   // Hidden until the buyer picks physical delivery.
///   visibleWhen: (values) =>
///       values.valueOf<Fulfilment>(OrderModel.fulfilment.column) ==
///       Fulfilment.ship,
/// )
/// ```
final class BeakFormSection {
  /// Creates a section titled [title] over [columns].
  const BeakFormSection({
    required this.title,
    required this.columns,
    this.visibleWhen,
  });

  /// Heading rendered above the section's fields.
  final String title;

  /// The columns rendered in this section, in order.
  final List<BeakColumn> columns;

  /// Predicate gating the whole section's visibility, if any.
  final BeakFormPredicate? visibleWhen;
}

/// Builds and owns the autoforms controller for one model's create/edit
/// form: a typed field per form-context column, client-side validators
/// mirroring the column's [BeakRule]s verbatim (identical messages to the
/// backend), belongs-to foreign keys as picker slots, and typed
/// [BeakRecord] output.
///
/// [BeakConfiguredForm] constructs and disposes one of these for you; instantiate
/// it directly only when hand-composing a form. Address fields through
/// column constants — never the underlying slot enums — via
/// [valueOf], [setValue], and [slotOf].
///
/// ```dart
/// final controller = BeakFormController(model: const ProductModel())
///   ..prefill(loadedRecord); // seed edit-mode values without dirtying
///
/// final String? name = controller.valueOf<String>(ProductModel.name.column);
/// controller.setValue<bool>(ProductModel.onSale.column, true);
///
/// final BeakRecord submission = controller.buildData();
/// ```
final class BeakFormController extends OiAfController<Enum, BeakRecord> {
  int _pendingSubmissions = 0;
  bool _disposeRequested = false;

  /// Lets autoforms finish its submit bookkeeping before releasing listeners.
  @override
  Future<OiAfSubmitResult<BeakRecord>> submit() async {
    _pendingSubmissions++;
    try {
      return await super.submit();
    } finally {
      _pendingSubmissions--;
      if (_disposeRequested && _pendingSubmissions == 0) super.dispose();
    }
  }

  /// A pending submission can settle after the form leaves the widget tree.
  @override
  void dispose() {
    if (_disposeRequested) return;
    _disposeRequested = true;
    if (_pendingSubmissions == 0) super.dispose();
  }

  /// Creates the controller for [model], optionally restricted and grouped
  /// by [sections].
  BeakFormController({
    required this.model,
    this.sections,
    this.valueMode = BeakFormValueMode.populated,
    this.validateRule,
  });

  /// The model this form edits.
  final BeakModel model;

  /// Controls absent/null/changed field submission semantics.
  final BeakFormValueMode valueMode;

  /// Optional presentation translation without changing validation rules.
  final String? Function(BeakRule rule, Object? value)? validateRule;

  String? _validate(BeakRule rule, Object? value) =>
      validateRule == null ? rule.validate(value) : validateRule!(rule, value);

  /// The declared sections, or `null` for one implicit section over every
  /// form column.
  final List<BeakFormSection>? sections;

  final Map<String, Enum> _slotByKey = {};
  final Map<Enum, BeakColumn> _columnBySlot = {};
  final Map<Enum, String> _keyBySlot = {};
  final Set<String> _prefilledKeys = {};
  final Map<String, String> _inputErrors = {};
  final Set<String> _invalidEdits = {};

  /// Parsing errors retained while an editor contains an incomplete value.
  Map<String, String> get inputErrors => Map.unmodifiable(_inputErrors);

  /// Keeps invalid text in the editor while blocking submission of stale data.
  void setInputError(BeakColumn column, String? message) {
    if (message == null) {
      _invalidEdits.remove(column.key);
    } else {
      _invalidEdits.add(column.key);
    }
    if (_inputErrors[column.key] == message) return;
    if (message == null) {
      _inputErrors.remove(column.key);
    } else {
      _inputErrors[column.key] = message;
    }
    notifyListeners();
  }

  @override
  bool get isDirty => _invalidEdits.isNotEmpty || super.isDirty;

  @override
  Future<bool> validate({
    Enum? field,
    OiAfValidationTrigger trigger = OiAfValidationTrigger.manual,
  }) async {
    final valid = await super.validate(field: field, trigger: trigger);
    final errors = field == null
        ? _inputErrors.values
        : [_inputErrors[_keyBySlot[field]]].nonNulls;
    return valid && errors.isEmpty;
  }

  int _claimedSlotCount = 0;

  /// The pool this form claims slots from: the model's own when it has one.
  late final List<Enum> _slots = model.formSlots ?? BeakFormSlot.values;

  /// The slot bridging [column]'s form field.
  ///
  /// Throws a [BeakConfigurationException] when the column has no form
  /// field (hidden from forms, the primary key, custom-rendered, or not
  /// listed in any section).
  Enum slotOf(BeakColumn column) => _slotOfKey(column.key);

  /// The slot bridging [relation]'s foreign-key picker.
  ///
  /// Throws a [BeakConfigurationException] when the relation's foreign key
  /// carries no form field.
  Enum slotOfForeignKey(BeakBelongsTo relation) =>
      _slotOfKey(relation.foreignKey);

  /// Whether a form field exists for the column stored under [columnKey] —
  /// the single eligibility source the form widget renders from.
  bool hasFieldForKey(String columnKey) => _slotByKey.containsKey(columnKey);

  /// Whether a form field exists for [column].
  bool hasFieldFor(BeakColumn column) => hasFieldForKey(column.key);

  /// The current typed value of [column]'s field.
  T? valueOf<T>(BeakColumn column) => get<T>(slotOf(column));

  /// The current editor value normalized for metadata validation, without rounding.
  Object? validationValueOf(BeakColumn column) =>
      _validationValue(column, valueOf<Object>(column));

  Object? _validationValue(BeakColumn column, Object? value) => switch (value) {
    final Color color => formatBeakHexColor(color),
    final BeakJson json => json.encode(),
    final num number
        when column is BeakIntColumn &&
            !column.semantic.hasCodec &&
            number.isFinite &&
            number == number.roundToDouble() =>
      number.toInt(),
    _ => value,
  };

  /// Sets [column]'s field to [value].
  void setValue<T>(BeakColumn column, T? value) {
    _invalidEdits.remove(column.key);
    final cleared = _inputErrors.remove(column.key) != null;
    set(slotOf(column), value);
    if (cleared) notifyListeners();
  }

  /// Seeds every field from [record] without marking the form dirty — the
  /// edit-mode prefill.
  void prefill(BeakRecord record) {
    _prefilledKeys.clear();
    _inputErrors.clear();
    _invalidEdits.clear();
    final values = <Enum, Object?>{};
    for (final MapEntry(key: slot, value: columnKey) in _keyBySlot.entries) {
      final BeakValue? value = record[columnKey];
      if (value != null) _prefilledKeys.add(columnKey);
      // A prefill is a replacement baseline, not a partial update. Explicitly
      // reset absent slots so discarded command arguments cannot survive.
      values[slot] = _fieldValueOf(
        slot,
        value == null ? _columnBySlot[slot]?.defaultValue : value.raw,
      );
    }
    rebase(values);
  }

  /// Whether [column]'s current value passes every one of its validation
  /// rules — evaluated directly against the typed rules, **without** running
  /// the autoforms validation pipeline, so no error text is revealed on
  /// fields the user hasn't touched. The wizard's synchronous step gate
  /// reads this; hidden and unregistered fields pass vacuously.
  bool passesRules(BeakColumn column) {
    final Enum? slot = _slotByKey[column.key];
    if (slot == null || !isFieldVisible(slot)) {
      return true;
    }
    final Object? value = get<Object>(slot);
    if (_inputErrors.containsKey(column.key) ||
        const BeakValidation()
            .columnErrors(column, _validationValue(column, value))
            .isNotEmpty) {
      return false;
    }
    for (final rule in column.rules) {
      final String? error = switch (rule) {
        BeakRequired() => _validate(rule, value),
        BeakMaxFileSize() || BeakAllowedFileTypes() => null,
        _ => _mirrorContent(rule, value),
      };
      if (error != null) {
        return false;
      }
    }
    return true;
  }

  /// Whether [section] is currently visible — its predicate holds, read
  /// through the first of its columns carrying a field.
  bool isSectionVisible(BeakFormSection section) {
    for (final column in section.columns) {
      final Enum? slot = _slotByKey[column.key];
      if (slot != null) {
        return isFieldVisible(slot);
      }
    }
    return true;
  }

  /// Maps a 422 response's field errors onto the matching fields; errors
  /// under unknown keys surface as global form errors.
  void applyServerErrors(Map<String, List<String>> errorsByColumnKey) {
    for (final MapEntry(:key, :value) in errorsByColumnKey.entries) {
      final Enum? slot = _slotByKey[key];
      if (slot != null) {
        setBackendErrors(slot, value);
      } else {
        setGlobalError('$key: ${value.join(' ')}');
      }
    }
  }

  @override
  BeakRecord buildData() {
    final values = <String, BeakValue>{};
    for (final MapEntry(key: slot, value: columnKey) in _keyBySlot.entries) {
      if (!shouldExportField(slot)) continue;
      if (valueMode == BeakFormValueMode.changes && !isFieldDirty(slot)) {
        continue;
      }
      final BeakValue? wire = _wireValueOf(slot);
      if (wire != null) {
        values[columnKey] = wire;
      } else if (valueMode == BeakFormValueMode.complete ||
          _prefilledKeys.contains(columnKey) ||
          isFieldDirty(slot)) {
        values[columnKey] = const BeakNullValue();
      }
    }
    return BeakRecord(values: values);
  }

  @override
  void defineFields() {
    final Map<String, BeakFormSection> sectionByColumnKey = {};
    for (final section in sections ?? const <BeakFormSection>[]) {
      for (final column in section.columns) {
        sectionByColumnKey.putIfAbsent(column.key, () => section);
      }
    }
    final Map<String, BeakBelongsTo> relationByForeignKey = {
      for (final relation in model.relationships)
        if (relation is BeakBelongsTo) relation.foreignKey: relation,
    };
    final String primaryKeyKey = model.primaryKey.key;

    for (final column in model.columnsFor(BeakContext.form)) {
      if (column.key == primaryKeyKey) {
        continue;
      }
      final BeakFormSection? section = sectionByColumnKey[column.key];
      if (sections != null && section == null) {
        continue;
      }
      final BeakBelongsTo? relation = relationByForeignKey[column.key];
      if (relation != null) {
        _registerForeignKey(relation, rules: column.rules, section: section);
      } else {
        _registerColumn(column, section: section);
      }
    }

    if (sections == null) {
      for (final MapEntry(:key, :value) in relationByForeignKey.entries) {
        if (!_slotByKey.containsKey(key)) {
          _registerForeignKey(value, rules: const [], section: null);
        }
      }
    }
  }

  void _registerColumn(BeakColumn column, {required BeakFormSection? section}) {
    final OiAfVisibleWhen<Enum>? visibility = _visibilityOf(section);
    if (column.semantic.hasCodec) {
      addComboBoxField<Object>(
        _claim(column.key, column: column),
        initialValue: column.defaultValue == null
            ? null
            : column.semantic.tryDecode(
                column.semantic.encode(column.defaultValue),
              ),
        visibleWhen: visibility,
        validators: [
          OiAfValidators.custom<Enum, Object>(
            (context) => const BeakValidation()
                .columnErrors(column, context.value)
                .firstOrNull,
          ),
        ],
      );
      return;
    }
    switch (column) {
      case BeakCustomColumn():
        return;
      case BeakJsonColumn():
        addComboBoxField<Object>(
          _claim(column.key, column: column),
          initialValue: column.defaultValue,
          visibleWhen: visibility,
          validators: _columnValidators<Object>(column),
        );
      case BeakStringColumn() || BeakTextColumn() || BeakUploadColumn():
        addTextField(
          _claim(column.key, column: column),
          initialValue: switch (column.defaultValue) {
            final String value => value,
            _ => null,
          },
          validators: _columnValidators<String>(column),
          visibleWhen: visibility,
        );
      case BeakRichTextColumn():
        addRichTextField(
          _claim(column.key, column: column),
          initialValue: switch (column.defaultValue) {
            final String value => value,
            _ => null,
          },
          validators: _columnValidators<String>(column),
          visibleWhen: visibility,
        );
      case BeakIntColumn(:final min, :final max):
        addNumberField(
          _claim(column.key, column: column),
          initialValue: switch (column.defaultValue) {
            final num value => value,
            _ => null,
          },
          min: min,
          max: max,
          decimalPlaces: 0,
          validators: _columnValidators<num>(column),
          visibleWhen: visibility,
        );
      case BeakDecimalColumn(:final precision):
        addNumberField(
          _claim(column.key, column: column),
          initialValue: switch (column.defaultValue) {
            final num value => value,
            _ => null,
          },
          decimalPlaces: precision,
          validators: _columnValidators<num>(column),
          visibleWhen: visibility,
        );
      case BeakBoolColumn():
        addBoolField(
          _claim(column.key, column: column),
          initialValue: switch (column.defaultValue) {
            final bool value => value,
            _ => column.tristate ? null : false,
          },
          tristate: column.tristate,
          validators: _columnValidators<bool?>(column),
          visibleWhen: visibility,
        );
      case final BeakEnumColumn<Enum> enumColumn:
        addSelectField<Enum>(
          _claim(column.key, column: column),
          initialValue: enumColumn.defaultValue,
          options: [
            for (final option in enumColumn.values)
              OiAfOption(value: option, label: enumColumn.labelFor(option)),
          ],
          validators: _columnValidators<Enum>(column),
          visibleWhen: visibility,
        );
      case BeakDateTimeColumn():
        addDateTimeField(
          _claim(column.key, column: column),
          validators: _columnValidators<DateTime>(column),
          visibleWhen: visibility,
        );
      case BeakColorColumn():
        addColorField(
          _claim(column.key, column: column),
          validators: _columnValidators<Color>(column),
          visibleWhen: visibility,
        );
    }
  }

  void _registerForeignKey(
    BeakBelongsTo relation, {
    required List<BeakRule> rules,
    required BeakFormSection? section,
  }) {
    addComboBoxField<Object>(
      _claim(relation.foreignKey, column: null),
      validators: _mirrors<Object>(rules),
      visibleWhen: _visibilityOf(section),
    );
  }

  Enum _claim(String key, {required BeakColumn? column}) {
    if (_claimedSlotCount >= _slots.length) {
      throw BeakConfigurationException(
        'Model "${model.table}" needs more than ${_slots.length} form fields, '
        'counting one per form column and one per belongs-to. Either narrow '
        'the form with `visibleOn` on the columns that do not belong on it, '
        'or give the model a larger slot pool by overriding `formSlots` — a '
        'generated model already does. Splitting into more sections does not '
        'help: every column listed in any section claims a field.',
      );
    }
    final Enum slot = _slots[_claimedSlotCount];
    _claimedSlotCount += 1;
    _slotByKey[key] = slot;
    _keyBySlot[slot] = key;
    if (column != null) {
      _columnBySlot[slot] = column;
    }
    return slot;
  }

  Enum _slotOfKey(String key) {
    final Enum? slot = _slotByKey[key];
    if (slot == null) {
      throw BeakConfigurationException(
        'Column "$key" of model "${model.table}" carries no form field '
        '(hidden from forms, the primary key, custom-rendered, or not '
        'listed in any section).',
      );
    }
    return slot;
  }

  OiAfVisibleWhen<Enum>? _visibilityOf(BeakFormSection? section) {
    final BeakFormPredicate? predicate = section?.visibleWhen;
    if (predicate == null) {
      return null;
    }
    return (reader) => predicate(BeakFormValues._(reader, _slotByKey));
  }

  List<OiAfValidator<Enum, T>> _columnValidators<T>(BeakColumn column) => [
    ..._mirrors<T>(column.rules),
    OiAfValidators.custom<Enum, T>((context) {
      final value = _validationValue(column, context.value);
      final mirrored = {for (final rule in column.rules) rule.validate(value)};
      return const BeakValidation()
          .columnErrors(column, value)
          .where((message) => !mirrored.contains(message))
          .firstOrNull;
    }),
  ];

  /// Builds the client-side validators mirroring [rules] for a field whose
  /// autoforms value type is [T].
  List<OiAfValidator<Enum, T>> _mirrors<T>(List<BeakRule> rules) => [
    for (final rule in rules)
      if (_mirror<T>(rule) case final OiAfValidator<Enum, T> validator)
        validator,
  ];

  /// Maps one [BeakRule] onto its client-side mirror — the exhaustive
  /// rule-to-validator mapping.
  ///
  /// Every mirror delegates to the rule's own `validate`, so client and
  /// server produce byte-identical messages. Presence ([BeakRequired])
  /// rejects empties; content rules skip absent values (matching the
  /// backend, which validates only submitted values); upload rules return
  /// `null` here because the upload field enforces them before the file
  /// leaves the client.
  OiAfValidator<Enum, T>? _mirror<T>(BeakRule rule) => switch (rule) {
    BeakRequired() => OiAfValidators.custom<Enum, T>(
      (context) => _validate(rule, context.value),
    ),
    BeakMaxFileSize() || BeakAllowedFileTypes() => null,
    BeakMinLength() ||
    BeakMaxLength() ||
    BeakEmail() ||
    BeakUrl() ||
    BeakPattern() ||
    BeakMin() ||
    BeakMax() ||
    BeakInList() ||
    BeakFutureDate() => OiAfValidators.custom<Enum, T>(
      (context) => _mirrorContent(rule, context.value),
    ),
  };

  /// Runs a content [rule] the way the backend does: only a genuinely
  /// absent (`null`) value passes — presence is [BeakRequired]'s job
  /// alone. A submitted empty or whitespace string IS validated, exactly
  /// as the backend validates every provided value.
  String? _mirrorContent(BeakRule rule, Object? value) {
    if (value == null) {
      return null;
    }
    return _validate(rule, value);
  }

  /// Converts a form field's value into its wire [BeakValue], or `null`
  /// when the field is unset.
  BeakValue? _wireValueOf(Enum slot) {
    final BeakColumn? column = _columnBySlot[slot];
    if (column == null) {
      final Object? relatedId = get<Object>(slot);
      return relatedId == null ? null : BeakValue.of(relatedId);
    }
    if (column.semantic.hasCodec) {
      final value = get<Object>(slot);
      return value == null ? null : column.semantic.encode(value);
    }
    return switch (column) {
      BeakJsonColumn() => switch (get<Object>(slot)) {
        final BeakJson json => BeakStringValue(json.encode()),
        final String text => BeakStringValue(text),
        null => null,
        _ => throw const BeakConfigurationException(
          'JSON input requires JSON text or a typed BeakJson value.',
        ),
      },
      BeakStringColumn() ||
      BeakTextColumn() ||
      BeakRichTextColumn() ||
      BeakUploadColumn() => switch (get<String>(slot)) {
        final String text => BeakStringValue(text),
        null => null,
      },
      BeakIntColumn() => switch (get<num>(slot)) {
        final num number => BeakIntValue(number.toInt()),
        null => null,
      },
      BeakDecimalColumn() => switch (get<num>(slot)) {
        final num number => BeakDoubleValue(number.toDouble()),
        null => null,
      },
      BeakBoolColumn() => switch (get<bool>(slot)) {
        final bool value => BeakBoolValue(value),
        null => null,
      },
      BeakEnumColumn<Enum>() => switch (get<Enum>(slot)) {
        final Enum option => BeakStringValue(option.name),
        null => null,
      },
      BeakDateTimeColumn() => switch (get<DateTime>(slot)) {
        final DateTime instant => BeakDateTimeValue(instant),
        null => null,
      },
      BeakColorColumn() => switch (get<Color>(slot)) {
        final Color color => BeakStringValue(formatBeakHexColor(color)),
        null => null,
      },
      BeakCustomColumn() => null,
    };
  }

  /// Converts a record's raw value into the type the slot's field holds.
  Object? _fieldValueOf(Enum slot, Object? raw) {
    if (raw == null) {
      return null;
    }
    final BeakColumn? column = _columnBySlot[slot];
    if (column == null) {
      return raw;
    }
    if (column.semantic.hasCodec) {
      final value = column.semantic.tryDecode(BeakValue.of(raw));
      if (value == null) {
        _inputErrors[column.key] =
            'The stored value does not match this field type. Enter a valid value.';
      }
      return value;
    }
    return switch (column) {
      BeakStringColumn() ||
      BeakTextColumn() ||
      BeakRichTextColumn() ||
      BeakJsonColumn() ||
      BeakUploadColumn() => raw.toString(),
      BeakIntColumn() || BeakDecimalColumn() => switch (raw) {
        final num number => number,
        _ => null,
      },
      BeakBoolColumn() => raw == true,
      final BeakEnumColumn<Enum> enumColumn => enumColumn.valueByName(
        raw is Enum ? raw.name : raw.toString(),
      ),
      BeakDateTimeColumn() => switch (raw) {
        final DateTime instant => instant,
        final String iso => DateTime.tryParse(iso),
        _ => null,
      },
      BeakColorColumn() => switch (raw) {
        final String hex => parseBeakHexColor(hex),
        _ => null,
      },
      BeakCustomColumn() => null,
    };
  }
}
