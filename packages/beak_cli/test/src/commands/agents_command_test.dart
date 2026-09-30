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

  Future<int> run(List<String> args) async {
    out.clear();
    return await createBeakRunner(
          BeakCliEnvironment(
            out: out,
            rootDirectory: fixture.project,
            now: () => DateTime.utc(2026, 7, 26, 12),
            probe: (host, port) async => false,
          ),
        ).run(['agents', ...args]) ??
        0;
  }

  void resolved({bool skill = false}) {
    fixture
      ..writeProject()
      ..writeBundle();
    if (skill) {
      fixture.writeSkill('beak', 'beak-add-resource');
    }
    fixture.resolve(['beak_core', if (skill) 'beak']);
  }

  test('writes the files, the docs and the skills', () async {
    resolved(skill: true);

    expect(await run([]), 0);

    expect(out.toString().split('\n'), [
      '  agents   AGENTS.md created · CLAUDE.md created',
      '  docs     Beak 0.9.0',
      '  skills   .claude/skills: 1 installed',
      '  skills   .agents/skills: 1 installed',
      '',
    ]);
    expect(fixture.exists('AGENTS.md'), isTrue);
    expect(fixture.read('CLAUDE.md'), '@AGENTS.md\n');
    expect(fixture.exists('.dart_tool/beak/docs/ai-index.md'), isTrue);
    expect(fixture.exists('.claude/skills/beak-add-resource/SKILL.md'), isTrue);
  });

  test('a second run writes nothing', () async {
    resolved(skill: true);
    await run([]);
    final Set<String> mtimes = {
      for (final entity in fixture.project.listSync(recursive: true))
        if (entity is File) '${entity.path} ${entity.lastModifiedSync()}',
    };

    expect(await run([]), 0);

    expect(out.toString(), contains('agents   up to date'));
    expect(out.toString(), contains('1 up to date'));
    expect({
      for (final entity in fixture.project.listSync(recursive: true))
        if (entity is File) '${entity.path} ${entity.lastModifiedSync()}',
    }, mtimes);
  });

  test('--check exits 1 and writes nothing while changes are needed', () async {
    resolved(skill: true);

    expect(await run(['--check']), 1);

    expect(out.toString(), contains('  would create AGENTS.md'));
    expect(out.toString(), contains('  would create CLAUDE.md'));
    expect(
      out.toString(),
      contains('  skills   .claude/skills: 1 to be installed'),
    );
    expect(out.toString(), contains('run `beak agents`'));
    expect(fixture.exists('AGENTS.md'), isFalse);
    expect(fixture.exists('.claude'), isFalse);
    expect(fixture.exists('.dart_tool/beak'), isFalse);
  });

  test('--check exits 0 once everything is current', () async {
    resolved(skill: true);
    await run([]);

    expect(await run(['--check']), 0);
    expect(out.toString(), isNot(contains('would')));
  });

  test(
    '--check leaves the docs copy out: it is in .dart_tool, uncommitted',
    () async {
      resolved();
      await run([]);
      Directory(
        p.join(fixture.project.path, '.dart_tool', 'beak'),
      ).deleteSync(recursive: true);

      expect(await run(['--check']), 0);

      expect(out.toString(), contains('would copy the docs of Beak 0.9.0'));
      expect(fixture.exists('.dart_tool/beak'), isFalse);
    },
  );

  test('--dry-run prints the plan and exits 0', () async {
    resolved();

    expect(await run(['--dry-run']), 0);

    expect(out.toString(), contains('would create AGENTS.md'));
    expect(fixture.exists('AGENTS.md'), isFalse);
  });

  test('--print writes the block to stdout and nothing else', () async {
    resolved();

    expect(await run(['--print']), 0);

    expect(out.toString(), startsWith('<!-- BEGIN:beak-agent-rules -->\n'));
    expect(
      out.toString().trimRight(),
      endsWith('<!-- END:beak-agent-rules -->'),
    );
    expect(fixture.exists('AGENTS.md'), isFalse);
    expect(fixture.exists('.dart_tool/beak'), isFalse);
  });

  test('--print works for a project that opted out', () async {
    fixture
      ..writeProject(beakYaml: 'agents:\n  instructions: none\n')
      ..writeBundle()
      ..resolve(['beak_core']);

    expect(await run(['--print']), 0);
    expect(out.toString(), contains('Beak 0.9.0'));
  });

  test('a damaged block exits 1 and names the file', () async {
    resolved();
    fixture.write('app/AGENTS.md', '<!-- BEGIN:beak-agent-rules -->\n');

    expect(await run([]), 1);

    expect(out.toString(), contains('  ! AGENTS.md: '));
    expect(fixture.read('AGENTS.md'), '<!-- BEGIN:beak-agent-rules -->\n');
  });

  test('--remove strips what it wrote and uninstalls the skills', () async {
    resolved(skill: true);
    await run([]);

    expect(await run(['--remove']), 0);

    expect(fixture.exists('CLAUDE.md'), isFalse);
    expect(
      fixture.read('AGENTS.md'),
      isNot(contains('BEGIN:beak-agent-rules')),
    );
    expect(fixture.exists('.claude/skills/beak-add-resource'), isFalse);
    expect(out.toString(), contains('CLAUDE.md deleted'));
    expect(out.toString(), contains('1 removed'));
  });

  test('--remove --check exits 1 while there is something to remove', () async {
    resolved();
    await run([]);

    expect(await run(['--remove', '--check']), 1);
    expect(fixture.exists('CLAUDE.md'), isTrue);
  });

  group('--skills', () {
    test('picks the targets', () async {
      resolved(skill: true);

      expect(await run(['--skills', 'cursor']), 0);

      expect(
        fixture.exists('.cursor/skills/beak-add-resource/SKILL.md'),
        isTrue,
      );
      expect(fixture.exists('.claude/skills'), isFalse);
    });

    test('takes several, comma separated', () async {
      resolved(skill: true);

      await run(['--skills', 'claude,cursor']);

      expect(fixture.exists('.claude/skills/beak-add-resource'), isTrue);
      expect(fixture.exists('.cursor/skills/beak-add-resource'), isTrue);
      expect(fixture.exists('.agents/skills'), isFalse);
    });

    test('none installs no skills', () async {
      resolved(skill: true);

      await run(['--skills', 'none']);

      expect(fixture.exists('.claude/skills'), isFalse);
      expect(out.toString(), isNot(contains('skills')));
    });

    test('rejects a target it does not know', () async {
      resolved();

      expect(run(['--skills', 'claude,vim']), throwsA(isA<UsageException>()));
    });

    test('--force replaces an edited skill', () async {
      resolved(skill: true);
      await run([]);
      File(
        p.join(
          fixture.project.path,
          '.claude/skills/beak-add-resource/SKILL.md',
        ),
      ).writeAsStringSync('mine\n');

      await run([]);
      expect(out.toString(), contains('1 edited, kept'));

      await run(['--force']);
      expect(out.toString(), contains('1 updated'));
      expect(
        fixture.read('.claude/skills/beak-add-resource/SKILL.md'),
        contains('Do the thing.'),
      );
    });
  });

  group('--[no-]instructions and --[no-]docs', () {
    test('--no-instructions writes only the docs', () async {
      resolved();

      expect(await run(['--no-instructions']), 0);

      expect(fixture.exists('AGENTS.md'), isFalse);
      expect(fixture.exists('.dart_tool/beak/docs/ai-index.md'), isTrue);
    });

    test('--no-docs writes only the instructions', () async {
      resolved();

      expect(await run(['--no-docs']), 0);

      expect(fixture.exists('AGENTS.md'), isTrue);
      expect(fixture.exists('.dart_tool/beak'), isFalse);
    });

    test('--instructions overrides beak.yaml', () async {
      fixture
        ..writeProject(beakYaml: 'agents:\n  instructions: none\n')
        ..writeBundle()
        ..resolve(['beak_core']);

      await run(['--instructions']);

      expect(fixture.exists('AGENTS.md'), isTrue);
    });
  });

  group('without pub get', () {
    test('still writes the files, and says the docs and skills wait', () async {
      fixture.writeProject();

      expect(await run([]), 0);

      expect(fixture.exists('AGENTS.md'), isTrue);
      expect(out.toString(), contains('docs     not materialized'));
      expect(
        out.toString(),
        contains('skills   not installed: run `flutter pub get`'),
      );
    });
  });

  test('a project without a Beak dependency exits 1', () async {
    fixture.writeProject(dependencies: const ['flutter']);

    expect(await run([]), 1);
    expect(
      out.toString(),
      contains('no Beak dependency here; run `beak init`'),
    );
    expect(fixture.exists('AGENTS.md'), isFalse);
  });

  test('takes no arguments', () async {
    resolved();

    expect(run(['extra']), throwsA(isA<UsageException>()));
  });

  test('--root names the workspace root', () async {
    fixture
      ..writeProject()
      ..writeBundle()
      ..resolve(['beak_core'], workspaceRoot: 'ws');

    await run(['--root', p.join(fixture.tmp.path, 'ws')]);

    expect(
      File(
        p.join(fixture.tmp.path, 'ws', '.dart_tool/beak/docs/ai-index.md'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(fixture.tmp.path, 'ws', 'AGENTS.md')).existsSync(),
      isTrue,
    );
  });

  group('refreshAgentFiles', () {
    BeakCliEnvironment env() => BeakCliEnvironment(
      out: out,
      rootDirectory: fixture.project,
      now: DateTime.now,
      probe: (host, port) async => false,
    );

    test('prints one line and writes the files and the docs', () {
      out.clear();
      resolved();

      final BeakAgentReport? report = refreshAgentFiles(env());

      expect(report, isNotNull);
      expect(
        out.toString(),
        'agents     AGENTS.md created · CLAUDE.md created · docs Beak 0.9.0, .dart_tool/beak/docs/ai-index.md\n'
            .replaceFirst('agents', '  agents'),
      );
    });

    test('says up to date the second time', () {
      resolved();
      refreshAgentFiles(env());
      out.clear();

      refreshAgentFiles(env());

      expect(
        out.toString(),
        startsWith('  agents     up to date · docs Beak 0.9.0'),
      );
    });

    test('leaves skills alone unless asked', () {
      resolved(skill: true);

      refreshAgentFiles(env());
      expect(fixture.exists('.claude/skills'), isFalse);

      refreshAgentFiles(env(), installSkills: true);
      expect(fixture.exists('.claude/skills/beak-add-resource'), isTrue);
    });

    test('says nothing in a project without Beak', () {
      fixture.writeProject(dependencies: const ['flutter']);

      expect(refreshAgentFiles(env()), isNull);
      expect(out.toString(), isEmpty);
    });

    test('reports a damaged block on its own line', () {
      resolved();
      fixture.write('app/AGENTS.md', '<!-- END:beak-agent-rules -->\n');

      refreshAgentFiles(env());

      expect(out.toString(), contains('  !          AGENTS.md: '));
    });

    test('never throws: a failure becomes a line', () {
      resolved();
      // A directory where AGENTS.md must go.
      Directory(p.join(fixture.project.path, 'AGENTS.md')).createSync();

      expect(() => refreshAgentFiles(env()), returnsNormally);
      expect(out.toString(), contains('agents'));
    });

    test('says why the docs are missing before pub get', () {
      fixture.writeProject();

      refreshAgentFiles(env());

      expect(out.toString(), contains('docs not materialized: '));
      expect(out.toString(), contains('flutter pub get'));
    });
  });
}
