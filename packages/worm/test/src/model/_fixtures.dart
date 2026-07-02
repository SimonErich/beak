/// Shared test fixtures for model unit tests.
library;

import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/validation/validation_rule.dart';

/// Snapshot of every lifecycle event a model has fired in order.
final class HookLog {
  /// Recorded event names in firing order.
  final List<String> events = <String>[];
}

/// Test model wired with the attribute store and lifecycle tracing.
///
/// Subclasses can flip [cancelBeforeValidate] /
/// [cancelBeforeSave] / [cancelBeforeCreate] /
/// [cancelBeforeUpdate] / [cancelBeforeDelete] to assert
/// hook cancellation semantics.
final class TestModel extends Model {
  /// Creates a [TestModel] bound to an external [log].
  TestModel({
    required this.tableNameOverride,
    this.log,
    this.usesTimestampsOverride = true,
    this.fillableOverride = const <String>[],
    this.guardedOverride = const <String>[],
    this.strictOverride = false,
    this.rulesOverride = const <Field<Object?>, List<ValidationRule>>{},
    this.updateRulesOverride,
    this.cancelBeforeValidate = false,
    this.cancelBeforeSave = false,
    this.cancelBeforeCreate = false,
    this.cancelBeforeUpdate = false,
    this.cancelBeforeDelete = false,
  });

  /// Optional event recorder.
  final HookLog? log;

  /// Table this model targets.
  final String tableNameOverride;

  /// Override for [usesTimestamps].
  final bool usesTimestampsOverride;

  /// Override for [fillable].
  final List<String> fillableOverride;

  /// Override for [guarded].
  final List<String> guardedOverride;

  /// Override for [strictMassAssignment].
  final bool strictOverride;

  /// Override for [rules].
  final Map<Field<Object?>, List<ValidationRule>> rulesOverride;

  /// Override for [updateRules]; falls back to [rules] when null.
  final Map<Field<Object?>, List<ValidationRule>>? updateRulesOverride;

  /// Cancel switches per lifecycle hook.
  bool cancelBeforeValidate;

  /// Cancel switches per lifecycle hook.
  bool cancelBeforeSave;

  /// Cancel switches per lifecycle hook.
  bool cancelBeforeCreate;

  /// Cancel switches per lifecycle hook.
  bool cancelBeforeUpdate;

  /// Cancel switches per lifecycle hook.
  bool cancelBeforeDelete;

  @override
  String get tableName => tableNameOverride;

  @override
  bool get usesTimestamps => usesTimestampsOverride;

  @override
  List<String> get fillable => fillableOverride;

  @override
  List<String> get guarded => guardedOverride;

  @override
  bool get strictMassAssignment => strictOverride;

  @override
  Map<Field<Object?>, List<ValidationRule>> get rules => rulesOverride;

  @override
  Map<Field<Object?>, List<ValidationRule>> get updateRules =>
      updateRulesOverride ?? rules;

  @override
  Object get id => getAttribute('id') ?? 0;

  @override
  Map<String, Object?> toRow() => <String, Object?>{...state.attributes};

  void _log(String event) => log?.events.add(event);

  @override
  Future<bool> beforeValidate() async {
    _log('beforeValidate');
    return !cancelBeforeValidate;
  }

  @override
  Future<void> afterValidate() async => _log('afterValidate');

  @override
  Future<bool> beforeSave() async {
    _log('beforeSave');
    return !cancelBeforeSave;
  }

  @override
  Future<bool> beforeCreate() async {
    _log('beforeCreate');
    return !cancelBeforeCreate;
  }

  @override
  Future<void> afterCreate() async => _log('afterCreate');

  @override
  Future<bool> beforeUpdate() async {
    _log('beforeUpdate');
    return !cancelBeforeUpdate;
  }

  @override
  Future<void> afterUpdate() async => _log('afterUpdate');

  @override
  Future<void> afterSave() async => _log('afterSave');

  @override
  Future<bool> beforeDelete() async {
    _log('beforeDelete');
    return !cancelBeforeDelete;
  }

  @override
  Future<void> afterDelete() async => _log('afterDelete');

  @override
  Future<void> afterHydrate() async => _log('afterHydrate');
}
