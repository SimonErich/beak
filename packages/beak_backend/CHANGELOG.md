# Changelog

All notable changes to this package are documented in the
[root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). The
`beak_*` packages are versioned in lockstep, so one entry there covers all of
them.

## 0.9.0 - Unreleased

The Shelf server: generated CRUD, query, uploads, auth, export, health probes and policy.

New in 0.9.0: the typed, deny-by-default policy DSL (`BeakPolicies`), `graphOnly: [XModel()]`, an outbox the host runs while it serves, `defaults.build` hooks for middleware and routes, `BeakBaselineMigration` for adopted databases, and a smaller public API (see Removed in the root changelog).

Beak is pre-1.0: the API is not frozen, the wire format is. See
[Upgrading](https://simonerich.github.io/beak/start-here/upgrading/) for how to
move between versions.
