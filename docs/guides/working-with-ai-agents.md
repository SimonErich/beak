---
title: Working with AI agents
description: Why Beak's config-over-code surface suits AI codegen, how to prompt an agent to define models and resources, and the type guardrails that catch its mistakes.
---

# Working with AI agents

A Beak resource is a handful of typed constants, not a pile of hand-wired
endpoints and widgets. That makes it a good fit for a coding agent: the surface it
has to write is small, typed, and reviewable, and the compiler catches the rest.
After this page you know why config-over-code helps here, how to prompt an agent to
define a model and a resource, how to scaffold the boilerplate with the CLI, and
which guardrails keep the output honest.

## Why config-over-code suits an agent

The failure mode of AI-generated backend code is plumbing that looks right and is
subtly wrong: a route that forgets validation, a serializer that drops a field, a
form that binds to the wrong key. Beak removes that whole category, because you do
not write plumbing. You write one typed definition and Beak generates the endpoint,
the table, the form, the detail row, the filter, and the CSV column from it.

```dart title="README.md"
abstract final class ProductColumns {
  static const name = BeakStringColumn(
    key: 'name', label: 'Name',
    searchable: true, sortable: true,
    rules: [BeakRequired(), BeakMaxLength(255)],
  );
  static const price = BeakDecimalColumn(
    key: 'price', label: 'Price', prefix: '€', rules: [BeakMin(0)],
  );
  static const List<BeakColumn> values = [name, price];
}
```

That is the entire surface an agent has to get right for the `name` and `price`
fields. Three properties make it agent-friendly:

- **Small.** A resource is a few `const` values, not hundreds of lines of glue. Less
  to generate means fewer places to go wrong.
- **Typed.** Every column is a named type with named parameters. There is no
  stringly-typed config to fat-finger and no `Map<String, dynamic>` to mis-shape.
- **Reviewable.** The definition reads like a spec. A human can diff a generated
  `ProductColumns` against the requirements in one glance, without tracing runtime
  behavior.

See [The one-definition promise](../concepts/the-one-definition-promise.md) for the
full list of surfaces that one definition drives.

## Scaffold first, fill second

Do not ask an agent to write the file layout from scratch. The CLI already knows the
shape. `beak make:resource` writes the three files a resource needs, correctly named
and wired, so the agent only has to fill in fields.

```console title="README.md"
$ beak make:resource Product \
    --fields name:string,price:decimal,active:bool
$ beak doctor   # checks paths, .env, and Docker services
```

`make:resource` writes the worm model, the Beak columns and model, and the
create-table migration, then prints the manual registration steps.

| File it writes | What goes in it |
| --- | --- |
| `lib/src/models/<snake>.dart` | the worm model (`extends Model`, `tableName`, `query()`) |
| `lib/src/models/<snake>_columns.dart` | the `XxxColumns` constants and the `XxxModel extends BeakModel` |
| `lib/src/migrations/create_<table>_table.dart` | the create-table worm migration, timestamp-prefixed |

The generated files are real, compiling Dart. The CLI test suite reads them back and
asserts their shape, so what the scaffold emits is exactly what the agent then
extends.

```dart title="packages/beak_cli/test/src/cli_test.dart"
final String wormModel = read('lib/src/models/widget.dart');
expect(wormModel, contains('final class Widget extends Model'));
expect(wormModel, contains('static QueryBuilder<Widget> query()'));

final String columns = read('lib/src/models/widget_columns.dart');
expect(columns, contains('abstract final class WidgetColumns'));
expect(columns, contains('final class WidgetModel extends BeakModel'));
expect(columns, contains("String get table => 'widgets';"));
```

The `--fields` value is a comma-separated list of `name:kind` tokens. The kinds and
their aliases are fixed, so an agent can generate the flag deterministically.

| Token | Becomes | Aliases |
| --- | --- | --- |
| `string` | `BeakStringColumn` | |
| `text` | `BeakTextColumn` | |
| `integer` | `BeakIntColumn` | `int` |
| `decimal` | `BeakDecimalColumn` | `double` |
| `boolean` | `BeakBoolColumn` | `bool` |
| `dateTime` | `BeakDateTimeColumn` | `datetime`, `date` |

## Prompting an agent to define a resource

With the scaffold in place, the job you hand the agent is the four-step recipe from
the README, in order. Give it the requirements and point it at each step:

1. **Columns and model.** Fill in the generated `XxxColumns` class: one typed
   `const` column per field, with its `rules`. Name the table, the display column,
   and any relationships on the `XxxModel`.
2. **Schema.** Complete the generated migration so its columns match the model, then
   register it in `bin/migrate.dart`.
3. **Server.** Register the model in the `BeakModelRegistry` you hand to
   `BeakServer`. Every endpoint is generated from there.
4. **Panel.** Add a `BeakResource(model: XxxModel(), icon: ...)` to your
   `BeakPanelConfig`. The list, create, show, and edit pages come with it.

A prompt that works well is concrete about the fields and their rules, and tells the
agent which validation to attach. For example:

> Fill in `ProductColumns` for a coffee product. Fields: `name` (required string,
> max 255, searchable and sortable), `price` (decimal, prefix `€`, at least 0),
> `roast` (enum of light/medium/dark), and `in_stock` (bool). Add a `belongsTo`
> relationship `category` on `ProductModel`. Match the migration columns to these,
> then register the migration and the model.

The agent's answer is a diff you can read against that sentence. Because the whole
definition is declarative, review is reading, not simulation.

## The guardrails that catch mistakes

An agent will still get things wrong. Beak's value here is that its type system
turns most of those mistakes into a red analyzer, not a runtime surprise. The gate
runs the strict analyzer with infos and warnings promoted to failures.

```yaml title="melos.yaml"
analyze-dart:
  run: melos exec -- "dart analyze --fatal-infos --fatal-warnings ."
```

Three constraints do most of the catching, and they are worth stating in the prompt
so the agent aims for them from the start:

- **No `dynamic`, no `as` casts, no `Map<String, dynamic>`** as a domain or public
  API type. A column value is a typed `BeakValue`; a row is a typed `BeakRecord`. An
  agent that reaches for a raw map to "just make it compile" gets a failing analyze
  instead. See [The type-safety promise](../concepts/the-type-safety-promise.md).
- **Enums and sealed classes over strings** for any known value set. A status field
  is a `BeakEnumColumn<Status>`, so a typo in a status value is a compile error, not
  a bad row.
- **No Material.** The panel is obers_ui only. A separate guard fails the build on any
  `package:flutter/material.dart` import, which is exactly the import an agent trained
  on generic Flutter reaches for first.

```yaml title="melos.yaml"
guard-material:
  run: dart run tool/check_no_material.dart
```

Wire these into the loop you run the agent in. After each change, run the same gate
the project is built on, and feed the output back:

```bash
melos run analyze     # 0 issues, or the agent tries again
melos run test        # the generated resource behaves
melos run format-check
```

An agent that has to pass a typed analyzer and a real test suite before it is done
produces resources you can trust, because the same rails that keep a human honest
keep it honest too. The [code guardrails](../contributing/code-guardrails.md) page
lists every rule the gate enforces.

## Continue reading

- [CLI commands](../reference/cli-commands.md) every `make:*` command and its flags.
- [Defining models](../models/defining-models.md) the definition the agent fills in.
- [The type-safety promise](../concepts/the-type-safety-promise.md) why the types
  refuse the shortcuts an agent tends to take.
- [Code guardrails](../contributing/code-guardrails.md) the full rule set the gate
  enforces.
- [Quickstart](../start-here/quickstart.md) run the store example end to end before
  you generate your own.
