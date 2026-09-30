import 'dart:convert';

import 'package:beak_core/beak_core.dart';

import '../form/beak_input_codec.dart';
import '../formatting/beak_formatting.dart';
import 'beak_form_commit_repository.dart';
import 'beak_run.dart';

/// A typed change reusable across a selection of records.
final class BeakFieldChange<T extends Object> {
  /// Captures a field and a value checked against its Dart type.
  const BeakFieldChange(this.field, this.value);

  /// Target field, belonging directly to the edited model.
  final BeakScalarField<T> field;

  /// Proposed value, including an explicit null.
  final T? value;

  /// Applies this change without mutating the original record.
  BeakRecord apply(BeakRecord record) => field.writeTo(record, value);
}

/// One row in a reviewable import or bulk edit.
final class BeakBatchRow {
  /// Captures the proposed values, baseline and validation errors.
  BeakBatchRow({
    required this.number,
    required this.values,
    this.initial,
    Map<String, List<String>> errors = const {},
  }) : errors = Map.unmodifiable({
         for (final entry in errors.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       });

  /// One-based source row number, including the CSV header when applicable.
  final int number;

  /// Submitted scalar values.
  final BeakRecord values;

  /// Existing record for an update, or null for a create.
  final BeakRecord? initial;

  /// Local validation failures keyed by field.
  final Map<String, List<String>> errors;

  /// Whether this row can be submitted for authoritative validation.
  bool get valid => errors.isEmpty;
}

/// An immutable preview; inspecting it never makes writes.
final class BeakBatchPreview {
  /// Captures rows for one model.
  BeakBatchPreview({required this.model, required Iterable<BeakBatchRow> rows})
    : rows = List.unmodifiable(rows);

  /// Shared metadata for every row.
  final BeakModel model;

  /// Rows and their field-level errors in source order.
  final List<BeakBatchRow> rows;

  /// Whether every row passed local validation and there is work to submit.
  bool get valid => rows.isNotEmpty && rows.every((row) => row.valid);

  /// Freezes independent graph saves with stable per-row recovery identities.
  List<BeakSavePlan> plans(String batchId) {
    if (!valid || batchId.isEmpty || batchId.length > 150) {
      throw const BeakValidationException(
        'Correct the batch preview before saving.',
      );
    }
    return List.unmodifiable([
      for (final row in rows) _plan(row, '$batchId-${row.number}'),
    ]);
  }

  BeakSavePlan _plan(BeakBatchRow row, String saveId) {
    final initial = row.initial;
    final id = initial == null ? null : model.primaryKeyOf(initial);
    if (initial != null && id == null) {
      throw const BeakConfigurationException(
        'Bulk updates require record identities.',
      );
    }
    final target = id == null
        ? BeakRecordRef.draft(model.table, 'row-${row.number}')
        : BeakRecordRef.existing(model.table, id);
    return BeakSavePlan(
      saveId: saveId,
      root: target,
      operations: [
        BeakSaveOperation(
          id: 'row',
          target: target,
          kind: id == null
              ? BeakSaveOperationKind.create
              : BeakSaveOperationKind.update,
          values: row.values,
          expectedUpdatedAt: switch (initial?['updated_at']?.raw) {
            final DateTime timestamp => timestamp,
            _ => null,
          },
        ),
      ],
    );
  }
}

/// Builds a bulk-edit review through the normal shared validation engine.
abstract final class BeakBulkEdit {
  /// Applies typed [changes] to every baseline and reports failures per row.
  static BeakBatchPreview preview({
    required BeakModel model,
    required Iterable<BeakRecord> records,
    required List<BeakFieldChange<Object>> changes,
  }) {
    final seen = <String>{};
    var patch = const BeakRecord(values: {});
    for (final change in changes) {
      if (change.field.model.table != model.table ||
          change.field.path.isNotEmpty ||
          !seen.add(change.field.key) ||
          change.field.key == model.primaryKey.key) {
        throw const BeakConfigurationException(
          'Bulk edits need unique, direct, non-identity fields.',
        );
      }
      patch = change.apply(patch);
    }
    if (changes.isEmpty) {
      throw const BeakConfigurationException('Choose a field to edit.');
    }
    final baselines = records.toList(growable: false);
    final identities = <Object>{};
    for (final record in baselines) {
      final id = model.primaryKeyOf(record);
      if (id == null || !identities.add(id)) {
        throw const BeakConfigurationException(
          'Bulk edits require a unique identity for every selected record.',
        );
      }
    }
    var number = 0;
    return BeakBatchPreview(
      model: model,
      rows: [
        for (final record in baselines)
          BeakBatchRow(
            number: ++number,
            values: patch,
            initial: record,
            errors: _validate(model, patch, initial: record),
          ),
      ],
    );
  }
}

/// Maps CSV headers to typed fields, using model codecs and shared validation.
final class BeakImportDefinition {
  /// Defaults header names to field labels; [headers] overrides individual names.
  BeakImportDefinition({
    required this.model,
    required Iterable<BeakScalarField<Object>> fields,
    Map<BeakScalarField<Object>, String> headers = const {},
    this.maximumRows = 500,
  }) : fields = List.unmodifiable(fields),
       headers = Map.unmodifiable(headers) {
    final keys = <String>{};
    final names = <String>{};
    for (final field in this.fields) {
      if (field.model.table != model.table ||
          field.path.isNotEmpty ||
          !keys.add(field.key) ||
          !names.add(header(field)) ||
          header(field).isEmpty) {
        throw const BeakConfigurationException(
          'Import fields and headers must be unique and belong to the model.',
        );
      }
    }
    if (maximumRows < 1 || this.fields.isEmpty) {
      throw const BeakConfigurationException(
        'Imports need fields and a positive row limit.',
      );
    }
  }

