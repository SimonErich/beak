---
title: Endpoint conventions
description: The endpoint signatures, query DTO vocabulary and type limits that beak_serverpod_generator recognizes, and the message it gives for each violation.
type: reference
audience: [expert, agent]
status: stable
search:
  boost: 2
---

# Endpoint conventions

The generator resolves your Serverpod client with the Dart analyzer and binds endpoint methods by name and by type. This page lists what it recognizes, exactly, and what it says when a shape does not fit.

## Import

The generator is a dev dependency and runs as a command. The generated file imports two packages, so the package that holds it depends on both:

```dart
import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/beak_serverpod.dart';
```

```console
$ dart run beak_serverpod_generator:generate --config beak_serverpod.yaml
```

## Summary

### Client and list endpoint (required)

| Rule | Detail |
| --- | --- |
| Client class | Exported by the configured `library`, named `Client` unless the config's `client:` (or `--client`) says otherwise |
| List endpoint | One field of `Client` whose type has a method named `list` returning `Future<Page>` |
| Page DTO | Exactly one field of type `List<Model>` (the read model) and an integer `totalCount`. Fields `page` and `pageSize` are used when present, otherwise the requested window is kept |
| Query DTO | The `list` parameter whose type has a `pageSize` field. It has an integer `page`, and its unnamed constructor has no required named parameter (`page` and `pageSize` carry defaults) |
| Uniqueness | Exactly one such endpoint over the whole client |
| Page origin | The default of `page` in the query DTO decides 0 or 1. The generated constructor takes `firstPage` to override |

### Query DTO vocabulary

| Property | Type | Effect |
| --- | --- | --- |
| `page` | `int` | Required. The requested page, translated to the endpoint's origin |
| `pageSize` | `int` | Required. The requested page size |
| `search` | `String?` | Forwards a validated search term |
| `sort` | enum | Enum value names are matched to generated field leaves. Direct siblings of the primary key win over deeper relations; other ambiguity needs a typed `sortFields` map |
| `descending` | `bool` | Keeps the endpoint's default until a sort is chosen |
| `includeArchived` | `bool` | Forwards the request for archived rows |
| Any other property | nullable scalar or enum | An equality filter when its name and type match a read field |

Nested conjunctions of equality filters work. Every other predicate is refused at runtime.

### Operations

| Operation | Method names | Signature | Binds |
| --- | --- | --- | --- |
| Read one | `get` or `getById` | Returns `Future<Model>` or `Future<Model?>`. Takes one non-null scalar id, plus an optional `locale` | `get` |
| Create | `create` | Returns `Future<Model>`, takes one typed input DTO, plus `locale` | `create`, the create form |
| Update | `update` or `edit` | Returns `Future<Model>`, takes the id and one typed input DTO, plus `locale` | `update`, the edit form |
| Delete | `delete` or `archive` | Returns `Future<void>`, takes the id | `archive` (ordinary delete) |
| Read many | `getMany` | Returns `Future<List<Model>>`, takes a `List` of the id type | `batchGet` |
| Count | none | Reuses the list query's `totalCount` | `aggregate` (count only) |

Parameters may be named or positional. A `locale: String` parameter on any method makes the generated constructor take a required `String Function() locale`. A create or update whose result is not the read model does not bind the generic form.

### Types

| Supported | Not supported |
| --- | --- |
| `String`, `int`, `double`, `bool`, `DateTime`, `Uri`, `UuidValue` | `Map` of any kind |
| Dart enums, resolved through their declared type | Nullable elements in an object list |
| Nullable versions of all of these | Duplicate class names in the selected graph |
| `List` and `Set` of a scalar | Models without a public unnamed constructor, or whose constructor takes positional parameters |
| Nested objects, and lists of non-nullable objects | |

Flattened descriptors name nested paths: `entry.title` becomes `entryTitle`, and a path that collides with an existing property uses `__` separators. Flattening stops at a recursive type.

### Generation errors

