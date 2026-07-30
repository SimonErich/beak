---
title: Reference
description: The exhaustive lookup section: every annotation, beak.yaml key, library, column type, rule, block, config field, REST route, CLI command, exception, and package, plus the one-page cheatsheet.
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
| [Column types reference](column-types.md) | All thirteen built-in column types, the authoring type each is declared as, and their options. |
| [Validation rules reference](validation-rules.md) | The eleven `BeakRule` types, what they apply to, and when they fail. |
| [Blocks index](blocks-index.md) | Every block in the block system, grouped by layout, display, data, record, and module. |
| [CLI commands](cli-commands.md) | `create`, `prepare`, `dev`, `introspect`, `eject`, `migrate`, `seed`, `make:resource`, `make:migration`, `doctor`. |
| [REST API](rest-api.md) | The routes a registered model generates, plus the search, export, upload, auth, and health surfaces. |
| [Configuration options](configuration-options.md) | `beak.yaml`, the environment variables, `BeakBackendConfig`, the storage configs, and `BeakPanelConfig`. |
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
| A resource's filters, actions, view modes, detail layout, form steps | `lib/resources/<table>.dart` ([Configuration options](configuration-options.md)) |
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

## Continue reading

- [Cheatsheet](cheatsheet.md) the single densest page in the site.
- [Annotations](annotations.md) the most-visited lookup table.
- [Quickstart](../start-here/quickstart.md) if you would rather run something first.
