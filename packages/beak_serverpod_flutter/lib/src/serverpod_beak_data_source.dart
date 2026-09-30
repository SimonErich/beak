import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_serverpod/wire.dart';

import 'serverpod_beak_http_client.dart';

/// The origin [serverpodBeakDataSource]'s client builds its URLs on.
///
/// Only the path and query of a URL travel through the tunnel (envelope v1),
/// so the host is never contacted; it only has to be a valid absolute URL.
const String beakServerpodTunnelOrigin = 'http://beak.tunnel';

/// The panel's data source over the Serverpod tunnel: Beak's stock
/// [HttpBeakDataSource] and [BeakClient] on top of [ServerpodBeakHttpClient].
///
/// ```dart
/// BeakPanel(
///   resources: [...],
///   auth: BeakAuthConfig(adapter: ServerpodAuthAdapter(...)),
///   dataSource: serverpodBeakDataSource(client.beakAdmin.dispatch),
/// );
/// ```
///
/// Pass it as `dataSource:`, not `httpClient:`: with an external
/// authentication adapter the panel registers no [BeakClient] of its own, so
/// it ignores `httpClient:` and requires a data source. The client sends no
/// bearer token: the Serverpod client authenticates `dispatch` itself
/// (JWT with refresh, server-side sessions or cookies).
// --8<-- [start:serverpodBeakDataSource]
HttpBeakDataSource serverpodBeakDataSource(BeakTunnelDispatch dispatch) =>
    HttpBeakDataSource(
      BeakClient(
        baseUrl: beakServerpodTunnelOrigin,
        httpClient: ServerpodBeakHttpClient(dispatch),
      ),
    );
// --8<-- [end:serverpodBeakDataSource]
