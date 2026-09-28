import 'package:beak_core/beak_core.dart';

import 'beak_resource_repository.dart';

/// The to-one relationships of [model]: the ones whose foreign key lives on
/// this table and points at exactly one record.
///
/// These are the relationships a row can render inline, because each row has
/// at most one related record to show.
List<BeakRelationship> beakToOneRelationsOf(BeakModel model) =>
    <BeakRelationship>[
      for (final relation in model.relationships)
        if (relation is BeakBelongsTo || relation is BeakHasOne) relation,
    ];

/// Returns [spec] eager-loading every to-one relationship of [model] it does
/// not already load.
///
/// Without them a foreign key renders as the uuid it stores — the panel showed
/// `a3f9c1e2-…` where the reader expected `Beverages`. Loading them with the
/// page costs one query rather than one per row, which is the whole reason
/// this is a list rather than a lookup.
///
/// A load the caller supplied wins: it may carry a constraint this cannot
/// know about.
BeakQuerySpec beakWithToOneLoads(BeakQuerySpec spec, BeakModel model) {
  final loaded = <String>{
    for (final load in spec.relationLoads) load.relationKey,
  };
  var result = spec;
  for (final relation in beakToOneRelationsOf(model)) {
    if (loaded.add(relation.key)) {
      result = result.withRelation(relation);
    }
  }
  return result;
}

/// Loads the [id] record of [model] with [relations] eager-loaded, in one
/// request.
///
/// Without additional relation requests, use [BeakDataSource.getOne]: a
/// transport can support record lookup without allowing primary-key filters
/// on its list queries. Any relations already included in that record survive.
/// When relations are requested, load them with the record in a single query;
/// the caller reads each relation off [BeakRecord.relations].
///
/// A missing record is a [BeakErr] holding a [BeakNotFoundException], the
/// same outcome `getOne` produces.
Future<BeakResult<BeakRecord>> beakLoadRecordWithRelations(
  BeakResourceRepository repository, {
  required BeakModel model,
  required Object id,
  required List<BeakRelationship> relations,
}) async {
  if (relations.isEmpty) {
    return repository.getOne(model.table, id);
  }
  var spec = BeakQuerySpec(table: model.table).withFilter(
    BeakFieldFilter.forKey(
      model.primaryKey.key,
      BeakOperator.eq,
      BeakValue.of(id),
    ),
  );
  for (final relation in relations) {
    spec = spec.withRelation(relation);
  }
  final BeakResult<BeakPage<BeakRecord>> result = await repository.query(spec);
  return switch (result) {
    BeakOk(:final value) when value.items.isNotEmpty => BeakOk(
      value.items.first,
    ),
    BeakOk() => BeakErr(
      BeakNotFoundException('No record of "${model.table}" with id "$id".'),
    ),
    BeakErr(:final error) => BeakErr(error),
  };
}

/// Eager-loads paths and relationship dependencies used by typed bindings.
/// Explicit constraints are retained when several fields share a relation.
BeakQuerySpec beakWithFieldLoads(
  BeakQuerySpec spec,
  Iterable<BeakFieldRef<Object>> fields,
) {
  List<BeakRelationLoad> insert(
    List<BeakRelationLoad> loads,
    List<BeakRelationship> path,
  ) {
    if (path.isEmpty) return loads;
    final head = path.first;
    final existing = loads
        .where((load) => load.relationKey == head.key)
        .firstOrNull;
    final next = BeakRelationLoad(
      head.key,
      filter: existing?.filter,
      nested: insert(existing?.nested ?? const [], path.sublist(1)),
    );
    return [...loads.where((load) => load.relationKey != head.key), next];
  }

  var loads = spec.relationLoads;
  for (final field in fields) {
    if (field.model.table != spec.table) {
      throw BeakConfigurationException(
        'Field "${field.qualifiedKey}" belongs to "${field.model.table}", not "${spec.table}".',
      );
    }
    loads = insert(loads, [
      ...field.path,
      if (field is BeakToOneField) field.relation,
      if (field is BeakToManyField) field.relation,
    ]);
  }
  return BeakQuerySpec(
    table: spec.table,
    filter: spec.filter,
    sorts: spec.sorts,
    search: spec.search,
    relationLoads: loads,
    pagination: spec.pagination,
    withTrashed: spec.withTrashed,
  );
}
