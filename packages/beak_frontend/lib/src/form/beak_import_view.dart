import 'dart:convert';
import 'dart:math';

import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals_flutter.dart';

import '../data/beak_record_batch.dart';
import '../data/beak_run.dart';
import '../di/beak_locator.dart';
import '../formatting/beak_formatting.dart';

/// Review-first CSV import with typed parsing, graph saves and receipt recovery.
class BeakImportView extends StatelessWidget {
  /// Inherits the panel's source and formatting unless [dataSource] is supplied.
  const BeakImportView({
    required this.definition,
    this.dataSource,
    this.initialCsv = '',
    this.title = 'Import records',
    super.key,
  });

  /// Explicit field allowlist and shared model metadata.
  final BeakImportDefinition definition;

  /// Optional standalone data source.
  final BeakDataSource? dataSource;

  /// Editable source text.
  final String initialCsv;

  /// Heading for the import surface.
  final String title;
  @override
  Widget build(BuildContext context) => _BeakBatchView(
    definition: definition,
    dataSource: dataSource,
    initialCsv: initialCsv,
    title: title,
  );
}

/// Reviews typed changes across selected records before saving each revision.
class BeakBulkEditView extends StatelessWidget {
  /// Every field change is validated against every selected record.
  const BeakBulkEditView({
    required this.model,
    required this.records,
    required this.changes,
    this.dataSource,
    this.title = 'Review changes',
    super.key,
  });

  /// Model owning all selected records.
  final BeakModel model;

  /// Current complete records, including revision timestamps.
  final List<BeakRecord> records;

  /// Typed patch applied to each selected record.
  final List<BeakFieldChange<Object>> changes;

  /// Optional standalone data source.
  final BeakDataSource? dataSource;

  /// Heading for this review surface.
  final String title;
  @override
  Widget build(BuildContext context) => _BeakBatchView(
    definition: BeakImportDefinition(
      model: model,
      fields: [for (final change in changes) change.field],
    ),
    records: records,
    changes: changes,
    dataSource: dataSource,
    title: title,
  );
}

class _BeakBatchView extends HookWidget {
  const _BeakBatchView({
    required this.definition,
    this.dataSource,
    this.initialCsv = '',
    required this.title,
    this.records,
    this.changes = const [],
  });
  final List<BeakRecord>? records;
  final List<BeakFieldChange<Object>> changes;

  /// Explicit field allowlist and shared model metadata.
  final BeakImportDefinition definition;

  /// Optional standalone source; normal panel screens inherit it.
  final BeakDataSource? dataSource;

  /// Optional editable starting text, useful for a downloadable-template preview.
  final String initialCsv;

  /// Heading for this embedded import surface.
  final String title;

