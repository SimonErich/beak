import 'package:beak_core/beak_core.dart';

import 'beak_action_policy.dart';
import 'beak_auth_guard.dart';
import 'beak_policy.dart';

/// Adds principal-scoped field access to resource and row policies.
///
/// Read access also gates search, sorting, filters and aggregates, preventing
/// inference through query results. Row-specific access belongs in row scopes.
///
/// A field arrives as the typed reference the model itself generates
/// (`ProductModel.price`): a column of a scalar, a relationship of a to-one or
/// to-many reference. Compare one with [BeakFieldRefIdentity.isSameFieldAs]
/// instead of reading its key:
///
/// ```dart
/// @override
/// bool canReadField(
///   BeakPrincipal? principal,
///   BeakModel model,
///   BeakFieldRef<Object> field,
/// ) => !field.isSameFieldAs(ProductModel.supplierCost);
/// ```
abstract interface class BeakFieldPolicy implements BeakPolicy {
  /// Whether [field] of [model] can appear in responses or user-controlled
  /// queries.
  bool canReadField(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  );

  /// Whether [field] of [model] can be supplied by the caller on create or
  /// update.
  bool canWriteField(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  );
}

/// A policy that names fields the caller may see but never supply.
///
/// [BeakFieldPolicy.canWriteField] answers "may this principal write this
/// field" with a 401 or 403. A read-only field is a different failure: the
/// caller is allowed to use the resource but sent a value the server owns
/// (a total, a number, a status the workflow moves), so the request is
/// rejected as a 422 field error, and the field is left out of the
/// capabilities' writable set so a form never offers it.
///
/// Server-side calculations still write these fields: the check applies to the
/// values the client supplied, not to what graph preparation derives.
abstract interface class BeakReadOnlyFieldPolicy implements BeakPolicy {
  /// Whether [field] of [model] rejects any value [principal] supplies.
  bool isFieldReadOnly(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  );
}

/// Identity of a typed field reference, which is not the reference object.
///
/// Generated models hand out a new reference per access path, so two
/// references to the same field are never `identical` and do not compare
/// equal. This is the comparison a policy wants.
extension BeakFieldRefIdentity on BeakFieldRef<Object> {
  /// Whether this reference and [other] point at the same field of the same
  /// model, along the same relationship path.
  bool isSameFieldAs(BeakFieldRef<Object> other) =>
      model.table == other.model.table && qualifiedKey == other.qualifiedKey;
}

typedef _FieldTest = bool Function(BeakModel model, BeakFieldRef<Object> field);

/// The field-access boundary shared by HTTP reads, writes and graph commits.
final class BeakFieldAccess {
  /// Binds registered metadata and the current request's trusted policy.
  const BeakFieldAccess({
    required this.registry,
    required this.policy,
    required this.principal,
  });

  /// Known models for recursive relationship redaction.
  final BeakModelRegistry registry;

  /// Server-owned access policy.
  final BeakPolicy policy;

  /// Current authenticated identity.
  final BeakPrincipal? principal;

  /// Whether [column] of [model] may be returned or used in a user-controlled
  /// query.
  bool canReadColumn(BeakModel model, BeakColumn column) =>
      _canRead(model, BeakScalarField<Object>(model: model, column: column));

  /// Rejects queries that could reveal a protected field indirectly.
  void requireReadColumn(BeakModel model, BeakColumn column) =>
      enforcePolicyDecision(
        allowed: canReadColumn(model, column),
        principal: principal,
        action: 'read field "${column.key}" of',
        model: model,
      );

  /// Rejects protected input fields before validation or persistence.
  ///
  /// [keys] are the field names a request body supplied, which is the one place
  /// a name still arrives as a string: each is resolved against [model] before
  /// any policy sees it. A name that is not a field of [model] is left for
  /// validation to reject. A protected field is a 401 or 403; a read-only one
  /// is a 422 naming every offending field.
  void requireWrite(BeakModel model, Iterable<String> keys) {
    final readOnly = <String, List<String>>{};
    for (final key in keys) {
      enforcePolicyDecision(
        allowed: _inputPasses(model, key, _canWrite),
        principal: principal,
        action: 'write field "$key" of',
        model: model,
      );
      if (!_inputPasses(model, key, _isWritable)) {
        readOnly[key] = const ['This field is read-only.'];
      }
    }
    if (readOnly.isNotEmpty) {
      throw BeakValidationException(
        'Read-only fields cannot be written.',
        fieldErrors: readOnly,
      );
    }
  }

  /// Removes protected fields from a record and all included relationships.
  BeakRecord redact(BeakModel model, BeakRecord record) {
    if (!policy.canView(principal, model)) return const BeakRecord(values: {});
    return BeakRecord(
      values: {
        for (final entry in record.values.entries)
          if (_columnPasses(model, entry.key, _canRead)) entry.key: entry.value,
      },
      relations: {
        for (final entry in record.relations.entries)
          if (model.relationshipByKey(entry.key)
              case final BeakRelationship relation)
            if (canReadRelation(model, relation))
              entry.key: [
                for (final related in entry.value)
                  redact(_relatedModel(relation), related),
              ],
      },
    );
  }

