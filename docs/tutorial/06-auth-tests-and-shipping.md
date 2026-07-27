---
title: Auth, tests, and shipping
description: Add accounts and a row policy on the server, prove them with Beak's testing toolkit, then build the store for production.
---

# Auth, tests, and shipping

Your store works, and right now anyone who can reach the API owns it. After this
chapter it knows who is asking, shows each caller only their own rows, has a
suite that proves the refusals, and a build you can put on a server.

## Take ownership of the server

The backend is generated until you ask for the file.

```console
beak eject server
```

That writes `lib/server.dart` holding Beak's own default,
`BeakServer beakServer(BeakServerDefaults defaults) => defaults.build();`, so it
compiles and changes nothing yet. Run `beak prepare` and the generated
`lib/beak/server.g.dart` starts building the server through your function.

!!! note "What just happened"
    - An eject is a diff against a working default, never a blank file.
    - `defaults` carries the resolved config (host, port, database URL), the
      registry, the data source, the upload driver, and `environment`: a
      `.env` file if there is one, with the real process environment winning.
    - `defaults.build()` takes what Beak cannot guess: `policy`, `authSessions`,
      `authGuard`, `onRequest`, `onUnexpectedError`.

## Who may sign in

Accounts, hashed passwords, and somewhere to keep sessions:

```dart title="examples/store/lib/server.dart"
BeakServer beakServer(BeakServerDefaults defaults) {
  final String secret =
      defaults.environment['AUTH_SECRET'] ?? 'store-dev-secret';
  final store = InMemoryTokenSessionStore();
  return defaults.build(
    policy: const StorePolicy(),
    authSessions: BeakAuthSessions(
      store: store,
      secret: secret,
      users: [
        BeakUserAccount(
          username: 'ada@example.com',
          passwordHash: hashBeakPassword('espresso', secret: secret),
          principal: const BeakPrincipal(
            id: StoreSeedIds.userAda,
            roles: {'staff'},
          ),
        ),
        BeakUserAccount(
          username: 'linus@example.com',
          passwordHash: hashBeakPassword('grinder', secret: secret),
          principal: const BeakPrincipal(
            id: StoreSeedIds.userLinus,
            roles: {'customer'},
          ),
        ),
      ],
    ),
    authGuard: TokenSessionAuthGuard(store),
  );
}
```

The eject wrote one import, `package:beak/server.dart`. Add
`import 'seeders/store_seeder.dart';` for the ids, and give `StoreSeedIds` a
`userAda` and a `userLinus` holding the ids of the two user rows your seeder
writes: a principal's `id` is the row it owns, so a policy can compare against
it. You will need Linus in a minute.

`hashBeakPassword` is HMAC-SHA256 under `secret`, so an account holds a hash and
never a plaintext password. `InMemoryTokenSessionStore` mints one opaque token
per login and holds it in memory, so a restart signs everyone out; implement
`TokenSessionStore` to keep sessions in Redis or a table instead.
`TokenSessionAuthGuard` turns the `Authorization: Bearer` header back into the
`BeakPrincipal` every policy method receives. Passing `authSessions` mounts
`POST /api/auth/login`, `POST /api/auth/logout` and `GET /api/auth/me`.

!!! warning "Before this goes anywhere real"
    Set `AUTH_SECRET` in the environment; the fallback above is a development
    convenience. A shipped store reads its accounts from the `users` table
    rather than from a list in source.

## Who sees what

An account says who you are. A policy says which rows you get.

```dart title="examples/store/lib/server.dart"
final class StorePolicy extends BeakAllowAllPolicy implements BeakRowPolicy {
  /// Creates the policy.
  const StorePolicy();

  /// Tables that need an account, whoever it belongs to.
  static const Set<String> _private = {'orders', 'users'};

  @override
  bool canView(BeakPrincipal? principal, String table) =>
      principal != null || !_private.contains(table);

  @override
  bool canDelete(BeakPrincipal? principal, String table, Object id) =>
      principal?.hasRole('staff') ?? false;

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, String table) {
    // Staff see everything; an anonymous caller never gets this far on a
    // private table, because [canView] already refused.
    if (principal == null || principal.hasRole('staff')) {
      return null;
    }
    final String ownerId = principal.id;
    return switch (table) {
      'orders' => BeakFieldFilter(
        column: OrderColumns.customerId,
        operator: BeakOperator.eq,
        value: BeakValue.of(ownerId),
      ),
      'users' => BeakFieldFilter(
        column: UserColumns.id,
        operator: BeakOperator.eq,
        value: BeakValue.of(ownerId),
      ),
      _ => null,
    };
  }
}
```

That file imports `models/order.dart` and `models/user.dart` for the two column
constants.

