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
/// query.
///
/// [BeakDataSource.getOne] cannot carry eager loads, so a detail page built
/// on it paid one round trip for the record and one more per relation panel.
/// This asks for all of it at once; the caller reads each relation off
/// [BeakRecord.relations].
///
/// A missing record is a [BeakErr] holding a [BeakNotFoundException], the
/// same outcome `getOne` produces.
Future<BeakResult<BeakRecord>> beakLoadRecordWithRelations(
  BeakResourceRepository repository, {
  required BeakModel model,
  required Object id,
  required List<BeakRelationship> relations,
}) async {
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
