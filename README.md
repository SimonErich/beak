# Beak

[![CI](https://github.com/SimonErich/beak/actions/workflows/ci.yaml/badge.svg)](https://github.com/SimonErich/beak/actions/workflows/ci.yaml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
![Dart](https://img.shields.io/badge/Dart-%5E3.11-0175C2?logo=dart)
![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.41-02569B?logo=flutter)

Beak is the toolbox for the admin panel that almost every Dart or Flutter app
grows eventually. You declare a model once, as an annotated Dart class, and
`beak prepare` generates the typed field references, the migration, a Shelf REST
API and a Flutter panel with the table, the form, the detail page, the filters
and the CSV export. The panel is built on obers_ui with no Material, and nobody
writes an endpoint, a string field reference or a `dynamic`.

> [!IMPORTANT]
> Beak is pre-1.0 and `0.9.0` is not tagged yet, so two things are rough today.
> A plain `beak create` pins `ref: v0.9.0`, which `pub get` cannot resolve until
> the tag exists: use `beak create --beak-path <repo root of a checkout>` (an
> absolute path, and `packages/beak` is appended) or `--beak-ref <branch>`.
> And the panel needs an obers_ui commit that is not pushed yet: the pin in the
> pubspecs is older than the code, so a project resolved from it does not compile
> `beak_frontend`. [Getting it running today](#getting-it-running-today) says what
> works meanwhile.

## One definition

This is a whole resource, the file `beak create` writes:

```dart title="examples/quickstart/lib/resources/notes/models/note.dart"
/// A note.
///
/// Declared once. `beak prepare` generates the typed columns, the model, the
/// relationships (both sides), and a typed record view into `note.beak.dart`,
/// so there is no registry to edit.
@Resource(timestamps: true)
final class Note extends BeakSchema {
  /// What the note is called.
  ///
  /// Non-nullable, so it is required: the form validator, the API and the
  /// schema all derive that from the type rather than restating it.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(255)])
  late final String title;

  /// The note itself.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? body;

  /// Whether the note is pinned to the top of the list.
  @Column(filterable: true)
  late final bool pinned;
}
```

The field's Dart type picks the column, and its nullability decides
required-ness once, for the form validator, the API and the database. A field
then feeds six mouths: the table cell, the form input (validating exactly as the
server does), the detail row, the filter, the API's validation and the CSV
column. You reference it as `NoteModel.title`, never as a string.

`beak prepare` writes what you do not want to write: the model part file
(`note.beak.dart`), the create-table migration, four wiring files in
`lib/beak/`, and the three entrypoints `lib/main.dart`, `bin/serve.dart` and
`bin/migrate.dart`. Migrations are explicit files that `beak migrate` runs by
name; Beak never alters a database on boot.

## Two ways to boot a panel

Both are supported, and `beak eject main` is the switch.

**Generated** is the default. `lib/main.dart` boots a panel `beak prepare` builds
from every model, each with a default resource presented as `beak.yaml` says.
A `BeakResource` subclass you write under `lib/` replaces the default of its
model. `beak prepare` rewrites `lib/main.dart`, so it is git-ignored.

**Authored** hands you the entrypoint: `beak create --authored`, or `beak eject
main` on an existing project. `lib/main.dart` becomes a
`BeakPanel(resources: [...])` that `beak prepare` never rewrites. This is what
`beak create --authored` writes for the resource above:

```dart title="lib/resources/notes/note_resource.dart"
/// How the panel presents notes: its table, filters, actions and pages.
///
/// The panel shows it once the `resources: [...]` list in `lib/main.dart`
/// includes it, and every `BeakResource` option set here shows up there.
final class NoteResource extends BeakResource {
  /// Creates the notes resource.
  const NoteResource()
    : super(
        model: const NoteModel(),
        icon: const BeakIconToken(OiIcons.fileText),
        navigationGroup: 'Content',
      );
}
```

```dart title="lib/main.dart"
/// Boots the panel.
void main() => runApp(buildPanel());

/// The panel, and every resource it shows.
///
/// This file is yours: `beak prepare` never rewrites it, so add each
/// resource class you write to `resources`.
///
/// [dataSource] replaces the HTTP-backed source, so a widget test
/// can pump this exact panel against an in-memory one.
BeakPanel buildPanel({BeakDataSource? dataSource}) => BeakPanel(
  title: 'Acme Admin',
  resources: [const NoteResource()],
  dataSource: dataSource,
);
```

Leave `screens` out of a resource and Beak derives the table, the form and the
detail page from the model. Add `BeakTableScreen`, `BeakFormScreen` or
`BeakWizardScreen` when you want to shape them. The
[shop](examples/clean_beak_config) is the worked example of that.

## Install and run

You need Dart `^3.11` and Flutter `3.41` or newer. There is no database to
install: a new project uses a SQLite file.

```console
$ git clone https://github.com/SimonErich/beak.git
$ dart pub global activate --source path beak/packages/beak_cli
$ beak --version
beak 0.9.0
$ beak create acme_admin --beak-path "$PWD/beak"
$ cd acme_admin
$ beak migrate
$ beak dev
  1 model · 0 resource classes · 0 screens · 0 overrides
  generated  up to date (7 files)
  panel      run this in another terminal:
               flutter run -d chrome
  api        starting…
```

`beak create` writes ten files (a pubspec, `beak.yaml`, the `Note` schema, a
`main.dart`, `.gitignore`, analysis options, `AGENTS.md`, `CLAUDE.md`, a widget
test and a README) and Flutter's `web/` folder, runs `flutter pub get` and
`beak prepare`, and installs the agent files, so the project is runnable as
created. `beak dev` regenerates the
wiring and serves the API on `:8080`; the panel is the `flutter run` line it
prints, in a second terminal. Set `DATABASE_URL` for Postgres instead of the
SQLite file. `beak doctor` checks the setup.

### Getting it running today

The server side needs nothing from obers_ui: `beak create`, `beak prepare`,
`beak migrate` and `beak dev` (the API) work as shown above, and `beak_core`,
`beak_backend` and `beak_cli` do not depend on it. The panel does, because
`beak_frontend` builds on obers_ui components (`OiFilterChip`, `OiPageLayout`,
`OiCapacityIndicator` and more) that the pinned commit lacks and that no public
obers_ui commit has yet. Until obers_ui publishes them and the pin moves, the
panel compiles only against an obers_ui checkout that already has them.

If you have one, put it next to the project, add a `pubspec_overrides.yaml`
beside its `pubspec.yaml` and run `flutter pub get`:

```yaml
dependency_overrides:
  obers_ui:
    path: ../obers_ui
  obers_ui_autoforms:
    path: ../obers_ui/packages/obers_ui_autoforms
  obers_ui_charts:
    path: ../obers_ui/packages/obers_ui_charts
```

With that in place a fresh `beak create` project passes its own `flutter test`.
Inside this repository `melos run link-obers-ui` does the same for every package
and example.

## Packages

An app depends on one package, `beak`. The rest is what it is built from, and a
few opt-in extras.

| Package | What it is |
| --- | --- |
| [`beak`](packages/beak) | The umbrella. One dependency, eight libraries (`beak.dart`, `schema.dart`, `panel.dart`, `server.dart`, `migrations.dart`, `testing.dart`, `ui.dart`, `charts.dart`) that keep Flutter out of the server and `dart:io` out of the panel. |
| [`beak_core`](packages/beak_core) | Pure Dart: the schema annotations, typed columns and rules, relationships, the serializable `BeakQuerySpec`, the storage abstraction, the `BeakDataSource` seam, and the docs bundle agents read. |
| [`beak_backend`](packages/beak_backend) | The Shelf server: generated CRUD, query, relation, aggregate and summary endpoints, graph commits with an outbox, uploads, auth, export, and the typed deny-by-default policy DSL. Over the worm ORM. |
| [`beak_frontend`](packages/beak_frontend) | The Flutter panel: `BeakPanel`, tables, forms, wizards, detail pages, blocks and charts on obers_ui. HookWidget, Signals, GetIt, go_router. |
| [`beak_cli`](packages/beak_cli) | The `beak` command: `create`, `init`, `prepare`, `dev`, `migrate`, `seed`, `introspect`, `eject`, `doctor`, `agents`, `docs`, `make:*`. |
| [`beak_test`](packages/beak_test) | `InMemoryBeakDataSource`, `BeakRecordingDataSource`, the executable data-source contract, record factories. |
| [`beak_image`](packages/beak_image) | The image transform runner behind image columns. |
| [`beak_storage_s3`](packages/beak_storage_s3), [`beak_storage_ftp`](packages/beak_storage_ftp) | Storage drivers for S3 or MinIO and for FTP. `memory` and `local` ship in `beak_core`. |
| [`beak_serverpod_server`](packages/beak_serverpod_server) | Runs Beak's API inside a Serverpod 4 server, behind one gated endpoint, on Serverpod's own database. |
| [`beak_serverpod`](packages/beak_serverpod) | The tunnel envelope and HTTP client behind the admin app, and the client bridge: `ServerpodResource` and codecs over an existing Serverpod client. |
| [`beak_serverpod_flutter`](packages/beak_serverpod_flutter) | The Serverpod side of the panel: the tunnel client and Beak's login, registration and recovery screens over Serverpod's email sign-in. |
| [`beak_serverpod_generator`](packages/beak_serverpod_generator) | Generates typed bridge resources from a Serverpod client. |

The [worm](packages/worm) ORM and its drivers are vendored under `packages/worm*`
(the bird has to eat something). Beak's packages are versioned in lockstep, all at
`0.9.0`, and none is on pub.dev yet. [Packages](https://simonerich.github.io/beak/reference/packages/)
in the docs says which one owns which type.

## Examples

Each example is a package of its own. `melos bootstrap` resolves all of them except `serverpod`, which is a Serverpod workspace with its own resolution.

| Example | What it shows | API |
| --- | --- | --- |
| [`quickstart`](examples/quickstart) | Exactly what `beak create` writes, checked in and held byte-identical by a test. One model, generated panel. | `:8080` |
| [`clean_beak_config`](examples/clean_beak_config) | The shop: eleven resources with exact `BeakDecimal` money, form screens and sections, named invoice actions, dynamic attributes and variants, media galleries, imports, a graph preparer and custom widgets. | `:8080` |
| [`foodio-adminpanel`](examples/foodio-adminpanel) | The Gabel food-ordering admin with 48,213 demo orders: composed lists with presets and saved views, a wizard with named steps, record templates, summaries, printable documents, durable effects, its own theme. | `:8081` |
| [`showcase`](examples/showcase) | The Aviary: every block type, column kind and relationship kind Beak has, with soft deletes. Three tests fail when Beak grows one the example does not show. | `:8082` |
| [`serverpod`](examples/serverpod) | A Serverpod 4.0.3 workspace with a Beak admin for `Author` and `Book`, running inside the Serverpod server. Outside melos. | `:8080` |

The four Beak-only examples run the same way. From an example's directory:

```console
$ dart run ../../packages/beak_cli/bin/beak.dart prepare
$ dart run bin/migrate.dart migrate
$ dart run bin/migrate.dart db:seed      # shop, foodio and showcase
$ dart run bin/serve.dart
```

Then start the panel with `flutter run -d chrome` in a second terminal. Each
panel defaults to its own example's port, and
`--dart-define=BEAK_API_BASE_URL=<origin>` points it elsewhere. Foodio reads its
port and database from `.env` (`cp -n .env.example .env`); the showcase sets its
port in `beak.yaml`. Each example's README has its own flags, web port and tests.

## Serverpod

You have a Serverpod 4 project and someone asks for an admin panel. Beak has two
ways in, and they differ in where Beak's code runs.

- **Admin app in your workspace.** A `<name>_admin` Flutter web app and a pure
  Dart `<name>_beak` schema package join your pub workspace, and Beak's REST API
  runs inside the Serverpod server behind one gated endpoint: `requireLogin` plus
  the `beak.admin` scope, deny by default, on Serverpod's own database session.
- **Client bridge.** A Beak panel over endpoints you already have, through your
  generated client, with `beak_serverpod_generator` writing the resources. No
  server change, and a smaller feature set: equality filters, one sort, one
  search, no relations, no atomic saves.
- Tested against Serverpod 4.0.3 only. The admin app is a proof on two tables, not
  a product; the [Serverpod section](https://simonerich.github.io/beak/serverpod/)
  lists every gap with its workaround.

## Working with AI agents

An agent's training data is older than the Beak it is asked to write.
`beak create`, `beak init` and `beak prepare` keep a small managed block in
`AGENTS.md` (between `<!-- BEGIN:beak-agent-rules -->` and
`<!-- END:beak-agent-rules -->`, nothing else in the file is touched) plus a
`CLAUDE.md` that imports it. The block points the agent at the docs of the Beak
version the project resolved.

```console
$ beak docs            # copy that version's docs to .dart_tool/beak/docs
$ beak agents          # AGENTS.md block, CLAUDE.md, docs and workflow skills
$ beak agents --check  # exit 1 while any of it is out of date, write nothing
```

The docs bundle ships inside `beak_core` (`doc/agent-docs`, built by
`melos run agent-docs`) with `ai-index.md` as the entry point that routes a task
to a page and lists the APIs an agent probably remembers wrong. Eight workflow
skills come with it: `beak-add-resource`, `beak-evolve-schema`,
`beak-adopt-database`, `beak-add-business-rule`, `beak-secure-api`,
`beak-upgrade`, `beak-frontend-build-screens` and `beak-serverpod-setup`. The
published site serves [`/llms.txt`](https://simonerich.github.io/beak/llms.txt),
`/llms-full.txt` and a Markdown twin of every page. This repository has its own
[AGENTS.md](AGENTS.md) for contributors.

## Development

Melos is pinned to `6.3.3`; version 7 dropped `melos.yaml`.

```console
$ dart pub global activate melos 6.3.3
$ melos bootstrap
$ melos run analyze        # 0 issues; also the Material, web-safety, docs and example guards
$ melos run test           # every package, e2e excluded
$ melos run coverage       # per-package line-coverage thresholds
$ melos run format-check
$ melos run up             # Postgres and MinIO, for the service-backed suites
$ melos run test-e2e
```

`melos run coverage` reads existing `lcov.info` files and does not regenerate
them, so delete stale `packages/*/coverage` first. After a change to `docs/`, a
file a page quotes, or this changelog, run `melos run agent-docs` and commit the
bundle; `melos run check-agent-docs` fails when it is stale.

`beak` and `beak_frontend` depend on obers_ui by pinned git commit
(`c956d25634c93e23847ec5a4150c1d62fe3a7c90`), so `melos bootstrap` needs that
commit to be fetchable from `github.com/SimonErich/obers_ui`, and a bootstrap
that resolves is not yet a build that compiles. The commit is fetchable, but it
predates components `beak_frontend` uses (`OiFilterChip`, `OiPageLayout`,
`OiCapacityIndicator`, `OiFieldLabel`, `OiIcon.raw` and more), and the obers_ui
state that has them is not published. Until it is, and the pin moves to it, you
work against a local checkout that has them. With such a checkout next to this
repository (`../obers_ui`), run:

```console
$ melos run link-obers-ui
```

`melos run link-obers-ui -- --unlink` does not unlink, because melos 6.3.3 appends
the flag to the end of the whole script. Use this instead:

```console
$ dart run tool/link_obers_ui.dart --unlink && melos bootstrap
```

Unlink before you tag a release; the lockfiles of `clean_beak_config` and
`foodio-adminpanel` are tracked and record a linked state while you are linked.
[Working with obers_ui](https://simonerich.github.io/beak/contributing/working-with-obers-ui/)
has the rest.

## Documentation

The site at <https://simonerich.github.io/beak/> is built from [`docs/`](docs)
with MkDocs Material.

- [Start](https://simonerich.github.io/beak/start-here/quickstart/): what Beak
  is, install, the quickstart, and the paths for a new project, an existing
  database, an existing Flutter app or an existing Serverpod project.
- [Learn](https://simonerich.github.io/beak/tutorial/): the tutorial, the
  examples, and the concepts behind the one-definition promise.
- [Guides](https://simonerich.github.io/beak/guides/): models, the panel, forms,
  blocks, theming, the backend, extending Beak, testing and recipes.
- [Reference](https://simonerich.github.io/beak/reference/): annotations, columns,
  rules, builders, REST routes, exceptions, `beak.yaml` and every CLI command.
- [Deployment](https://simonerich.github.io/beak/shipping/going-to-production/):
  the Docker setup under [`deploy/`](deploy).
- [Contributing](https://simonerich.github.io/beak/contributing/) and the
  [architecture](https://simonerich.github.io/beak/architecture/) pages.

Preview it locally with the pinned toolchain: `python3 -m venv ~/.venvs/beak-docs
&& ~/.venvs/beak-docs/bin/pip install -r docs/requirements.txt`, then
`~/.venvs/beak-docs/bin/mkdocs serve`. Every public API also carries dartdoc.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, the gate and the code
guardrails, and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Report vulnerabilities
privately as [SECURITY.md](SECURITY.md) describes. What changed between versions:
[CHANGELOG.md](CHANGELOG.md).

## License

[Apache-2.0](LICENSE) © Marqably GmbH.
