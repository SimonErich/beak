import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../support/agents_fixture.dart';
import '../../support/beak_cli_internals.dart';

void main() {
  late AgentsFixture fixture;
  late StringBuffer out;

  setUp(() {
    fixture = AgentsFixture();
    out = StringBuffer();
  });

  Future<int> run(List<String> args) async =>
      await createBeakRunner(
        BeakCliEnvironment(
          out: out,
          rootDirectory: fixture.project,
          now: () => DateTime.utc(2026, 7, 26, 12),
          probe: (host, port) async => false,
        ),
      ).run(['docs', ...args]) ??
      0;

  void resolved() {
    fixture
      ..writeProject()
      ..writeBundle()
      ..resolve(['beak_core']);
  }

  test('copies the docs and prints where to start', () async {
    resolved();

    expect(await run([]), 0);

    expect(out.toString().split('\n'), [
      '  docs   Beak 0.9.0 · 2 pages · .dart_tool/beak/docs/',
      '  start  ai-index: .dart_tool/beak/docs/ai-index.md',
      '',
    ]);
    expect(fixture.exists('.dart_tool/beak/docs/ai-index.md'), isTrue);
    expect(
      fixture.exists('.dart_tool/beak/docs/models/defining-models.md'),
      isTrue,
    );
  });

  test('a second run leaves the copy alone', () async {
    resolved();
    await run([]);
    final File index = File(
      p.join(fixture.project.path, '.dart_tool/beak/docs/ai-index.md'),
    )..setLastModifiedSync(DateTime(2020));

    expect(await run([]), 0);
    expect(index.lastModifiedSync(), DateTime(2020));
  });

  test('--path prints only the absolute folder', () async {
    resolved();

    expect(await run(['--path']), 0);

    expect(
      out.toString(),
      '${p.join(fixture.project.path, '.dart_tool', 'beak', 'docs')}\n',
    );
  });

  test(
    '--json prints the version, the paths, the source and the page count',
    () async {
      resolved();

      expect(await run(['--json']), 0);

      expect(jsonDecode(out.toString()), {
        'version': '0.9.0',
        'path': p.join(fixture.project.path, '.dart_tool', 'beak', 'docs'),
        'index': p.join(
          fixture.project.path,
          '.dart_tool',
          'beak',
          'docs',
          'ai-index.md',
        ),
        'source': fixture.package('beak_core').path,
        'pages': 2,
      });
    },
  );

  test('without pub get it exits 1 and says to run it', () async {
    fixture.writeProject();

    expect(await run([]), 1);
    expect(out.toString(), contains('flutter pub get'));
    expect(fixture.exists('.dart_tool/beak/docs'), isFalse);
  });

  test('with a package config but no beak_core it exits 1', () async {
    fixture
      ..writeProject()
      ..resolve(['beak_frontend']);

    expect(await run([]), 1);
    expect(out.toString(), contains('beak_core'));
  });

  test(
    'a project without a Beak dependency is told to run beak init',
    () async {
      fixture.writeProject(dependencies: const ['flutter']);

      expect(await run([]), 1);
      expect(
        out.toString(),
        contains('no Beak dependency here; run `beak init`'),
      );
    },
  );

  test('takes no arguments', () async {
    resolved();

    expect(run(['extra']), throwsA(isA<UsageException>()));
  });

  test('--root names the workspace the docs go to', () async {
    fixture
      ..writeProject()
      ..writeBundle()
      ..resolve(['beak_core'], workspaceRoot: 'ws');

    expect(await run(['--root', p.join(fixture.tmp.path, 'ws')]), 0);

    expect(
      File(
        p.join(fixture.tmp.path, 'ws', '.dart_tool/beak/docs/ai-index.md'),
      ).existsSync(),
      isTrue,
    );
    expect(out.toString(), contains('../ws/.dart_tool/beak/docs/'));
  });
}
