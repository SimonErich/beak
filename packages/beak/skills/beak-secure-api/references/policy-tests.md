# Server policy and per-role tests

Compiled and run in a project created with `beak create` at Beak 0.9, with
`Supplier` and `Company` resources. `package:beak/server.dart` provides
everything below.

## `lib/server.dart`

```dart
import 'package:beak/server.dart';

import 'resources/companies/models/company.dart';
import 'resources/suppliers/models/supplier.dart';

const _staff = BeakAccess.role('staff');
const _admin = BeakAccess.role('admin');

/// Who may do what: anything not listed is denied.
BeakServer beakServer(BeakServerDefaults defaults) {
  final secret = defaults.environment['AUTH_SECRET'] ?? 'dev-secret';
  return defaults.build(
    policy: BeakPolicies(
      rules: [
        BeakModelRules(
          const SupplierModel(),
          read: BeakAccess.any([_staff, _admin]),
          write: _admin,
          rowScope: (principal) =>
              principal.hasRole('admin') ? null : SupplierModel.active.eq(true),
        ),
        BeakModelRules(const CompanyModel(), read: BeakAccess.authenticated),
      ],
    ),
    authSessions: BeakAuthSessions(
      store: InMemoryTokenSessionStore(),
      secret: secret,
      users: [
        for (final (name, role) in [('sam', 'staff'), ('ada', 'admin')])
          BeakUserAccount(
            username: name,
            passwordHash: hashBeakPassword('pw-$name', secret: secret),
            principal: BeakPrincipal(id: name, roles: {role}),
          ),
      ],
    ),
  );
}
```

The two demo users above exist so the tests can sign in. Replace them with your
own accounts before production: keep hashes out of source, load them from the
environment or a table behind a custom `BeakAuthGuard` and `TokenSessionStore`,
and pick a real `AUTH_SECRET`. The first time `lib/server.dart` exists, run
`beak prepare`: until then the generated host does not call it and
`/api/auth/login` answers 404. Later edits need no regeneration.

Other `BeakModelRules` arguments:

```dart
BeakModelRules(
  const OrderModel(),
  read: staff,
  write: manager,
  delete: manager,
  rowScope: (principal) => OrderModel.userId.eq(principal.id),
  readOnlyFields: {OrderModel.totalInCents, OrderModel.number},
  actions: {InvoiceActions.issue: BeakAccess.role('billing')},
)
```

## `test/policy_test.dart`

```dart
import 'dart:io';

import 'package:beak/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop/beak/server.g.dart';
import 'package:shop/resources/suppliers/models/supplier.dart';

void main() {
  late DatabaseAdapter adapter;
  late HttpServer server;
  late BeakClient anonymous;
  const table = 'suppliers'; // or const SupplierModel().table

  Future<BeakClient> signedInAs(String user) async {
    final session = await anonymous.login(username: user, password: 'pw-$user');
    return BeakClient(
      baseUrl: anonymous.baseUrl,
      tokenProvider: () => session.token,
    );
  }

  setUp(() async {
    final probe = await ServerSocket.bind('127.0.0.1', 0);
    final port = probe.port;
    await probe.close();
    final host = beakHost(
      environment: {
        'DATABASE_URL': 'sqlite::memory:',
        'HOST': '127.0.0.1',
        'PORT': '$port',
        'BEAK_STORAGE_DRIVER': 'none',
      },
    );
    adapter = adapterFromUrl(host.config.databaseUrl);
    await adapter.connect();
    await MigrationRunner(adapter: adapter, migrations: host.migrations).migrate();
    server = await host.buildServer(adapter: adapter).start();
    anonymous = BeakClient(baseUrl: 'http://127.0.0.1:$port');
  });

  tearDown(() async {
    anonymous.close();
    await server.close(force: true);
    await adapter.disconnect();
    await Worm.reset();
  });

  test('roles see what they should', () async {
    final staff = await signedInAs('sam');
    final admin = await signedInAs('ada');
    final query = const SupplierModel().query();

    await expectLater(
      anonymous.query(table, query),
      throwsA(isA<BeakAuthenticationException>()),
    );

    BeakRecord supplier(String name, {required bool active}) => BeakRecord(
      values: {
        SupplierModel.name.key: SupplierModel.name.encode(name),
        SupplierModel.email.key: SupplierModel.email.encode('$name@example.com'),
        SupplierModel.active.key: SupplierModel.active.encode(active),
      },
    );

    await expectLater(
      staff.create(table, supplier('Acme', active: true)),
      throwsA(isA<BeakAuthorizationException>()),
    );
    await admin.create(table, supplier('Acme', active: true));
    await admin.create(table, supplier('Gone', active: false));

    expect((await admin.query(table, query)).items, hasLength(2));
    expect((await staff.query(table, query)).items, hasLength(1));
    expect(await staff.aggregate(table, const SupplierModel().count()), 1);
    final csv = await staff.export(table, query);
    expect(csv, contains('Acme'));
    expect(csv, isNot(contains('Gone')));

    // A model no rule lists is closed to everyone.
    await expectLater(
      staff.query('notes', const NoteModel().query()),
      throwsA(isA<BeakAuthorizationException>()),
    );
  });
}
```

Status mapping: an anonymous request is a `BeakAuthenticationException` (401), a
signed-in role without access a `BeakAuthorizationException` (403), a field the
server owns a `BeakValidationException` (422). Denied graph commits do not throw:
`client.commit(plan)` returns a result with `complete == false` and the error in
`outcomes`. Import the notes schema (`NoteModel`) or use another model of the
project for the closed-model assertion. A row outside the scope is not an error:
the query succeeds with fewer rows, which is what a scope means.

Also test each role against `GET /api/<table>/capabilities` when the panel
should hide controls: `client.capabilities(table)` returns the field allowlists.
