# Server files

Beak's API runs inside the Serverpod server behind one endpoint method, on
Serverpod's own database and sessions. Copied from
`examples/serverpod/bookshop_server` in https://github.com/SimonErich/beak with
`bookshop` renamed to `acme`. Serverpod's analyzer turns every public method of
an `Endpoint` subclass in `lib/` into an RPC, so `serverpod generate` needs no
registration step: the client gets `client.beakAdmin.dispatch`.

## `acme_server/pubspec.yaml` additions

The `serverpod*` packages keep the exact version the project already pins; never
loosen them. Beak's packages come from the same release tag as the CLI.

```yaml
dependencies:
  acme_beak:
    path: ../acme_beak
  beak_backend:
    git:
      url: https://github.com/SimonErich/beak.git
      ref: v0.9.0
      path: packages/beak_backend
  beak_serverpod_server:
    git:
      url: https://github.com/SimonErich/beak.git
      ref: v0.9.0
      path: packages/beak_serverpod_server

dev_dependencies:
  # For the tests: beak_core, beak_serverpod, beak_test, worm and worm_postgres,
  # each as the same git dependency with its own `path: packages/<name>`.
```

`beak_serverpod_server` needs Dart 3.12.2 or newer and `serverpod` 4.0.3 or newer
within 4.x. Run `dart pub get` at the workspace root afterwards.

## Beak's receipt table (copy verbatim, do not edit)

`acme_server/lib/src/beak/models/beak_commit_receipt.spy.yaml`

```yaml
### TOOL-OWNED by Beak. Do not edit.
### Durable graph-commit receipts: idempotent replay and recovery.
### Beak's form Save is a graph commit, so any Beak admin needs this table.
class: BeakCommitReceipt
serverOnly: true
table: beak_commit_receipt
fields:
  ### (principal, saveId) namespace key.
  receiptKey: String, unique

  ### Hash of the submitted plan; a replay with another hash is rejected.
  requestHash: String

  ### The prepared plan, kept for recovery.
  requestJson: String

  ### The authoritative result (a pending marker while in flight).
  resultJson: String

  createdAt: DateTime, default=now
```

Serverpod's `create-migration` owns this table, so Beak never runs its own
receipt migration here.

## Scopes, policy, engine and endpoint

`acme_server/lib/src/beak/acme_scopes.dart`

```dart
import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:serverpod/serverpod.dart';

/// The scopes of the admin, kept in one place like Serverpod's `Scope.admin`.
///
/// `beak.admin` only opens the Beak tunnel. What an admin may then do is decided
/// by the policy, and the policy reads the other scopes.
abstract final class AcmeScopes {
  /// Opens the Beak tunnel (`beak.admin`); the gate on `BeakAdminEndpoint`.
  static const Scope admin = BeakScopes.admin;

  /// May read and write authors and books in the admin.
  static const Scope staff = Scope('acme.staff');
}
```

`acme_server/lib/src/beak/acme_policy.dart`

```dart
import 'package:acme_beak/acme_beak.dart';
import 'package:beak_backend/beak_backend.dart';

import 'acme_scopes.dart';

/// Who may do what in the admin. Deny by default: holding `beak.admin` opens the
/// tunnel and grants nothing. A rule that is not written is a rule that is
/// closed, so deleting needs a deliberate rule.
final BeakPolicies acmePolicy = BeakPolicies(
  rules: [
    BeakModelRules(const AuthorModel(), read: _staff, write: _staff),
    BeakModelRules(const BookModel(), read: _staff, write: _staff),
  ],
);

final BeakAccess _staff = BeakAccess.role(AcmeScopes.staff.name!);
```

