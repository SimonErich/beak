import 'package:beak_core/beak_core.dart';
import 'package:signals/signals.dart';

import '../data/beak_resource_repository.dart';
import '../state/beak_view_model.dart';

/// Owns a form's record lifecycle: loading the record in edit mode,
/// submitting through the repository (the catch boundary), and exposing
/// server-side field errors for inline display.
final class FormViewModel extends BeakViewModel {
  /// Creates the view model for [model] over [dataSource]; a non-null
  /// [recordId] puts the form in edit mode.
  FormViewModel(this.model, BeakDataSource dataSource, {this.recordId})
    : _repository = BeakResourceRepository(dataSource) {
    _initial = ownedSignal<BeakRecord?>(null);
    _loading = ownedSignal(recordId != null);
    _submitting = ownedSignal(false);
    _error = ownedSignal<BeakException?>(null);
    _fieldErrors = ownedSignal(const {});
    _saved = ownedSignal<BeakRecord?>(null);
  }

  /// The model this form edits.
  final BeakModel model;

  /// The record under edit, or `null` for create mode.
  final Object? recordId;

  final BeakResourceRepository _repository;

  late final Signal<BeakRecord?> _initial;
  late final Signal<bool> _loading;
  late final Signal<bool> _submitting;
  late final Signal<BeakException?> _error;
  late final Signal<Map<String, List<String>>> _fieldErrors;
  late final Signal<BeakRecord?> _saved;

  /// Whether this form edits an existing record.
  bool get isEdit => recordId != null;

  /// The loaded record in edit mode (`null` while loading or in create
  /// mode).
  ReadonlySignal<BeakRecord?> get initial => _initial;

  /// Whether the edit-mode record is loading.
  ReadonlySignal<bool> get loading => _loading;

  /// Whether a submit is in flight.
  ReadonlySignal<bool> get submitting => _submitting;

  /// The last non-validation failure (load or submit).
  ReadonlySignal<BeakException?> get error => _error;

  /// Server-side validation errors by column key, cleared on the next
  /// submit.
  ReadonlySignal<Map<String, List<String>>> get fieldErrors => _fieldErrors;

  /// The record the last successful submit stored.
  ReadonlySignal<BeakRecord?> get saved => _saved;

  /// Loads the record under edit (no-op in create mode).
  Future<void> load() async {
    final Object? id = recordId;
    if (id == null) {
      return;
    }
    _loading.value = true;
    final result = await _repository.getOne(model.table, id);
    switch (result) {
      case BeakOk(:final value):
        _initial.value = value;
      case BeakErr(:final error):
        _error.value = error;
    }
    _loading.value = false;
  }

  /// Submits [record]: create in create mode, partial update in edit mode.
  ///
  /// Server validation failures land in [fieldErrors]; other failures in
  /// [error]. Returns the stored record on success, `null` otherwise.
  Future<BeakRecord?> submit(BeakRecord record) async {
    _submitting.value = true;
    _error.value = null;
    _fieldErrors.value = const {};
    final Object? id = recordId;
    final result = id == null
        ? await _repository.create(model.table, record)
        : await _repository.update(model.table, id, record);
    _submitting.value = false;
    switch (result) {
      case BeakOk(:final value):
        _saved.value = value;
        return value;
      case BeakErr(error: final BeakValidationException validation):
        _fieldErrors.value = validation.fieldErrors;
        return null;
      case BeakErr(:final error):
        _error.value = error;
        return null;
    }
  }
}
