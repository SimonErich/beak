# Changelog

All notable changes to this package are documented in the
[root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). The
`beak_*` packages are versioned in lockstep, so one entry there covers all of
them.

## 0.9.0 - Unreleased

Beak's login, registration and password-recovery screens over an existing Serverpod generated client, plus the tunnel client and data source (`ServerpodBeakHttpClient`) behind the admin app.

New in 0.9.0: Serverpod 4.0.3 or newer within 4.x (0.0.x pinned 4.0.0-beta.0), and failures are classified over the sealed Serverpod client exceptions.

Beak is pre-1.0: the API is not frozen, the wire format is. See
[Upgrading](https://simonerich.github.io/beak/start-here/upgrading/) for how to
move between versions.
