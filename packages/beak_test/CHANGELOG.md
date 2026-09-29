# Changelog

All notable changes to this package are documented in the
[root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). The
`beak_*` packages are versioned in lockstep, so one entry there covers all of
them.

## 0.9.0 - Unreleased

A complete in-memory data source, the executable `BeakDataSource` contract, record factories and schema-parity assertions.

New in 0.9.0: a README, and `InMemoryBeakDataSource` follows the backend more closely: dotted relation paths and relation filters, has-many attach and detach, `like` patterns, and search through the same filter builder the server uses.

Beak is pre-1.0: the API is not frozen, the wire format is. See
[Upgrading](https://simonerich.github.io/beak/start-here/upgrading/) for how to
move between versions.
