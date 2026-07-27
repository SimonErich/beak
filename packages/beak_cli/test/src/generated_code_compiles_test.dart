import 'dart:io';

import 'package:beak_cli/beak_cli.dart';
import 'package:test/test.dart';

/// The Definition-of-Done proof: `beak make:resource Widget` output must
/// compile and pass the repo's strict analysis inside a fresh project that
/// depends on Beak the way a user's project does — the umbrella, and nothing
/// else. Anything narrower would let a `depend_on_referenced_packages` info
/// through, which is a failure the monorepo can never reproduce.
void main() {
  test(
    'a generated resource compiles and passes strict analyze',
    () async {
      final Directory repoRoot = Directory.current.parent.parent;
      final Directory temp = Directory.systemTemp.createTempSync(
        'beak_generated',
      );
      addTearDown(() => temp.deleteSync(recursive: true));

      final environment = BeakCliEnvironment(
        out: StringBuffer(),
        rootDirectory: temp,
        now: () => DateTime.utc(2026, 7, 3, 12),
        probe: (host, port) async => false,
      );
      File('${temp.path}/pubspec.yaml').writeAsStringSync('''
name: generated_probe
publish_to: none
environment:
  sdk: ^3.11.0
  flutter: '>=3.41.0'
dependencies:
  beak:
    path: ${repoRoot.path}/packages/beak
  flutter:
    sdk: flutter
dev_dependencies:
  lints: ^6.0.0
''');
      // Scaffold after the pubspec exists: `make:resource` now runs
      // `prepare`, which reads the package name from it to write the
      // entrypoint imports.
      final int? code = await createBeakRunner(environment).run([
        'make:resource',
        'Widget',
        '--fields',
        'name:string,notes:text,stock:int,price:decimal,'
            'active:bool,released_at:datetime',
      ]);
      expect(code, 0);

      File('${temp.path}/analysis_options.yaml').writeAsStringSync(
        File('${repoRoot.path}/analysis_options.yaml').readAsStringSync(),
      );

      Future<ProcessResult> run(List<String> command) => Process.run(
        command.first,
        command.skip(1).toList(),
        workingDirectory: temp.path,
      );

      final ProcessResult pubGet = await run(['flutter', 'pub', 'get']);
      expect(pubGet.exitCode, 0, reason: '${pubGet.stdout}\n${pubGet.stderr}');

      final ProcessResult format = await run(['dart', 'format', '.']);
      expect(format.exitCode, 0, reason: '${format.stdout}\n${format.stderr}');

      final ProcessResult analyze = await run([
        'dart',
        'analyze',
        '--fatal-infos',
        '--fatal-warnings',
        '.',
      ]);
      expect(
        analyze.exitCode,
        0,
        reason: '${analyze.stdout}\n${analyze.stderr}',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
