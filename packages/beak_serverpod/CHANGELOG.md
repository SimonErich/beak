# Changelog

All notable changes to this package are documented in the
[root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). The
`beak_*` packages are versioned in lockstep, so one entry there covers all of
them.

## 0.9.0 - Unreleased

Typed resource bindings and generated-model codecs that let a Beak panel read and write through an existing Serverpod client (the client bridge), plus the tunnel envelope v1 wire types and HTTP client behind the admin app.

New in 0.9.0: `package:beak_serverpod/wire.dart`, the `beak-serverpod-setup` skill, and typed ordering and search. The root changelog has a section, "Migrating from beak_serverpod 0.0.x".

Beak is pre-1.0: the API is not frozen, the wire format is. See
[Upgrading](https://simonerich.github.io/beak/start-here/upgrading/) for how to
move between versions.