  /// Resource being imported.
  final BeakModel model;

  /// Explicit allowlist of importable fields.
  final List<BeakScalarField<Object>> fields;

  /// Optional presentation names for source columns.
  final Map<BeakScalarField<Object>, String> headers;

  /// Maximum data rows in one preview.
  final int maximumRows;

  /// Expected CSV header for a field.
  String header(BeakScalarField<Object> field) => headers[field] ?? field.label;

  /// Parses a bounded RFC-style CSV document without making network requests.
  BeakBatchPreview preview(
    String csv, {
    BeakFormatting formatting = const BeakFormatting(),
  }) {
    final records = _csv(
      csv.startsWith('\ufeff') ? csv.substring(1) : csv,
      maximumRows + 1,
    );
    if (records.isEmpty) {
      throw const BeakValidationException(
        'Paste a CSV header and at least one row.',
      );
    }
    final names = records.first.map((name) => name.trim()).toList();
    if (names.isNotEmpty) names[0] = names[0].replaceFirst('\ufeff', '');
    if (names.toSet().length != names.length ||
        names.any((name) => !fields.any((field) => header(field) == name))) {
      throw const BeakValidationException(
        'CSV headers must be unique declared import fields.',
      );
    }
    final byHeader = {for (final field in fields) header(field): field};
    final rows = <BeakBatchRow>[];
    for (var index = 1; index < records.length; index++) {
      final cells = records[index];
      if (cells.length != names.length) {
        throw BeakValidationException(
          'CSV row ${index + 1} has ${cells.length} values; expected ${names.length}.',
        );
      }
      final errors = <String, List<String>>{};
      final values = <String, BeakValue>{};
      for (var cell = 0; cell < names.length; cell++) {
        final field = byHeader[names[cell]]!;
        try {
          final value = _parse(field.column, cells[cell], formatting);
          values[field.key] = beakValueForColumn(field.column, value);
        } on FormatException catch (error) {
          errors[field.key] = [error.message];
        } on ArgumentError {
          errors[field.key] = ['Value does not match ${field.label}.'];
        }
      }
      final record = BeakRecord(values: values);
      for (final entry in _validate(model, record).entries) {
        errors.putIfAbsent(entry.key, () => entry.value);
      }
      rows.add(BeakBatchRow(number: index + 1, values: record, errors: errors));
    }
    return BeakBatchPreview(model: model, rows: rows);
  }

