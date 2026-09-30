import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../agents/beak_docs_bundle.dart';
import '../agents/beak_project_kind.dart';
import '../agents/beak_workspace.dart';
import '../cli_runner.dart';
import '../project/beak_project_config.dart';

/// Puts the docs of the Beak version the project resolved where an agent can
/// read them.
///
/// The docs ship inside `beak_core`, in the pub cache, and are copied to
/// `.dart_tool/beak/docs/` in the workspace root: a coding agent's training
/// data is older than Beak, and this is the copy that matches the code it is
/// about to write. `beak prepare` and `beak agents` refresh it too, so this
/// is for running it by hand, and for scripts that want the path.
///
/// ```console
/// $ beak docs
///   docs  Beak 0.9.0 · 186 pages · .dart_tool/beak/docs/
///   start ai-index: .dart_tool/beak/docs/ai-index.md
/// $ beak docs --path
/// /home/me/acme_admin/.dart_tool/beak/docs
/// ```
final class DocsCommand extends Command<int> {
  /// Creates the command against [environment].
  DocsCommand(this.environment) {
    argParser
      ..addFlag(
        'path',
        help: 'Print only the absolute path of the docs folder.',
        negatable: false,
      )
      ..addFlag(
        'json',
        help: 'Print version, path, index, source and page count as JSON.',
        negatable: false,
      )
      ..addOption(
        'root',
        help:
            'The pub workspace root, when it cannot be found by walking up '
            'from this project.',
        valueHelp: 'dir',
      );
  }

  /// The injected seams.
  final BeakCliEnvironment environment;

  @override
  String get name => 'docs';

  @override
  String get description =>
      'Copy the docs of the resolved Beak version to .dart_tool/beak/docs.';

  @override
  String get invocation => 'beak docs [--path] [--json] [--root <dir>]';

  @override
  Future<int> run() async {
    if ((argResults?.rest ?? const []).isNotEmpty) {
      throw UsageException('beak docs takes no arguments.', invocation);
    }
    final Directory root = environment.rootDirectory;
    if (BeakProjectKind.isModelsOnly(root)) {
      environment.out.writeln(BeakProjectKind.modelsOnlyPackage);
      return 0;
    }
    final BeakProjectConfig config = BeakProjectConfig.load(
      root,
      packageName: BeakProjectConfig.packageNameOf(root),
    );
    if (BeakProjectKind.detect(root, config: config) == null) {
      environment.out.writeln(BeakProjectKind.notABeakProject);
      return 1;
    }
    final BeakDocsResult result = materializeDocs(
      BeakWorkspace.locate(root, workspaceRoot: _workspaceRoot()),
    );
    return switch (result) {
      BeakDocsUnavailable(:final reason) => _unavailable(reason),
      BeakDocsReady() => _print(result),
    };
  }

  int _unavailable(String reason) {
    environment.out.writeln('  docs  not available: $reason');
    return 1;
  }

  int _print(BeakDocsReady ready) {
    final String directory = p.absolute(ready.directory.path);
    if (argResults?['json'] == true) {
      environment.out.writeln(
        const JsonEncoder.withIndent('  ').convert({
          'version': ready.version,
          'path': directory,
          'index': p.absolute(ready.indexFile.path),
          'source': p.absolute(ready.source.parent.parent.path),
          'pages': ready.pages,
        }),
      );
    } else if (argResults?['path'] == true) {
      environment.out.writeln(directory);
    } else {
      final String shown = _shown(ready.directory);
      environment.out
        ..writeln(
          '  docs   Beak ${ready.version} · ${ready.pages} pages · $shown/',
        )
        ..writeln('  start  ai-index: ${_shown(ready.indexFile)}');
    }
    return 0;
  }

  /// [entity] relative to the project, in posix form.
  String _shown(FileSystemEntity entity) => p.posix.joinAll(
    p.split(p.relative(entity.path, from: environment.rootDirectory.path)),
  );

  Directory? _workspaceRoot() => switch (argResults?['root']) {
    final String path => Directory(p.absolute(path)),
    _ => null,
  };
}
