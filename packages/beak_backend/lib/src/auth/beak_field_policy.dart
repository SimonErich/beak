import 'package:beak_core/beak_core.dart';

import 'beak_auth_guard.dart';
import 'beak_action_policy.dart';
import 'beak_policy.dart';

/// Adds principal-scoped field access to resource and row policies.
///
/// Read access also gates search, sorting, filters and aggregates, preventing
/// inference through query results. Row-specific access belongs in row scopes.
abstract interface class BeakFieldPolicy implements BeakPolicy {
  /// Whether a field can appear in responses or user-controlled queries.
  bool canReadField(BeakPrincipal? principal, String table, String key);

  /// Whether a field can be supplied by the caller on create or update.
  bool canWriteField(BeakPrincipal? principal, String table, String key);
}

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

  /// Whether [key] may be returned or used in a user-controlled query.
  bool canRead(String table, String key) => switch (policy) {
    final BeakFieldPolicy fields => fields.canReadField(principal, table, key),
    _ => true,
  };

  /// Whether [key] may be supplied in a caller's mutation.
  bool canWrite(String table, String key) => switch (policy) {
    final BeakFieldPolicy fields => fields.canWriteField(principal, table, key),
    _ => true,
  };

  /// Rejects queries that could reveal a protected field indirectly.
  void requireRead(String table, String key) => enforcePolicyDecision(
    allowed: canRead(table, key),
    principal: principal,
    action: 'read field "$key" of',
    table: table,
  );

  /// Rejects protected input fields before validation or persistence.
  void requireWrite(String table, Iterable<String> keys) {
    final model = registry.byTableOrThrow(table);
    for (final key in keys) {
      enforcePolicyDecision(
        allowed: _canWriteInput(model, key),
        principal: principal,
        action: 'write field "$key" of',
        table: table,
      );
    }
  }

  bool _canWriteInput(BeakModel model, String key) {
    final relation = model.relationshipByKey(key);
    if (relation != null) return canWriteRelation(model, relation);
    return _canWriteColumn(model, key);
  }

  bool _canWriteColumn(BeakModel model, String key) =>
      canWrite(model.table, key) &&
      model.relationships.whereType<BeakBelongsTo>().every(
        (relation) =>
            relation.foreignKey != key || canWrite(model.table, relation.key),
      );

  /// Removes protected fields from a record and all included relationships.
  BeakRecord redact(String table, BeakRecord record) {
    if (!policy.canView(principal, table)) return const BeakRecord(values: {});
    final model = registry.byTableOrThrow(table);
    return BeakRecord(
      values: {
        for (final entry in record.values.entries)
          if (canRead(table, entry.key)) entry.key: entry.value,
      },
      relations: {
        for (final entry in record.relations.entries)
          if (model.relationshipByKey(entry.key)
              case final BeakRelationship relation)
            if (canReadRelation(model, relation))
              entry.key: [
                for (final related in entry.value)
                  redact(relation.relatedTable, related),
              ],
      },
    );
  }

  /// Whether the relation and its linking identity may be exposed.
  bool canReadRelation(BeakModel model, BeakRelationship relation) =>
      canRead(model.table, relation.key) &&
      policy.canView(principal, relation.relatedTable) &&
      switch (relation) {
        BeakBelongsTo(:final foreignKey) => canRead(model.table, foreignKey),
        BeakHasMany(:final foreignKey) || BeakHasOne(:final foreignKey) =>
          canRead(relation.relatedTable, foreignKey),
        _ => true,
      };

  /// Rejects traversals that expose either side of a protected link.
  void requireReadRelation(BeakModel model, BeakRelationship relation) =>
      enforcePolicyDecision(
        allowed: canReadRelation(model, relation),
        principal: principal,
        action: 'read relationship "${relation.key}" of',
        table: model.table,
      );

  /// Relationship writes also write their underlying foreign-key field.
  bool canWriteRelation(BeakModel model, BeakRelationship relation) =>
      canWrite(model.table, relation.key) &&
      switch (relation) {
        BeakBelongsTo(:final foreignKey) => canWrite(model.table, foreignKey),
        BeakHasMany(:final foreignKey) ||
        BeakHasOne(:final foreignKey) => _canWriteColumn(
          registry.byTableOrThrow(relation.relatedTable),
          foreignKey,
        ),
        _ => true,
      };

  /// Resolves the field allowlists for forms under resource-level permissions.
  BeakAccessCapabilities capabilities(String table, {Object? id}) {
    final model = registry.byTableOrThrow(table);
    final readable = policy.canView(principal, table);
    final writable = id == null
        ? policy.canCreate(principal, table)
        : policy.canUpdate(principal, table, id);
    return BeakAccessCapabilities(
      executableActions: {
        for (final action in model.behavior.actions)
          if (writable &&
              (id != null || action.allowOnCreate) &&
              switch (policy) {
                final BeakActionPolicy actions => actions.canExecuteAction(
                  principal,
                  table,
                  id,
                  action.name,
                ),
                _ => true,
              })
            action.name,
      },
      readableFields: {
        for (final column in model.columns)
          if (readable && canRead(table, column.key)) column.key,
        for (final relation in model.relationships)
          if (readable && canReadRelation(model, relation)) relation.key,
      },
      writableFields: {
        for (final column in model.columns)
          if (writable && _canWriteInput(model, column.key)) column.key,
        for (final relation in model.relationships)
          if (writable && canWriteRelation(model, relation)) relation.key,
      },
    );
  }
}