| The rule | Written as | The caller gets |
| --- | --- | --- |
| The catalog is public | `canView` allows tables outside `_private` | products, categories and tags with no account |
| Orders and customers need an account | `canView` refuses when `principal` is null | 401, a `BeakAuthenticationException` |
| A customer sees only their own | `scopeFor` filters on the owner column | 200, with the other rows absent |
| Only staff may delete | `canDelete` refuses a signed-in customer | 403, a `BeakAuthorizationException` |

A denied anonymous request is a 401 and a denied signed-in one is a 403, so the
same `canView` tells a browser to sign in and tells a customer no.
Extending `BeakAllowAllPolicy` means writing only the methods you restrict.
`scopeFor` is intersected into every read and write of that table: query,
aggregate, get-one, update, delete, export and global search, so no endpoint is
left to forget. It lives in the API, not the panel, so a `curl` skips nothing.
And `OrderColumns.customerId` is generated from the schema you wrote in
[chapter 3](03-relationships.md), so a renamed field breaks the policy at
compile time instead of quietly matching no rows.

## Sign in from the panel

The client side takes no code at all. The panel always mounts `/login`, and
with no `onLogin` callback that screen signs in through the registered
`BeakSessionStore`, which posts to `/api/auth/login`, keeps the token, and puts
it on every later request. That is why `examples/store` has no `lib/auth.dart`.

Run `beak eject auth` when you want the rest of the surface. It writes a
one-line `BeakAuthConfig beakAuth() => const BeakAuthConfig();`, and
`BeakAuthConfig` is where you turn `/register` and `/recover` off, set an
idle-lock timeout, or pass an `onLogin` because you authenticate somewhere
else.

```console
beak dev
```

Run `flutter run -d chrome` in the second terminal as before, then open
`/login`. Sign in as `ada@example.com` / `espresso` and the panel behaves as it
did. Restart the app, sign in as `linus@example.com` / `grinder`, and the orders
list is empty while the catalog is unchanged. Try to delete a product as Linus
and the API refuses.

!!! question "What this skipped"
    - Registration, recovery, and the idle lock screen:
      [Auth and idle-lock](../panel/auth-and-idle-lock.md).
    - `canCreate`, `canUpdate`, `canDeleteUpload`, and writing your own guard:
      [Auth and policies](../backend/auth-and-policies.md).

## Prove it

`package:beak/testing.dart` gives you `InMemoryBeakDataSource`: a complete
`BeakDataSource` over maps that honours the whole query spec, filters, sorts,
search, paging and eager loads included. Hand it to the generated `BeakApp` and
the panel runs with no server in sight, which is what the store does inside a
`testWidgets` body:

```dart title="examples/store/test/widget_test.dart"
    final registry = buildBeakRegistry();
    final source = InMemoryBeakDataSource(registry: registry)
      ..seed(const ProductModel(), [
        BeakRecord.fromRow(const {
          'id': 'p1',
          'name': 'Espresso Beans',
          'sku': 'COF-ESP-1KG',
          'price': 12.5,
          'stock': 42,
          'featured': true,
          'status': 'published',
        }),
      ]);

    // A desktop-sized surface: the default 800×600 test window is narrower
    // than the panel's own layout breakpoints.
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(BeakApp(dataSource: source));
    await tester.pumpAndSettle();
```

The rest of that file asserts things you can only assert because the panel is
data: that the sidebar lists `products`, `orders` and `users` but not the hidden
`order_items`, and that every column kind and relationship kind is demonstrated
somewhere. When the question is how many round trips a screen costs, wrap the
source in `BeakRecordingDataSource`, which forwards every call and records it,
so `expect(source.queryCalls, hasLength(1))` becomes a test.

### The API, asserted once and run twice

The store keeps every API assertion in `test/api_scenario.dart` and runs it from
two entrypoints that differ only in the environment they pass. The SQLite runner
needs nothing installed:

```dart title="examples/store/test/api_sqlite_test.dart"
void main() {
  final Directory uploads = Directory.systemTemp.createTempSync(
    'store_uploads_',
  );
  tearDownAll(() => uploads.deleteSync(recursive: true));

  runStoreApiScenario(
    description: 'store API on sqlite',
    environmentFor: (port) => {
      'DATABASE_URL': 'sqlite::memory:',
      'BEAK_STORAGE_DRIVER': 'local',
      'BEAK_LOCAL_ROOT_DIR': uploads.path,
      'BEAK_LOCAL_PUBLIC_BASE_URL': 'http://127.0.0.1:$port/uploads',
    },
  );
}
```

