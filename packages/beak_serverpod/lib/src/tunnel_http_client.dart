import 'dart:convert';

import 'package:http/http.dart' as http;

import 'wire.dart';

/// The one call the tunnel rides on, e.g. the generated
/// `client.beakAdmin.dispatch`.
typedef BeakTunnelDispatch = Future<String> Function(String request);

/// What a transport failure means to an HTTP caller.
sealed class BeakTunnelFault {
  const BeakTunnelFault();
}

/// The transport answered with an HTTP status before Beak ran (for example
/// Serverpod's own 401/403 gate, or its 413 body cap).
final class BeakTunnelHttpFault extends BeakTunnelFault {
  /// A failure with [statusCode] and a human-readable [message].
  const BeakTunnelHttpFault(this.statusCode, this.message);

  /// HTTP status the caller sees.
  final int statusCode;

  /// Human-readable reason.
  final String message;
}

/// The transport never produced an answer (offline, timeout, reset).
final class BeakTunnelNetworkFault extends BeakTunnelFault {
  /// A failure described by [message].
  const BeakTunnelNetworkFault(this.message);

  /// Human-readable reason.
  final String message;
}

/// Classifies a transport exception, or returns `null` to let it propagate
/// unchanged.
typedef BeakTunnelFaultMapper = BeakTunnelFault? Function(Object error);

/// An [http.Client] that carries every request through a single string RPC
/// (envelope v1), so Beak's HTTP data layer runs unchanged on top of a
/// transport such as a Serverpod endpoint.
///
/// Only [beakWireRequestHeaders] travel. Transport failures are classified
/// by [faults]: an HTTP fault becomes a response with a Beak error body (so
/// `BeakClient` raises its usual typed exception), a network fault becomes an
/// [http.ClientException], exactly as a socket failure would.
base class BeakTunnelHttpClient extends http.BaseClient {
  /// Tunnels through [dispatch]; [faults] classifies transport errors.
  BeakTunnelHttpClient(this.dispatch, {BeakTunnelFaultMapper? faults})
    : _faults = faults;

  /// The underlying string RPC.
  final BeakTunnelDispatch dispatch;

  final BeakTunnelFaultMapper? _faults;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final String body = await request.finalize().bytesToString();
    final wire = BeakWireRequest(
      method: request.method,
      path: request.url.path.isEmpty ? '/' : request.url.path,
      query: request.url.query,
      headers: request.headers,
      body: body,
    );
    final String reply;
    try {
      reply = await dispatch(wire.encode());
    } on Object catch (error) {
      switch (_faults?.call(error)) {
        case null:
          rethrow;
        case BeakTunnelNetworkFault(:final message):
          throw http.ClientException(message, request.url);
        case BeakTunnelHttpFault(:final statusCode, :final message):
          return _response(
            request,
            BeakWireResponse(
              status: statusCode,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
              body: jsonEncode({
                'code': _codeFor(statusCode),
                'message': message,
              }),
            ),
          );
      }
    }
    return _response(request, BeakWireResponse.decode(reply));
  }

  static http.StreamedResponse _response(
    http.BaseRequest request,
    BeakWireResponse response,
  ) {
    final List<int> bytes = utf8.encode(response.body);
    return http.StreamedResponse(
      Stream.value(bytes),
      response.status,
      contentLength: bytes.length,
      request: request,
      headers: response.headers,
    );
  }

  static String _codeFor(int statusCode) => switch (statusCode) {
    401 => 'authentication',
    403 => 'authorization',
    404 => 'not_found',
    409 => 'conflict',
    413 => 'payload_too_large',
    _ => 'transport',
  };
}
