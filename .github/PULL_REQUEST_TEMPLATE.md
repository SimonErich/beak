<!-- Thanks for contributing to Beak! Keep PRs focused and green. -->

## What & why

<!-- What does this change do, and why? Link any related issue (Fixes #123). -->

## How I verified it

<!-- Commands run, scenarios exercised. New behavior needs tests; changed
     behavior needs updated tests. -->

## Checklist

- [ ] `melos run analyze` is clean (0 issues, incl. the no-Material, hook-widget and web-safety guards)
- [ ] `melos run format-check` is clean
- [ ] `melos run test` passes (no skips)
- [ ] `melos run coverage` passes (regenerated after code changes)
- [ ] Public API changes carry dartdoc; complex additions include a usage example
- [ ] Commits follow Conventional Commits
- [ ] If I touched `packages/worm*`, `melos run test-worm` passes and the description says why Beak needed the change
