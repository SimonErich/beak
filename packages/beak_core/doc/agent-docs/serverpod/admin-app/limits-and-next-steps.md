# Limits and next steps

> What the Serverpod admin path covers today, what it leaves out, and the workaround for each gap.

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
| Default-deny row scopes | The generated policy has no per-account filter | Add a `BeakRowScope` to `BeakPolicies.admitted` |
| Generated code in CI | `generated/lib` is gitignored | Run `beak generate --check` before analyze and tests |
| Policy decisions per record | Role rules are exact; row rules may be a lower bound | Ask capabilities with a record id, or keep a server policy test |
| Multi-language enum labels | The generated model carries wire names | Set `BeakPanelConfig.labels` with a `BeakLabels` mapping |

## Why it is shaped this way

The engine stays inside Serverpod, so it inherits Serverpod's database, sessions and transactions instead of running a second server.

## What it means for you

Plan the workarounds below before you depend on the admin for the affected features.

## Next steps

1. Add a row scope for accounts that should see only their own records.
2. Connect the writes a use case owns with `BeakWriteHandler.commands` and
   `otherwise: BeakUnmatched.refuse`.
3. Add the tree rules for categories and navigation.
4. Schedule `engine.pruneExpiredReceipts` from a host `FutureCall`.
5. Keep `beak generate --check` in CI, so a model change that was not reviewed
   fails before it reaches a database.

## Continue reading

- [Writes, commands and trees](write-bindings.md): the write and tree hooks.
- [Generating the schema package](generate.md): the generation gate.
- [Testing](../../shipping/testing.md): the route sweep and the API tests.
