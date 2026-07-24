---
title: Reference
description: The exhaustive lookup section: every column type, rule, block, config field, REST route, CLI command, exception, and package, plus the one-page cheatsheet.
---

# Reference

This is the section you scan, not the one you read. Every page here is a
complete lookup table for one surface of Beak: the column types, the validation
rules, the blocks, the config fields, the generated REST routes, the CLI, the
exception family, and the package map. When you know the name and want the
signature, start here.

If you want it all on one screen, the [Cheatsheet](cheatsheet.md) condenses the
minimal wiring plus every table below into a single dense page, worth pinning or
handing to an AI agent.

## The pages

| Page | What it lists |
| --- | --- |
| [Cheatsheet](cheatsheet.md) | The whole toolbox on one page: minimal wiring, every type, and every command. |
| [Column types reference](column-types.md) | All thirteen built-in column types, their options, and what each renders as. |
| [Validation rules reference](validation-rules.md) | The eleven `BeakRule` types, what they apply to, and when they fail. |
| [Blocks index](blocks-index.md) | Every block in the block system, grouped by layout, display, data, record, and module. |
| [CLI commands](cli-commands.md) | The `beak` scaffolding commands (`make:resource`, `make:model`, `make:columns`, `make:migration`, `doctor`). |
| [REST API](rest-api.md) | The routes a registered model generates, plus the search, export, upload, and auth surfaces. |
| [Configuration options](configuration-options.md) | `BeakPanelConfig`, `BeakResource`, `BeakBackendConfig`, and the environment variables behind them. |
| [Exceptions](exceptions.md) | The sealed `BeakException` family and the HTTP status and JSON `code` each maps to. |
| [Glossary](glossary.md) | The Beak vocabulary: column, resource, block, scope, driver, spec, and the rest. |
| [Packages](packages.md) | What each `beak_*` package contains and how they depend on one another. |

## How the reference relates to the rest of the docs

The [Core concepts](../concepts/index.md), [Models and data](../models/index.md),
and [The panel](../panel/index.md) sections teach these APIs in prose, with the
reasoning and the worked examples. The reference pages here restate the same
surface as flat tables so you can find a parameter without rereading the
explanation. Every signature is quoted from the source, so what you see is what
compiles.

## Continue reading

- [Cheatsheet](cheatsheet.md) the single densest page in the site.
- [Column types reference](column-types.md) the most-visited lookup table.
- [Quickstart](../start-here/quickstart.md) if you would rather run something first.
