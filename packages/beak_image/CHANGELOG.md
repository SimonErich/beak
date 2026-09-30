# Changelog

All notable changes to this package are documented in the
[root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). The
`beak_*` packages are versioned in lockstep, so one entry there covers all of
them.

## 0.9.0 - Unreleased

Image decoding and transforms behind Beak's upload pipeline.

New in 0.9.0: a truncated or corrupt image is a `BeakValidationException` and never a raw codec error, and an animated GIF is decoded for its first frame only.

Beak is pre-1.0: the API is not frozen, the wire format is. See
[Upgrading](https://simonerich.github.io/beak/start-here/upgrading/) for how to
move between versions.