  Object? _parse(BeakColumn column, String text, BeakFormatting formatting) {
    if (text.isEmpty) return null;
    if (column.semantic.hasCodec ||
        column.semantic.kind == BeakSemanticKind.percentage ||
        column is BeakJsonColumn) {
      final parsed = BeakInputCodec.parse(column, text, formatting);
      if (parsed.error != null) throw FormatException(parsed.error!);
      return parsed.value;
    }
    return switch (column) {
      BeakIntColumn() => switch (formatting.parseNumber(text)) {
        final num value when value.isFinite && value == value.roundToDouble() =>
          value.toInt(),
        _ => throw const FormatException('Enter a whole number.'),
      },
      BeakDecimalColumn() => switch (formatting.parseNumber(text)) {
        final num value when value.isFinite => value.toDouble(),
        _ => throw const FormatException('Enter a finite number.'),
      },
      BeakBoolColumn() => switch (text.trim().toLowerCase()) {
        'true' => true,
        'false' => false,
        _ => throw const FormatException('Use true or false.'),
      },
      BeakDateTimeColumn() =>
        DateTime.tryParse(text) ??
            (throw const FormatException('Use an ISO-8601 timestamp.')),
      _ => text,
    };
  }
}

Map<String, List<String>> _validate(
  BeakModel model,
  BeakRecord input, {
  BeakRecord? initial,
}) {
  try {
    model.behavior.validateEdits(input, initial: initial);
    final candidate = model.behavior.apply(
      const BeakValidation().applyDefaults(
        model,
        BeakRecord(
          values: {...?initial?.values, ...input.values},
          relations: {...?initial?.relations, ...input.relations},
        ),
        includeMissing: initial == null,
      ),
      initial: initial,
      overriddenFields: input.values.keys.toSet(),
    );
    return const BeakValidation().validate(
      model,
      candidate,
      isCreate: initial == null,
      initial: initial,
    );
  } on BeakValidationException catch (error) {
    return error.fieldErrors.isEmpty
        ? {
            '_record': [error.message],
          }
        : error.fieldErrors;
  }
}

List<List<String>> _csv(String source, int maximumRows) {
  if (source.length > 2000000) {
    throw const BeakValidationException(
      'CSV exceeds the 2 million character text limit.',
    );
  }
  final rows = <List<String>>[];
  var row = <String>[];
  var cell = StringBuffer();
  var quoted = false;
  var closedQuote = false;
  void endCell() {
    row.add(cell.toString());
    cell = StringBuffer();
    closedQuote = false;
  }

  void endRow() {
    endCell();
    rows.add(row);
    row = [];
    if (rows.length > maximumRows) {
      throw BeakValidationException(
        'Import exceeds ${maximumRows - 1} data rows.',
      );
    }
  }

  for (var i = 0; i < source.length; i++) {
    final character = source[i];
    if (quoted) {
      if (character == '"') {
        if (i + 1 < source.length && source[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
          closedQuote = true;
        }
      } else {
        cell.write(character);
      }
    } else if (character == ',') {
      endCell();
    } else if (character == '\r' || character == '\n') {
      endRow();
      if (character == '\r' && i + 1 < source.length && source[i + 1] == '\n') {
        i++;
      }
    } else if (character == '"' && cell.isEmpty && !closedQuote) {
      quoted = true;
    } else if (character == '"' || closedQuote) {
      throw const BeakValidationException('Malformed CSV quoting.');
    } else {
      cell.write(character);
    }
  }
  if (quoted) {
    throw const BeakValidationException(
      'CSV contains an unclosed quoted field.',
    );
  }
  if (cell.isNotEmpty || row.isNotEmpty || closedQuote) endRow();
  return rows;
}

/// Receipt-aware batch execution with cancellation between independent records.
///
/// Each graph keeps its own transaction guarantee. The batch is not one shared
/// transaction; completed records remain saved when a later record fails.
final class BeakBatchRepository {
  /// Uses the same graph transport and receipt boundary as configured forms.
  BeakBatchRepository(this.source);

  /// Commit-capable source, normally the panel's mutation-aware source.
  final BeakCommitDataSource source;
  final Map<String, String> _plans = {};
  final Map<String, BeakSaveResult> _receipts = {};
  bool _running = false;
  bool _cancelled = false;

  /// Confirmed or uncertain receipts, in execution order.
  List<BeakSaveResult> get receipts => List.unmodifiable(_receipts.values);

  /// Stops before the next record; an in-flight write still receives its receipt.
  void cancel() => _cancelled = true;

  /// Executes until complete, cancelled, rejected or uncertain; safe to resume.
  Future<BeakResult<List<BeakSaveResult>>> execute(
    List<BeakSavePlan> plans, {
    void Function(int completed, int total)? onProgress,
  }) => beakRun(() async {
    if (_running) {
      throw const BeakConfigurationException('A batch is already running.');
    }
    final ids = <String>{};
    for (final plan in plans) {
      final signature = jsonEncode(plan.toJson());
      if (!ids.add(plan.saveId) ||
          (_plans[plan.saveId] != null && _plans[plan.saveId] != signature)) {
        throw const BeakConflictException(
          'A batch save identity was reused with different content.',
        );
      }
      _plans[plan.saveId] = signature;
    }
    _running = true;
    _cancelled = false;
    try {
      var completed = 0;
      for (final plan in plans) {
        final previous = _receipts[plan.saveId];
        if (previous?.hasUnknown ?? false) break;
        if (previous?.complete ?? false) {
          onProgress?.call(++completed, plans.length);
          continue;
        }
        if (_cancelled) break;
        final receipt = await BeakFormCommitRepository(source).commit(plan);
        _receipts[plan.saveId] = receipt;
        if (!receipt.complete) break;
        onProgress?.call(++completed, plans.length);
      }
      return [
        for (final plan in plans)
          if (_receipts[plan.saveId] case final BeakSaveResult receipt) receipt,
      ];
    } finally {
      _running = false;
    }
  });

  /// Resolves an uncertain record before execution can resume.
  Future<BeakResult<BeakSaveResult>> recover(String saveId) =>
      beakRun(() async {
        if (_running || !_plans.containsKey(saveId)) {
          throw const BeakConfigurationException(
            'Wait for this batch before recovering a known save.',
          );
        }
        final receipt = await BeakFormCommitRepository(source).recover(
          saveId,
          operationIds: [
            for (final outcome
                in _receipts[saveId]?.outcomes ?? const <BeakOperationResult>[])
              outcome.id,
          ],
        );
        _receipts[saveId] = receipt;
        return receipt;
      });
}
