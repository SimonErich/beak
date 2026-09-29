import 'package:beak_serverpod_flutter/beak_serverpod_flutter.dart';
import 'package:bookshop_client/bookshop_client.dart';
import 'package:flutter/widgets.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

import 'src/bookshop_admin.dart';

/// The bookshop admin: Serverpod's email login through Beak's auth screens,
/// and every panel request tunnelled through the generated
/// `client.beakAdmin.dispatch`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionManager = FlutterAuthSessionManager();
  final Client client =
      Client(
          await getServerUrl(),
          // Buffered CSV export rides the tunnel too; the 20 second default
          // is for ordinary calls.
          connectionTimeout: const Duration(seconds: 60),
        )
        ..connectivityMonitor = FlutterConnectivityMonitor()
        ..authSessionManager = sessionManager;
  // Restores the stored session and refreshes its access token if needed.
  await client.auth.initialize();
  final auth = ServerpodAuthAdapter(
    client: client,
    sessionManager: sessionManager,
    resolveIdentity: bookshopAdminIdentity(sessionManager),
  );
  await auth.initialize();
  runApp(bookshopAdminPanel(dispatch: client.beakAdmin.dispatch, auth: auth));
}
