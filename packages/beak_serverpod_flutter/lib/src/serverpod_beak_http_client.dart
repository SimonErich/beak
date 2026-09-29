import 'package:beak_serverpod/wire.dart';
import 'package:serverpod_client/serverpod_client.dart';

/// Classifies Serverpod 4's sealed client exceptions for the tunnel.
///
/// - `ServerpodClientUnauthorized` (401) and `ServerpodClientForbidden` (403)
///   come from the endpoint gate (`requireLogin`, the `beak.admin` scope) and
///   reach the panel as its usual sign-in / access-denied errors.
/// - Every other `ServerpodClientHttpException` keeps its status, notably
///   413 when a body exceeds the server's `maxRequestSize`.
/// - `ServerpodClientNetworkException` (offline, reset, and the client's
///   `connectionTimeout`) becomes an `http.ClientException`, as a socket
///   failure would.
/// - `ServerpodClientUnknownException` is a transport answer Serverpod could
///   not classify: a 502.
///
/// Anything else (a `SerializableException` the app's own code threw) is
/// left to propagate unchanged.
BeakTunnelFault? serverpodTunnelFault(Object error) => switch (error) {
  ServerpodClientUnauthorized() => const BeakTunnelHttpFault(
    401,
    'Your session has ended. Sign in again.',
  ),
  ServerpodClientForbidden() => const BeakTunnelHttpFault(
    403,
    'This account may not use the admin.',
  ),
  ServerpodClientHttpException(statusCode: 413) => const BeakTunnelHttpFault(
    413,
    'The request is larger than the server accepts.',
  ),
  ServerpodClientHttpException(:final statusCode, :final message) =>
    BeakTunnelHttpFault(statusCode, message),
  ServerpodClientNetworkException(:final message) => BeakTunnelNetworkFault(
    message,
  ),
  ServerpodClientUnknownException(:final message) => BeakTunnelHttpFault(
    502,
    message,
  ),
  _ => null,
};

/// The panel's HTTP transport over the generated `client.beakAdmin.dispatch`.
///
/// ```dart
/// BeakPanel(
///   resources: [...],
///   httpClient: ServerpodBeakHttpClient(client.beakAdmin.dispatch),
/// );
/// ```
///
/// It needs nothing but the one string call, so authentication (JWT refresh,
/// server-side sessions, cookie mode) is whatever the Serverpod client does.
base class ServerpodBeakHttpClient extends BeakTunnelHttpClient {
  /// Tunnels through [dispatch], mapping Serverpod's sealed exceptions with
  /// [serverpodTunnelFault].
  ServerpodBeakHttpClient(super.dispatch) : super(faults: serverpodTunnelFault);
}
