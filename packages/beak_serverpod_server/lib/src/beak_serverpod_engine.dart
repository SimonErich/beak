import 'dart:async';
import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/wire.dart';
import 'package:serverpod/serverpod.dart'
    show AuthenticationInfo, LogLevel, Session;
import 'package:shelf/shelf.dart' as shelf;
import 'package:worm/worm.dart' show DatabaseAdapter;

import 'beak_admin_gate.dart';
import 'beak_serverpod.dart';
import 'beak_serverpod_framework_tables.dart';
import 'beak_tunnel_path.dart';
import 'serverpod_session_adapter.dart';

/// Turns the signed-in Serverpod user into the principal Beak's policies
/// decide on, or `null` to refuse the request (403).
///
/// It only runs for a user who holds [BeakScopes.admin].
///
/// Throw a [BeakAuthenticationException] or [BeakAuthorizationException] to
/// refuse with 401 or 403 and a message.
typedef BeakServerpodPrincipalResolver =
    FutureOr<BeakPrincipal?> Function(Session session, AuthenticationInfo auth);

/// Stock principal resolvers.
abstract final class BeakServerpodPrincipal {
  /// The user's id, with every scope name as a role.
  static BeakPrincipal fromScopes(Session session, AuthenticationInfo auth) =>
      BeakPrincipal(
        id: auth.userIdentifier,
        roles: {
          for (final scope in auth.scopes)
            if (scope.name case final String name) name,
        },
      );
}

/// Beak's stock Shelf pipeline, run in memory inside a Serverpod request.
///
/// One app-owned endpoint method feeds it envelopes:
///
/// ```dart
/// final bookshopBeak = BeakServerpodEngine(
///   registry: bookshopRegistry,
///   policy: bookshopPolicy,
///   graphOnly: [const OrderModel()],
///   preparePlan: const BookshopOrderRules().prepare,
/// );
///
/// class BeakAdminEndpoint extends Endpoint with BeakAdminGate {
///   Future<String> dispatch(Session session, String request) =>
///       bookshopBeak.dispatch(session, request);
/// }
/// ```
///
/// Per request, [dispatch]:
///
/// 1. decodes envelope v1 and refuses any path outside `/api/**` (see
///    [beakTunnelUrl]) with 404;
/// 2. drops every header but [beakWireRequestHeaders];
/// 3. refuses a session that is not signed in (401) or does not hold
///    [BeakScopes.admin] (403), even when the endpoint forgot
///    [BeakAdminGate], then resolves the principal from
///    `session.authenticated` alone and hands it to Beak's auth middleware
///    through a context value only this library can create, so no header
///    can forge an identity;
/// 4. runs the pipeline inside [BeakServerpod.runInSession], so every
///    statement Beak issues uses the request's Serverpod session, pool and
///    (in a graph commit) one Serverpod transaction;
/// 5. logs `beak <method> <path> -> <status>` and unexpected errors to
///    `session.log`.
final class BeakServerpodEngine {
  /// Builds the pipeline once; [policy] is required on purpose, there is no
  /// allow-all default.
  ///
  /// [graphOnly] models accept writes only through `POST /api/commits`
  /// (their [preparePlan] owns the invariants). [frameworkTables] maps the
  /// graph-commit receipts onto the tool-owned Serverpod model
  /// ([beakServerpodFrameworkTables]). [now] is the clock behind every write.
  ///
  /// [adapter] is the worm adapter Beak runs on. It defaults to a
  /// [ServerpodSessionAdapter] that takes the request's session from the
  /// zone. Pass a decorator over one to audit or record statements; typed ORM
  /// hooks (`sessionOf`/`transactionOf`) need the undecorated adapter.
  BeakServerpodEngine({
    required this.registry,
    required BeakPolicy policy,
    this.principal = BeakServerpodPrincipal.fromScopes,
    BeakSavePlanPreparer? preparePlan,
    BeakSavePlanFinalizer? finalizePlan,
    List<BeakModel> graphOnly = const [],
    int statementTimeoutInSeconds = 30,
    this.frameworkTables = beakServerpodFrameworkTables,
    DateTime Function()? now,
    DatabaseAdapter? adapter,
  }) : _handler = _pipeline(
         registry: registry,
         policy: policy,
         preparePlan: preparePlan,
         finalizePlan: finalizePlan,
         graphOnly: graphOnly,
         frameworkTables: frameworkTables,
         now: now,
         adapter:
             adapter ??
             ServerpodSessionAdapter(
               statementTimeoutInSeconds: statementTimeoutInSeconds,
             ),
       );

  /// The models this engine serves.
  final BeakModelRegistry registry;

  /// Maps the signed-in Serverpod user to a Beak principal.
  final BeakServerpodPrincipalResolver principal;

  /// Where the graph-commit receipts live.
  final BeakFrameworkTables frameworkTables;

  final shelf.Handler _handler;

