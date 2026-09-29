# Setting up the admin app

> Add a Beak admin app to a Serverpod 4 workspace, register the gated endpoint on the server, declare two resources and sign in to a running panel.

You have a Serverpod 4 workspace with a couple of tables and no admin. After this page you have a `<name>_admin` app in that workspace, signed in with a Serverpod account, listing and editing rows of two tables through Beak. Every file below is the example's own (`examples/serverpod`, project name `bookshop`); rename `bookshop` to your project.

## What you'll build

Two new packages and a handful of server files:

- `bookshop_beak`, a pure Dart package with one Beak schema class per table.
- `lib/src/beak/` in `bookshop_server`: a receipts model, the scopes, a policy, an engine and one endpoint.
- `bookshop_admin`, a Flutter web app with a `BeakPanel` and one `BeakResource` per table.
- A grant script, so a Serverpod account can be let into the panel.

Serverpod stays the owner of the tables, the migrations and the sign-in. You will not write a Beak migration or give Beak a database URL.

## Before you start

- A Serverpod project on exactly 4.0.3, created with `serverpod create`, as a pub workspace. Dart 3.12.2 or newer and Flutter 3.44.4 or newer (Serverpod 4.0.3's own floor).
- The `serverpod` CLI at 4.0.3. A globally activated CLI may be another release; the example ships a pinned one in `tool/serverpod_cli_4`.
- The `beak` CLI ([Installation](../../start-here/installation.md)).
- Beak's packages. Beak is not on pub.dev yet, so every Beak package comes from one git ref or one path. The example lives in the Beak repository and uses `path:`. Your workspace uses a git dependency, with the same `ref` on every Beak package:

  ```yaml
  # Illustrative: one entry like this per Beak package you depend on.
  beak_backend:
    git:
      url: https://github.com/SimonErich/beak.git
      ref: v0.9.0
      path: packages/beak_backend
  ```

- Two tables to show. The example has `author` and `book` (see `examples/serverpod/bookshop_server/lib/src/catalog/`). A workspace with Serverpod's template greeting only has no table to mirror yet.

## Build it

### 1. The schema package

Create a pure Dart package next to the server and add it to the root `pubspec.yaml` under `workspace:`. The example's root lists all five packages, two of them new:

```yaml title="examples/serverpod/pubspec.yaml"
name: _
publish_to: none

environment:
  sdk: '^3.12.2'

workspace:
  - bookshop_client
  - bookshop_server
  - bookshop_flutter
  - bookshop_beak
  - bookshop_admin
```

The new package depends on `beak_core` only, so the server can import it without dragging Flutter in.

```yaml title="examples/serverpod/bookshop_beak/pubspec.yaml"
name: bookshop_beak
description: >-
  Beak models for the bookshop (pure Dart, web-safe). Shared by
  bookshop_server and bookshop_admin; depends on beak_core only.
publish_to: none

environment:
  sdk: '^3.12.2'

resolution: workspace

dependencies:
  beak_core:
    path: ../../../packages/beak_core

dev_dependencies:
  lints: '>=3.0.0 <7.0.0'
```

Now mirror each table. Here is the Serverpod model and its Beak schema class side by side.

```yaml title="examples/serverpod/bookshop_server/lib/src/catalog/book.spy.yaml"
### A title the shop stocks.
class: Book
table: book
fields:
  ### The title printed on the cover.
  title: String

  ### The ISBN, unique per edition.
  isbn: String, unique

  ### How the book is bound.
  format: BookFormat

  ### Shelf price in cents.
  priceInCents: int

  ### Copies on the shelf.
  stock: int, default=0

  ### First publication date.
  publishedOn: DateTime?

  ### What the shop pays the supplier. Never leaves the server: it is not
  ### in the generated client, and the Beak model does not declare it.
  supplierCostInCents: int?, scope=serverOnly

  ### Who wrote it.
  author: Author?, relation(onDelete=Cascade)
```

```dart title="examples/serverpod/bookshop_beak/lib/models/book.dart"
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/schema.dart';

import 'author.dart';
import 'book_format.dart';

part 'book.beak.dart';

/// A title the shop stocks.
///
/// Describes the Serverpod table `book`. The server-only supplier cost column
/// is deliberately not declared here: what Beak does not model never leaves
/// the server through Beak.
@Resource(table: 'book', managesSchema: false)
final class Book extends BeakSchema {
  /// Serverpod's serial id, assigned by the database.
  @Column(visibleOn: {BeakContext.detail})
  late final int? id;

  /// The title printed on the cover.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(200)])
  late final String title;

  /// The ISBN, unique per edition.
  @Column(label: 'ISBN', searchable: true, unique: true)
  late final String isbn;

  /// How the book is bound.
  @Column(filterable: true)
  late final BookFormat format;

  /// Shelf price in cents.
  @Column(
    columnName: 'priceInCents',
    label: 'Price in cents',
    sortable: true,
    rules: [BeakMin(0)],
  )
  late final int priceInCents;

  /// Copies on the shelf.
  @Column(sortable: true, defaultValue: 0, rules: [BeakMin(0)])
  late final int stock;

  /// First publication date.
  @Column(
    columnName: 'publishedOn',
    label: 'Published',
    format: BeakDateFormat.dateOnly,
    sortable: true,
  )
  late final DateTime? publishedOn;

  /// Who wrote it.
  @BelongsTo(
    foreignKey: 'authorId',
    onDelete: BeakOnDelete.cascade,
    inverse: false,
  )
  late final Author author;
}
```

The mapping the example follows:

| In the `.spy.yaml` model | In the Beak schema class |
| --- | --- |
| `class: Book`, `table: book` | `@Resource(table: 'book', managesSchema: false)`: Serverpod owns the schema, so Beak never migrates it |
| The serial `id`, which Serverpod adds itself | Declare `late final int? id;` yourself so Beak uses the integer key |
| `title: String` | `late final String title;` (not nullable means required) |
| `bio: String?` | `late final BeakText? bio;` for long text, `String?` for short |
| `priceInCents: int` | `@Column(columnName: 'priceInCents')`: Serverpod's physical columns keep their camelCase, Beak's default is snake_case |
| `format: BookFormat` | A Dart enum with the same value names in its own file (below) |
| `author: Author?, relation(...)` | `@BelongsTo(foreignKey: 'authorId', ...)` on the child, `@HasMany(foreignKey: 'authorId')` on the parent |
| `isbn: String, unique` | `@Column(unique: true)` |
| `stock: int, default=0` | `@Column(defaultValue: 0)` |
| `supplierCostInCents: int?, scope=serverOnly` | Nothing. A column the schema class does not declare never leaves the server through Beak |

The enum must list the same names as the Serverpod one. The `.spy.yaml` states `serialized: byName` (the 4.0.3 default), and Beak's enum column stores the value name, so an enum serialized by index would not match its integer column.

```dart title="examples/serverpod/bookshop_beak/lib/models/book_format.dart"
/// How a book is bound (or not bound at all).
///
/// Mirrors the Serverpod enum `BookFormat` (`book_format.spy.yaml`, stored by
/// name). Keep the two lists identical: the value names are what the database
/// holds.
enum BookFormat {
  /// A paperback edition.
  paperback,

  /// A hardcover edition.
  hardcover,

  /// A digital edition.
  ebook,
}
```

The barrel hides `Author` and `Book`, because those are also the names of the Serverpod protocol classes, and code that needs both imports the protocol with a prefix. Everyone else uses the generated `AuthorModel`, `BookModel` and `buildBeakRegistry()`.

```dart title="examples/serverpod/bookshop_beak/lib/bookshop_beak.dart"
/// Beak models of the bookshop (pure Dart, web-safe).
///
/// The schema classes `Author` and `Book` are hidden: their names are the
/// Serverpod protocol classes' names, and code that needs both imports the
/// protocol with a prefix. Use the generated `AuthorModel` and `BookModel`
/// (typed field references), and `buildBeakRegistry()` for the server.
library;

export 'beak/registry.g.dart';
export 'models/author.dart' hide Author;
export 'models/book.dart' hide Book;
export 'models/book_format.dart';
```

Resolve the workspace with `dart pub get` at the root, then generate the parts from inside the package:

```console
$ beak prepare
  2 models · models-only package
  generated  3 of 3 files
  agents     skipped: models-only package (beak_core without an app): no Beak app here, nothing to do
```

In a package that depends on `beak_core` alone, `beak prepare` writes the `*.beak.dart` parts and `lib/beak/registry.g.dart` and nothing else. If it also creates `bin/` or `lib/beak/app.g.dart`, your CLI is older than this release.

### 2. The server

Add the dependencies to `bookshop_server/pubspec.yaml`. The Beak packages come from the same ref, the `serverpod*` packages keep the exact version the project already pins.

```yaml title="examples/serverpod/bookshop_server/pubspec.yaml"
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

For the tests, `dev_dependencies` add `beak_core`, `beak_serverpod`, `beak_test`, `worm` and `worm_postgres` the same way.

Beak's graph commits keep receipts, and Serverpod's migrations must own the receipts table. Copy Beak's model file verbatim and do not edit it:

```yaml title="examples/serverpod/bookshop_server/lib/src/beak/models/beak_commit_receipt.spy.yaml"
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

Then four small files. The scopes first: `beak.admin` opens the tunnel, `bookshop.staff` is what your policy reads.

```dart title="examples/serverpod/bookshop_server/lib/src/beak/bookshop_scopes.dart"
/// The scopes of the bookshop admin, kept in one place like Serverpod's
/// `Scope.admin`.
///
/// `beak.admin` only opens the Beak tunnel. What an admin may then do is
/// decided by the policy, and the policy reads the other scopes.
abstract final class BookshopScopes {
  /// Opens the Beak tunnel (`beak.admin`); the gate on `BeakAdminEndpoint`.
  static const Scope admin = BeakScopes.admin;

  /// May read and write authors and books in the admin.
  static const Scope staff = Scope('bookshop.staff');
}
```

The policy names every model and every operation it allows. Anything it does not name is closed.

```dart title="examples/serverpod/bookshop_server/lib/src/beak/bookshop_policy.dart"
/// Who may do what in the bookshop admin.
///
/// Deny by default: holding `beak.admin` opens the tunnel and grants nothing.
/// Staff (the `bookshop.staff` scope) read and write authors and books.
/// Nobody may delete: a rule that is not written is a rule that is closed, so
/// removing an author (and, by cascade, their books) needs a deliberate rule.
final BeakPolicies bookshopPolicy = BeakPolicies(
  rules: [
    BeakModelRules(const AuthorModel(), read: _staff, write: _staff),
    BeakModelRules(const BookModel(), read: _staff, write: _staff),
  ],
);

final BeakAccess _staff = BeakAccess.role(BookshopScopes.staff.name!);
```

The engine, one per process, and the endpoint, one method:

```dart title="examples/serverpod/bookshop_server/lib/src/beak/bookshop_beak_engine.dart"
/// The bookshop's Beak engine: one per process, shared by every request.
///
/// It serves Beak's stock API for the models in `bookshop_beak` on the
/// request's own Serverpod session, so every statement runs on Serverpod's
/// database with its transactions and logging.
final BeakServerpodEngine bookshopBeak = BeakServerpodEngine(
  registry: buildBeakRegistry(),
  policy: bookshopPolicy,
);
```

```dart title="examples/serverpod/bookshop_server/lib/src/beak/beak_admin_endpoint.dart"
/// The Beak admin tunnel: one method, gated by [BeakAdminGate] (a signed-in
/// user holding the `beak.admin` scope) before any Beak code runs.
class BeakAdminEndpoint extends Endpoint with BeakAdminGate {
  /// Runs one Beak request (envelope v1) and returns the response envelope.
  Future<String> dispatch(Session session, String request) =>
      bookshopBeak.dispatch(session, request);
}
```

The grant script is `bin/beak_admin.dart`. Copy it from the example and rename the imports; [Authentication and scopes](../authentication.md) explains what it does. It shares the sign-in setup with the server, so move the template's `pod.initializeAuthServices(...)` call from `run` into a top-level function that both call:

```dart title="examples/serverpod/bookshop_server/lib/server.dart"
void initializeBookshopAuth(Serverpod pod) {
  pod.initializeAuthServices(
    tokenManagerBuilders: [
      // Use JWT for authentication keys towards the server.
      JwtConfigFromPasswords(),
    ],
```

Generate the client and write the migration, from inside `bookshop_server`:

```console
$ serverpod generate
$ serverpod create-migration --tag bookshop
```

`serverpod generate` adds `client.beakAdmin.dispatch` to `bookshop_client`. `serverpod create-migration` writes the SQL for the receipts table, next to any table you changed:

```sql title="examples/serverpod/bookshop_server/migrations/20260929023756894-bookshop/migration.sql"
CREATE TABLE "beak_commit_receipt" (
    "id" bigserial PRIMARY KEY,
    "receiptKey" text NOT NULL,
    "requestHash" text NOT NULL,
    "requestJson" text NOT NULL,
    "resultJson" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### 3. The admin app

Create a Flutter web app inside the workspace and add it to the root `workspace:` list. Add `resolution: workspace` to its pubspec, which `flutter create` does not.

```console
$ flutter create --platforms=web --empty --no-pub bookshop_admin
```

The pubspec is short. The `serverpod_*` lines carry the exact version the workspace already pins.

```yaml title="examples/serverpod/bookshop_admin/pubspec.yaml"
name: bookshop_admin
description: Beak admin panel for the bookshop (Flutter web).
publish_to: none
version: 0.1.0

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

dev_dependencies:
  beak_backend:
    path: ../../../packages/beak_backend
  beak_core:
    path: ../../../packages/beak_core
  flutter_test:
    sdk: flutter
  http: ^1.6.0
  lints: '>=3.0.0 <7.0.0'
  postgres: ^3.5.16
  serverpod_auth_core_client: 4.0.3
  shelf: ^1.4.2
  signals: ^6.3.0
  worm:
    path: ../../../packages/worm
```

`main` builds the Serverpod client, gives it the session manager, wraps both in `ServerpodAuthAdapter` and hands the generated `dispatch` to the panel. The client gets a 60 second `connectionTimeout` because the CSV export travels through the same call.

```dart title="examples/serverpod/bookshop_admin/lib/main.dart"
/// The bookshop admin: Serverpod's email login through Beak's auth screens,
/// and every panel request tunnelled through the generated
/// `client.beakAdmin.dispatch`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionManager = FlutterAuthSessionManager();
  final Client client =
      Client(
          await getServerUrl(),
          // Buffered CSV export rides the tunnel too; the 20 second default
          // is for ordinary calls.
          connectionTimeout: const Duration(seconds: 60),
        )
        ..connectivityMonitor = FlutterConnectivityMonitor()
        ..authSessionManager = sessionManager;
  // Restores the stored session and refreshes its access token if needed.
  await client.auth.initialize();
  final auth = ServerpodAuthAdapter(
    client: client,
    sessionManager: sessionManager,
    resolveIdentity: bookshopAdminIdentity(sessionManager),
  );
  await auth.initialize();
  runApp(bookshopAdminPanel(dispatch: client.beakAdmin.dispatch, auth: auth));
}
```

The panel takes Beak's login screens, the resources and one data source:

```dart title="examples/serverpod/bookshop_admin/lib/src/bookshop_admin.dart"
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
```

`dataSource:` is the tunnel. It is not a test seam here: with an external authentication adapter the panel registers no HTTP client of its own, so it needs this. The identity resolver keeps a signed-in customer without the scope on the sign-in screen, instead of in an empty shell of 403s:

```dart title="examples/serverpod/bookshop_admin/lib/src/bookshop_admin.dart"
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
```

A resource is what any Beak resource is: typed references from the generated model, no string field names.

```dart title="examples/serverpod/bookshop_admin/lib/resources/author_resource.dart"
final class AuthorResource extends BeakResource {
  /// Creates the Authors section.
  AuthorResource()
    : super(
        model: const AuthorModel(),
        title: 'Authors',
        filters: [AuthorModel.name.textFilter()],
        screens: [
          BeakTableScreen(fields: [AuthorModel.name, AuthorModel.website]),
          BeakFormScreen(
            roles: const {
              BeakScreenRole.read,
              BeakScreenRole.create,
              BeakScreenRole.edit,
            },
            layout: BeakFormLayout(
              children: [
                AuthorModel.name.inputText(),
                AuthorModel.website.inputText(),
                AuthorModel.bio.inputText(maxLines: 6),
              ],
            ),
          ),
        ],
      );
}
```

`BookResource` in the same folder adds a relation filter and a combobox for the author. Both are listed in `bookshopResources()`.

## Run it

The example needs no Docker: `dart run bin/main.dart --apply-migrations` starts an embedded Postgres. Use `dart run`, not `dart bin/main.dart`, because only `dart run` builds the Argon2 native asset the email sign-in needs.

```console
# 1. In examples/serverpod: resolve the whole workspace.
dart pub get

