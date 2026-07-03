import 'package:beak_core/beak_core.dart';

import '../common/uuid_v4.dart';
import '../data/beak_data_source.dart';
import 'validation_service.dart';

/// The per-model logic layer between the generated handlers and the data
/// source: validation, create-time defaults (minted uuid ids, timestamps),
/// and relation-kind gating — handlers stay parse-and-route thin.
final class BeakResourceService {
  /// Creates the service for [model] over [dataSource].
  ///
  /// [now] and [generateId] inject the clock and id mint for tests.
  BeakResourceService(
    this.model,
    this.dataSource, {
    this.validation = const ValidationService(),
    DateTime Function()? now,
    String Function()? generateId,
  }) : _now = now ?? DateTime.now,
       _generateId = generateId ?? generateUuidV4;

  /// The model this service exposes.
  final BeakModel model;

  /// The source the service reads and writes through.
  final BeakDataSource dataSource;

  /// The validation boundary run before every write.
  final ValidationService validation;

  final DateTime Function() _now;
  final String Function() _generateId;

  /// The column key the service stamps on create.
  static const String createdAtColumnKey = 'created_at';

  /// The column key the service stamps on create and update.
  static const String updatedAtColumnKey = 'updated_at';

  /// Runs [spec] against the data source.
  ///
  /// Throws a [BeakValidationException] when the spec targets another table
  /// than this service's model.
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) {
    if (spec.table != model.table) {
      throw BeakValidationException(
        'Query spec targets "${spec.table}" but this endpoint serves '
        '"${model.table}".',
      );
    }
    return dataSource.query(spec);
  }

  /// The record with primary key [id].
  ///
  /// Throws a [BeakNotFoundException] when it does not exist.
  Future<BeakRecord> getOne(Object id) async =>
      await dataSource.getOne(model.table, id) ??
      (throw BeakNotFoundException(
        'No record of "${model.table}" with id "$id".',
      ));

  /// Validates and stores [input], minting a uuid primary key (for
  /// string-keyed models) and stamping `created_at`/`updated_at` when the
  /// model declares them and the caller did not.
  Future<BeakRecord> create(BeakRecord input) {
    final prepared = _withCreateDefaults(input);
    validation.validate(model, prepared, isCreate: true);
    return dataSource.create(model.table, prepared);
  }

  /// Validates the provided fields of [input] (partial semantics), stamps
  /// `updated_at` when the model declares it, and applies the update.
  Future<BeakRecord> update(Object id, BeakRecord input) {
    validation.validate(model, input, isCreate: false);
    var values = input.values;
    if (model.columnByKey(updatedAtColumnKey) is BeakDateTimeColumn) {
      values = {...values, updatedAtColumnKey: BeakDateTimeValue(_now())};
    }
    return dataSource.update(model.table, id, BeakRecord(values: values));
  }

  /// Deletes the record with primary key [id] — softly for soft-deleting
  /// models unless [force].
  Future<void> delete(Object id, {bool force = false}) =>
      dataSource.delete(model.table, id, force: force);

  /// The records whose primary keys appear in [ids], in one query.
  Future<List<BeakRecord>> batchGet(List<Object> ids) =>
      dataSource.batchGet(model.table, ids);

  /// Links [relatedIds] through the to-many relation [relationKey].
  Future<void> attach(Object id, String relationKey, List<Object> relatedIds) {
    _attachableRelation(relationKey);
    return dataSource.attach(model.table, id, relationKey, relatedIds);
  }

  /// Unlinks [relatedIds] from the to-many relation [relationKey].
  Future<void> detach(Object id, String relationKey, List<Object> relatedIds) {
    _attachableRelation(relationKey);
    return dataSource.detach(model.table, id, relationKey, relatedIds);
  }

  BeakRelationship _attachableRelation(String relationKey) {
    final relationship = model.relationshipByKey(relationKey);
    if (relationship == null) {
      throw BeakNotFoundException(
        'Model "${model.table}" has no relation "$relationKey".',
      );
    }
    if (relationship is! BeakBelongsToMany && relationship is! BeakHasMany) {
      throw BeakValidationException(
        'Relation "$relationKey" of "${model.table}" is a '
        '${relationship.runtimeType}; attach/detach need a to-many relation.',
      );
    }
    return relationship;
  }

  BeakRecord _withCreateDefaults(BeakRecord input) {
    final values = {...input.values};
    final primaryKey = model.primaryKey;
    if (primaryKey is BeakStringColumn && values[primaryKey.key] == null) {
      values[primaryKey.key] = BeakStringValue(_generateId());
    }
    final stamp = BeakDateTimeValue(_now());
    for (final columnKey in const [createdAtColumnKey, updatedAtColumnKey]) {
      if (model.columnByKey(columnKey) is BeakDateTimeColumn &&
          values[columnKey] == null) {
        values[columnKey] = stamp;
      }
    }
    return BeakRecord(values: values, relations: input.relations);
  }
}
