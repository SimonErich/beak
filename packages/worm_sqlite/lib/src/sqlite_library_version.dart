/// Numeric comparison of SQLite library version strings.
library;

/// Whether [libVersion] is at least [minimum].
///
/// Both are dotted version strings in the shape the `sqlite3` driver reports
/// (`3.45.1`). Components compare as numbers rather than as text, because text
/// ordering puts `3.9.0` *after* `3.35.0` while it is in fact four years
/// older, and SQLite's feature floors (`DROP COLUMN` at 3.35) sit exactly
/// where that inversion bites.
///
/// A component [minimum] declares and [libVersion] omits reads as zero, so
/// `3.35` satisfies a `3.35.0` floor. A component that is not a number reads
/// as zero too, which fails the check rather than waving an unrecognised
/// build through.
bool sqliteVersionAtLeast(String libVersion, {required String minimum}) {
  final actual = _components(libVersion);
  final floor = _components(minimum);
  for (var index = 0; index < floor.length; index++) {
    final left = index < actual.length ? actual[index] : 0;
    final right = floor[index];
    if (left != right) return left > right;
  }
  return true;
}

List<int> _components(String version) => <int>[
  for (final part in version.split('.')) int.tryParse(part.trim()) ?? 0,
];
