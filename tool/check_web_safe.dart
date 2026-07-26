/// Web-safety guard for the panel-side import graph (`melos run guard-web`).
///
/// A Beak project is one package with two entrypoints: `lib/main.dart` (the
/// Flutter panel, which must build for web) and `bin/serve.dart` (the Dart VM
/// server). Pubspec *dependencies* cost nothing — only *imports* reach the
/// compiler — so the split is real only as long as nothing the panel imports
/// pulls in server code.
///
/// Nothing enforces that on its own. `dart:io` is not a compile error on web:
/// dart2js and dartdevc both ship a patched `dart:io` whose members throw at
/// runtime, so a stray server import produces a green build, a fatter bundle,
/// and an `UnsupportedError` in the browser. It also silently costs the
/// package its `platform:web` tag on pub.dev, because pana walks transitive
/// imports the same way this tool does.
///
/// So: walk the import graph from each panel-side entrypoint and fail on any
/// web-unsafe URI. Beak's own packages are traversed; everything else is a
/// boundary node, checked by URI but not walked into (pana covers those).
///
/// Sibling of `tool/check_no_material.dart`, and wired into `melos run
/// analyze` next to it.
library;

import 'dart:io';

/// SDK libraries that do not work in a browser.
///
/// `dart:io` is the one that actually bites: it compiles on web and throws at
/// runtime, so only a guard like this one catches it.
const List<String> webUnsafeSdkLibraries = [
  'dart:io',
  'dart:ffi',
  'dart:mirrors',
];

/// Package prefixes that belong to the server half of Beak.
///
/// Matched as prefixes so `package:worm_postgres/...` and
/// `package:beak_storage_s3/...` are caught alongside their roots.
const List<String> webUnsafePackagePrefixes = [
  'package:beak_backend',
  'package:beak_image',
  'package:beak_storage_',
  'package:minio',
  'package:postgres',
  'package:shelf',
  'package:worm',
];

/// The panel-side entrypoints whose import graphs must stay web-safe,
/// relative to the repo root.
const List<String> panelEntrypoints = [
  'packages/beak_core/lib/beak_core.dart',
  'packages/beak_frontend/lib/beak_frontend.dart',
];

/// Package name prefixes whose sources this tool walks into.
///
/// Third-party packages are boundary nodes: their URI is still checked, but
/// their sources are pana's problem, not ours.
const String walkedPackagePrefix = 'beak_';

/// Returns why [uri] is unsafe for a web build, or `null` when it is fine.
///
/// The message is the user-facing half of a failure, so it names the rule
/// rather than just echoing the URI.
String? webUnsafeReason(String uri) {
  for (final library in webUnsafeSdkLibraries) {
    if (uri == library || uri.startsWith('$library/')) {
      return '$library does not work in a browser';
    }
  }
  for (final prefix in webUnsafePackagePrefixes) {
    if (uri.startsWith(prefix)) {
      return '$prefix is server-side code';
    }
  }
  return null;
}

/// Returns every URI [dartSource] pulls in via `import`, `export` or `part`.
///
/// Deliberately line-based and directive-anchored, matching
/// `forbiddenImportsIn` in `tool/check_no_material.dart`: a URI mentioned in a
/// doc comment or a string constant is not an import.
List<String> referencedUrisIn(String dartSource) {
  final uris = <String>[];
  for (final line in dartSource.split('\n')) {
    final trimmed = line.trim();
    final isDirective =
        trimmed.startsWith('import ') ||
        trimmed.startsWith('export ') ||
        trimmed.startsWith('part ');
    if (!isDirective || trimmed.startsWith('part of ')) {
      continue;
    }
    final match = RegExp("""['"]([^'"]+)['"]""").firstMatch(trimmed);
    if (match != null) {
      uris.add(match.group(1)!);
    }
  }
  return uris;
}

/// Resolves [uri], referenced from [fromFilePath], to a repo file path, or
/// `null` when it is a boundary node this tool does not walk into.
String? resolveWalkableUri(String uri, {required String fromFilePath}) {
  if (uri.startsWith('dart:')) {
    return null;
  }
  if (uri.startsWith('package:')) {
    final withoutScheme = uri.substring('package:'.length);
    final int slash = withoutScheme.indexOf('/');
    if (slash < 0) {
      return null;
    }
    final String package = withoutScheme.substring(0, slash);
    final String path = withoutScheme.substring(slash + 1);
    if (!package.startsWith(walkedPackagePrefix)) {
      return null;
    }
    return 'packages/$package/lib/$path';
  }
  final Uri base = Uri.file(fromFilePath);
  return base.resolve(uri).toFilePath();
}

/// One web-unsafe URI, and the chain of files that reached it.
final class WebSafetyViolation {
  /// Creates a violation.
  const WebSafetyViolation({
    required this.uri,
    required this.reason,
    required this.importChain,
  });

  /// The offending `import`/`export`/`part` URI.
  final String uri;

  /// Why [uri] is unsafe, from [webUnsafeReason].
  final String reason;

  /// File paths from the entrypoint down to the file declaring [uri].
  final List<String> importChain;

  @override
  String toString() =>
      '$uri — $reason\n    via ${importChain.join('\n     -> ')}';
}

/// Walks the import graph rooted at [entrypoint] and returns every
/// web-unsafe URI it reaches.
///
/// [readFile] is injected so the walk is testable against an in-memory file
/// system; it returns `null` for a path that does not exist, which is how
/// generated or platform-conditional files are tolerated.
List<WebSafetyViolation> webSafetyViolations(
  String entrypoint, {
  required String? Function(String path) readFile,
}) {
  final violations = <WebSafetyViolation>[];
  final visited = <String>{};
  final pending = <List<String>>[
    [entrypoint],
  ];
  while (pending.isNotEmpty) {
    final List<String> chain = pending.removeLast();
    final String path = chain.last;
    if (!visited.add(path)) {
      continue;
    }
    final String? source = readFile(path);
    if (source == null) {
      continue;
    }
    for (final uri in referencedUrisIn(source)) {
      final String? reason = webUnsafeReason(uri);
      if (reason != null) {
        violations.add(
          WebSafetyViolation(uri: uri, reason: reason, importChain: chain),
        );
        continue;
      }
      final String? next = resolveWalkableUri(uri, fromFilePath: path);
      if (next != null) {
        pending.add([...chain, next]);
      }
    }
  }
  return violations;
}

void main() {
  String? readFile(String path) {
    final file = File(path);
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  final violations = <WebSafetyViolation>[];
  for (final entrypoint in panelEntrypoints) {
    violations.addAll(webSafetyViolations(entrypoint, readFile: readFile));
  }
  if (violations.isNotEmpty) {
    stderr.writeln(
      'Web-unsafe imports reachable from the panel entrypoints:\n',
    );
    violations.map((v) => '  $v\n').forEach(stderr.writeln);
    stderr.writeln(
      'Move server-side code behind a separate library (see '
      'package:beak_core/io.dart) so the panel graph stays web-safe.',
    );
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Web-safety guard passed '
    '(${panelEntrypoints.length} panel entrypoints walked).',
  );
}
