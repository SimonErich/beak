/// Beak's Serverpod tunnel, the parts both ends share (pure Dart, web-safe).
///
/// - [BeakWireRequest] / [BeakWireResponse]: envelope v1, one Beak HTTP
///   exchange as the string a single Serverpod endpoint method carries.
/// - [BeakTunnelHttpClient]: an `http.Client` over that string call, so the
///   panel's HTTP data layer runs unchanged.
library;

export 'src/tunnel_http_client.dart';
export 'src/wire.dart';
