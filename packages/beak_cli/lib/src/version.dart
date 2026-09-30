/// The version of this CLI, and so of the Beak release it scaffolds.
///
/// Kept in step with `pubspec.yaml` by `test/src/version_test.dart`.
/// `beak create` pins a new project's git dependency to the release tag
/// (`v0.9.0` for `0.9.0`), so a scaffold resolves the framework the CLI that
/// wrote it was built against.
library;

/// This CLI's version, as the pubspec declares it.
const String beakCliVersion = '0.9.0';

/// The git ref a scaffolded project depends on unless `--beak-ref` names
/// another: the release tag of [beakCliVersion].
const String beakReleaseRef = 'v$beakCliVersion';
