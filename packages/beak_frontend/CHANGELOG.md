# Changelog

All notable changes to this package are documented here. The `beak_*` packages
are versioned in lockstep.

## Unreleased

- Record actions declare optional resource roles, including document actions.
  Generated lists and live read/edit forms honor them without changing permissions.
  Custom form frame builders now also receive the current presentation mode.

- Wizard steps separate navigation labels from pinned content headings and
  introductions. Input scrolling and step changes preserve the managed draft.
- Compact relationship rows support minimum height, a configurable stacking
  threshold, scoped identity input sizes and conditional read-only details.
  Hidden column headings no longer add labels inside desktop cells.
- Record-page metadata uses body typography while compact identity templates
  retain captions; custom hosts can override the subtitle variant.
- Form and block card headers have an overridable 16-pixel content gap.
  Card padding and record-template text gaps are configurable, including compact
  milestone metadata and aligned review totals.

- Expanded row blocks distribute space by child weights after actual gaps and
  stack when their available container width becomes too narrow.
- Radio choice groups inherit section heading typography and selectable-card
  geometry from shared Obers component themes.

- Framed dashboards and generated record details no longer add a second card
  behind their declared surfaces. Page gutters remain part of shared layout.
- Embedded table base filters apply from the first query and survive shared
  query changes, pagination, search and mutation refreshes.
- Stored-draft Resume and Discard actions wrap inside narrow forms and wizards.
- Fixed grids automatically stack when their spanned children would become
  narrower than the configurable minimum, using the available container width.
- Added exact relationship code entry with automatic scoped lookup, loading,
  validation and local Apply/Remove actions.
- Calculated values support read-only field and checkbox presentations with
  explicit loading and permission dependencies. Input labels and workflow
  milestones can describe the live draft.
- Summary labels use the available width beside trailing prices; summary
  headings and inset metric strips support compact themed presentations.

The Flutter panel: shell, data table, forms, detail views, actions and dashboard blocks, on obers_ui.

Beak is pre-1.0 and the API is not yet frozen; the wire format is. See
[Upgrading](https://simonerich.github.io/beak/) for what changed between
versions once there is a released version to change from.