`test/e2e/postgres_test.dart` calls the same function with a Postgres
`DATABASE_URL` and carries `@Tags(['e2e'])`, so it runs only when asked. The
scenario boots the real server through `beakHost(environment: ...)`, migrates
fresh, seeds, and talks to it with a `BeakClient`. Its last test checks what you
wrote today, including that a signed-in customer's order list comes back empty:

```dart title="examples/store/test/api_scenario.dart"
    test('the row policy scopes orders and gates deletes', () async {
      // The catalog is public; the orders are not.
      await expectLater(
        client.query('orders', const BeakQuerySpec(table: 'orders')),
        throwsA(isA<BeakAuthenticationException>()),
      );
      expect(
        (await client.query(
          'products',
          const BeakQuerySpec(table: 'products'),
        )).total,
        greaterThan(0),
      );

      final customer = await asUser(client, 'linus@example.com', 'grinder');
      addTearDown(customer.close);

      expect(
        (await staff.query(
          'orders',
          const BeakQuerySpec(table: 'orders'),
        )).total,
        1,
      );
      expect(
        (await customer.query(
          'orders',
          const BeakQuerySpec(table: 'orders'),
        )).total,
        0,
      );

      await expectLater(
        customer.delete('products', StoreSeedIds.productTeaser),
        throwsA(isA<BeakAuthorizationException>()),
      );
    });
```

Three commands run the lot:

```console
flutter test                          # the panel, on InMemoryBeakDataSource
dart test test/api_sqlite_test.dart   # the whole API, on sqlite::memory:
dart test test/e2e --tags e2e         # the same assertions, on Postgres
```

The SQLite run needs no services, so every push checks the row policy, uploads,
restore, export and the stale-save conflict. The Postgres run adds what a driver
can differ on: real `uuid` columns, real `ilike`, real transactions. In the Beak
repository that one is `melos run up && melos run test-e2e`. A backend that
passes one and fails the other is what the shape is for.

## Ship it

Nothing here is bound to SQLite or to local disk. Both are environment
variables, read once at boot, where a wrong value fails with the fix in the
message rather than at the first upload.

| Variable | Default | What it changes |
| --- | --- | --- |
| `DATABASE_URL` | `sqlite:beak.db` | `postgres://user:pass@host:5432/db` moves the store to Postgres |
| `BEAK_STORAGE_DRIVER` | unset (local disk under `storage/uploads`) | `s3`, `local`, `ftp` or `memory`, each with its own `BEAK_*` settings; `none` turns uploads off |
| `PORT`, `HOST` | `8080`, `0.0.0.0` | where the API listens |
| `AUTH_SECRET` | none | the secret your `lib/server.dart` hashes passwords under, read from `defaults.environment` |

```console
DATABASE_URL=postgres://beak:beak@db:5432/store dart run bin/migrate.dart migrate
dart compile exe bin/serve.dart -o beak-server
flutter build web --dart-define=BEAK_API_BASE_URL=https://api.example.com
```

`bin/serve.dart` and `bin/migrate.dart` are generated and git-ignored, so a
build machine runs `beak prepare` before it compiles them. `beak eject main`
un-ignores them instead, which is what `examples/store` does.

The panel is a static bundle, so its API origin is fixed at build time: the
default comes from `api.baseUrl` in `beak.yaml`, and the `--dart-define` wins
over it. Set `baseUrl: auto` instead and the panel calls the origin it was
served from, which is what one host in front of both halves wants. Serve it
with a SPA fallback so a refresh on `/products/42` still lands on the app.
[Going to production](../deployment/going-to-production.md) walks
through `deploy/`: an AOT-compiled server image, an nginx-served panel image,
and a compose stack with Postgres and MinIO behind health checks.

## What you built

Six chapters, one package, no plumbing: a resource from one annotated class and
the panel that came with it, columns whose type and nullability drive the form
and the API and the database, relationships declared once per pair, a seeder and
the REST API under the panel, filters and actions and a dashboard by narrowing
what was derived, and now accounts, a row policy, a suite that proves them, and
a production build.

Read [Core concepts](../concepts/index.md) for the ideas underneath, or
[The panel](../panel/index.md) for more of the surface you shaped in
[chapter 5](05-shaping-the-panel.md). The finished store is `examples/store` in
the Beak repository.

## Continue reading

- [Shaping the panel](05-shaping-the-panel.md) is the chapter before this.
- [Auth and policies](../backend/auth-and-policies.md) the full policy surface,
  guards, and the generated `/api/auth` routes.
- [Testing](../guides/testing.md) the toolkit in depth, including the data
  source contract and schema parity.
- [Environment and config](../deployment/environment-and-config.md) every
  variable Beak reads, and where it reads it.
- [Going to production](../deployment/going-to-production.md) the deploy folder,
  file by file.
