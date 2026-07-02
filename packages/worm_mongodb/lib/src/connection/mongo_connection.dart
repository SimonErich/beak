/// Thin lifecycle wrapper around a `mongo_dart` connection.
library;

import 'package:mongo_dart/mongo_dart.dart';

/// Owns a single `mongo_dart` [Db] instance and tracks whether it
/// is open.
///
/// The adapter never talks to `mongo_dart` directly — every read
/// and write goes through this connection so lifecycle, retries,
/// and session management have one place to live.
final class MongoConnection {
  /// Creates a connection bound to [uri] (a standard
  /// `mongodb://user:pass@host:port/db` connection string).
  MongoConnection({required String uri}) : _db = Db(uri);

  /// Constructs a connection from a connection-string URI.
  factory MongoConnection.fromUri(String uri) => MongoConnection(uri: uri);

  /// Adopts a pre-constructed [Db] — used by tests that want to
  /// hand in a configured driver.
  MongoConnection.fromDb(this._db);

  final Db _db;
  bool _open = false;

  /// The underlying driver handle. Exposed read-only so the
  /// adapter and integration tests can call driver methods that
  /// don't yet have a wrapper.
  Db get db => _db;

  /// Whether [open] has been called and [close] has not.
  bool get isOpen => _open;

  /// Opens the connection if it is not already open. Safe to call
  /// multiple times.
  Future<void> open() async {
    if (_open) return;
    await _db.open();
    _open = true;
  }

  /// Closes the underlying [Db] and marks the connection closed.
  /// Safe to call multiple times.
  Future<void> close() async {
    if (!_open) return;
    await _db.close();
    _open = false;
  }
}