Each is a `FormatException`. The command prints it as `Companion generation failed: <message>` and exits with 1.

| Message | Cause |
| --- | --- |
| `Cannot resolve library <uri> from <root>.` | The `library` does not resolve in the consumer package. Run `dart pub get` and check the URI |
| `<uri> does not export a model named <name>.` | A name in `models` or `types` is not exported by the client library |
| `<uri> does not export client <name>.` | The library does not export the client class (`Client` unless configured) |
| `<Model> needs one unambiguous Client endpoint with list(query) returning a typed page; found <n>.` | No `list`, or several, that return a page of the model |
| `<Model> requires query page/pageSize defaults and page totalCount.` | The query DTO has a required named parameter, no `page`, or the page DTO has no integer `totalCount` |
| `<Model> needs a typed get/getById method.` | No read method returning the model |
| `<Model> get needs one non-null scalar identity.` | The read method takes a nullable id, a non-scalar, or more than one parameter besides `locale` |
| `<Model>.<method> requires one typed input.` | A create or update has no input DTO or more than one |
| `<Model>: ambiguous operations <a>, <b>.` | Two methods match the same operation, for example `get` and `getById` |
| `<Model>.<method>: unsupported parameter <name>; add a typed adapter.` | A parameter is neither the id, the query, the input, the id list nor `locale: String` |
| `<Name> needs a public constructor with named parameters.` | A model has no public unnamed constructor, or takes positional parameters |
| `Unsupported Serverpod property <path>: <type>.` | A field is a `Map` or another unsupported type |
| `Two distinct model types are named <name>.` | Two classes with one name in the selected graph |
| `Unsupported nested shape <type>.` | A nullable element in an object list |
| `<Model>.<name> is not a readable field.` | A constructor parameter of a model has no public field of the same name |

## Source

| What | File |
| --- | --- |
| Endpoint discovery and binding | `packages/beak_serverpod_generator/lib/src/resource_generator.dart` |
| Type mapping, field descriptors, codecs | `packages/beak_serverpod_generator/lib/src/generator.dart` |
| The command | `packages/beak_serverpod_generator/bin/generate.dart` |
| The runtime the output targets | `packages/beak_serverpod/lib/src/` |

A conforming endpoint set, from the generator's own test fixture. The query and page DTOs:

```dart title="packages/beak_serverpod_generator/test/fixtures/resources.dart"
class EntryQuery {
  EntryQuery({
    this.page = 0,
    this.pageSize = 25,
    this.search,
    this.sort = ResourceSort.title,
    this.descending = true,
    this.status,
    this.includeArchived = false,
  });
  final int page;
  final int pageSize;
  final String? search;
  final ResourceSort sort;
  final bool descending;
  final ResourceStatus? status;
  final bool includeArchived;
}

class EntryPage {
  EntryPage({required this.records, required this.totalCount});
  final List<EntryView> records;
  final int totalCount;
}
```

The client and the endpoint methods the generator binds, signatures only:

```dart title="packages/beak_serverpod_generator/test/fixtures/resources.dart"
class Client {
  Client(this.entry);
  final EntryEndpoint entry;
}
// ...
Future<EntryPage> list({
  required EntryQuery query,
  required String locale,
}) async {
// ...
Future<EntryView> getById(UuidValue id) async => value;
Future<EntryView> create(EntryInput input) async {
// ...
Future<EntryView> update({
  required UuidValue id,
  required EntryInput input,
}) => create(input);
Future<void> archive(UuidValue id) async {
// ...
Future<List<EntryView>> getMany({required List<UuidValue> ids}) async => [
```

The fixture is a small stand-in for a generated Serverpod client, and the generator's tests run against it, not against a live Serverpod project.

## Continue reading

- [Generating bridge resources](generator.md): the config file, the command and the regeneration loop.
- [Bridge resources](resources.md): what the generated resource accepts and refuses at runtime.
- [Troubleshooting](../troubleshooting.md): the runtime messages of the bridge.
