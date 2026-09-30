---
title: Concepts
description: Why Beak is shaped the way it is, in eight short pages on the resource model, the two promises, authority, layers, data flow, blocks and errors.
type: index
audience: [beginner, expert]
status: stable
---

# Concepts

The guides tell you what to write. These pages tell you why Beak is built the way it is, so the API stops looking arbitrary. Each one has a diagram, working code from the maintained examples, and a short list of what it means for you.

If you are new, read the first four in order. If you already have a panel running and something surprised you, go straight to the page that matches the surprise.

## Which page to read

| You want to... | Read | For that |
| --- | --- | --- |
| See how a schema, a model, a resource, a screen and a page divide the work | [Declarative resources](declarative-resources.md) | The five things you write or generate, and what Beak's runtime owns |
| Know why one field feeds the table, the form, the API and the migration | [The one-definition promise](the-one-definition-promise.md) | The seven consumers of a column, and where the promise stops |
| Know why you never write a field name as a string | [The type-safety promise](the-type-safety-promise.md) | Generated typed fields, sealed families, and every string that remains |
| Decide which side a rule belongs on | [Where authority lives](where-authority-lives.md) | Client preview against server authority, policies, and the Serverpod mapping |
| Learn where code goes on the server and in the panel | [The four layers](the-four-layers.md) | Handler, Service, DataSource and Widget, ViewModel, Repository, DataSource |
| Follow a query or a save end to end | [How data flows](how-data-flows.md) | `BeakQuerySpec`, save plans, receipts and refresh |
| Choose between a block and a form node | [The block system](the-block-system.md) | Blocks for screens that show, form nodes for drafts that edit |
| Tell a thrown exception, a result and a receipt apart | [Results and errors](results-and-errors.md) | Typed failures, field errors and uncertain writes |

The code on these pages comes from three places. `examples/quickstart` is the smallest project `beak create` writes. `examples/serverpod` is a Beak admin inside a Serverpod workspace, with a real policy. The `packages/` sources are quoted where a page explains a mechanism, and every quote is either an include of a marked section or a fence the docs check against the file.

## Continue reading

- [Tutorial](../tutorial/index.md) build a small panel step by step and meet these ideas in use.
- [Models](../models/index.md) the guides behind the schema, field and relationship pages.
- [Architecture](../architecture/index.md) the same layers in contributor detail.
- [Examples](../examples/index.md) the maintained projects, from the quickstart to the full shop.
