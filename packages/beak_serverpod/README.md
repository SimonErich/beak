# beak_serverpod

The pure-Dart half of Beak's Serverpod support. It holds two things that never
import a Serverpod package: the tunnel that carries Beak's REST API through one
Serverpod endpoint method (the admin app), and the typed resource bindings that
put a Beak panel over endpoints you already have (the client bridge).

Part of [Beak](https://github.com/SimonErich/beak), a configuration-driven
admin-panel framework for Dart and Flutter.

## Which package do I need

Serverpod keeps owning tables, migrations, sign-in and scopes. Beak has two ways
onto a Serverpod 4 project, and each uses a different mix of packages:

| You want | Path | Packages |
| --- | --- | --- |
| An admin in your workspace, with relations, atomic form saves and no endpoint per table | Admin app | [`beak_serverpod_server`](https://github.com/SimonErich/beak/tree/main/packages/beak_serverpod_server) on the server, [`beak_serverpod_flutter`](https://github.com/SimonErich/beak/tree/main/packages/beak_serverpod_flutter) in the panel; this package supplies the tunnel both share |
| A Beak panel over endpoints that already return DTOs, with no server change | Client bridge | This package for the bindings, [`beak_serverpod_generator`](https://github.com/SimonErich/beak/tree/main/packages/beak_serverpod_generator) to write them, `beak_serverpod_flutter` for the sign-in screens |

[Choosing an integration](https://simonerich.github.io/beak/serverpod/choosing-an-integration/)
compares them row by row. You depend on this package directly only on the
bridge path. On the admin app path it arrives through the other two.

## The tunnel

`package:beak_serverpod/wire.dart` is web-safe and has no Serverpod dependency.
It flattens one Beak HTTP request into the string a single endpoint method can
carry (envelope version 1: `v`, `method`, `path`, `query`, `headers`, `body`) and
unwraps the answer (`status`, `headers`, `body`). `BeakTunnelHttpClient` is an
`http.Client` over that string call, so the panel's stock HTTP data layer runs
unchanged on top of it.

Only four request headers travel, so credentials and proxy claims can never
reach Beak through the envelope. The server takes identity from the Serverpod
session alone.

```dart title="packages/beak_serverpod/lib/src/wire.dart"
const Set<String> beakWireRequestHeaders = {
  'content-type',
  'accept',
  'if-unmodified-since',
  'x-beak-request-id',
};
```

A round trip, from the package's own test:

```dart title="packages/beak_serverpod/test/wire_test.dart"
final client = BeakTunnelHttpClient((request) async {
  sent = request;
  return const BeakWireResponse(
    status: 200,
    headers: {'content-type': 'application/json'},
    body: '{"ok":true}',
  ).encode();
});
final response = await client.post(
  Uri.parse('http://beak.tunnel/api/book/query?x=%20y'),
  headers: {'authorization': 'Bearer t', 'content-type': 'text/plain'},
  body: 'hello',
);
expect(response.statusCode, 200);
expect(response.body, '{"ok":true}');
expect(response.headers['content-type'], 'application/json');
final wire = BeakWireRequest.decode(sent!);
expect(wire.method, 'POST');
expect(wire.path, '/api/book/query');
expect(wire.query, 'x=%20y');
expect(wire.body, 'hello');
expect(wire.headers.keys, ['content-type']);
```

A transport failure is classified by the `faults:` mapper you pass. A
`BeakTunnelHttpFault` becomes a response with a Beak error body, so `BeakClient`
raises its usual typed exception (401 is `BeakAuthenticationException`, 403
`BeakAuthorizationException`, 404 `BeakNotFoundException`, 409
`BeakConflictException`). A `BeakTunnelNetworkFault` becomes an
`http.ClientException`, as a socket failure would. `beak_serverpod_flutter`
ships the mapper for Serverpod's client exceptions.

## The client bridge

A `ServerpodResource<T, Id, Create, Update>` is a `BeakModel` that brings its own
data source. You hand it typed callbacks over your generated Serverpod client,
one per operation, and the panel finds the source on the model: no repository, no
registry entry, no HTTP client. Beak never opens a database connection, and it
refuses every operation you did not bind.

`ServerpodModel` holds the presentation, and `resource` is a logical key you
choose, not a table name:

```dart title="packages/beak_serverpod/test/src/resource_test.dart"
const model = ServerpodModel(
  resource: 'users',
  columns: [
    BeakStringColumn(key: 'id', label: 'ID'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ],
  primaryKey: BeakStringColumn(key: 'id', label: 'ID'),
  displayColumn: BeakStringColumn(key: 'name', label: 'Name'),
);
```

Only `query` and `get` are required. `create` needs its `createCodec` and
`update` its `updateCodec`. The resource's `capabilities` follow what is bound
(`read` always, then `create`, `update` and `delete`), so the panel does not
offer what would fail:

```dart title="packages/beak_serverpod/test/src/resource_test.dart"
final binding = ServerpodResource<_User, UuidValue, _User, _User>(
  model: model,
  codec: codec,
  idCodec: ServerpodCodecs.uuid,
  identify: (user) => user.id,
  query: (_) async =>
      BeakPage(items: [user], total: 1, page: 1, perPage: 20),
  get: (key) async => key == id ? user : null,
  createCodec: codec,
  create: (input) async => input,
  updateCodec: codec,
  update: (_, input) async => input,
  editValues: (user) => _User(user.id, '${user.name} edit'),
  archive: (key) async {
    expect(key, id);
    archived = true;
  },
  // ...
);
```

Writing this by hand for every endpoint set is what
[`beak_serverpod_generator`](https://github.com/SimonErich/beak/tree/main/packages/beak_serverpod_generator)
is for. It reads your generated client and writes the `ServerpodResource`, the
typed field descriptors and the codecs.

Mount the resource like any other. Because the model brings its data source, the
panel needs no `dataSource:`. To turn your domain exceptions into Beak's typed
errors, set `mapException` once on the panel: `BeakPanel(mapException: ...)`, or on
the `BeakPanelConfig` you pass as `config:` (which excludes the everyday options):

```dart
// Illustrative: `entries` is a ServerpodResource, `EntryLocked` your own exception.
BeakPanel(
  config: BeakPanelConfig(
    title: 'Entries',
    resources: [BeakResource(model: entries, title: 'Entries')],
    auth: BeakAuthConfig(adapter: auth),
    mapException: (exception, stackTrace) => switch (exception) {
      EntryLocked() => const BeakConflictException(
        'Someone else is editing this entry.',
      ),
      _ => null,
    },
  ),
)
```

A `BeakException` passes through untouched, an `Exception` goes through `mapException`, and one
that returns `null` propagates unchanged. An `Error` is never caught.

## Main types

| Type | What it is |
| --- | --- |
| `BeakWireRequest`, `BeakWireResponse`, `beakWireVersion` | Envelope v1: one Beak HTTP exchange as a string. |
| `BeakTunnelHttpClient`, `BeakTunnelDispatch` | An `http.Client` over one string RPC. |
| `BeakTunnelFault`, `BeakTunnelHttpFault`, `BeakTunnelNetworkFault` | How a transport failure is described to the HTTP caller. |
| `ServerpodResource` | A `BeakModel` bound to typed client callbacks. |
| `ServerpodModel` | Columns, primary key and display column for a resource. |
| `ServerpodField`, `ServerpodRelationField` | A generated, typed property reference, `.column(label, options:)` and `.read(record)`. |
| `ServerpodColumnOptions` | Where a column shows (`visibleOn`, detail-only by default), and whether it sorts, searches and filters. |
| `ServerpodCodecs`, `ServerpodCodec`, `ServerpodValueCodec` | Strict value conversion: `string`, `integer`, `decimal`, `boolean`, `dateTime`, `uuid`, `uri`, `enumeration(values)`, each with `.nullable`, `.list` and `.set`. |
| `ServerpodQueryReader` | Turns a `BeakQuerySpec` into the endpoint's own vocabulary and refuses what does not fit. |
| `ServerpodDataSource`, `ServerpodExceptionMapper` | Routes by resource key. |
| `ServerpodOperation` | `query`, `get`, `create`, `update`, `delete`, `restore`, `forceDelete`, `batchGet`, `aggregate`. |

## Limits

The bridge can only ask your endpoints, so it cannot build what needs a
database.

- Filters are an AND of equality filters on fields you allowlisted. There is one
  sort, on a `sortable` column, and one search term. Anything else throws a
  `BeakConfigurationException` (`Unsupported query for resource "<key>".`).
- Relations are not loaded with the rows. A query with relation loads is
  refused, and attach and detach say so.
- Form saves are staged: the panel sends each operation as its own create or
  update call. The result says `staged`, and atomicity is your endpoint's.
- There are no summaries, no CSV export and no server-side field permissions.
  `BeakPermissions` on a resource hides controls and nothing else, so every
  endpoint has to authorize its own operation.
- A `BeakPanel` given `dataSource:` replaces every model's own source. Do not set
  it on a bridge panel, and do not mix bridge resources with admin app resources
  in one panel.
- Columns are detail-only until you say `BeakContext.table` in `visibleOn`.
- The bridge is older and narrower than the admin app. It is covered by unit
  tests and by a generator that runs against fixtures, not by a running Serverpod
  server.

## Continue reading

- [Bridge resources](https://simonerich.github.io/beak/serverpod/bridge/resources/): every option, and exactly what the bridge refuses.
- [Generating bridge resources](https://simonerich.github.io/beak/serverpod/bridge/generator/): have the binding written from your client.
- [How the admin app works](https://simonerich.github.io/beak/serverpod/admin-app/how-it-works/): where the tunnel goes on the server.
- [Version compatibility](https://simonerich.github.io/beak/serverpod/versions/): which Beak and Serverpod versions go together.

## Status

Pre-1.0 and versioned in lockstep with the other `beak_*` packages (0.9.0). Not on pub.dev yet: depend on it from git with `ref: v0.9.0` once that tag exists, or from a checkout with `path:`. What changed: the [root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). Contributing: [CONTRIBUTING.md](https://github.com/SimonErich/beak/blob/main/CONTRIBUTING.md).

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](https://github.com/SimonErich/beak/blob/main/LICENSE).
