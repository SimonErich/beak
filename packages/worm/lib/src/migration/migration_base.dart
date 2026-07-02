/// Base class for user-authored migrations.
library;

import '../adapter/database_adapter.dart';
import '../schema/schema_facade.dart';

/// Base class every migration extends.
///
/// A migration carries a stable [name] (file name without
/// extension) and implements either of two equivalent surfaces:
///
/// * [upSchema] / [downSchema] — the high-level [Schema] facade
///   with fluent `create` / `alter` / `drop` calls. Preferred
///   for new migrations.
/// * [up] / [down] — the low-level adapter API. Kept for
///   backward compatibility; default implementations throw so a
///   migration that overrides neither surface fails loudly.
///
/// `MigrationRunner` always invokes [upSchema] / [downSchema];
/// their default bodies forward to [up] / [down] so legacy
/// migrations continue to run unchanged.
abstract base class Migration {
  /// Const constructor for subclasses.
  const Migration();

  /// File-name identifier without extension
  /// (e.g. `20260101_000000_create_users_table`).
  String get name;

  /// Whether this migration drops or rewrites data. Runners use
  /// this to gate destructive runs behind the production
  /// `--force` flag.
  bool get isDestructive => false;

  /// Names of migrations that must run before this one.
  ///
  /// Override to make the runner topologically order this
  /// migration after its prerequisites, regardless of
  /// registration order. The default is empty — equivalent
  /// migrations preserve their registration order.
  List<String> get dependsOn => const <String>[];

  /// Apply schema changes through the raw [DatabaseAdapter].
  ///
  /// Default throws [UnimplementedError] — override either this
  /// or [upSchema]. The runner only calls this transitively
  /// (via the default [upSchema]) so migrations using the
  /// fluent facade never hit this body.
  Future<void> up(DatabaseAdapter adapter) async {
    throw UnimplementedError(
      'Migration "$name" must override either up(adapter) or '
      'upSchema(schema).',
    );
  }

  /// Revert schema changes applied by [up].
  ///
  /// Default throws [UnimplementedError] — see [up].
  Future<void> down(DatabaseAdapter adapter) async {
    throw UnimplementedError(
      'Migration "$name" must override either down(adapter) or '
      'downSchema(schema).',
    );
  }

  /// Apply schema changes through the fluent [Schema] facade.
  ///
  /// Default delegates to [up] so legacy migrations work
  /// unchanged. New migrations override this and call
  /// `schema.create(...)` / `schema.alter(...)` /
  /// `schema.drop(...)`.
  Future<void> upSchema(Schema schema) => up(schema.adapter);

  /// Revert schema changes through the fluent [Schema] facade.
  ///
  /// Default delegates to [down] so legacy migrations work
  /// unchanged.
  Future<void> downSchema(Schema schema) => down(schema.adapter);
}
