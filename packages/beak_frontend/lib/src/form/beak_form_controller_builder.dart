import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui_autoforms/obers_ui_autoforms.dart';

import '../common/hex_color.dart';

/// The fixed pool of autoforms field keys Beak bridges runtime columns onto.
///
/// `obers_ui_autoforms` keys fields by a Dart enum for compile-time safety;
/// Beak's columns are runtime values, so [BeakFormController] claims one
/// slot per form column in declaration order. Users never touch slots —
/// they address fields through column constants
/// ([BeakFormController.slotOf], [BeakFormController.valueOf]).
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

  final OiAfReader<BeakFormSlot> _reader;
  final Map<String, BeakFormSlot> _slotByKey;

  /// The current typed value of [column], or `null` when the field is unset
  /// or the column carries no form field.
  T? valueOf<T>(BeakColumn column) {
    final BeakFormSlot? slot = _slotByKey[column.key];
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
///   columns: const [OrderColumns.address, OrderColumns.courier],
///   // Hidden until the buyer picks physical delivery.
///   visibleWhen: (values) =>
///       values.valueOf<Fulfilment>(OrderColumns.fulfilment) ==
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
/// [BeakDataForm] constructs and disposes one of these for you; instantiate
/// it directly only when hand-composing a form. Address fields through
/// column constants — never the underlying [BeakFormSlot]s — via
/// [valueOf], [setValue], and [slotOf].
///
/// ```dart
/// final controller = BeakFormController(model: const ProductModel())
///   ..prefill(loadedRecord); // seed edit-mode values without dirtying
///
/// final String? name = controller.valueOf<String>(ProductColumns.name);
/// controller.setValue<bool>(ProductColumns.onSale, true);
///
/// final BeakRecord submission = controller.buildData();
/// ```
final class BeakFormController
    extends OiAfController<BeakFormSlot, BeakRecord> {
  /// Creates the controller for [model], optionally restricted and grouped
  /// by [sections].
  BeakFormController({required this.model, this.sections});

  /// The model this form edits.
  final BeakModel model;

  /// The declared sections, or `null` for one implicit section over every
  /// form column.
  final List<BeakFormSection>? sections;

  final Map<String, BeakFormSlot> _slotByKey = {};
  final Map<BeakFormSlot, BeakColumn> _columnBySlot = {};
  final Map<BeakFormSlot, String> _keyBySlot = {};
  int _claimedSlotCount = 0;

  /// The slot bridging [column]'s form field.
  ///
  /// Throws a [BeakConfigurationException] when the column has no form
  /// field (hidden from forms, the primary key, custom-rendered, or not
  /// listed in any section).
  BeakFormSlot slotOf(BeakColumn column) => _slotOfKey(column.key);

  /// The slot bridging [relation]'s foreign-key picker.
  ///
  /// Throws a [BeakConfigurationException] when the relation's foreign key
  /// carries no form field.
  BeakFormSlot slotOfForeignKey(BeakBelongsTo relation) =>
      _slotOfKey(relation.foreignKey);

  /// Whether a form field exists for the column stored under [columnKey] —
  /// the single eligibility source the form widget renders from.
  bool hasFieldForKey(String columnKey) => _slotByKey.containsKey(columnKey);

  /// Whether a form field exists for [column].
  bool hasFieldFor(BeakColumn column) => hasFieldForKey(column.key);

  /// The current typed value of [column]'s field.
  T? valueOf<T>(BeakColumn column) => get<T>(slotOf(column));

  /// Sets [column]'s field to [value].
  void setValue<T>(BeakColumn column, T? value) => set(slotOf(column), value);

  /// Seeds every field from [record] without marking the form dirty — the
  /// edit-mode prefill.
  void prefill(BeakRecord record) {
    final values = <BeakFormSlot, Object?>{};
    for (final MapEntry(key: slot, value: columnKey) in _keyBySlot.entries) {
      final BeakValue? value = record[columnKey];
      if (value != null) {
        values[slot] = _fieldValueOf(slot, value.raw);
      }
    }
    rebase(values);
  }

  /// Whether [section] is currently visible — its predicate holds, read
  /// through the first of its columns carrying a field.
  bool isSectionVisible(BeakFormSection section) {
    for (final column in section.columns) {
      final BeakFormSlot? slot = _slotByKey[column.key];
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
      final BeakFormSlot? slot = _slotByKey[key];
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
      final BeakValue? wire = _wireValueOf(slot);
      if (wire != null) {
        values[columnKey] = wire;
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
    final OiAfVisibleWhen<BeakFormSlot>? visibility = _visibilityOf(section);
    switch (column) {
      case BeakCustomColumn():
        return;
      case BeakStringColumn() ||
          BeakTextColumn() ||
          BeakJsonColumn() ||
          BeakUploadColumn():
        addTextField(
          _claim(column.key, column: column),
          validators: _mirrors<String>(column.rules),
          visibleWhen: visibility,
        );
      case BeakRichTextColumn():
        addRichTextField(
          _claim(column.key, column: column),
          validators: _mirrors<String>(column.rules),
          visibleWhen: visibility,
        );
      case BeakIntColumn(:final min, :final max):
        addNumberField(
          _claim(column.key, column: column),
          min: min,
          max: max,
          decimalPlaces: 0,
          validators: _mirrors<num>(column.rules),
          visibleWhen: visibility,
        );
      case BeakDecimalColumn(:final precision):
        addNumberField(
          _claim(column.key, column: column),
          decimalPlaces: precision,
          validators: _mirrors<num>(column.rules),
          visibleWhen: visibility,
        );
      case BeakBoolColumn():
        addBoolField(
          _claim(column.key, column: column),
          initialValue: false,
          validators: _mirrors<bool?>(column.rules),
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
          validators: _mirrors<Enum>(column.rules),
          visibleWhen: visibility,
        );
      case BeakDateTimeColumn():
        addDateTimeField(
          _claim(column.key, column: column),
          validators: _mirrors<DateTime>(column.rules),
          visibleWhen: visibility,
        );
      case BeakColorColumn():
        addColorField(
          _claim(column.key, column: column),
          validators: _mirrors<Color>(column.rules),
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

  BeakFormSlot _claim(String key, {required BeakColumn? column}) {
    if (_claimedSlotCount >= BeakFormSlot.values.length) {
      throw BeakConfigurationException(
        'Auto forms support at most ${BeakFormSlot.values.length} fields; '
        'model "${model.table}" declares more. Split the form with sections '
        'or hide columns from the form context.',
      );
    }
    final BeakFormSlot slot = BeakFormSlot.values[_claimedSlotCount];
    _claimedSlotCount += 1;
    _slotByKey[key] = slot;
    _keyBySlot[slot] = key;
    if (column != null) {
      _columnBySlot[slot] = column;
    }
    return slot;
  }

  BeakFormSlot _slotOfKey(String key) {
    final BeakFormSlot? slot = _slotByKey[key];
    if (slot == null) {
      throw BeakConfigurationException(
        'Column "$key" of model "${model.table}" carries no form field '
        '(hidden from forms, the primary key, custom-rendered, or not '
        'listed in any section).',
      );
    }
    return slot;
  }

  OiAfVisibleWhen<BeakFormSlot>? _visibilityOf(BeakFormSection? section) {
    final BeakFormPredicate? predicate = section?.visibleWhen;
    if (predicate == null) {
      return null;
    }
    return (reader) => predicate(BeakFormValues._(reader, _slotByKey));
  }

  /// Builds the client-side validators mirroring [rules] for a field whose
  /// autoforms value type is [T].
  List<OiAfValidator<BeakFormSlot, T>> _mirrors<T>(List<BeakRule> rules) => [
    for (final rule in rules)
      if (_mirror<T>(rule) case final OiAfValidator<BeakFormSlot, T> validator)
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
  OiAfValidator<BeakFormSlot, T>? _mirror<T>(BeakRule rule) => switch (rule) {
    BeakRequired() => OiAfValidators.custom<BeakFormSlot, T>(
      (context) => rule.validate(context.value),
    ),
    BeakMaxFileSize() || BeakAllowedFileTypes() => null,
    BeakMinLength() ||
    BeakMaxLength() ||
    BeakEmail() ||
    BeakUrl() ||
    BeakPattern() ||
    BeakMin() ||
    BeakMax() ||
    BeakInList() => OiAfValidators.custom<BeakFormSlot, T>(
      (context) => _mirrorContent(rule, context.value),
    ),
  };

  /// Runs a content [rule] the way the backend does: only a genuinely
  /// absent (`null`) value passes — presence is [BeakRequired]'s job
  /// alone. A submitted empty or whitespace string IS validated, exactly
  /// as `ValidationService` validates every provided value server-side.
  String? _mirrorContent(BeakRule rule, Object? value) {
    if (value == null) {
      return null;
    }
    return rule.validate(value);
  }

  /// Converts a form field's value into its wire [BeakValue], or `null`
  /// when the field is unset.
  BeakValue? _wireValueOf(BeakFormSlot slot) {
    final BeakColumn? column = _columnBySlot[slot];
    if (column == null) {
      final Object? relatedId = get<Object>(slot);
      return relatedId == null ? null : BeakValue.of(relatedId);
    }
    return switch (column) {
      BeakStringColumn() ||
      BeakTextColumn() ||
      BeakRichTextColumn() ||
      BeakJsonColumn() ||
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
      BeakBoolColumn() => BeakBoolValue(getOr(slot, false)),
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
  Object? _fieldValueOf(BeakFormSlot slot, Object? raw) {
    if (raw == null) {
      return null;
    }
    final BeakColumn? column = _columnBySlot[slot];
    if (column == null) {
      return raw;
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
        raw.toString(),
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
