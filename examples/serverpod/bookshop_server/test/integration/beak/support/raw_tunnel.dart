import 'dart:convert';

import 'package:beak_serverpod/wire.dart';

/// Sends envelopes as they are and returns Beak's reply undecoded, so tests
/// see the exact bytes Beak answers with and can forge envelopes the real
/// client never builds.
final class RawTunnel {
  /// Rides on [dispatch] (the endpoint's or an engine's).
  const RawTunnel(this.dispatch);

  /// The tunnel.
  final Future<String> Function(String request) dispatch;

  /// A request the real client could build.
  Future<BeakWireResponse> call(
    String method,
    String path, {
    Object? json,
    Map<String, String> headers = const {},
  }) async => BeakWireResponse.decode(
    await dispatch(
      BeakWireRequest(
        method: method,
        path: path,
        query: '',
        headers: {
          if (json != null) 'content-type': 'application/json',
          ...headers,
        },
        body: json == null ? '' : jsonEncode(json),
      ).encode(),
    ),
  );

  /// A hand-written envelope: whatever [headers] and [path] say, exactly.
  Future<BeakWireResponse> forged(
    String method,
    String path, {
    Object? json,
    String query = '',
    Map<String, String> headers = const {},
  }) async => BeakWireResponse.decode(
    await dispatch(
      jsonEncode({
        'v': beakWireVersion,
        'method': method,
        'path': path,
        'query': query,
        'headers': {
          if (json != null) 'content-type': 'application/json',
          ...headers,
        },
        'body': json == null ? '' : jsonEncode(json),
      }),
    ),
  );
}
