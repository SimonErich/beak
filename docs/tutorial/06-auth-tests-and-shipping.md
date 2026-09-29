---
title: Auth, tests, and shipping
description: Close the API behind sign-in and per-role rules, put the panel behind a login, prove both with tests, and build the server and panel you would deploy.
type: tutorial
audience: [beginner]
status: stable
---

# Auth, tests, and shipping

Until now anyone who could reach port 8080 could read, write and delete everything. That was right for five chapters of building and is wrong from here on. This chapter closes the API, puts a sign-in in front of the panel, proves both with tests, and builds the two programs you would put on a server.

## What you'll build

- a server that needs a sign-in, with two accounts and one rule set per model,
- a panel that shows a login form before anything else,
- four tests in three files: the panel over an in-memory data source, the API over an in-memory database, and the policy itself,
- a server executable and a static panel bundle.

## Before you start

You need chapter 5 finished. Stop `beak dev`; you restart it in a moment. The shop in `examples/clean_beak_config` has no login at all, so the auth code in this chapter is not quoted from it. It uses the same types the framework's own policy tests use, and every line was run for this page.

## Close the server

A `BeakServer` built without a policy allows everything to everyone, anonymous callers included, and nothing warns at boot. That suits the first hour. The panel's own permissions do not change it: hiding a button protects nothing, because a client that skips the panel skips the check. Authorization is the server's job.

The server needs a secret to hash passwords with. Put it in `.env`, which `beak create` already git-ignores, and keep a `.env.example` without the value for your teammates:

```bash
echo "AUTH_SECRET=change-me-locally" > .env
```

Then create `lib/server.dart`. `beak prepare` looks for a function called `beakServer` in that file and hands it the generated defaults, which you extend and return:

```dart title="lib/server.dart"
import 'package:beak/server.dart';

import 'resources/categories/models/category.dart';
import 'resources/categories/models/category_attribute.dart';
import 'resources/products/models/product.dart';

/// Closes the API: sign in to read, staff write, managers delete.
BeakServer beakServer(BeakServerDefaults defaults) {
  final String? secret = defaults.environment['AUTH_SECRET'];
  if (secret == null) {
    throw StateError('Set AUTH_SECRET before starting the server.');
  }
  const staff = BeakAccess.role('staff');
  const manager = BeakAccess.role('manager');
  return defaults.build(
    authSessions: BeakAuthSessions(
      store: InMemoryTokenSessionStore(),
      secret: secret,
      users: [
        BeakUserAccount(
          username: 'sam@example.com',
          passwordHash: hashBeakPassword('s3cret', secret: secret),
          principal: const BeakPrincipal(id: 'sam', roles: {'staff'}),
        ),
        BeakUserAccount(
          username: 'mia@example.com',
          passwordHash: hashBeakPassword('m4nager', secret: secret),
          principal: const BeakPrincipal(
            id: 'mia',
            roles: {'staff', 'manager'},
          ),
        ),
      ],
    ),
    policy: BeakPolicies(
      rules: [
        BeakModelRules(
          const ProductModel(),
          read: BeakAccess.authenticated,
          write: staff,
          delete: manager,
        ),
        BeakModelRules(
          const CategoryModel(),
          read: BeakAccess.authenticated,
          write: staff,
          delete: manager,
        ),
        BeakModelRules(
          const CategoryAttributeModel(),
          read: BeakAccess.authenticated,
          write: staff,
          delete: manager,
        ),
      ],
    ),
  );
}
```

Two halves. `authSessions` answers who is calling: it mounts `POST /api/auth/login`, `POST /api/auth/logout` and `GET /api/auth/me`, and turns the bearer token on every other request into a principal (an id and some roles). `policy` answers what that principal may do. `BeakPolicies` denies by default: a model with no rule is invisible, so a model you add next month stays closed until someone opens it. That is also why `CategoryAttributeModel` is listed. The category form loads its attributes, and a model the policy does not name cannot be loaded even through a relation.

