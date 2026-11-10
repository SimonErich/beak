# Setting up the admin app

> Add the Beak admin to a Serverpod 4 workspace, from the definition classes and their generated models to the gated endpoint and the signed-in panel.

After this page you have a Serverpod server that serves Beak's API behind one
gated endpoint and a Flutter admin whose models are generated from one
definition class per exposed Serverpod model. The reference workspace is
`examples/serverpod`.

## At a glance

| Step | What you do |
| --- | --- |
| 1 | Add `apps/<name>_admin` with `beak.yaml` and the `definitions` package |
| 2 | Write a definition class per exposed model and run `beak generate` |
| 3 | Mount `BeakAdminEndpoint` with `BeakServerpodEngine.admitted` |
| 4 | Boot `runServerpodBeakAdmin` and sign in |

## The panel package

```yaml title="examples/serverpod/bookshop_admin/beak.yaml"
serverpod:
  server: ../bookshop_server
  models: [lib/src]
  migrations: migrations

generate:
  definitions: definitions
  handlers: ../bookshop_server/lib/src/beak/generated
  prefix: Bookshop
  areas:
    catalog: {read: bookshop.staff, write: bookshop.staff}
```

`definitions/` is a pure-Dart package (`beak_core`, `beak_serverpod`) that both
the panel and the server depend on; it is a workspace member. `handlers` is a
folder inside the server.

## The definition classes

```dart title="examples/serverpod/bookshop_admin/definitions/lib/src/catalog/author.dart"
/// Someone whose books the shop sells.
@Resource()
@ServerpodModel(
  area: 'catalog',
  create: BeakHandling.stock,
  update: BeakHandling.stock,
)
final class Author extends BeakSchema {
  /// The name printed on the cover.
  @Display()
  late final String name;

  /// A short biography for the author page.
  late final String? bio;

  /// The author's own website.
  late final String? website;
}
```

The package barrel exports what `beak generate` writes:

```dart title="examples/serverpod/bookshop_admin/definitions/lib/bookshop_definitions.dart"
export 'src/generated/models.dart';
```

A write opens its operation on the class; a read-only model names a `reason:`.
The generator refuses a mismatch with Serverpod before writing anything
([Generating the admin from definition classes](generate.md)).

## The server side

```dart title="examples/serverpod/bookshop_server/lib/src/beak/bookshop_beak_engine.dart"
final BeakServerpodEngine bookshopBeak = BeakServerpodEngine.admitted(
  models: bookshopModels,
  handlers: const BookshopHandlers(book: BookAdminHandler()),
  principal: BeakServerpodPrincipal.fromScopes,
);
```

`bookshopModels` comes from the definitions package and `BookshopHandlers` from
the generated handler folder. Book's restock command runs through
`BookAdminHandler`; a model that opens custom code adds a required
argument ([Writes, commands and trees](write-bindings.md)). The endpoint keeps
its own sign-in and scope gate and returns
`bookshopBeak.dispatch(session, request)`.

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
  config: (context, auth) => BeakPanelConfig(
    title: 'Shop',
    resources: [BeakResource.standard(const BookModel())],
    auth: BeakAuthConfig(adapter: auth),
  ),
);
```

`runServerpodBeakAdmin` installs path-based URLs, restores the session, resolves
the roles and builds the tunnel data source. It calls `config` in a context
that holds `localizationsDelegates` for `locale`, so the panel's own copy is
read from `context`; model and field names come from the label files
([Labels in every language](../../panel/labels.md)).

## Rules and limits

- Generated code is never edited. Change the Serverpod model, the migration or
  the definition class and run `beak generate`.
- The server enforces permissions; the panel only decides what to offer.
- Every write is stock persistence, a derived stamp, or the model's handler
  calling an existing use case.

## Verify it

- `beak generate --check` passes.
- `dart analyze` is clean in the definitions package and the server.
- The panel signs in, lists the model, and one write reaches its stock path or
  its handler.

## Reference

- [Generating the admin from definition classes](generate.md): the classes and the checks.
- [How the admin app works](how-it-works.md): the request path.
- `examples/serverpod/bookshop_admin`: the reference workspace.

## Continue reading

- [Writes, commands and trees](write-bindings.md): connect a write to a use case.
- [Limits and next steps](limits-and-next-steps.md): what the path does not cover.