  @override
  Widget build(BuildContext context) {
    final source = dataSource ?? beakDependencies(context)<BeakDataSource>();
    final formatting = BeakFormatting.of(context);
    final controller = useTextEditingController(text: initialCsv);
    final configuration = _BatchConfiguration(
      definition,
      source,
      formatting,
      records,
      changes,
      initialCsv,
    );
    final state = useMemoized(() => _ImportState(configuration), const []);
    useEffect(() {
      if (state.configure(configuration)) controller.text = initialCsv;
      return null;
    }, [definition, source, formatting, records, changes]);
    useEffect(() => state.dispose, [state]);
    return Watch((context) {
      final definition = state.definition;
      final records = state.records;
      final preview = state.preview.value;
      final receipts = state.receipts.value;
      final locked = state.locked;
      final unknown = receipts.any((receipt) => receipt.hasUnknown);
      return OiColumn(
        breakpoint: context.breakpoint,
        gap: const OiResponsive(16),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OiLabel.h3(title),
          if (records == null) ...[
            OiLabel.body(
              'Paste CSV with these headers: ${definition.fields.map(definition.header).join(', ')}.',
            ),
            OiTextInput(
              controller: controller,
              label: 'CSV data',
              maxLines: 8,
              enabled: !locked,
              onChanged: (_) => state.invalidate(),
            ),
          ],
          OiButton.secondary(
            label: records == null ? 'Preview import' : 'Preview changes',
            onTap: locked ? null : () => state.prepare(controller.text),
          ),
          if (state.configurationChanged.value) ...[
            const OiLabel.body(
              'The source or batch configuration changed. Resolve any interrupted save before starting a new review.',
            ),
            OiButton.secondary(
              label: 'Start new review',
              onTap: !state.busy.value && !unknown
                  ? () {
                      if (state.acceptConfiguration()) {
                        controller.text = state.initialCsv;
                      }
                    }
                  : null,
            ),
          ],
          if (state.editing.value && records == null)
            const OiLabel.caption(
              'Correct unsaved rows in the CSV. Keep already saved rows in their original positions and unchanged.',
            ),
          if (state.error.value case final String error) OiLabel.body(error),
          if (preview != null) ...[
            OiLabel.body(
              '${preview.rows.length} records. ${preview.rows.where((row) => !row.valid).length} need correction.',
            ),
            for (final row in preview.rows.take(20))
              OiCard(
                child: OiColumn(
                  breakpoint: context.breakpoint,
                  gap: const OiResponsive(8),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OiLabel.body('Row ${row.number}'),
                    for (final field in definition.fields)
                      OiLabel.body(
                        '${definition.header(field)}: ${row.initial == null ? '' : '${formatting.formatCell(field.column, row.initial!)} → '}${formatting.formatCell(field.column, row.values)}',
                      ),
                    for (final errors in row.errors.values)
                      for (final error in errors) OiLabel.body(error),
                  ],
                ),
              ),
            if (preview.rows.length > 20)
              const OiLabel.caption(
                'Showing the first 20 records. Every record is validated before submission.',
              ),
            const OiLabel.caption(
              'Records save individually. Completed records stay saved if a later record fails or you stop.',
            ),
            OiButton.primary(
              label: receipts.isEmpty
                  ? '${records == null ? 'Import' : 'Update'} ${preview.rows.length} records'
                  : 'Resume ${records == null ? 'import' : 'updates'}',
              onTap:
                  preview.valid &&
                      !state.busy.value &&
                      !unknown &&
                      !state.configurationChanged.value &&
                      state.completed.value < preview.rows.length
                  ? state.submit
                  : null,
            ),
          ],
          if (state.canCorrect)
            OiButton.secondary(
              label: records == null
                  ? 'Edit remaining rows'
                  : 'Reload remaining records',
              onTap: records == null ? state.correct : state.reloadRemaining,
            ),
          if (state.busy.value) ...[
            const OiLabel.body('Working…'),
            OiButton.secondary(
              label: 'Stop after current record',
              onTap: state.cancel,
            ),
          ],
          if (receipts.isNotEmpty)
            OiLabel.body(
              '${state.completed.value} of ${state.total} records saved.',
            ),
          if (unknown)
            OiButton.secondary(
              label: 'Check interrupted save',
              onTap: state.busy.value ? null : state.recover,
            ),
        ],
      );
    });
  }
}

/// A logical configuration, independent of freshly allocated widget arguments.
final class _BatchConfiguration {
  _BatchConfiguration(
    this.definition,
    this.source,
    this.formatting,
    this.records,
    this.changes,
    this.initialCsv,
  );
  final BeakImportDefinition definition;
  final BeakDataSource source;
  final BeakFormatting formatting;
  final List<BeakRecord>? records;
  final List<BeakFieldChange<Object>> changes;
  final String initialCsv;

  late final String signature = jsonEncode({
    'model': definition.model.table,
    'limit': definition.maximumRows,
    'fields': [
      for (final field in definition.fields)
        [field.model.table, field.path, field.key, definition.header(field)],
    ],
    'records': records?.map((record) => record.toJson()).toList(),
    'changes': [
      for (final change in changes)
        [change.field.model.table, change.field.key, change.value?.toString()],
    ],
  });

  bool equivalent(_BatchConfiguration other) =>
      identical(source, other.source) && signature == other.signature;
}

/// Screen state; repository boundaries convert failures into typed results.
final class _ImportState {
  _ImportState(this._configuration);
  _BatchConfiguration _configuration;
  _BatchConfiguration? _pendingConfiguration;
  BeakImportDefinition get definition => _configuration.definition;
  BeakDataSource get source => _configuration.source;
  BeakFormatting get formatting => _configuration.formatting;
  List<BeakRecord>? get records => _configuration.records;
  List<BeakFieldChange<Object>> get changes => _configuration.changes;
  String get initialCsv => _configuration.initialCsv;
  final preview = signal<BeakBatchPreview?>(null);
  final error = signal<String?>(null);
  final busy = signal(false);
  final completed = signal(0);
  final receipts = signal<List<BeakSaveResult>>([]);
  final editing = signal(false);
  final configurationChanged = signal(false);
  final Map<int, (BeakBatchRow, BeakSavePlan)> _saved = {};
  BeakBatchPreview? _baseline;
  BeakBatchRepository? _repository;
  List<BeakSavePlan>? _plans;
  bool _disposed = false;
  bool _cancelRequested = false;
  bool get _unknown => receipts.value.any((receipt) => receipt.hasUnknown);
  int get total => preview.value?.rows.length ?? _baseline?.rows.length ?? 0;
  bool get locked =>
      busy.value ||
      _unknown ||
      configurationChanged.value ||
      (receipts.value.isNotEmpty && completed.value < total && !editing.value);
  bool get canCorrect =>
      !busy.value &&
      !_unknown &&
      !configurationChanged.value &&
      !editing.value &&
      receipts.value.isNotEmpty &&
      completed.value < total;