Each rule names who may `read`, `write` and `delete`. Reading is any signed-in account, writing needs the `staff` role, and deleting needs `manager`. A rule can go further and narrow rows or fields. This is the framework's own test for it, where each principal sees only the notes of their own author. It belongs to the framework's test models, not to your project:

```dart
--8<-- "packages/beak_backend/test/src/auth/beak_policies_handlers_test.dart:policyRules"
```

Now the honest part about the accounts. They live in a list built at boot, the hash is one shared secret without per-user salt, sessions live in process memory and last 12 hours, and nobody throttles login attempts. That is a login for building a panel, not an account system. For production, implement `BeakAuthGuard` over your identity provider or gateway, and keep the `BeakPolicies` half exactly as it is. [Auth and policies](../backend/auth-and-policies.md) has the interface and the full limits.

Regenerate and start the API:

```bash
beak dev
```

```console
$ beak dev
  3 models · 2 resource classes · 0 screens · 1 override
  generated  1 of 7 files
  panel      run this in another terminal:
               flutter run -d chrome
  api        starting…
listening on http://0.0.0.0:8080
```

The `1 override` is your `beakServer`. Ask for a product without signing in:

```bash
curl -s -i -X POST localhost:8080/api/products/query \
  -H 'content-type: application/json' -d '{"table":"products"}'
```

```text
HTTP/1.1 401 Unauthorized
{"code":"authentication","message":"Sign in to view \"products\".","requestId":"c309e7532df538f9"}
```

Sign in as Sam:

```bash
curl -s -X POST localhost:8080/api/auth/login \
  -H 'content-type: application/json' \
  -d '{"username":"sam@example.com","password":"s3cret"}'
```

```json
{"token":"2f97c2bc8525aa7e47a169e6f0ff50306350f9b468b05691e97d3c16f54545da","principal":{"id":"sam","roles":["staff"]}}
```

Copy your token (it will differ) into a shell variable and use it. Sam reads fine and is refused a delete:

```bash
export TOKEN=2f97c2bc8525aa7e47a169e6f0ff50306350f9b468b05691e97d3c16f54545da
curl -s -i -X DELETE localhost:8080/api/products/00000000-0000-4000-8000-000000000009 \
  -H "authorization: Bearer $TOKEN"
```

```text
HTTP/1.1 403 Forbidden
{"code":"authorization","message":"Principal \"sam\" is not allowed to delete \"products\".","requestId":"e0e2857e12a2eb24"}
```

Sign in as Mia (`mia@example.com`, password `m4nager`), repeat the same `DELETE` with her token, and the answer is `204 No Content`. That deleted the hand grinder; `beak seed` brings it back.

## Put the panel behind it

The panel takes the same idea as an argument. `BeakAuthConfig()` with no arguments signs in through the `/api/auth/login` route you just mounted and keeps the token in memory. Add it to `lib/main.dart`, as an optional parameter so a test can leave it out:

```dart title="lib/main.dart"
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import 'operations.dart';
import 'overview.dart';
import 'resources/categories/category_resource.dart';
import 'resources/products/product_resource.dart';

/// Boots the panel behind a sign-in.
void main() => runApp(buildPanel(auth: const BeakAuthConfig()));

/// The panel, and every resource it shows.
///
/// This file is yours: `beak prepare` never rewrites it, so add each
/// resource class you write to `resources`.
///
/// [dataSource] replaces the HTTP-backed source, so a widget test
/// can pump this exact panel against an in-memory one. [auth] puts a sign-in
/// in front of the panel, and a test leaves it out.
BeakPanel buildPanel({BeakDataSource? dataSource, BeakAuthConfig? auth}) =>
    BeakPanel(
      title: 'Shop',
      --8<-- "examples/clean_beak_config/lib/main.dart:shopBranding"
      pages: [shopOverview(), shopOperations()],
      resources: [ProductResource(), CategoryResource()],
      dataSource: dataSource,
      auth: auth,
    );
```

