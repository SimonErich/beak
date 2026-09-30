# The admin app

A Flutter web app in the workspace. Every panel request travels through the
generated `client.beakAdmin.dispatch`, and login is Serverpod's own. Modeled on
`examples/serverpod/bookshop_admin` in https://github.com/SimonErich/beak.
`acme` stands for your project name.

Create it inside the workspace root, then add it to the root `workspace:` list:

```console
flutter create --platforms=web --empty --no-pub acme_admin
```

## `acme_admin/pubspec.yaml`

`serverpod_flutter` and `serverpod_auth_core_flutter` carry the exact version the
workspace already pins (`serverpod: 4.0.3` in the server pubspec means
`4.0.3` here). Beak comes from one release tag.

```yaml
name: acme_admin
description: Beak admin panel for acme (Flutter web).
publish_to: none
version: 0.1.0

environment:
  sdk: '^3.12.2'
  flutter: '^3.44.4'

resolution: workspace

dependencies:
  acme_beak:
    path: ../acme_beak
  acme_client:
    path: ../acme_client
  beak:
    git:
      url: https://github.com/SimonErich/beak.git
      ref: v0.9.0
      path: packages/beak
  beak_serverpod_flutter:
    git:
      url: https://github.com/SimonErich/beak.git
      ref: v0.9.0
      path: packages/beak_serverpod_flutter
  flutter:
    sdk: flutter
  serverpod_auth_core_flutter: 4.0.3
  serverpod_flutter: 4.0.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  lints: '>=3.0.0 <7.0.0'
```

## `acme_admin/lib/main.dart`

```dart
import 'package:acme_client/acme_client.dart';
import 'package:beak_serverpod_flutter/beak_serverpod_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

import 'src/acme_admin.dart';

/// Serverpod's email login through Beak's auth screens, and every panel request
/// tunnelled through the generated `client.beakAdmin.dispatch`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionManager = FlutterAuthSessionManager();
  final Client client =
      Client(
          await getServerUrl(),
          // Buffered CSV export rides the tunnel too; the 20 second default is
          // for ordinary calls.
          connectionTimeout: const Duration(seconds: 60),
        )
        ..connectivityMonitor = FlutterConnectivityMonitor()
        ..authSessionManager = sessionManager;
  await client.auth.initialize();
  final auth = ServerpodAuthAdapter(
    client: client,
    sessionManager: sessionManager,
    resolveIdentity: acmeAdminIdentity(sessionManager),
  );
  await auth.initialize();
  runApp(acmeAdminPanel(dispatch: client.beakAdmin.dispatch, auth: auth));
}
```

## `acme_admin/lib/src/acme_admin.dart`

```dart
import 'package:beak/panel.dart';
import 'package:beak_serverpod_flutter/beak_serverpod_flutter.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';

import '../resources/author_resource.dart';
import '../resources/book_resource.dart';

/// The scope that opens the Beak tunnel (`BeakScopes.admin` on the server).
const String beakAdminScopeName = 'beak.admin';

/// The admin's sections, in navigation order.
List<BeakResource> acmeResources() => [BookResource(), AuthorResource()];

/// Beak's panel over the Serverpod tunnel. [dispatch] is the generated
/// `client.beakAdmin.dispatch` (a fake in widget tests).
BeakPanel acmeAdminPanel({
  required BeakTunnelDispatch dispatch,
  required BeakAuthAdapter auth,
}) => BeakPanel(
  title: 'Acme admin',
  resources: acmeResources(),
  auth: BeakAuthConfig(adapter: auth, register: true, recover: true),
  dataSource: serverpodBeakDataSource(dispatch),
);

/// Maps the signed-in Serverpod user to Beak's identity: only an account holding
/// [beakAdminScopeName] may open the panel. The scopes come from the token
/// Serverpod issued at sign-in, so a grant takes effect on the next sign-in. The
/// endpoint gate and Beak's policy still decide every request; this only keeps a
/// signed-in customer on the sign-in screen instead of an empty shell of 403s.
ServerpodIdentityResolver acmeAdminIdentity(
  FlutterAuthSessionManager sessionManager,
) => (signedIn) async {
  final AuthSuccess? auth = sessionManager.authInfo;
  if (!signedIn || auth == null) return null;
  return BeakAuthIdentity(
    id: auth.authUserId,
    canAccessPanel: auth.scopeNames.contains(beakAdminScopeName),
  );
};
```

Presentation permissions can be mapped from the same token
(`BeakPermissions`); they only hide controls. Every endpoint enforces its own
policy.

## A resource

`acme_admin/lib/resources/book_resource.dart` (use `beak-frontend-build-screens`
for anything beyond this)

```dart
import 'package:acme_beak/acme_beak.dart';
import 'package:beak/panel.dart';

/// The Books section: every reference is a typed ref of the `Book` model in
/// `acme_beak`, so a renamed or retyped field stops this file compiling.
final class BookResource extends BeakResource {
  /// Creates the Books section.
  BookResource()
    : super(
        model: const BookModel(),
        title: 'Books',
        filters: [
          BookModel.title.textFilter(),
          BookModel.author.relationFilter(),
          BookModel.format.selectFilter(),
        ],
        screens: [
          BeakTableScreen(
            fields: [BookModel.title, BookModel.author.name, BookModel.format],
          ),
          BeakFormScreen(
            roles: const {
              BeakScreenRole.read,
              BeakScreenRole.create,
              BeakScreenRole.edit,
            },
            layout: BeakFormLayout(
              children: [
                BookModel.title.inputText(),
                BookModel.author.inputCombobox(),
                BookModel.format.inputSelect(),
              ],
            ),
          ),
        ],
      );
}
```

## Launch it from `serverpod start` (optional)

Add an entry to `acme_server/pubspec.yaml`; `serverpod start` then offers it
(Ctrl+R) beside the template's app:

```yaml
serverpod:
  flutter_apps:
    Admin:
      path: ../acme_admin
      displayName: "Admin"
      device: chrome
```

## Widget tests

Test the panel without Serverpod by passing a fake `dispatch` that runs Beak's
stock Shelf pipeline over worm's `InMemoryAdapter` (see
`bookshop_admin/test/support/fake_bookshop_server.dart` in the example: it
speaks envelope v1 to the real Beak handlers), and a stub `BeakAuthAdapter`
that reports a signed-in identity. Open a section, assert on the rows, and
assert on `server.calls` for the requests the panel made. Login itself is tested
with the real `ServerpodAuthAdapter` over a mocked HTTP transport
(`admin_login_test.dart` in the example).
