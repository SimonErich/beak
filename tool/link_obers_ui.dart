/// Links Beak against a local obers_ui checkout (`melos run link-obers-ui`).
///
/// Beak depends on obers_ui by pinned git commit, so a fresh clone resolves
/// with nothing else on disk. Contributors who change obers_ui and Beak
/// together want the opposite: their working copy, hot-reloadable.
///
/// This writes path `dependency_overrides` into the `pubspec_overrides.yaml`
/// of the packages that actually depend on obers_ui. Melos owns the entries
/// listed in each file's `# melos_managed_dependency_overrides:` header and
/// leaves everything else alone, so these survive `melos bootstrap`.
///
/// ```bash
/// melos run link-obers-ui              # use ../obers_ui
/// melos run link-obers-ui -- --unlink  # back to the pinned commits
/// ```
library;

import 'dart:io';

/// The obers_ui packages, mapped to their path inside the checkout.
///
/// The empty string is the checkout root (the `obers_ui` package itself).
const Map<String, String> obersUiPackagePaths = {
  'obers_ui': '',
  'obers_ui_autoforms': 'packages/obers_ui_autoforms',
  'obers_ui_charts': 'packages/obers_ui_charts',
};

/// The sibling checkout Beak links against, relative to the repo root.
const String obersUiCheckoutDir = '../obers_ui';

/// Marker introducing the block this tool owns, so `--unlink` can remove
/// exactly what `--link` added without disturbing melos's entries.
const String blockMarker = '# beak: linked obers_ui checkout';

/// Returns the obers_ui package names [pubspecSource] declares as
/// dependencies, in the order [obersUiPackagePaths] lists them.
List<String> obersUiDependenciesOf(String pubspecSource) => [
  for (final package in obersUiPackagePaths.keys)
    if (RegExp('^  $package:\$', multiLine: true).hasMatch(pubspecSource))
      package,
];

/// Returns [overridesSource] with this tool's block removed.
///
/// An absent block is not an error — unlinking twice is a no-op.
String withoutObersUiBlock(String overridesSource) {
  final int start = overridesSource.indexOf(blockMarker);
  if (start < 0) {
    return overridesSource;
  }
  return '${overridesSource.substring(0, start).trimRight()}\n';
}

/// Returns [overridesSource] with path overrides for [packages] appended,
/// replacing any block a previous run wrote.
///
/// [depthFromRoot] is how many directories deep the package sits inside the
/// repo (2 for `packages/x` and `examples/x`), which sets how far the relative
/// path has to climb.
String withObersUiBlock(
  String overridesSource, {
  required List<String> packages,
  required int depthFromRoot,
}) {
  // `obersUiCheckoutDir` is relative to the repo root, so climb out of the
  // package first: packages/beak_frontend + ../obers_ui => ../../../obers_ui.
  final String climb = '../' * depthFromRoot;
  final buffer = StringBuffer(withoutObersUiBlock(overridesSource))
    ..writeln(blockMarker);
  for (final package in packages) {
    final String suffix = obersUiPackagePaths[package]!;
    final String path =
        '$climb$obersUiCheckoutDir${suffix.isEmpty ? '' : '/$suffix'}';
    buffer
      ..writeln('  $package:')
      ..writeln('    path: $path');
  }
  return buffer.toString();
}

/// Ensures [overridesSource] starts with a `dependency_overrides:` mapping.
String withDependencyOverridesHeader(String overridesSource) =>
    overridesSource.contains('dependency_overrides:')
    ? overridesSource
    : '${overridesSource.trimRight()}\ndependency_overrides:\n'.trimLeft();

void main(List<String> args) {
  final bool unlink = args.contains('--unlink');
  final checkout = Directory(obersUiCheckoutDir);
  if (!unlink && !checkout.existsSync()) {
    stderr.writeln(
      'No obers_ui checkout at $obersUiCheckoutDir.\n'
      'Clone it next to this repo:\n'
      '  git clone https://github.com/SimonErich/obers_ui.git '
      '$obersUiCheckoutDir',
    );
    exitCode = 1;
    return;
  }

  var touched = 0;
  for (final dir in ['packages', 'examples']) {
    final root = Directory(dir);
    if (!root.existsSync()) {
      continue;
    }
    for (final entity in root.listSync(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final pubspec = File('${entity.path}/pubspec.yaml');
      if (!pubspec.existsSync()) {
        continue;
      }
      final List<String> packages = obersUiDependenciesOf(
        pubspec.readAsStringSync(),
      );
      if (packages.isEmpty) {
        continue;
      }
      final overrides = File('${entity.path}/pubspec_overrides.yaml');
      final String existing = overrides.existsSync()
          ? overrides.readAsStringSync()
          : '';
      final String updated = unlink
          ? withoutObersUiBlock(existing)
          : withObersUiBlock(
              withDependencyOverridesHeader(existing),
              packages: packages,
              depthFromRoot: 2,
            );
      if (updated.trim().isEmpty) {
        if (overrides.existsSync()) {
          overrides.deleteSync();
        }
      } else {
        overrides.writeAsStringSync(updated);
      }
      touched += 1;
      stdout.writeln(
        '${unlink ? 'unlinked' : 'linked'} ${entity.path} '
        '(${packages.join(', ')})',
      );
    }
  }
  stdout.writeln(
    unlink
        ? 'Restored the pinned obers_ui commits in $touched packages.'
        : 'Linked $touched packages against $obersUiCheckoutDir.',
  );
}
