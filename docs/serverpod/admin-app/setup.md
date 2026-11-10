---
title: Setting up the admin app
description: Add the Beak admin to a Serverpod 4 workspace, from the reviewed inventory and generated schema package to the gated endpoint and the signed-in panel.
type: guide
audience: [expert]
status: stable
---

# Setting up the admin app

After this page you have a Serverpod server that serves Beak's API behind one
gated endpoint and a Flutter admin whose models were generated from a reviewed
inventory. The reference workspace is `examples/serverpod`.

## At a glance

| Step | What you do |
| --- | --- |
| 1 | Add `apps/<name>_admin` with `beak.yaml` and `definitions/` |
| 2 | Review the inventory and run `beak generate` |
| 3 | Mount `BeakAdminEndpoint` with `BeakServerpodEngine.admitted` |
| 4 | Boot `runServerpodBeakAdmin` and sign in |

## The panel package

```yaml
serverpod:
  server: ../../server
  models: [lib/src]
  migrations: migrations
generate:
  output: generated
  inventory: definitions/resources
  prefix: Shop
  areas:
    catalog: {read: readCatalog, write: writeCatalog}
  writes: [configuration, catalog]
```

`generated/` is a pure-Dart package whose `lib/` only `beak generate` writes;
`definitions/` holds the inventory and the authored behavior. Both are workspace
members.

## The reviewed inventory

```yaml
area: catalog
resources:
  Book:
    display: title
    operations: [read, create, update]
    write: configuration
    writeFields: [title, isbn, authorId]
```

A write names a `write` binding and the columns it may change. A read-only model
names a `reason:`. The generator refuses a mismatch before writing anything.

## The server side

```dart title="server/lib/src/beak/shop_beak_engine.dart"
final shopBeak = BeakServerpodEngine.admitted(
  models: shopModels,
  definitions: shopDefinitions,
  principal: BeakServerpodPrincipal.fromScopes,
  writes: BeakWriteBindings<ShopWrite>(
    (binding) => switch (binding) {
      ShopWrite.configuration => const BeakWriteHandler.stock(),
    },
  ),
);
```

`models` and `ShopWrite` come from the generated package; `shopDefinitions`
comes from the definitions package. The endpoint keeps its own sign-in and
scope gate and returns `shopBeak.dispatch(session, request)`.

A write that belongs to a use case uses `BeakWriteHandler.commands`; see
[Writes, commands and trees](write-bindings.md).

## The panel

```dart
Future<void> main() => runServerpodBeakAdmin<Client>(
  apiUrl: getServerUrl,
  client: (url) => Client(url),
  initialize: (client) => client.auth.initialize(),
  dispatch: (client) => client.beakAdmin.dispatch,
  roles: (client) async =>
      client.authSessionManager.authInfo?.scopeNames ?? const <String>{},
  panelRole: 'beak.admin',
  config: (auth) => BeakPanelConfig(
    title: 'Shop',
    resources: [
      BeakResource.standard(const BookModel(), 'Books'),
    ],
    auth: BeakAuthConfig(adapter: auth),
  ),
);
```

`runServerpodBeakAdmin` installs path-based URLs, restores the session, resolves
the roles and builds the tunnel data source.

## Rules and limits

- Generated code is never edited. Change the model, the migration or the
  inventory and run `beak generate`.
- The server enforces permissions; the panel only decides what to offer.
- Every write is stock persistence, a trusted stamp, or an existing use case.
  A model whose use cases own every change uses `otherwise: BeakUnmatched.refuse`.

## Verify it

- `beak generate --check` passes.
- `dart analyze` is clean in the generated package, the definitions and the server.
- The panel signs in, lists the model, and one write reaches its use case.

## Reference

- [Generating the schema package](generate.md): the inputs and the review rules.
- [How the admin app works](how-it-works.md): the request path.
- `examples/serverpod/bookshop_admin`: the reference workspace.

## Continue reading

- [Writes, commands and trees](write-bindings.md): connect a write to a use case.
- [Limits and next steps](limits-and-next-steps.md): what the path does not cover.
