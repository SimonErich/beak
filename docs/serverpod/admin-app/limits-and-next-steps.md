---
title: Limits and next steps
description: What the Serverpod admin path covers today, what it leaves out, and the workaround for each gap.
type: concept
audience: [expert]
status: stable
---

# Limits and next steps

The Serverpod admin path is proven on `examples/serverpod`: generated models, a
gated engine, stock and use-case writes, and a panel whose routes render at
phone and desktop widths. This page lists what it does not cover.

## The idea in one picture

The tunnel carries reads and writes through Serverpod; each gap below is a part of Beak that the tunnel does not mount yet.

## How it works

Each gap below is a part of Beak the tunnel does not mount yet, not a bug in the path that is there.

## Gaps

| Gap | Why | Workaround |
| --- | --- | --- |
| Uploads through the tunnel | The engine mounts no storage, so a file cannot travel through the envelope | Use the bridge path for media, or add a host upload endpoint |
| A hosted outbox worker | The tunnel starts no delivery loop | Map the outbox table and run a host worker |
| Default-deny row scopes | A model reads every row unless its definition opens `list: BeakHandling.custom` | Declare a custom list and return the account's filter from the handler's `scope` |
| Generated code in CI | A project may gitignore the parts and handler bases | Run `beak generate --check` before analyze and tests |
| A list answered by a use case | A custom list narrows Beak's query; it does not replace it | Keep a use-case report as its own page or endpoint |
| Policy decisions per record | Role rules are exact; row rules may be a lower bound | Ask capabilities with a record id, or keep a server policy test |

## Why it is shaped this way

The engine stays inside Serverpod, so it inherits Serverpod's database, sessions and transactions instead of running a second server.

## What it means for you

Plan the workarounds below before you depend on the admin for the affected features.

## Next steps

1. Open `list: BeakHandling.custom` for models whose accounts should see only
   their own records.
2. Open the writes a use case owns as `custom` or `commands:` and implement
   them on the generated handler.
3. Add the tree rules for categories and navigation.
4. Schedule `engine.pruneExpiredReceipts` from a host `FutureCall`.
5. Keep `beak generate --check` in CI, so a Serverpod model change that no
   definition class reflects fails before it reaches a database.

## Continue reading

- [Writes, commands and trees](write-bindings.md): the write and tree hooks.
- [Generating the admin from definition classes](generate.md): the generation gate.
- [Testing](../../shipping/testing.md): the route sweep and the API tests.
