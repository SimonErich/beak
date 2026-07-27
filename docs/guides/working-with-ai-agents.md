---
title: Working with AI agents
description: The AGENTS.md beak create writes, how to prompt an agent to add a resource, and the guardrails that catch what it gets wrong.
---

# Working with AI agents

A Beak resource is one annotated class, not a pile of hand-wired endpoints and
widgets. That makes it a good fit for a coding agent: the surface it has to write
is small, typed, and reviewable, and the compiler catches the rest. After this
page you know what `beak create` already tells an agent, how to prompt one to add
a resource, and which guardrails keep the output honest.

## Beak writes the agent's brief for you

`beak create` scaffolds an `AGENTS.md` at the project root. Most coding agents
read it without being asked, and the ones that do not can be pointed at it in one
sentence. It says where things go:

```markdown title="examples/store/AGENTS.md"
## Where things go

| What | Where |
| --- | --- |
| A resource | `lib/models/<name>.dart` — one `@Resource` class per file |
| A custom page | `lib/screens/<name>.dart` — a top-level `BeakScreen` |
| Panel title, icons, sections | `beak.yaml` |
| Theme / auth / dashboard / server overrides | `lib/{theme,auth,dashboard,server}.dart` |
| Generated wiring | `lib/beak/*.g.dart` — do not edit |

Nothing needs registering. `beak prepare` reads each schema class and
generates its columns, model, relationships (both sides) and a typed record
view into a `.beak.dart` part beside it, then wires everything up.

A field's Dart type picks its column: `String`, `BeakText`, `BeakRichText`,
`int`, `double`, `bool`, `DateTime`, an enum, `BeakHexColor`, `BeakImageRef`,
`BeakFileRef`. Nullability decides whether it is required.
```

and what must stay true:

```markdown title="examples/store/AGENTS.md"
## Invariants

- Never write a column key or table name as a string. Reference the column
  constant (`NoteColumns.title`) and the model (`const NoteModel().query()`).
- Never import `package:flutter/material.dart` or `cupertino.dart`. Beak's UI
  is obers_ui.
- Widgets are `HookWidget`; `StatefulWidget` is not used.
- Read record values through the generated record view: `record.asNote.title`
  is a `String`, `record.asNote.body` a `String?` — matching what the schema
  declared. `NoteColumns.title.readFrom(record)` is the lower-level form.
```

and the commands to run:

```bash title="examples/store/AGENTS.md"
beak dev        # generate, serve the API, run the panel
beak prepare    # regenerate the wiring only
beak migrate    # apply migrations
beak seed       # run seeders
beak doctor     # diagnose the project
```

Keep the file up to date as your project grows. It is the cheapest context an
agent will ever read, and every fact in it saves a wrong turn.

## Why config-over-code suits an agent

The failure mode of AI-generated backend code is plumbing that looks right and is
subtly wrong: a route that forgets validation, a serializer that drops a field, a
form that binds to the wrong key. Beak removes that whole category, because you
do not write plumbing. You write one class and Beak generates the endpoint, the
table, the form, the detail row, the filter, and the CSV column from it.

```dart title="examples/store/lib/models/category.dart"
/// A shelf of the catalog.
@Resource()
final class Category extends BeakSchema {
  /// What the category is called.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// The one-line blurb shown above the product list.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? blurb;
}
```

That is the entire surface an agent has to get right for a whole resource. Three
properties make it agent-friendly:

- **Small.** A resource is one file. Less to generate means fewer places to go
  wrong, and no second file that can drift out of step with the first.
- **Typed.** The field's type picks the column kind and its nullability decides
  required-ness, once, for the form validator, the API and the database. There is
  no stringly-typed config to fat-finger and no `Map<String, dynamic>` to
  mis-shape.
- **Reviewable.** The class reads like a spec. A human can diff it against the
  requirements in one glance, without tracing runtime behavior.

See [The one-definition promise](../concepts/the-one-definition-promise.md) for
the full list of surfaces that one definition drives.

## Scaffold first, fill second

Do not ask an agent to invent the file layout. The CLI already knows it.

```console
beak create acme_admin
cd acme_admin
beak make:resource Product --fields name:string!,price:decimal!,active:bool
```

`make:resource` writes one file, `lib/models/product.dart`, and then runs
`beak prepare`, which generates the part file beside it and the create-table
migration. The agent's job starts from a compiling resource, not a blank page.

The `--fields` value is a comma-separated list of `name:kind` tokens, so an agent
can generate the flag deterministically. A trailing `!` means non-nullable, which
means required.

| Token | Becomes | Aliases |
| --- | --- | --- |
| `string` | a `String` field | |
| `text` | a `BeakText` field | |
| `integer` | an `int` field | `int` |
| `decimal` | a `double` field | `double` |
| `boolean` | a `bool` field | `bool` |
| `datetime` | a `DateTime` field | `date` |

```dart title="packages/beak_cli/test/src/cli_test.dart"
      final String source = read('lib/models/widget.dart');
      expect(source, contains('@Resource(timestamps: true)'));
      expect(source, contains('final class Widget extends BeakSchema'));
      expect(source, contains("part 'widget.beak.dart';"));
      expect(source, contains('late final String name;'));
      expect(source, contains('late final double price;'));
      expect(source, contains('late final bool? active;'));
```

The CLI's own test suite reads the scaffold back and asserts its shape, so what
the scaffold emits is exactly what the agent then extends.

!!! tip "Starting from a database you already have"
    `beak introspect postgres://…` reads an existing schema and writes the same
    annotated classes an agent would have written, foreign keys included. Point
    it at the database, then hand the agent the result to refine. That is a much
    better prompt than a description of the tables.

## Prompting an agent to add a resource

With the scaffold in place, the job is short and each step names one file:

1. **The resource.** Fill in `lib/models/<name>.dart`: one field per column, with
   its type, its nullability, and its `@Column` options. Add relationships with
   `@BelongsTo`, `@HasOne`, `@HasMany`, `@BelongsToMany` (only one side; the
   other is generated).
2. **Regenerate.** Run `beak prepare`. It writes the part file, the registry, the
   panel wiring, and the migration a new resource needs.
3. **Presentation.** Set the icon, label or section in `beak.yaml` under
   `resources.<table>`.
4. **Anything derived that is wrong.** Only then, add
   `lib/resources/<table>.dart` for that resource's filters, actions, view modes,
   detail layout or form steps.

A prompt that works well is concrete about the fields and their rules, and says
which annotation carries what:

> Add a `Product` resource to `lib/models/product.dart`. Fields: `name` (a
> required `String`, searchable and sortable, max 255, and the `@Display`
> field), `price` (a required `double` with prefix `€` and `BeakMin(0)`),
> `roast` (an enum of light/medium/dark, filterable, with `@Badges` colours),
> and `inStock` (a required `bool`, filterable). Add `@BelongsTo` to `Category`.
> Then run `beak prepare` and `beak doctor`.

The answer is a diff you can read against that sentence. Because the whole
definition is declarative, review is reading, not simulation.

!!! warning "Generated files are not for editing"
    `lib/beak/*.g.dart` and `lib/models/*.beak.dart` are committed, so an agent
    can read them, which is useful: they are where the column constants it should
    reference are declared. They are never edited. An agent that "fixes" a
    generated file has its change erased by the next `beak prepare`, and
    `beak doctor` reports the file as stale.

## The guardrails that catch mistakes

An agent will still get things wrong. Beak's value here is that its type system
turns most of those mistakes into a red analyzer, not a runtime surprise.
`beak create` writes a strict `analysis_options.yaml` for exactly this reason:

```yaml title="examples/store/analysis_options.yaml"
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
```

Four constraints do most of the catching, and they are worth restating in the
prompt so the agent aims for them from the start:

- **No string keys.** A column is `ProductColumns.name`, a table is
  `const ProductModel().table`. An agent that types `'name'` into a filter or a
  layout gets a compile error, not a control that silently matches nothing.
- **No `dynamic`, no `Map<String, dynamic>`** as a domain or public API type. A
  column value is a typed `BeakValue`; a row is a typed `BeakRecord`; a record
  reads back through the generated view (`record.asProduct.price` is a
  `double`). See [The type-safety promise](../concepts/the-type-safety-promise.md).
- **Enums and sealed classes over strings** for any known value set. A status
  field is a Dart enum, so a typo in a status value is a compile error, not a bad
  row.
- **No Material.** The panel is obers_ui only, from `package:beak/ui.dart`. This
  is the import an agent trained on generic Flutter reaches for first, and it is
  the first thing to check in a diff that touches a screen.

Wire these into the loop you run the agent in. After each change, run the same
four commands and feed the output back:

```bash
beak prepare      # regenerate; a schema error is named here, with the field
beak doctor       # discovery, stale generated files, missing migrations
flutter analyze   # 0 issues, or the agent tries again
flutter test      # the smoke test beak create wrote, plus yours
```

`beak doctor --json` reports the same checks as machine-readable output with a
non-zero exit, which is what you want in CI or in an agent's own tool loop.

The smoke test `beak create` writes is worth keeping: it boots the panel against
an `InMemoryBeakDataSource` and asserts every discovered model is registered, so
a resource an agent added but broke fails a test rather than a demo.

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

    // ... a desktop-sized test surface ...
    await tester.pumpWidget(BeakApp(dataSource: source));
    await tester.pumpAndSettle();

    expect(beakModels, isNotEmpty, reason: 'no model was discovered');
```

An agent that has to pass a strict analyzer, `beak doctor`, and a real test suite
before it is done produces resources you can trust, because the same rails that
keep a human honest keep it honest too.

## Continue reading

- [Defining a resource](../models/defining-models.md) the one class the agent writes.
- [Annotations](../reference/annotations.md) every annotation and option, in tables an agent can follow.
- [CLI commands](../reference/cli-commands.md) `create`, `make:resource`, `prepare`, `introspect`, `doctor`, `eject`.
- [Testing](testing.md) the seams that let an agent prove its own work.
- [The type-safety promise](../concepts/the-type-safety-promise.md) why the types refuse the shortcuts an agent tends to take.
