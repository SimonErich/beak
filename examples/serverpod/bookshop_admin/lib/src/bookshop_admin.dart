import 'package:beak/panel.dart';
import 'package:beak_serverpod_flutter/beak_serverpod_flutter.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';

import '../resources/author_resource.dart';
import '../resources/book_resource.dart';

/// The scope that opens the Beak tunnel (`BeakScopes.admin` on the server).
const String beakAdminScopeName = 'beak.admin';

/// The admin's sections, in navigation order.
List<BeakResource> bookshopResources() => [BookResource(), AuthorResource()];

/// The Dog-Eared Books admin: Beak's panel over the Serverpod tunnel.
///
/// [dispatch] is the generated `client.beakAdmin.dispatch` (a fake in the
/// widget tests); [auth] is the [ServerpodAuthAdapter] over the same client.
/// Sign-up and password recovery use Serverpod's email IDP; a new account
/// still needs the admin scopes granted (`bin/beak_admin.dart grant`) before
/// it can open the panel.
BeakPanel bookshopAdminPanel({
  required BeakTunnelDispatch dispatch,
  required BeakAuthAdapter auth,
}) => BeakPanel(
  title: 'Dog-Eared Books',
  resources: bookshopResources(),
  auth: BeakAuthConfig(adapter: auth, register: true, recover: true),
  dataSource: serverpodBeakDataSource(dispatch),
);

/// Maps the signed-in Serverpod user to Beak's identity: only an account
/// holding [beakAdminScopeName] may open the panel.
///
/// The scopes come from the token Serverpod issued at sign-in, so a grant
/// takes effect on the next sign-in. The server's endpoint gate and Beak's
/// policy still decide every request; this only keeps a signed-in customer on
/// the sign-in screen instead of an empty shell of 403s.
ServerpodIdentityResolver bookshopAdminIdentity(
  FlutterAuthSessionManager sessionManager,
) => (signedIn) async {
  final AuthSuccess? auth = sessionManager.authInfo;
  if (!signedIn || auth == null) return null;
  return BeakAuthIdentity(
    id: auth.authUserId,
    canAccessPanel: auth.scopeNames.contains(beakAdminScopeName),
  );
};
