import 'dart:async';

import 'package:serverpod/serverpod.dart' show Session, Transaction;
import 'package:worm/worm.dart' show DatabaseAdapter;

import 'serverpod_session_adapter.dart';

/// The seam between a Serverpod request and Beak's data layer.
///
/// Beak's pipeline is Serverpod-agnostic: a Shelf handler over a
/// `WormDataSource` over a worm adapter. The one thing it cannot carry is
/// the request's [Session], so the engine puts it in the zone and
/// [ServerpodSessionAdapter] reads it from there, once per statement.
///
/// ```dart
/// Future<String> dispatch(Session session, String request) =>
///     BeakServerpod.runInSession(session, () => engine.handle(request));
/// ```
///
/// Inside a Beak transaction, [sessionOf] and [transactionOf] hand typed
/// Serverpod ORM calls the same session and transaction, so both sides
/// commit or roll back together:
///
/// ```dart
/// await adapter.transaction((tx) async {
///   await sp.Book.db.updateRow(
///     BeakServerpod.sessionOf(tx),
///     book,
///     transaction: BeakServerpod.transactionOf(tx),
///   );
/// });
/// ```
abstract final class BeakServerpod {
  /// Private and unforgeable: no other code can plant a session under it.
  static final Object _sessionKey = Object();

  /// Runs [body] with [session] as the zone's Serverpod session.
  ///
  /// Every future, timer, microtask and stream callback created inside
  /// [body] inherits the zone, so an adapter call made anywhere below it
  /// resolves to [session].
  static R runInSession<R>(Session session, R Function() body) =>
      runZoned(body, zoneValues: {_sessionKey: session});

  /// The zone's session, or `null` outside [runInSession].
  static Session? get currentSessionOrNull =>
      switch (Zone.current[_sessionKey]) {
        final Session session => session,
        _ => null,
      };

  /// The zone's session.
  ///
  /// Throws a [StateError] outside [runInSession]: silently falling back to
  /// some other session would run Beak's statements outside the request's
  /// transaction and authentication.
  static Session get currentSession =>
      currentSessionOrNull ??
      (throw StateError(
        'No Serverpod Session in this zone. Beak database calls must run '
        'inside BeakServerpod.runInSession(session, ...).',
      ));

  /// The session a Beak adapter runs on, for typed Serverpod ORM calls.
  ///
  /// Throws an [ArgumentError] when [adapter] is not a
  /// [ServerpodSessionAdapter].
  static Session sessionOf(DatabaseAdapter adapter) => switch (adapter) {
    final ServerpodSessionAdapter serverpod => serverpod.session,
    _ => throw ArgumentError.value(
      adapter,
      'adapter',
      'is not a ServerpodSessionAdapter',
    ),
  };

  /// The Serverpod transaction a Beak transaction adapter is bound to.
  ///
  /// Pass it as `transaction:` to every typed ORM call made inside a Beak
  /// transaction; without it the call runs on another pooled connection and
  /// neither sees nor joins Beak's uncommitted writes. Throws an
  /// [ArgumentError] when [adapter] is not inside a transaction.
  static Transaction transactionOf(DatabaseAdapter adapter) =>
      switch (adapter) {
        ServerpodSessionAdapter(:final Transaction serverpodTransaction) =>
          serverpodTransaction,
        _ => throw ArgumentError.value(
          adapter,
          'adapter',
          'is not a ServerpodSessionAdapter inside a transaction',
        ),
      };
}