`BeakServerpodPrincipal.fromScopes` (the engine's default) turns every Serverpod
scope name into a Beak role, which is why `BeakAccess.role` takes the scope name.
Other `BeakModelRules` arguments: `delete:`, `rowScope:`, `readOnlyFields:`,
`actions:` (see `beak-secure-api`). A model no rule lists is invisible.

`acme_server/lib/src/beak/acme_beak_engine.dart`

```dart
import 'package:acme_beak/acme_beak.dart';
import 'package:beak_serverpod_server/beak_serverpod_server.dart';

import 'acme_policy.dart';

/// One per process, shared by every request. A policy is required: there is no
/// allow-all default.
final BeakServerpodEngine acmeBeak = BeakServerpodEngine(
  registry: buildBeakRegistry(),
  policy: acmePolicy,
);
```

Extra arguments: `graphOnly: [const OrderModel()]` with a `preparePlan:` for
transactional rules, `principal:` to map the Serverpod user to a `BeakPrincipal`
differently, `statementTimeoutInSeconds:`.

`acme_server/lib/src/beak/beak_admin_endpoint.dart`

```dart
import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:serverpod/serverpod.dart';

import 'acme_beak_engine.dart';

/// The Beak admin tunnel: one method, gated by [BeakAdminGate] (a signed-in user
/// holding the `beak.admin` scope) before any Beak code runs.
class BeakAdminEndpoint extends Endpoint with BeakAdminGate {
  /// Runs one Beak request (envelope v1) and returns the response envelope.
  Future<String> dispatch(Session session, String request) =>
      acmeBeak.dispatch(session, request);
}
```

Only `/api/**` (except `/api/auth/**`) is reachable through the tunnel, only
`content-type`, `accept`, `if-unmodified-since` and `x-beak-request-id` travel,
and the principal comes from `session.authenticated` alone.

## Granting access: `acme_server/bin/beak_admin.dart`

Move the template's `pod.initializeAuthServices(...)` call from `run` in
`lib/server.dart` into a top-level `void initializeAcmeAuth(Serverpod pod)` and
call it from `run` and from this script, so both configure the same identity
providers.

```dart
// Grants and revokes admin access for an email account.
//
//   dart run bin/beak_admin.dart grant <email> [-- <serverpod args>]
//   dart run bin/beak_admin.dart revoke <email> [-- <serverpod args>]
//
// Goes through Serverpod (`withSession` and AuthServices), never through SQL.
// Scopes are copied into a token when it is issued, so the user signs in again
// to pick a grant up. `revoke` also revokes every token of the user.
import 'dart:io';

import 'package:acme_server/server.dart' show initializeAcmeAuth;
import 'package:acme_server/src/beak/acme_scopes.dart';
import 'package:acme_server/src/generated/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

const String _usage =
    'usage: dart run bin/beak_admin.dart grant|revoke <email> '
    '[-- <serverpod args>]';

/// The scopes `grant` adds and `revoke` removes.
final Set<Scope> _adminScopes = {AcmeScopes.admin, AcmeScopes.staff};

Future<void> main(List<String> arguments) async {
  final int split = arguments.indexOf('--');
  final List<String> ours = split < 0 ? arguments : arguments.sublist(0, split);
  final List<String> serverpodArgs =
      split < 0 ? const [] : arguments.sublist(split + 1);
  if (ours.length != 2 || !{'grant', 'revoke'}.contains(ours.first)) {
    stderr.writeln(_usage);
    exit(64);
  }
  final String command = ours[0];
  final String email = ours[1].trim().toLowerCase();

  final pod = Serverpod(serverpodArgs);
  initializeAcmeAuth(pod);
  var exitStatus = 0;
  try {
    await pod.withSession((session) async {
      final account = await AuthServices.getIdentityProvider<EmailIdp>().admin
          .findAccount(session, email: email);
      if (account == null) {
        stderr.writeln('No email account for $email. Sign up first.');
        exitStatus = 1;
        return;
      }
      final users = AuthServices.instance.authUsers;
      final Set<String> before = (await users.get(
        session,
        authUserId: account.authUserId,
      )).scopeNames;
      final Set<String> adminNames = {
        for (final scope in _adminScopes) scope.name!,
      };
      final Set<String> after = switch (command) {
        'grant' => {...before, ...adminNames},
        _ => before.difference(adminNames),
      };
      // `update(scopes:)` replaces the whole set, hence the merge above.
      await users.update(
        session,
        authUserId: account.authUserId,
        scopes: {for (final name in after) Scope(name)},
      );
      stdout.writeln('$command $email: $before -> $after');
      if (command == 'revoke') {
        await AuthServices.instance.tokenManager.revokeAllTokens(
          session,
          authUserId: account.authUserId,
        );
      }
    });
  } finally {
    await pod.shutdown(exitProcess: false);
  }
  exit(exitStatus);
}
```

The script talks to the database, so the user runs it (`dart run` builds the
Argon2 native asset the email login needs). It assumes the template's email
identity provider; adapt the account lookup for another provider.

## Tests that belong to the server

`withServerpod` from `serverpod_test` (the generated
`test/integration/test_tools/serverpod_test_tools.dart`) drives the real
endpoint. Send envelopes with `BeakWireRequest` from
`package:beak_serverpod/wire.dart` (`BeakWireRequest(method:, path:, query: '',
headers: {...}, body: ...).encode()`, answered as `BeakWireResponse.decode(...)`).
The bookshop example has the full set:
`test/integration/beak/beak_admin_endpoint_test.dart` and
`beak_admin_security_test.dart`. Prove at least:

- anonymous: `endpoints.beakAdmin.dispatch(sessionBuilder, request)` throws
  `ServerpodUnauthenticatedException`;
- signed in without `beak.admin` (also with `Scope.admin`): throws
  `ServerpodInsufficientAccessException`;
- only `beak.admin`: every table answers 403 with code `authorization`;
- staff: read and write succeed, an unlisted operation (delete) answers 403;
- a table Beak does not register (`serverpod_auth_core_user`,
  `beak_commit_receipt`) answers 404;
- a server-only column never appears in a response and a client cannot write it.

Sign a session in with
`sessionBuilder.copyWith(authentication: AuthenticationOverride.authenticationInfo(userId, {scopes}))`.
