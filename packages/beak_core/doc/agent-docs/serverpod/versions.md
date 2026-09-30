# Version compatibility

> Which Beak and Serverpod versions go together, the pins the example uses, the Dart and Flutter floors, and what broke between Serverpod 4.0 beta and 4.0.x.

Beak 0.9.0 is built and tested against Serverpod 4.0.3, and only that version. The declared constraints are wider, so this page separates what is tested from what pub will let you resolve.

## Import

Where the versions appear. The server pins every `serverpod*` package exactly and takes Beak's packages from one ref (the example uses `path:` because it lives in Beak's repository):

```yaml title="examples/serverpod/bookshop_server/pubspec.yaml"
environment:
  sdk: '^3.12.2'

resolution: workspace

dependencies:
  beak_backend:
    path: ../../../packages/beak_backend
  beak_serverpod_server:
    path: ../../../packages/beak_serverpod_server
  bookshop_beak:
    path: ../bookshop_beak
  serverpod: 4.0.3
  serverpod_auth_idp_server: 4.0.3
  serverpod_cloud_storage: 4.0.3
```

The admin app pins its two `serverpod_*` packages to the same number and adds a Flutter floor:

```yaml title="examples/serverpod/bookshop_admin/pubspec.yaml"
environment:
  sdk: '^3.12.2'
  flutter: '^3.44.4'

resolution: workspace

dependencies:
  beak:
    path: ../../../packages/beak
  beak_serverpod_flutter:
    path: ../../../packages/beak_serverpod_flutter
  bookshop_beak:
    path: ../bookshop_beak
  bookshop_client:
    path: ../bookshop_client
  flutter:
    sdk: flutter
  serverpod_auth_core_flutter: 4.0.3
  serverpod_flutter: 4.0.3
```

## Summary

### What is tested

| Part | Version |
| --- | --- |
| Beak packages | 0.9.0. Every `beak_*` package moves in lockstep; `beak --version` prints it |
| Serverpod (server, client, Flutter, auth) | 4.0.3 |
| Serverpod CLI | 4.0.3 (`serverpod --version`); a globally activated CLI may be another release |
| Dart SDK | `^3.12.2` declared. The example's tests were run on Dart 3.13.2 |
| Flutter | `^3.44.4` declared for the admin app. The tests were run on Flutter 3.47.2 |

### What each package declares

| Package | Dart | Serverpod constraint | Other floors |
| --- | --- | --- | --- |
| `beak_serverpod` | `^3.11.0` | None. It is pure Dart and imports no Serverpod package | `http ^1.6.0`, `uuid ^4.5.3` |
| `beak_serverpod_generator` | `^3.11.0` | None. It reads your client's Dart types | `analyzer ^10.0.1`, `dart_style ^3.1.0` |
| `beak_serverpod_flutter` | `^3.11.0` | `serverpod_auth_core_flutter`, `serverpod_auth_idp_client`, `serverpod_client`: `>=4.0.3 <5.0.0` | Flutter `>=3.41.0`, `signals ^6.3.0` |
| `beak_serverpod_server` | `^3.12.2` | `serverpod: '>=4.0.3 <5.0.0'` | `worm`, `worm_postgres`, `beak_backend` from the same Beak ref |
| Example server | `^3.12.2` | `serverpod`, `serverpod_auth_idp_server`, `serverpod_cloud_storage`: `4.0.3`. Dev: `serverpod_test: 4.0.3` | |
| Example admin | `^3.12.2` | `serverpod_flutter`, `serverpod_auth_core_flutter`: `4.0.3`. Dev: `serverpod_auth_core_client: 4.0.3` | Flutter `^3.44.4` |

Beak's ranges allow any 4.x from 4.0.3 up. Only 4.0.3 is tested. The pin is yours to keep exact: Serverpod's own template pins exactly, and a client, a server and a Flutter package on different releases is a mismatch Beak cannot warn you about.

### Rules

