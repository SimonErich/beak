---
title: Generating bridge resources
description: Generate typed bridge resources, field descriptors and codecs from your Serverpod client with beak_serverpod.yaml and one command, and keep them in step.
type: guide
audience: [expert]
status: stable
---

# Generating bridge resources

After this page you can point `beak_serverpod_generator` at your generated Serverpod client, get a ready-made `ServerpodResource` for each model, and regenerate it whenever an endpoint changes. Writing the binding by hand is on [Bridge resources](resources.md); the generator writes the same thing from the client's Dart types.

## At a glance

The generator reads the exported `Client` class and the model classes of your client package with the Dart analyzer. For every model you list, it finds the endpoint that lists it, the ones that read and write it, and the query and page DTOs around them, and writes one Dart file. It never writes to your server, never writes a migration and never opens a database.

Add the generator as a dev dependency and `beak_serverpod` (with `beak_core`) as a runtime dependency of the package that holds your panel. If a model has a `UuidValue`, add `uuid` too, because the generated file imports it. Generate Serverpod's client first, resolve packages, then run the generator.

The config lives next to your `pubspec.yaml`:

```yaml
# Illustrative: the config used against the generator's own test fixture.
library: package:example_client/example_client.dart
models:
  - EntryView
output: lib/beak/entry_resources.g.dart
```

```console
$ dart run beak_serverpod_generator:generate --config beak_serverpod.yaml
Generated /home/me/consumer/lib/beak/entry_resources.g.dart
```

That is the whole loop. The file it wrote, for that fixture, has `EntryViewFields` (a typed descriptor per property), `EntryViewFormSlot`, `EntryViewRelations`, `EntryViewCodec` and `EntryViewResource`, and the same companions for the query, page and input DTOs the endpoint refers to. Nothing in it is yours to edit.

Using the resource takes a client, a logical key, the primary-key descriptor and the columns you want to show. This compiles against the generated file (illustrative, not a file in the repository):

```dart
EntryViewResource(
  client: client,
  resource: 'entries',
  primaryKey: EntryViewFields.entryId,
  locale: currentLocale,
  columns: [
    EntryViewFields.entryTitle.column(
      'Title',
      options: const ServerpodColumnOptions(
        visibleOn: {BeakContext.table, BeakContext.detail},
        sortable: true,
        searchable: true,
      ),
    ),
    EntryViewFields.entryStatus.column(
      'Status',
      options: const ServerpodColumnOptions(
        visibleOn: {BeakContext.table, BeakContext.detail},
        filterable: true,
        enumLabels: {
          ResourceStatus.active: 'Active',
          ResourceStatus.paused: 'Paused',
        },
      ),
    ),
  ],
  permissions: BeakPermissions({
    BeakOperation.read: () => true,
    BeakOperation.update: () => false,
  }),
);
```

`resource` is a logical key you choose. `locale` appears only because the fixture's endpoint methods take a `locale` string; it is a required callback when they do. The generated resource binds `list`, `getById`, `create`, `update`, `archive` and `getMany` where the endpoint has them, and derives `count` from the list query's total. [Bridge resources](resources.md) says what the panel then accepts.

## Rules and limits

| Rule | Detail |
| --- | --- |
| Generation is structural | It maps Dart types and RPC signatures. Table names, authorization, validation, transactions and cleanup stay in Serverpod |
| It fails instead of guessing | An ambiguous or unsupported shape stops generation with a specific message, listed on [Endpoint conventions](endpoint-conventions.md) and [Troubleshooting](../troubleshooting.md) |
| Only the configured output is written | An unchanged file is left untouched. The command prints `Generated <path>` when it wrote the file and `Up to date <path>` when it did not |
| The client class is `Client` unless you name another | Set `client:` in the config or pass `--client` |
| The file imports models through your `library` | A type the configured library exports is imported from it, never from the client's `lib/src`, so the output passes `implementation_imports` |
| List models by their read type | `models:` produces a `<Model>Resource`. `types:` adds descriptors and codecs without endpoint discovery. Command DTOs and nested types are collected on their own; do not list them again |
| Command-only fields need labels | A create or edit form takes its fields from the command DTO. Labels come from a matching read column; give `createLabels` and `editLabels` for the rest |
| Domain workflows stay yours | A create or update whose result is not the read model does not bind the generic form. Write a custom screen for it |
| Regenerate after every model or endpoint change | The output is a function of the client's types, so it drifts silently when they change |

## Verify it

Run the generator twice; the second run must change nothing, and the output must analyze clean:

```console
$ dart run beak_serverpod_generator:generate --config beak_serverpod.yaml
Generated /home/me/consumer/lib/beak/entry_resources.g.dart
$ dart run beak_serverpod_generator:generate --config beak_serverpod.yaml
Up to date /home/me/consumer/lib/beak/entry_resources.g.dart
$ dart analyze lib
Analyzing lib...
No issues found!
```

The package tests resolve models with the analyzer, then compile and run the generated codecs and CRUD transport against fixtures:

```console
$ cd packages/beak_serverpod_generator && dart test
01:12 +11: All tests passed!
```

## Reference

| Config key | Type | Meaning |
| --- | --- | --- |
| `library` | String | The library URI that exports `Client` and the models, e.g. `package:example_client/example_client.dart` |
| `models` | List of String | Read models that get a `<Model>Resource` and endpoint discovery |
| `types` | List of String | Types that get descriptors and codecs only |
| `output` | String | The file to write, relative to the root |
| `client` | String | The client class, `Client` unless set. `--client` overrides it |

At least one of `models` and `types` is required. Otherwise the command stops with `Provide library, models or types (string lists), output, and optionally the client class name.`

| Command-line option | Default | Meaning |
| --- | --- | --- |
| `--config` | `beak_serverpod.yaml` | The config file |
| `--root` | The directory of the config file | The consumer package, when you run from elsewhere |
| `--client` | `client:` from the config, else `Client` | The client class the library exports |

Exit code 1 and a `Companion generation failed: ...` line on stderr mean the generation stopped.

The function behind the command, verbatim:

```dart title="packages/beak_serverpod_generator/lib/src/generator.dart"
Future<String> generateServerpodCompanions({
  required String packageRoot,
  required String library,
  required List<String> types,
  List<String> models = const [],
  String client = 'Client',
}) async {
```

Supported scalar types are strings, integers, doubles, booleans, `DateTime`, `Uri`, `UuidValue` and Dart enums, nullable or not, plus lists and sets of those. Nested objects and lists of non-nullable objects work. Arbitrary maps, nullable object-list elements, duplicate class names in the selected graph and models whose unnamed constructor is missing, private or takes positional parameters fail with an explicit message.

## Continue reading

- [Endpoint conventions](endpoint-conventions.md): the exact endpoint shapes the generator recognizes.
- [Bridge resources](resources.md): what a generated resource accepts and refuses at runtime.
- [Troubleshooting](../troubleshooting.md): what each generator and bridge message means.