  bool configure(_BatchConfiguration next) {
    if (_configuration.equivalent(next)) {
      _pendingConfiguration = null;
      configurationChanged.value = false;
      // An active queue retains the model and transport that created its plans.
      if (!busy.value && _plans == null && !editing.value) {
        _configuration = next;
      }
      return false;
    }
    if (busy.value ||
        _unknown ||
        (receipts.value.isNotEmpty && completed.value < total)) {
      _pendingConfiguration = next;
      configurationChanged.value = true;
      cancel();
      return false;
    }
    _configuration = next;
    _pendingConfiguration = null;
    configurationChanged.value = false;
    _clear();
    return true;
  }

  bool acceptConfiguration() {
    if (busy.value || _unknown) return false;
    final next = _pendingConfiguration;
    if (next == null) return false;
    _configuration = next;
    _pendingConfiguration = null;
    configurationChanged.value = false;
    _clear();
    return true;
  }

  void _clear() {
    preview.value = null;
    error.value = null;
    receipts.value = [];
    completed.value = 0;
    editing.value = false;
    _saved.clear();
    _baseline = null;
    _plans = null;
    _repository = null;
  }

  void invalidate() {
    if (locked) return;
    if (editing.value) {
      preview.value = null;
      error.value = null;
      _plans = null;
    } else {
      _clear();
    }
  }

  void correct() {
    if (!canCorrect) return;
    _baseline = preview.value;
    final plans = _plans;
    if (plans == null || _baseline == null) return;
    final applied = {
      for (final receipt in receipts.value)
        if (receipt.complete) receipt.saveId,
    };
    for (var index = 0; index < plans.length; index++) {
      if (applied.contains(plans[index].saveId)) {
        final row = _baseline!.rows[index];
        _saved[row.number] = (row, plans[index]);
      }
    }
    editing.value = true;
    preview.value = null;
    error.value = null;
    _plans = null;
  }

  Future<void> _checkAccess(BeakBatchPreview candidate) async {
    if (source case final BeakCapabilityDataSource permissions) {
      for (final row in candidate.rows) {
        if (_saved.containsKey(row.number)) continue;
        final access = await permissions.capabilities(
          definition.model.table,
          id: row.initial == null
              ? null
              : definition.model.primaryKeyOf(row.initial!),
        );
        if (definition.fields.any(
          (field) =>
              row.values.values.containsKey(field.key) &&
              !access.canWrite(field.key),
        )) {
          throw BeakAuthorizationException(
            records == null
                ? 'Some import fields are not writable by your account.'
                : 'Some selected records or fields are not writable by your account.',
          );
        }
        if (records == null) break;
      }
    }
  }

  BeakBatchPreview _preserveSaved(BeakBatchPreview candidate) {
    for (final entry in _saved.entries) {
      final matches = candidate.rows.where((row) => row.number == entry.key);
      if (matches.isEmpty ||
          jsonEncode(matches.single.values.toJson()) !=
              jsonEncode(entry.value.$1.values.toJson())) {
        throw BeakValidationException(
          'Row ${entry.key} has already been saved. Keep saved rows unchanged and in their original positions.',
        );
      }
    }
    return BeakBatchPreview(
      model: candidate.model,
      rows: [for (final row in candidate.rows) _saved[row.number]?.$1 ?? row],
    );
  }

  Future<void> prepare(String csv) async {
    if (locked) return;
    invalidate();
    busy.value = true;
    final result = await beakRun(() async {
      final candidate = _preserveSaved(
        records == null
            ? definition.preview(csv, formatting: formatting)
            : BeakBulkEdit.preview(
                model: definition.model,
                records: records!,
                changes: changes,
              ),
      );
      await _checkAccess(candidate);
      return candidate;
    });
    if (_disposed) return;
    busy.value = false;
    switch (result) {
      case BeakOk(:final value):
        preview.value = value;
        error.value = null;
      case BeakErr(:final error):
        this.error.value = error.message;
        preview.value = null;
    }
  }

