import 'package:beak_core/beak_core.dart';

/// Builds the source under test, freshly, for each contract test.
typedef BeakDataSourceBuilder = Future<BeakDataSource> Function();

/// Seeds [records] into [model]'s table on the source under test.
///
/// A contract cannot assume how a source is populated — the in-memory one has
/// `seed`, a worm-backed one needs SQL, a Serverpod one needs a session — so
/// the caller supplies it.
typedef BeakDataSourceSeeder =
    Future<void> Function(
      BeakDataSource source,
      BeakModel model,
      List<BeakRecord> records,
    );

/// Links [relatedIds] to [ownerId] across [relation] on the source under
/// test, the way the store holds a link and without calling
/// [BeakDataSource.attach].
///
/// The counterpart of [BeakDataSourceSeeder] for a many-to-many relation,
/// whose links live in a pivot table no model describes. The in-memory source
/// has `seedPivot`; a SQL one inserts pivot rows.
typedef BeakDataSourceLinkSeeder =
    Future<void> Function(
      BeakDataSource source,
      BeakBelongsToMany relation,
      Object ownerId,
      List<Object> relatedIds,
    );