Restart the panel with `flutter run -d chrome`. A visitor who is not signed in lands on a Sign in card, whatever address they opened, and the card asks for an Email address and a password. The label is not decoration: the panel's sign-in form only accepts email-shaped names, which is why the accounts above are `sam@example.com` and not `sam`. Sign in as Sam and the panel opens on the Shop overview, with a Sign out button in the top bar.

The panel does not know Sam cannot delete, and it draws the trash icon anyway. Press it: a toast says the record is deleted and offers Undo, and the row leaves the table. When the Undo window closes the panel sends the delete, the server answers with an `unapplied` outcome, and the row is back. The panel hid nothing and the server refused. If a role never deletes, `BeakResource` also takes `canDelete: false`, which keeps the icon away from everyone. What each role sees is presentation. The rule is on the server.

## Test it

Three kinds of test, each the cheapest one for what it proves. They use helpers that ship with Beak: `package:beak/testing.dart` has `InMemoryBeakDataSource`, and `beakHost(environment: {...})` on the generated server lets a test point the real host at an in-memory database.

The first is a widget test. It pumps the product resource over an in-memory data source with two seeded products and looks for the formatted prices. The shop's version is the model:

```dart title="test/support/money.dart"
--8<-- "examples/clean_beak_config/test/support/money.dart"
```

```dart title="test/widget_test.dart"
import 'package:beak/panel.dart';
import 'package:beak/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop/beak/registry.g.dart';
import 'package:shop/resources/products/models/product.dart';
import 'package:shop/resources/products/product_resource.dart';

import 'support/money.dart';

void main() {
  --8<-- "examples/clean_beak_config/test/shop_widget_test.dart:productPriceTest"
}
```

`eur('12.50')` builds an exact `BeakDecimal` from text, so no expectation passes through a binary float. This replaces the placeholder test `beak create` wrote.

The other two need the real server. The shop's `ShopTestApi` starts the generated host on a loopback port over `sqlite::memory:`, migrates and seeds it, and hands back the client the panel uses. Yours does the same and signs in first, because the server now insists:

```dart title="test/support/shop_test_api.dart"
import 'dart:io';

import 'package:beak/migrations.dart';
import 'package:shop/beak/server.g.dart';

/// The generated server on an in-memory database, with a client signed in.
final class ShopTestApi {
  ShopTestApi._(this.adapter, this.server, this.baseUrl, this.client);

  /// Isolated, in-memory SQLite database.
  final DatabaseAdapter adapter;

  /// HTTP server on an ephemeral loopback port.
  final HttpServer server;

  /// The origin the server listens on.
  final String baseUrl;

  /// The same wire client the panel uses, signed in as the given account.
  final BeakClient client;

  /// Migrates and seeds a fresh database, then signs in.
  static Future<ShopTestApi> start({
    String username = 'sam@example.com',
    String password = 's3cret',
  }) async {
    final probe = await ServerSocket.bind('127.0.0.1', 0);
    final port = probe.port;
    await probe.close();
    final host = beakHost(
      environment: {
        'DATABASE_URL': 'sqlite::memory:',
        'HOST': '127.0.0.1',
        'PORT': '$port',
        'BEAK_STORAGE_DRIVER': 'none',
        'AUTH_SECRET': 'test-secret',
      },
    );
    final adapter = adapterFromUrl(host.config.databaseUrl);
    await adapter.connect();
    await MigrationRunner(
      adapter: adapter,
      migrations: host.migrations,
      seeders: host.seeders,
    ).fresh(seed: true);
    final server = await host.buildServer(adapter: adapter).start();
    final baseUrl = 'http://127.0.0.1:$port';
    final login = BeakClient(baseUrl: baseUrl);
    final session = await login.login(username: username, password: password);
    login.close();
    return ShopTestApi._(
      adapter,
      server,
      baseUrl,
      BeakClient(baseUrl: baseUrl, tokenProvider: () => session.token),
    );
  }

  /// Releases all transport and database state after the test.
  Future<void> dispose() async {
    client.close();
    await server.close(force: true);
    await adapter.disconnect();
    await Worm.reset();
  }
}
```

