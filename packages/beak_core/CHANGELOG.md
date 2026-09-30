# Changelog

All notable changes to this package are documented in the
[root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). The
`beak_*` packages are versioned in lockstep, so one entry there covers all of
them.

## 0.9.0 - Unreleased

Typed columns, models, relationships, the serializable query spec and the storage abstraction. No Flutter, no `dart:io`.

New in 0.9.0: sorting, search, aggregates, summaries and actions take typed field references and objects instead of strings, rules size the stored column, server-side authoring gets typed record and candidate-graph helpers, and the version-matched docs bundle ships in `doc/agent-docs`.

Beak is pre-1.0: the API is not frozen, the wire format is. See
[Upgrading](https://simonerich.github.io/beak/start-here/upgrading/) for how to
move between versions.
