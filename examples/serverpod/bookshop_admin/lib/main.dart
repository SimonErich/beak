import 'package:beak/panel.dart';
import 'package:beak_serverpod_flutter/beak_serverpod_flutter.dart';
import 'package:bookshop_client/bookshop_client.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

import 'src/bookshop_admin.dart';

// --8<-- [start:main]
/// The bookshop admin: Serverpod's email login through Beak's auth screens,
/// and every panel request tunnelled through the generated
/// `client.beakAdmin.dispatch`.
Future<void> main() => runServerpodBeakAdmin<Client>(
  apiUrl: getServerUrl,
  client: (url) => Client(
    url,
    // Buffered CSV export rides the tunnel too; the 20 second default is
    // for ordinary calls.
    connectionTimeout: const Duration(seconds: 60),
  )..connectivityMonitor = FlutterConnectivityMonitor(),
  initialize: (client) => client.auth.initialize(),
  dispatch: (client) => client.beakAdmin.dispatch,
  roles: (client) async =>
      client.authSessionManager.authInfo?.scopeNames ?? const <String>{},
  panelRole: beakAdminScopeName,
  config: (context, auth) => BeakPanelConfig(
    title: 'Dog-Eared Books',
    resources: bookshopResources(),
    auth: BeakAuthConfig(adapter: auth, register: true, recover: true),
  ),
);
// --8<-- [end:main]