The map given to `beakHost` replaces the process environment entirely, `.env` included. That is why the test supplies its own `AUTH_SECRET`, and why it can never touch your `beak.db`. `Worm.reset()` in `dispose` is mandatory: worm refuses a second initialization in the same process.

Now the tests. The first is the shop's own check that a save applies the model defaults, and the only change is the client, which now comes from the helper:

```dart title="test/product_api_test.dart"
@TestOn('vm')
library;

import 'package:beak/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop/resources/products/models/product.dart';

import 'support/money.dart';
import 'support/shop_test_api.dart';

void main() {
  late ShopTestApi api;

  setUp(() async => api = await ShopTestApi.start());
  tearDown(() => api.dispose());

  test('a new product applies the model defaults', () async {
    final client = api.client;
    --8<-- "examples/clean_beak_config/test/shop_api_test.dart:productDefaultsPlan"
  });
}
```

The second test is the policy, and it is the one only a server test can write. A widget test cannot see authorization:

```dart title="test/product_policy_test.dart"
@TestOn('vm')
library;

import 'package:beak/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop/resources/products/models/product.dart';

import 'support/shop_test_api.dart';

void main() {
  test('an anonymous caller cannot read products', () async {
    final api = await ShopTestApi.start();
    addTearDown(api.dispose);
    final anonymous = BeakClient(baseUrl: api.baseUrl);
    addTearDown(anonymous.close);
    await expectLater(
      anonymous.query('products', const ProductModel().query()),
      throwsA(isA<BeakAuthenticationException>()),
    );
  });

  test('staff may read but not delete, managers may delete', () async {
    final staff = await ShopTestApi.start();
    addTearDown(staff.dispose);
    final page = await staff.client.query(
      'products',
      const ProductModel().query(),
    );
    expect(page.items, isNotEmpty);
    final id = page.items.first['id']!.raw!;
    await expectLater(
      staff.client.delete('products', id),
      throwsA(isA<BeakAuthorizationException>()),
    );

    final manager = await ShopTestApi.start(
      username: 'mia@example.com',
      password: 'm4nager',
    );
    addTearDown(manager.dispose);
    await manager.client.delete('products', id);
    final left = await manager.client.query(
      'products',
      const ProductModel().query(),
    );
    expect(left.items.map((record) => record['id']!.raw), isNot(contains(id)));
  });
}
```

Run everything, and analyze:

```bash
flutter analyze
flutter test
```

```console
$ flutter analyze
Analyzing shop...
No issues found! (ran in 2.6s)
$ flutter test
00:03 +4: All tests passed!
```

The API tests log every request to stderr, so a real run is chattier than this. Each test gets its own database, and the run takes a few seconds.

## Build it

The project compiles to two programs. The panel is Flutter and becomes static files. The server is pure Dart, never imports Flutter, and becomes one bundle. `beak doctor` fails a panel file that imports server code, which matters because `dart:io` compiles for the web and only breaks when it runs.

```bash
flutter build web --release
dart build cli --target bin/serve.dart -o build/serve
dart build cli --target bin/migrate.dart -o build/migrate
```

```console
$ flutter build web --release
Compiling lib/main.dart for the Web...                             45.0s
✓ Built build/web
$ dart build cli --target bin/serve.dart -o build/serve
Generated: .../build/serve/bundle/bin/serve
$ dart build cli --target bin/migrate.dart -o build/migrate
Generated: .../build/migrate/bundle/bin/migrate
```

