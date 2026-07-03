import 'dart:io';

import 'package:beak_cli/beak_cli.dart';
import 'package:test/test.dart';

/// The Definition-of-Done proof: `beak make:resource Widget` output must
/// compile and pass the repo's strict analysis inside a fresh package
/// depending only on worm and beak_core.
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
      final int? code = await createBeakRunner(environment).run([
        'make:resource',
        'Widget',
        '--fields',
        'name:string,notes:text,stock:int,price:decimal,'
            'active:bool,released_at:datetime',
      ]);
      expect(code, 0);

      File('${temp.path}/pubspec.yaml').writeAsStringSync('''
name: generated_probe
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  beak_core:
    path: ${repoRoot.path}/packages/beak_core
  worm:
    path: ${repoRoot.path}/packages/worm
dev_dependencies:
  lints: ^6.0.0
''');
      File('${temp.path}/analysis_options.yaml').writeAsStringSync(
        File('${repoRoot.path}/analysis_options.yaml').readAsStringSync(),
      );

      Future<ProcessResult> run(List<String> command) => Process.run(
        command.first,
        command.skip(1).toList(),
        workingDirectory: temp.path,
      );

      final ProcessResult pubGet = await run(['dart', 'pub', 'get']);
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