# 2. Local secrets (git-ignored).
cp bookshop_server/config/passwords.example.yaml bookshop_server/config/passwords.yaml

# 3. Terminal 1: the server, on an embedded Postgres.
cd bookshop_server && dart run bin/main.dart --apply-migrations

# 4. Terminal 2: the admin.
cd bookshop_admin && flutter run -d chrome --web-port 8095
```

In the admin, choose "Create account". In development the server log doubles as the mail server: it prints the verification code (`Registration code for you@example.com: <code>`), so paste it from there. The new account can sign in and still cannot open the panel. Let it in from a third terminal, then sign in again:

```console
cd bookshop_server && dart run bin/beak_admin.dart grant you@example.com
```

Scopes are copied into a token when it is issued, so the sign-in after the grant is not optional.

> **Note: What just happened**
>
> - The grant added `beak.admin` (opens the tunnel) and `bookshop.staff` (your policy's role) to the account's Serverpod scopes.
> - Every list, form and filter in the panel is now a `client.beakAdmin.dispatch` call: one string in, one string out, gated by Serverpod before any Beak code runs.
> - A form save is a graph commit on one Serverpod transaction. Its receipt is a row in `beak_commit_receipt`.

> **Question: What this skipped**
>
> - Why the request path is safe: [How the admin app works](how-it-works.md).
> - What a revoke does and when it bites: [Authentication and scopes](../authentication.md).
> - The gaps: [Limits and next steps](limits-and-next-steps.md).

## Checkpoint

You are done when all of these hold:

- The sidebar shows Books and Authors, and the Books table lists each book with its author's name.
- Filtering by author, format and price narrows the table. Creating a book from the form saves it. (Replaying a commit with the same save id, as a retry after a lost response does, inserts nothing twice; the server test does exactly that.)
- An account without `beak.admin` stays on the sign-in screen after a correct password, and an account with only `beak.admin` gets 403 from every table.
- Deleting a book is refused with a 403 by the server. `BeakResource.canDelete` defaults to true and the example leaves it, so nothing in the panel hides the action; add `canDelete: false` for that.

The example proves these with tests, and you can run them without starting anything:

```console
cd bookshop_server && dart test     # embedded Postgres, no Docker
cd bookshop_admin && flutter test   # widget tests against a fake dispatch
```

Both suites pass on the example. The server suite drives the real endpoint, gate, policy and database. The widget tests run Beak's real handlers over an in-memory database behind a fake `dispatch`.

> **Tip: Coding agents**
>
> Run `beak agents` in `bookshop_admin`. It writes an `AGENTS.md` block for a Serverpod admin (the layout, the loop after a model change, what never to edit), copies these docs to `.dart_tool/beak/docs` and installs the workflow skills, including `beak-serverpod-setup`, which walks an agent through the steps on this page.

## Continue reading

- [How the admin app works](how-it-works.md): the request path behind what you just built.
- [Authentication and scopes](../authentication.md): grants, revokes, token lifetimes and the sign-in flows.
- [Limits and next steps](limits-and-next-steps.md): what to fix before you plan on this for more than two tables.
