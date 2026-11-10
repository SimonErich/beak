import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';

import '../tunnel.dart';
import 'serverpod_auth_adapter.dart';
import 'serverpod_beak_data_source.dart';

/// Boots a Beak admin over a Serverpod client in one call.
///
/// It does what every Serverpod admin `main` otherwise repeats: path-based
/// URLs on the web, the stored session, the identity and its roles, and the
/// panel data source that sends every request through one Serverpod endpoint.
///
/// ```dart
/// Future<void> main() => runServerpodBeakAdmin<Client>(
///   apiUrl: () => const String.fromEnvironment('SERVER_URL'),
///   client: (url) => Client(url),
///   dispatch: (client) => client.beakAdmin.dispatch,
///   roles: (client) async => {
///     for (final role in await client.myUserAccount.getEffectivePermissions())
///       role.name,
///   },
///   panelRole: 'accessAdminPanel',
///   initialize: (client) => client.auth.initialize(),
///   locale: const Locale('de'),
///   supportedLocales: AppLocalizations.supportedLocales,
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   config: (context, auth) => BeakPanelConfig(
///     title: AppLocalizations.of(context).appTitle,
///     resources: shopResources,
///     auth: BeakAuthConfig(adapter: auth),
///   ),
/// );
/// ```
///
/// [config] runs in a [BuildContext] that holds the app's localizations, so
/// the app's own copy is read from it (see [BeakLocalizedPanel]); model and
/// field labels come from the generated models in [locale]'s language.
///
/// [roles] answers the account's effective roles after every sign-in; model
/// permissions are checked against them. [panelRole], when set, must be one of
/// them or the account cannot enter the panel. [mapException] and
/// [isUnauthenticated] pass through to the auth adapter.
Future<void> runServerpodBeakAdmin<C extends ServerpodClientShared>({
  required FutureOr<String> Function() apiUrl,
  required C Function(String url) client,
  required BeakTunnelDispatch Function(C client) dispatch,
  required BeakPanelConfig Function(BuildContext context, BeakAuthAdapter auth)
  config,
  Locale? locale,
  List<Locale> supportedLocales = BeakLocalizations.supportedLocales,
  Iterable<LocalizationsDelegate<Object?>> localizationsDelegates = const [],
  Future<Set<String>> Function(C client)? roles,
  String? panelRole,
  BeakException? Function(Object error, StackTrace stackTrace)? mapException,
  bool Function(Object error)? isUnauthenticated,
  Future<void> Function(C client)? initialize,
  FlutterAuthSessionManager? sessionManager,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) usePathUrlStrategy();
  final FlutterAuthSessionManager session =
      sessionManager ?? FlutterAuthSessionManager();
  final C api = client(await apiUrl());
  api.authSessionManager = session;
  await initialize?.call(api);
  final auth = ServerpodAuthAdapter(
    client: api,
    sessionManager: session,
    isUnauthenticated: isUnauthenticated,
    exceptionMapper: mapException == null
        ? null
        : (error, stackTrace) =>
              mapException(error, stackTrace) ??
              const BeakInternalException('Authentication transport failed.'),
    resolveIdentity: roles == null && panelRole == null
        ? null
        : (signedIn) async {
            if (!signedIn) return null;
            final granted = roles == null ? const <String>{} : await roles(api);
            return BeakAuthIdentity(
              id: session.authInfo?.authUserId ?? '',
              roles: granted,
              canAccessPanel: panelRole == null || granted.contains(panelRole),
            );
          },
  );
  await auth.initialize();
  runApp(
    BeakLocalizedPanel(
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: localizationsDelegates,
      config: (context) => config(context, auth),
      dataSource: serverpodBeakDataSource(dispatch(api)),
    ),
  );
}
