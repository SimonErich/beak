import 'package:beak_core/beak_core.dart';

import 'beak_revision_timestamp.dart';

/// Brings back the soft-deleted row that creating [prepared] would duplicate.
///
/// The key is [BeakAdmission.restoreKey] of [model]: when a row with the same
/// values for every key column was soft-deleted, that row is restored and
/// takes the new values, so it keeps its identity and its creation time and
/// the unique index over the key never sees a second row. Re-adding a removed
/// translation is the typical case.
///
/// Returns `null` when [model] has no restore key, does not soft-delete, the
/// key has no value (a partial key identifies nothing), or no deleted row
/// matches: the caller then inserts as usual. [now] stamps the revision.
///
/// A live row with the same key is a duplicate and fails with a field error on
/// the last key column. Throws a [BeakValidationException] for it.
Future<BeakRecord?> beakRestoreSoftDeleted(
  BeakModel model,
  BeakDataSource data,
  BeakRecord prepared, {
  required DateTime Function() now,
}) async {
  final key = model.admission?.restoreKey ?? const <BeakColumn>[];
  if (key.isEmpty || !model.softDeletes) return null;
  final filters = <BeakFilter>[];
  for (final column in key) {
    final value = prepared[column.key];
    if (value == null || value.raw == null) return null;
    filters.add(BeakFieldFilter.forKey(column.key, BeakOperator.eq, value));
  }
  BeakQuerySpec lookup({required bool withTrashed}) => model.query(
    filter: BeakAndFilter(filters),
    withTrashed: withTrashed,
    pagination: const BeakPagination(perPage: 1),
  );
  if ((await data.query(lookup(withTrashed: false))).items.isNotEmpty) {
    throw BeakValidationException(
      'A "${model.table}" record with this ${_names(key)} already exists.',
      fieldErrors: {
        key.last.key: ['This ${key.last.label} is already in use.'],
      },
    );
  }
  final trashed = (await data.query(
    lookup(withTrashed: true),
  )).items.firstOrNull;
  final id = trashed == null ? null : model.primaryKeyOf(trashed);
  if (trashed == null || id == null) return null;
  await data.restore(model.table, id);
  final previous = switch (trashed[model.updatedAtColumnKey]) {
    BeakDateTimeValue(:final value) => value,
    _ => null,
  };
  final unchanged = {
    model.primaryKey.key,
    model.createdAtColumnKey,
    model.deletedAtColumnKey,
    ?model.isDeletedColumnKey,
  };
  return data.update(
    model.table,
    id,
    BeakRecord(
      values: {
        for (final entry in prepared.values.entries)
          if (!unchanged.contains(entry.key)) entry.key: entry.value,
        if (model.columnByKey(model.updatedAtColumnKey) is BeakDateTimeColumn)
          model.updatedAtColumnKey: BeakDateTimeValue(
            beakRevisionTimestamp(now(), previous: previous),
          ),
      },
    ),
  );
}

String _names(List<BeakColumn> key) => [
  for (final column in key) column.label.toLowerCase(),
].join(' and ');