  static shelf.Handler _pipeline({
    required BeakModelRegistry registry,
    required BeakPolicy policy,
    required BeakSavePlanPreparer? preparePlan,
    required BeakSavePlanFinalizer? finalizePlan,
    required List<BeakModel> graphOnly,
    required BeakFrameworkTables frameworkTables,
    required DateTime Function()? now,
    required DatabaseAdapter adapter,
  }) => const shelf.Pipeline()
      .addMiddleware(beakRequestLogMiddleware(onRequest: _logRequest))
      .addMiddleware(beakJsonMiddleware())
      .addMiddleware(beakErrorMappingMiddleware(onUnexpectedError: _logError))
      .addMiddleware(beakAuthMiddleware(guard: const _TrustedGuard()))
      .addHandler(
        beakApiRouter(
          registry: registry,
          dataSource: WormDataSource(registry, adapter: adapter, now: now),
          policy: policy,
          preparePlan: preparePlan,
          finalizePlan: finalizePlan,
          graphOnly: graphOnly,
          commitReceipts: frameworkTables.receipts,
          now: now,
          onUnexpectedError: _logError,
        ),
      );

  /// Runs one envelope-v1 request on [session] and returns the response
  /// envelope.
  // --8<-- [start:dispatch]
  Future<String> dispatch(Session session, String request) =>
      BeakServerpod.runInSession(
        session,
        () async => (await _handle(session, request)).encode(),
      );
  // --8<-- [end:dispatch]

  Future<BeakWireResponse> _handle(Session session, String envelope) async {
    final BeakWireRequest wire;
    try {
      wire = BeakWireRequest.decode(envelope);
    } on BeakValidationException catch (error) {
      return _error(400, error);
    }
    final Uri? url = beakTunnelUrl(wire.path, wire.query);
    if (url == null) {
      return _error(
        404,
        BeakNotFoundException('No handler for ${wire.method} ${wire.path}.'),
      );
    }
    final AuthenticationInfo? auth = session.authenticated;
    if (auth == null) {
      // The endpoint gate normally answers first; this is the fallback when
      // the engine is mounted behind an ungated endpoint.
      return _error(
        401,
        const BeakAuthenticationException('Sign in to use the Beak admin.'),
      );
    }
    if (!auth.scopes.contains(BeakScopes.admin)) {
      // The endpoint gate already refuses this; the engine repeats it so an
      // endpoint that forgot BeakAdminGate cannot open the tunnel to every
      // signed-in user whose roles a policy rule happens to accept.
      return _error(403, const BeakAuthorizationException(_notAllowed));
    }
    final BeakPrincipal? resolved;
    try {
      resolved = await principal(session, auth);
    } on BeakAuthenticationException catch (error) {
      return _error(401, error);
    } on BeakAuthorizationException catch (error) {
      return _error(403, error);
    }
    if (resolved == null) {
      return _error(403, const BeakAuthorizationException(_notAllowed));
    }
    final shelf.Response response = await _handler(
      shelf.Request(
        wire.method,
        url,
        headers: {
          for (final MapEntry(:key, :value) in wire.headers.entries)
            key == 'x-beak-request-id' ? 'x-request-id' : key: value,
        },
        body: wire.body,
        context: {_trustedPrincipalKey: _TrustedPrincipal(resolved)},
      ),
    );
    return BeakWireResponse(
      status: response.statusCode,
      headers: {
        for (final MapEntry(:key, :value) in response.headers.entries)
          if (!_hopByHop.contains(key.toLowerCase())) key: value,
      },
      body: await response.readAsString(),
    );
  }

  static const String _notAllowed = 'Not allowed to use the Beak admin.';

  static const Set<String> _hopByHop = {
    'content-length',
    'transfer-encoding',
    'connection',
  };

  static BeakWireResponse _error(int status, BeakException error) =>
      BeakWireResponse(
        status: status,
        headers: const {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode({'code': error.code, 'message': error.message}),
      );

  static void _logRequest(BeakRequestLogEntry entry) =>
      BeakServerpod.currentSessionOrNull?.log(
        'beak ${entry.method} /${entry.path} -> ${entry.statusCode} '
        '(${entry.duration.inMilliseconds} ms) [${entry.requestId}]',
        level: entry.statusCode >= 500 ? LogLevel.error : LogLevel.info,
      );

  static void _logError(Object error, StackTrace stackTrace) =>
      BeakServerpod.currentSessionOrNull?.log(
        'beak: unexpected error',
        level: LogLevel.error,
        exception: error,
        stackTrace: stackTrace,
      );
}

const String _trustedPrincipalKey = 'beak.serverpod.principal';

/// Only this library can construct one, so a context entry of this type
/// always comes from [BeakServerpodEngine.dispatch].
final class _TrustedPrincipal {
  const _TrustedPrincipal(this.principal);

  final BeakPrincipal principal;
}

/// Reads the principal [BeakServerpodEngine] resolved from the Serverpod
/// session. Headers are never consulted.
// --8<-- [start:TrustedGuard]
final class _TrustedGuard implements BeakAuthGuard {
  const _TrustedGuard();

  @override
  Future<BeakPrincipal?> authenticate(shelf.Request request) async =>
      switch (request.context[_trustedPrincipalKey]) {
        _TrustedPrincipal(:final principal) => principal,
        _ => null,
      };
}
// --8<-- [end:TrustedGuard]