  Future<void> reloadRemaining() async {
    if (!canCorrect || records == null) return;
    final previousPlans = _plans;
    correct();
    busy.value = true;
    final result = await beakRun(() async {
      final refreshed = <BeakRecord>[];
      for (final row in _baseline!.rows) {
        if (_saved.containsKey(row.number)) {
          refreshed.add(row.initial!);
          continue;
        }
        final id = definition.model.primaryKeyOf(row.initial!)!;
        final record = await source.getOne(definition.model.table, id);
        if (record == null) {
          throw BeakNotFoundException('Record $id is no longer available.');
        }
        refreshed.add(record);
      }
      final candidate = _preserveSaved(
        BeakBulkEdit.preview(
          model: definition.model,
          records: refreshed,
          changes: changes,
        ),
      );
      await _checkAccess(candidate);
      return candidate;
    });
    if (_disposed) return;
    busy.value = false;
    switch (result) {
      case BeakOk(:final value):
        preview.value = value;
      case BeakErr(:final error):
        _plans = previousPlans;
        preview.value = _baseline;
        editing.value = false;
        this.error.value = error.message;
    }
  }

  Future<void> submit() async {
    if (busy.value ||
        _unknown ||
        configurationChanged.value ||
        preview.value?.valid != true) {
      return;
    }
    busy.value = true;
    _cancelRequested = false;
    error.value = null;
    final result = await beakRun(() async {
      if (source case final BeakCommitDataSource commits) {
        _repository ??= BeakBatchRepository(commits);
      } else {
        throw const BeakConfigurationException(
          'This source does not support graph imports.',
        );
      }
      await _checkAccess(preview.value!);
      if (_disposed) return <BeakSaveResult>[];
      if (configurationChanged.value) {
        throw const BeakConfigurationException(
          'The batch source changed before submission. Start a new review.',
        );
      }
      if (_cancelRequested) return <BeakSaveResult>[];
      if (_plans == null) {
        final candidate = preview.value!;
        final fresh = candidate.plans(
          'import-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x3fffffff)}',
        );
        _plans = [
          for (var index = 0; index < fresh.length; index++)
            _saved[candidate.rows[index].number]?.$2 ?? fresh[index],
        ];
      }
      editing.value = false;
      final executed = await _repository!.execute(
        _plans!,
        onProgress: (count, total) {
          if (!_disposed) completed.value = count;
        },
      );
      return executed.valueOrThrow;
    });
    if (_disposed) return;
    _syncReceipts();
    busy.value = false;
    switch (result) {
      case BeakErr(:final error):
        this.error.value = error.message;
      case BeakOk(:final value):
        final failures = value
            .expand((receipt) => receipt.outcomes)
            .where((outcome) => outcome.status != BeakWriteOutcome.applied);
        if (failures.isNotEmpty) {
          error.value =
              failures.first.error?.message ??
              'The current record has not been confirmed saved.';
        }
    }
  }

  void _syncReceipts() {
    final ids = {
      for (final plan in _plans ?? _saved.values.map((saved) => saved.$2))
        plan.saveId,
    };
    receipts.value = [
      for (final receipt in _repository?.receipts ?? const <BeakSaveResult>[])
        if (ids.contains(receipt.saveId)) receipt,
    ];
    completed.value = receipts.value
        .where((receipt) => receipt.complete)
        .length;
    final candidate = preview.value ?? _baseline;
    final plans = _plans;
    if (candidate != null && plans != null) {
      final applied = {
        for (final receipt in receipts.value)
          if (receipt.complete) receipt.saveId,
      };
      for (var index = 0; index < plans.length; index++) {
        if (applied.contains(plans[index].saveId)) {
          final row = candidate.rows[index];
          _saved[row.number] = (row, plans[index]);
        }
      }
    }
  }

  Future<void> recover() async {
    final repository = _repository;
    if (busy.value || repository == null) return;
    busy.value = true;
    error.value = null;
    for (final receipt in receipts.value.where(
      (receipt) => receipt.hasUnknown,
    )) {
      final result = await repository.recover(receipt.saveId);
      if (_disposed) return;
      if (result case BeakErr(:final error)) {
        this.error.value = error.message;
        break;
      }
    }
    _syncReceipts();
    busy.value = false;
  }

  void cancel() {
    _cancelRequested = true;
    _repository?.cancel();
  }

  void dispose() {
    _disposed = true;
    cancel();
    preview.dispose();
    error.dispose();
    busy.dispose();
    completed.dispose();
    receipts.dispose();
    editing.dispose();
    configurationChanged.dispose();
  }
}
