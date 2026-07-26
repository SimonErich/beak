/// Coverage-threshold enforcer for the Beak monorepo (`melos run coverage`).
///
/// Run from the repo root after `melos run test`. For every gated package
/// (under `packages/` and `apps/`, vendored `worm*` excluded) that has a
/// `test/` directory, it locates the lcov report — converting the VM-JSON
/// output of `dart test --coverage` when needed — computes the line-coverage
/// percentage, and exits non-zero if any package misses its threshold.
library;

import 'dart:io';

/// Default line-coverage threshold (in percent) for gated packages.
const int defaultThresholdPct = 85;

/// Per-package threshold overrides, keyed by package directory name.
///
/// Phase 00 scaffolds empty skeletons, so packages start at zero and later
/// phases raise them as real code lands. `beak_core` is pure and holds 100.
const Map<String, int> thresholdOverridesPct = {
  'beak_core': 100,
  'beak_backend': 90,
  'beak_frontend': 85,
  'beak_cli': 85,
  // A testing toolkit whose own tests are thin would be a poor advert.
  'beak_test': 90,
  'reference_admin': 85,
  'reference_admin_server': 85,
};

/// Directories that hold gated packages, relative to the repo root.
const List<String> packageRootDirs = ['packages', 'apps'];

/// Line-coverage numbers extracted from an lcov report.
final class LcovSummary {
  /// Creates a summary of [linesFound] instrumented lines, of which
  /// [linesHit] were executed at least once.
  const LcovSummary({required this.linesFound, required this.linesHit});

  /// Total number of instrumented lines (`DA:` entries).
  final int linesFound;

  /// Number of instrumented lines with a non-zero execution count.
  final int linesHit;

  /// Line coverage in percent. A report with no executable lines counts as
  /// fully covered.
  double get percent => linesFound == 0 ? 100 : linesHit / linesFound * 100;
}

/// Parses the `DA:<line>,<count>` entries of [lcovContent] into an
/// [LcovSummary].
LcovSummary parseLcov(String lcovContent) {
  var linesFound = 0;
  var linesHit = 0;
  for (final line in lcovContent.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('DA:')) {
      continue;
    }
    linesFound += 1;
    final parts = trimmed.substring('DA:'.length).split(',');
    final hitCount = parts.length < 2 ? 0 : int.tryParse(parts[1]) ?? 0;
    if (hitCount > 0) {
      linesHit += 1;
    }
  }
  return LcovSummary(linesFound: linesFound, linesHit: linesHit);
}

/// The line-coverage threshold (in percent) that [packageName] must meet.
int thresholdFor(String packageName) =>
    thresholdOverridesPct[packageName] ?? defaultThresholdPct;

/// Whether [summary] satisfies a [thresholdPct] percent line-coverage floor.
bool meetsThreshold(LcovSummary summary, int thresholdPct) =>
    summary.percent >= thresholdPct;

Future<void> main() async {
  final failures = <String>[];
  for (final package in _gatedPackages()) {
    final name = package.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    if (!Directory('${package.path}/test').existsSync()) {
      continue;
    }
    final summary = await _packageCoverage(package);
    if (summary == null) {
      failures.add('$name: no coverage data — run `melos run test` first');
      continue;
    }
    final thresholdPct = thresholdFor(name);
    final report =
        '$name: ${summary.percent.toStringAsFixed(1)}% line coverage '
        '(threshold $thresholdPct%, ${summary.linesHit}/${summary.linesFound} '
        'lines)';
    if (meetsThreshold(summary, thresholdPct)) {
      stdout.writeln('OK   $report');
    } else {
      stdout.writeln('FAIL $report');
      failures.add(report);
    }
  }
  if (failures.isNotEmpty) {
    stderr.writeln('Coverage gate failed:');
    failures.forEach(stderr.writeln);
    exitCode = 1;
    return;
  }
  stdout.writeln('Coverage gate passed.');
}

/// Gated package directories: children of [packageRootDirs] that contain a
/// `pubspec.yaml`, excluding the vendored `worm*` packages.
List<Directory> _gatedPackages() {
  final packages = <Directory>[];
  for (final rootDir in packageRootDirs) {
    final root = Directory(rootDir);
    if (!root.existsSync()) {
      continue;
    }
    for (final entity in root.listSync(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      if (name.startsWith('worm')) {
        continue;
      }
      if (File('${entity.path}/pubspec.yaml').existsSync()) {
        packages.add(entity);
      }
    }
  }
  packages.sort((a, b) => a.path.compareTo(b.path));
  return packages;
}

/// Reads (or first produces) the lcov report of [package] and summarizes it.
///
/// `flutter test --coverage` writes `coverage/lcov.info` directly, while
/// `dart test --coverage` writes VM-JSON files that are converted here via
/// `package:coverage`'s `format_coverage`. Returns `null` when no coverage
/// data exists.
Future<LcovSummary?> _packageCoverage(Directory package) async {
  final lcovFile = File('${package.path}/coverage/lcov.info');
  if (!lcovFile.existsSync()) {
    final coverageDir = Directory('${package.path}/coverage');
    if (!coverageDir.existsSync()) {
      return null;
    }
    final hasVmJson = coverageDir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .any((f) => f.path.endsWith('.json'));
    if (!hasVmJson) {
      return null;
    }
    final result = await Process.run('dart', [
      'run',
      'coverage:format_coverage',
      '--lcov',
      '--in=${coverageDir.path}',
      '--out=${lcovFile.path}',
      '--packages=${package.path}/.dart_tool/package_config.json',
      '--report-on=${package.path}/lib',
    ]);
    if (result.exitCode != 0) {
      // interop: ProcessResult.stderr is typed dynamic in dart:io.
      final Object? processStderr = result.stderr;
      stderr.writeln('format_coverage failed for ${package.path}:');
      stderr.writeln(processStderr);
      return null;
    }
  }
  return parseLcov(lcovFile.readAsStringSync());
}
