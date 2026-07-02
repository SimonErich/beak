/// Base class for database seeders.
library;

import '../adapter/database_adapter.dart';
import 'environment.dart';

/// Base class every user-authored seeder extends.
///
/// A seeder declares the [Environment] it targets and implements
/// [run]. `SeederRunner` skips seeders whose [environment] does not
/// match the runtime environment (matching is exact, or `all`).
///
/// Override [order] to control execution order — `SeederRunner`
/// sorts the registered seeders by ascending [order] before
/// running them. The default `0` preserves registration order
/// for equal values (stable sort).
abstract base class Seeder {
  /// Const constructor for subclasses.
  const Seeder();

  /// Identifier used by `db:seed`. Defaults to the type name.
  String get name;

  /// Environment(s) this seeder is allowed to run in.
  Environment get environment => Environment.all;

  /// Explicit execution order. Lower runs first; ties preserve
  /// registration order via the runner's stable sort.
  int get order => 0;

  /// When `true`, the runner executes [run] with model lifecycle
  /// events muted (via `Worm.withoutEvents`) so bulk inserts skip
  /// observer/hook overhead. Defaults to `false`.
  bool get muteEvents => false;

  /// Seed work.
  Future<void> run(DatabaseAdapter adapter);
}