| Rule | Reason |
| --- | --- |
| Use one Beak ref for every Beak package | Beak is pre-1.0 and its packages are versioned in lockstep. `beak init` defaults to `--beak-ref v0.9.0` |
| Pin every `serverpod*` package to the same exact version in server, client and app | Serverpod's template pins them together, and Beak's ranges do not enforce it |
| Dart 3.12.2 and Flutter 3.44.4 are Serverpod 4.0.3's own floors | Beak's admin path inherits them; the bridge packages alone need Dart 3.11 |
| Beak is a git or path dependency | It is not on pub.dev; `pub get` needs network access to GitHub |

### From Serverpod 4.0 beta to 4.0.x

Beak's baseline pinned `4.0.0-beta.0` for the Flutter auth packages. Serverpod changed the client exceptions between the beta and `4.0.0-rc.1`, and 4.0.3 keeps the new shape. Any code that catches client exceptions breaks on the upgrade.

| | 4.0.0-beta.0 | 4.0.0-rc.1 and 4.0.3 |
| --- | --- | --- |
| `ServerpodClientException` | A plain class with `message` and `statusCode` | `sealed`, with `message` only |
| Where `statusCode` lives | On every client exception | On `ServerpodClientHttpException` (also sealed) and its subclasses |
| HTTP subclasses | `ServerpodClientBadRequest`, `Unauthorized`, `Forbidden`, `NotFound`, `InternalServerError` extend `ServerpodClientException` | The same five, plus `ServerpodClientUnknownHttpException` for a status without its own class, all extend `ServerpodClientHttpException` |
| Transport failures | Not distinguished | `ServerpodClientNetworkException` and `ServerpodClientUnknownException`, without a status code |
| Dart and Flutter floors | Dart `^3.10.3`, Flutter `^3.38.4` | Dart `^3.12.2`, Flutter `^3.44.4` |

In Beak 0.9.0 that turned `error is ServerpodClientException && error.statusCode == 401` into `error is ServerpodClientHttpException && error.statusCode == 401`, and it is why the tunnel classifies failures with a pattern match over the sealed hierarchy. Because the hierarchy is sealed, a `switch` over it is checked for exhaustiveness:

```dart title="packages/beak_serverpod_flutter/lib/src/serverpod_beak_http_client.dart"
BeakTunnelFault? serverpodTunnelFault(Object error) => switch (error) {
  ServerpodClientUnauthorized() => const BeakTunnelHttpFault(
    401,
    'Your session has ended. Sign in again.',
  ),
  ServerpodClientForbidden() => const BeakTunnelHttpFault(
    403,
    'This account may not use the admin.',
  ),
  ServerpodClientHttpException(statusCode: 413) => const BeakTunnelHttpFault(
    413,
    'The request is larger than the server accepts.',
  ),
  ServerpodClientHttpException(:final statusCode, :final message) =>
    BeakTunnelHttpFault(statusCode, message),
  ServerpodClientNetworkException(:final message) => BeakTunnelNetworkFault(
    message,
  ),
  ServerpodClientUnknownException(:final message) => BeakTunnelHttpFault(
    502,
    message,
  ),
  _ => null,
};
```

Beak 0.9.0 does not resolve against `4.0.0-beta.0`: the constraints start at 4.0.3.

## Source

| Fact | File |
| --- | --- |
| Package constraints | `packages/beak_serverpod/pubspec.yaml`, `packages/beak_serverpod_generator/pubspec.yaml`, `packages/beak_serverpod_flutter/pubspec.yaml`, `packages/beak_serverpod_server/pubspec.yaml` |
| Exact pins | `examples/serverpod/bookshop_server/pubspec.yaml`, `examples/serverpod/bookshop_admin/pubspec.yaml` |
| The pinned CLI | `tool/serverpod_cli_4/pubspec.yaml` |
| The exception hierarchy | `serverpod_client` `lib/src/serverpod_client_exception.dart`, compared between 4.0.0-beta.0, 4.0.0-rc.1 and 4.0.3 |
| The Beak ref default | `packages/beak_cli/lib/src/commands/init_command.dart` |

## Continue reading

- [Troubleshooting](troubleshooting.md): the errors a version mismatch produces.
- [Setting up the admin app](admin-app/setup.md): the pins in a working workspace.
- [Packages](../reference/packages.md): every Beak package and what it depends on.
