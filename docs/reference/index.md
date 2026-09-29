---
title: Reference
description: Look up any annotation, field type, rule, block, option, REST route, CLI command or exception.
type: index
audience: [expert, agent]
status: draft
search: {boost: 2}
---

# Reference

This is the section you scan, not the one you read. Every page here is a
complete lookup table for one surface of Beak: the annotations a schema class
carries, the keys of `beak.yaml`, the libraries you import, the column types,
the validation rules, the blocks, the config fields, the generated REST routes,
the CLI, the exception family, and the package map. When you know the name and
want the signature, start here.

If you want it all on one screen, the [Cheatsheet](cheatsheet.md) condenses the
whole toolbox into a single dense page, worth pinning or handing to an AI agent.

## The pages

| Page | What it lists |
| --- | --- |
| [Cheatsheet](cheatsheet.md) | The whole toolbox on one page: one resource end to end, every type, and every command. |
| [Annotations](annotations.md) | Every annotation a schema class can carry, and the Dart type each applies to. |
| [beak.yaml](beak-yaml.md) | Every key of the project file, and what happens when you leave it out. |
| [Libraries](libraries.md) | The eight libraries of `package:beak` and which one a file should import. |
| [Column types reference](field-types.md) | All thirteen built-in column types, the authoring type each is declared as, and their options. |
| [Validation rules reference](validation-rules.md) | The eleven `BeakRule` types, what they apply to, and when they fail. |
| [Blocks index](blocks.md) | Every block in the block system, grouped by layout, display, data, record, and module. |
| [CLI commands](cli-commands.md) | `create`, `prepare`, `dev`, `introspect`, `eject`, `migrate`, `seed`, `make:resource`, `make:migration`, `doctor`. |
| [REST API](rest-api.md) | The routes a registered model generates, plus the search, export, upload, auth, and health surfaces. |
| [Configuration options](configuration.md) | `beak.yaml`, the environment variables, `BeakBackendConfig`, the storage configs, and `BeakPanelConfig`. |
| [Exceptions](exceptions.md) | The sealed `BeakException` family and the HTTP status and JSON `code` each maps to. |
| [Glossary](glossary.md) | The Beak vocabulary: schema class, column, resource, block, scope, driver, spec, and the rest. |
| [Packages](packages.md) | What each package contains, how they depend on one another, and the examples that exercise them. |

## Where each decision lives

Most "which page do I want" questions are really "where does this decision
live". There are five answers.

| Decision | Where |
| --- | --- |
| Columns, relationships, table name, soft deletes, timestamps | the `@Resource` class in `lib/models/<name>.dart` ([Annotations](annotations.md)) |
| Panel title, API origin, server port | `beak.yaml` ([beak.yaml](beak-yaml.md)) |
| A resource's icon, label, section, or hiding it | `beak.yaml`, under `resources.<table>` |
| A resource's filters, actions, view modes, detail layout, form steps | `lib/resources/<table>.dart` ([Configuration options](configuration.md)) |
| Theme, auth, the `/` screen, the server | `lib/theme.dart`, `lib/auth.dart`, `lib/dashboard.dart`, `lib/server.dart` |

Everything else is generated into `lib/beak/*.g.dart` and
`lib/models/*.beak.dart`, committed, and never edited.

## How the reference relates to the rest of the docs

The [Core concepts](../concepts/index.md), [Schema](../models/index.md), and
[The panel](../panel/index.md) sections teach these APIs in prose, with the
reasoning and the worked examples. The reference pages here restate the same
surface as flat tables so you can find a parameter without rereading the
explanation. Every signature is quoted from the source, so what you see is what
compiles.

## Which page to read

| You want to… | Read | For |
| --- | --- | --- |
| Find the configuration entrypoint for each common task | [Cheatsheet](cheatsheet.md) | Reference for experts and agents |
| Look up every annotation a schema class can carry, what it changes and where it applies | [Annotations](annotations.md) | Reference for experts and agents |
| Look up every column type, the Dart type it is declared as, its options and its defaults | [Field types](field-types.md) | Reference for experts and agents |
| Look up every validation rule, its arguments, what it checks and the message it emits | [Validation rules](validation-rules.md) | Reference for experts and agents |
| Look up the model behavior and action types with their fields and defaults | [Behavior and actions](behavior-and-actions.md) | Reference for experts and agents |
| Look up the files beak prepare writes and the symbols generated for each schema | [Generated files and symbols](generated-files.md) | Reference for experts and agents |
| Look up the input builders you can call on a typed field in a form | [Input builders](input-builders.md) | Reference for experts and agents |
| Look up the filter builders you can call on a typed field in a list | [Filter builders](filter-builders.md) | Reference for experts and agents |
| Look up the resource screens and the form layout nodes with their options | [Screens and form layouts](screens-and-layouts.md) | Reference for experts and agents |
| Look up every block type and its typed options | [Blocks](blocks.md) | Reference for experts and agents |
| Look up the query specification, filters, operators and typed values | [Queries](queries.md) | Reference for experts and agents |
| Look up every option of the panel, of a resource, of authentication, maintenance mode and formatting | [Panel and resource options](panel-options.md) | Reference for experts and agents |
| Look up every key of the project file and what happens when you leave it out | [beak.yaml](beak-yaml.md) | Reference for experts and agents |
| Look up every environment variable and every backend and storage configuration field, with defaults | [Configuration and environment](configuration.md) | Reference for experts and agents |
| Look up every beak command, its flags, the files it writes and its exit codes | [CLI commands](cli-commands.md) | Reference for experts and agents |
| Look up every endpoint the backend generates, with request bodies, responses and the error envelope | [REST API](rest-api.md) | Reference for experts and agents |
| Look up the exception family, each stable code, its HTTP status and when Beak throws it | [Exceptions](exceptions.md) | Reference for experts and agents |
| Look up the libraries of package:beak, what each is for and what it may import | [Libraries](libraries.md) | Reference for experts and agents |
| Look up the packages behind Beak, what each owns and which ones an app installs | [Packages](packages.md) | Reference for experts and agents |
| Look up one-line definitions of Beak vocabulary, cross-linked to the page that explains each | [Glossary](glossary.md) | Reference for beginners, experts and agents |

## Continue reading

- [Cheatsheet](cheatsheet.md) the single densest page in the site.
- [Annotations](annotations.md) the most-visited lookup table.
- [Quickstart](../start-here/quickstart.md) if you would rather run something first.
