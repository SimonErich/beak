import 'package:beak/migrations.dart';

/// The part of the host system Beak does not own.
///
/// The `accounts` table belongs to the product that existed before Beak did:
/// its schema is created here, the way that system would create it. Beak's
/// `@Resource(managesSchema: false)` on [LegacyAccount] says so, which is why
/// `beak prepare` generated no migration for it.
abstract final class LegacySystem {
  /// Creates the legacy tables if they are not there yet.
  ///
  /// Stands in for whatever the other system runs at deploy time.
  static Future<void> ensureSchema(DatabaseAdapter adapter) async {
    await adapter.rawQuery('''
CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  plan_code TEXT NOT NULL
)''', const <Object?>[]);
  }

  /// Inserts a couple of accounts, so the panel has something to show.
  static Future<void> seed(DatabaseAdapter adapter) async {
    for (final (id, name, email, plan) in const [
      ('acc-1', 'Northwind', 'ops@northwind.test', 'growth'),
      ('acc-2', 'Initech', 'billing@initech.test', 'starter'),
    ]) {
      await adapter.rawQuery(
        'INSERT OR IGNORE INTO accounts (id, name, email, plan_code) '
        'VALUES (?, ?, ?, ?)',
        [id, name, email, plan],
      );
    }
  }
}