`build/web` is what a static host serves. `dart build cli` needs a recent Dart SDK (these steps ran on 3.13.2) and writes a bundle, not a single file: `bin/serve` is the executable and `lib/` holds the native SQLite library it loads, so ship the whole `bundle/` directory. `bin/serve.dart` and `bin/migrate.dart` are written by `beak prepare`, which is why they exist in every project.

## Run it

Run the bundles the way a host would, with the configuration in the environment:

```bash
export DATABASE_URL=sqlite:/tmp/shop-prod.db
export AUTH_SECRET=a-long-random-secret
export WORM_ENV=production
export PORT=8090
export HOST=127.0.0.1
./build/migrate/bundle/bin/migrate migrate
./build/serve/bundle/bin/serve
```

```console
$ ./build/migrate/bundle/bin/migrate migrate
migrated  20260926_000000_beak_commit_receipts
migrated  20260927_000000_beak_outbox
migrated  20260929_174129_create_categories_table
migrated  20260929_174339_create_products_table
migrated  20260929_174548_create_category_attributes_table
migrated  20260929_174611_add_category_to_products
$ ./build/serve/bundle/bin/serve
listening on http://127.0.0.1:8090
```

Sam and Mia still exist, with the passwords from `lib/server.dart`, which is why the accounts section above says to replace them before this goes anywhere real. `WORM_ENV=production` makes `migrate fresh` and `migrate refresh` refuse to run without `--force`, and it keeps demo seeders that say `Environment.development` out. The server never migrates a file or Postgres database by itself; you run the migrate bundle as a deploy step, before the new server takes traffic. From another terminal:

```bash
curl -s localhost:8090/healthz
```

```json
{"status":"ok"}
```

The `deploy/` folder in the repository has two Dockerfiles, an nginx config and a compose file that automate these steps for the shop. It is a starting point to copy and adapt, and [Going to production](../shipping/going-to-production.md) lists what does not work in it as it stands.

!!! note "What just happened"
    - Who is calling and what they may do are separate. `authSessions` identifies the caller, `BeakPolicies` decides, and a model without a rule is closed.
    - The panel's sign-in form and the server's policy are two halves of one feature. The form makes signing in pleasant, the policy makes not signing in impossible.
    - A test is cheapest at the layer where the claim lives: rendering in a widget test over an in-memory source, transactions and authorization in a server test over in-memory SQLite.
    - The server is one bundle and the panel is static files, so they deploy separately.

!!! question "What this skipped"
    - Row scopes, field rules, named actions and your own identity provider: [Auth and policies](../backend/auth-and-policies.md).
    - Panel-side sign-in, registration, password recovery and the idle lock: [Auth and idle-lock](../panel/auth-and-idle-lock.md).
    - The three test levels in full, including form sessions with no screen: [Testing](../shipping/testing.md).
    - Postgres, S3 storage, a reverse proxy and the rest of the checklist: [Going to production](../shipping/going-to-production.md) and [Security](../shipping/security.md).

## Checkpoint

```bash
beak doctor
```

```console
$ beak doctor
  OK   project depends on Beak
  OK   beak.yaml parses
  OK   discovered 3 models · 2 resource classes · 0 screens · 1 override
  OK   lib/main.dart lists every resource class
  OK   generated files up to date
  OK   every model has a migration
  ...
All checks passed.
```

That is the whole tutorial project: three models written in one place each, two resources, a panel with your own columns and pages, a seeder, an API that refuses strangers, four tests and two build outputs. The shop in `examples/clean_beak_config` is the same idea with eleven resources, and now you can read it.

## Continue reading

- [Clean shop](../examples/clean-shop.md): the full shop this tutorial was cut from, with orders, invoices and variants.
- [Security](../shipping/security.md): the hardening list for a server that faces anyone.
- [Going to production](../shipping/going-to-production.md): hosts, Postgres, storage and what stays yours.
