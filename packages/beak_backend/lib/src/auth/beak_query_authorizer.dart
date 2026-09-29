import 'package:beak_core/beak_core.dart';

import 'beak_auth_guard.dart';
import 'beak_field_policy.dart';
import 'beak_policy.dart';

/// Expands relationship paths while applying every traversed model's policy.
///
/// Related row scopes share the same existential predicate as the user's
/// condition. An allowed sibling can never authorize matching a hidden child.
final class BeakQueryAuthorizer {
  /// Creates a request-local policy boundary over known model metadata.
  const BeakQueryAuthorizer({
    required this.registry,
    required this.policy,
    required this.principal,
  });

  /// Registered models used to resolve paths.
  final BeakModelRegistry registry;

  /// Server-owned authorization policy.
  final BeakPolicy policy;

  /// Current authenticated identity.
  final BeakPrincipal? principal;

  BeakFieldAccess get _fields =>
      BeakFieldAccess(registry: registry, policy: policy, principal: principal);

  /// Authorizes filters, search paths, and every eager-loaded relationship.
  BeakQuerySpec authorizeQuery(BeakQuerySpec spec) {
    final model = _model(spec.table);
    for (final sort in spec.sorts) {
      _requireFieldPath(model, sort.columnKey);
    }
    final search = spec.search;
    final predicates = <BeakFilter>[
      if (spec.filter != null) _filter(model, spec.filter!, const {}, 0),
      if (scopeFor(model) case final BeakFilter scope) scope,
      if (beakSearchFilter(search, model, registry)
          case final BeakFilter searchFilter)
        _filter(model, searchFilter, const {}, 0),
    ];
    return BeakQuerySpec(
      table: spec.table,
      filter: BeakFilter.allOf(predicates),
      sorts: spec.sorts,
      relationLoads: [
        for (final load in spec.relationLoads) _load(model, load, 0),
      ],
      pagination: spec.pagination,
      withTrashed: spec.withTrashed,
    );
  }

  /// Applies identical authorization to aggregate predicates.
  BeakAggregateSpec authorizeAggregate(BeakAggregateSpec spec) {
    if (spec.columnKey case final String key) {
      _requireFieldPath(_model(spec.table), key);
    }
    final query = authorizeQuery(
      BeakQuerySpec(table: spec.table, filter: spec.filter),
    );
    return BeakAggregateSpec.forKey(
      table: spec.table,
      function: spec.function,
      columnKey: spec.columnKey,
      filter: query.filter,
      withTrashed: spec.withTrashed,
    );
  }

  /// Authorizes every grouping and measure field and the shared population.
  BeakSummarySpec authorizeSummary(BeakSummarySpec spec) {
    final model = _model(spec.table);
    if (spec.groupByKey case final key?) _requireFieldPath(model, key);
    for (final measure in spec.measures) {
      if (measure.columnKey case final key?) _requireFieldPath(model, key);
    }
    final query = authorizeQuery(
      BeakQuerySpec(
        table: spec.table,
        filter: spec.filter,
        search: spec.search,
        withTrashed: spec.withTrashed,
      ),
    );
    return BeakSummarySpec.forKeys(
      table: spec.table,
      groupByKey: spec.groupByKey,
      filter: query.filter,
      limit: spec.limit,
      withTrashed: spec.withTrashed,
      measures: [
        for (final measure in spec.measures)
          BeakSummaryMeasure.forKey(
            measure.key,
            columnKey: measure.columnKey,
            filter: measure.filter == null
                ? null
                : _filter(model, measure.filter!, const {}, 0),
          ),
      ],
    );
  }

  /// Expands a row policy for identity-based reads and writes.
  ///
  /// The caller checks the root operation permission; traversed relations
  /// still require view access.
  BeakFilter? scopeFor(BeakModel model) => _scope(model, const {}, 0);

  BeakModel _model(String table) {
    final model = registry.byTableOrThrow(table);
    enforcePolicyDecision(
      allowed: policy.canView(principal, model),
      principal: principal,
      action: 'view',
      model: model,
    );
    return model;
  }

  void _requireFieldPath(BeakModel model, String key) {
    final parts = key.split('.');
    var current = model;
    for (final part in parts.take(parts.length - 1)) {
      final relation = current.relationshipByKey(part);
      if (relation == null) {
        throw BeakValidationException('Unknown relationship "$part".');
      }
      _fields.requireReadRelation(current, relation);
      current = _model(relation.relatedTable);
    }
    final column = current.columnByKey(parts.last);
    if (column == null) {
      throw BeakValidationException('Unknown field "${parts.last}".');
    }
    _fields.requireReadColumn(current, column);
  }