  /// Whether the relation and its linking identity may be exposed.
  bool canReadRelation(BeakModel model, BeakRelationship relation) {
    final related = _relatedModel(relation);
    return _canRead(model, _relationField(model, relation)) &&
        policy.canView(principal, related) &&
        switch (relation) {
          BeakBelongsTo(:final foreignKey) => _columnPasses(
            model,
            foreignKey,
            _canRead,
          ),
          BeakHasMany(:final foreignKey) || BeakHasOne(:final foreignKey) =>
            _columnPasses(related, foreignKey, _canRead),
          _ => true,
        };
  }

  /// Rejects traversals that expose either side of a protected link.
  void requireReadRelation(BeakModel model, BeakRelationship relation) =>
      enforcePolicyDecision(
        allowed: canReadRelation(model, relation),
        principal: principal,
        action: 'read relationship "${relation.key}" of',
        model: model,
      );

  /// The id handed to [BeakPolicy.canDelete] when a capability is asked for a
  /// model and not for a record: the key no stored record has (zero, or the
  /// empty string), so a policy that decides per record says no, and a role
  /// rule, which ignores the id, answers for the model.
  Object _absentRecordId(BeakModel model) =>
      model.primaryKey is BeakIntColumn ? 0 : '';

  /// Resolves the field allowlists for forms under resource-level permissions.
  BeakAccessCapabilities capabilities(BeakModel model, {Object? id}) {
    final readable = policy.canView(principal, model);
    final writable = id == null
        ? policy.canCreate(principal, model)
        : policy.canUpdate(principal, model, id);
    bool suppliable(String key) =>
        _inputPasses(model, key, _canWrite) &&
        _inputPasses(model, key, _isWritable);
    return BeakAccessCapabilities(
      canCreate: policy.canCreate(principal, model),
      canDelete: policy.canDelete(
        principal,
        model,
        id ?? _absentRecordId(model),
      ),
      executableActions: {
        for (final action in model.behavior.actions)
          if (writable &&
              (id != null || action.allowOnCreate) &&
              switch (policy) {
                final BeakActionPolicy actions => actions.canExecuteAction(
                  principal,
                  model,
                  id,
                  action,
                ),
                _ => true,
              })
            action.name,
      },
      readableFields: {
        for (final column in model.columns)
          if (readable && canReadColumn(model, column)) column.key,
        for (final relation in model.relationships)
          if (readable && canReadRelation(model, relation)) relation.key,
      },
      writableFields: {
        for (final column in model.columns)
          if (writable && suppliable(column.key)) column.key,
        for (final relation in model.relationships)
          if (writable && suppliable(relation.key)) relation.key,
      },
    );
  }

  bool _canRead(BeakModel model, BeakFieldRef<Object> field) =>
      switch (policy) {
        final BeakFieldPolicy fields => fields.canReadField(
          principal,
          model,
          field,
        ),
        _ => true,
      };

  bool _canWrite(BeakModel model, BeakFieldRef<Object> field) =>
      switch (policy) {
        final BeakFieldPolicy fields => fields.canWriteField(
          principal,
          model,
          field,
        ),
        _ => true,
      };

  bool _isWritable(BeakModel model, BeakFieldRef<Object> field) =>
      switch (policy) {
        final BeakReadOnlyFieldPolicy fields => !fields.isFieldReadOnly(
          principal,
          model,
          field,
        ),
        _ => true,
      };

  BeakModel _relatedModel(BeakRelationship relation) =>
      registry.byTableOrThrow(relation.relatedTable);

  BeakFieldRef<Object> _relationField(
    BeakModel model,
    BeakRelationship relation,
  ) {
    final target = _relatedModel(relation);
    return switch (relation.cardinality) {
      BeakRelationCardinality.one => BeakToOneField(
        model: model,
        relation: relation,
        target: target,
      ),
      BeakRelationCardinality.many => BeakToManyField(
        model: model,
        relation: relation,
        target: target,
      ),
    };
  }

  // Whether the column stored under [key] passes [test]. A key that is not a
  // column of the model is no field, so no policy has a say in it.
  bool _columnPasses(BeakModel model, String key, _FieldTest test) =>
      switch (model.columnByKey(key)) {
        final BeakColumn column => test(
          model,
          BeakScalarField<Object>(model: model, column: column),
        ),
        null => true,
      };

  // Whether a request-body [key] passes [test] on every field it stands for: a
  // relationship alias also writes its foreign key, and a foreign key also
  // writes its alias.
  bool _inputPasses(BeakModel model, String key, _FieldTest test) {
    final relation = model.relationshipByKey(key);
    if (relation != null) return _relationPasses(model, relation, test);
    return _columnInputPasses(model, key, test);
  }

  bool _columnInputPasses(BeakModel model, String key, _FieldTest test) =>
      _columnPasses(model, key, test) &&
      model.relationships.whereType<BeakBelongsTo>().every(
        (relation) =>
            relation.foreignKey != key ||
            test(model, _relationField(model, relation)),
      );

  bool _relationPasses(
    BeakModel model,
    BeakRelationship relation,
    _FieldTest test,
  ) =>
      test(model, _relationField(model, relation)) &&
      switch (relation) {
        BeakBelongsTo(:final foreignKey) => _columnPasses(
          model,
          foreignKey,
          test,
        ),
        BeakHasMany(:final foreignKey) || BeakHasOne(:final foreignKey) =>
          _columnInputPasses(_relatedModel(relation), foreignKey, test),
        _ => true,
      };
}