  BeakFilter? _scope(BeakModel model, Set<String> activeScopes, int depth) {
    final scope = beakRowScope(policy, principal, model);
    if (scope == null) return null;
    if (activeScopes.contains(model.table)) {
      throw const BeakConfigurationException(
        'Cyclic relationship row policies.',
      );
    }
    return _filter(model, scope, {...activeScopes, model.table}, depth + 1);
  }

  BeakFilter _filter(
    BeakModel model,
    BeakFilter filter,
    Set<String> activeScopes,
    int depth,
  ) {
    if (depth > 64) {
      throw const BeakValidationException(
        'The relationship query is nested too deeply.',
      );
    }
    return switch (filter) {
      BeakAndFilter(:final filters) => BeakAndFilter([
        for (final child in filters)
          _filter(model, child, activeScopes, depth + 1),
      ]),
      BeakOrFilter(:final filters) => BeakOrFilter([
        for (final child in filters)
          _filter(model, child, activeScopes, depth + 1),
      ]),
      BeakRelationFilter(:final relationKey, :final filter) => _relation(
        model,
        relationKey.split('.'),
        filter,
        activeScopes,
        depth + 1,
      ),
      BeakFieldFilter(:final columnKey, :final operator, :final value) => () {
        final parts = columnKey.split('.');
        if (parts.length > 1) {
          return _relation(
            model,
            parts.take(parts.length - 1).toList(),
            BeakFieldFilter.forKey(parts.last, operator, value),
            activeScopes,
            depth + 1,
          );
        }
        final column = model.columnByKey(columnKey);
        if (column == null) {
          throw BeakValidationException(
            'Unknown field "$columnKey" on "${model.table}".',
          );
        }
        if (activeScopes.isEmpty) _fields.requireReadColumn(model, column);
        return filter;
      }(),
    };
  }

  BeakFilter _relation(
    BeakModel model,
    List<String> path,
    BeakFilter predicate,
    Set<String> activeScopes,
    int depth,
  ) {
    if (depth > 64 || path.isEmpty) {
      throw const BeakValidationException('Invalid relationship path.');
    }
    final relation = model.relationshipByKey(path.first);
    if (relation == null) {
      throw BeakValidationException('Unknown relationship "${path.first}".');
    }
    final target = _model(relation.relatedTable);
    if (activeScopes.isEmpty) {
      _fields.requireReadRelation(model, relation);
    }
    final inner = path.length == 1
        ? _filter(target, predicate, activeScopes, depth + 1)
        : _relation(
            target,
            path.skip(1).toList(),
            predicate,
            activeScopes,
            depth + 1,
          );
    return BeakRelationFilter(
      relation.key,
      BeakFilter.allOf([
        inner,
        if (_scope(target, activeScopes, depth + 1) case final BeakFilter scope)
          scope,
      ])!,
    );
  }

  BeakRelationLoad _load(BeakModel model, BeakRelationLoad load, int depth) {
    if (depth > 64) {
      throw const BeakValidationException(
        'The eager load is nested too deeply.',
      );
    }
    final path = load.relationKey.split('.');
    final relation = model.relationshipByKey(path.first);
    if (relation == null) {
      throw BeakValidationException('Unknown relationship "${path.first}".');
    }
    final target = _model(relation.relatedTable);
    _fields.requireReadRelation(model, relation);
    if (path.length > 1) {
      return BeakRelationLoad(
        relation.key,
        filter: _scope(target, const {}, depth + 1),
        nested: [
          _load(
            target,
            BeakRelationLoad(
              path.skip(1).join('.'),
              filter: load.filter,
              nested: load.nested,
            ),
            depth + 1,
          ),
        ],
      );
    }
    return BeakRelationLoad(
      relation.key,
      filter: BeakFilter.allOf([
        if (load.filter != null)
          _filter(target, load.filter!, const {}, depth + 1),
        if (_scope(target, const {}, depth + 1) case final BeakFilter scope)
          scope,
      ]),
      nested: [
        for (final nested in load.nested) _load(target, nested, depth + 1),
      ],
    );
  }
}
