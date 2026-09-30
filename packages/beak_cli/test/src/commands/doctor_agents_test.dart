import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../support/agents_fixture.dart';
import '../../support/beak_cli_internals.dart';

void main() {
  late AgentsFixture fixture;

  setUp(() {
    fixture = AgentsFixture();
  });

  /// A resolved project whose Beak is [version].
  void project({
    String version = '0.9.0',
    String? beakYaml,
    bool resolved = true,
  }) {
    fixture.writeProject(beakYaml: beakYaml);
    if (resolved) {
      fixture
        ..writeBundle(version: version)
        ..resolve(['beak_core']);
    }
  }

  /// Writes every agent file, as `beak agents` does.
  void agents([BeakAgentOptions options = const BeakAgentOptions()]) {
    syncAgentFiles(fixture.project, options: options);
  }

  Future<List<BeakCheck>> agentChecks() async {
    final List<BeakCheck> checks = await diagnose(
      BeakCliEnvironment(
        out: StringBuffer(),
        rootDirectory: fixture.project,
        now: () => DateTime.utc(2026, 7, 26, 12),
        probe: (host, port) async => false,
      ),
    );
    return [
      for (final check in checks)
        if (check.group == 'agents') check,
    ];
  }

  BeakCheck checkMatching(
    List<BeakCheck> checks,
    String needle,
  ) => checks.firstWhere(
    (check) => check.label.contains(needle),
    orElse: () => throw StateError(
      'no check matching "$needle" in:\n'
      '${checks.map((check) => '  ${check.status.name} ${check.label}').join('\n')}',
    ),
  );

  test('a project that is fully set up passes every agents check', () async {
    project();
    agents();

    final List<BeakCheck> checks = await agentChecks();

    expect(
      checks.map((check) => check.status),
      everyElement(BeakCheckStatus.ok),
    );
    expect(
      checkMatching(checks, 'AGENTS.md has the Beak 0.9.0 block').remedy,
      isNull,
    );
    expect(
      checkMatching(checks, 'CLAUDE.md reads AGENTS.md').status,
      BeakCheckStatus.ok,
    );
    expect(checkMatching(checks, 'KiB').status, BeakCheckStatus.ok);
    expect(checkMatching(checks, 'docs bundle').label, contains('Beak 0.9.0'));
    expect(
      checkMatching(checks, 'no Beak skills installed').remedy,
      contains('beak agents'),
    );
    expect(
      checkMatching(checks, 'CLI $beakCliVersion').status,
      BeakCheckStatus.ok,
    );
  });

  test('no check about agents ever fails', () async {
    project();

    final List<BeakCheck> checks = await agentChecks();

    expect(checks, isNotEmpty);
    expect(
      checks.map((check) => check.status),
      isNot(contains(BeakCheckStatus.fail)),
    );
  });

  test('a project without a Beak dependency has no agents checks', () async {
    fixture.writeProject(dependencies: const ['flutter']);

    expect(await agentChecks(), isEmpty);
  });

  group('agent instructions', () {
    test('a missing block is a warning that says beak agents', () async {
      project();

      final BeakCheck check = checkMatching(
        await agentChecks(),
        'no Beak block',
      );

      expect(check.status, BeakCheckStatus.warn);
      expect(check.label, startsWith('AGENTS.md'));
      expect(check.remedy, 'beak agents');
    });

    test('a file without the markers is missing the block too', () async {
      project();
      fixture.write('app/AGENTS.md', '# Mine\n');

      expect(
        checkMatching(await agentChecks(), 'no Beak block').status,
        BeakCheckStatus.warn,
      );
    });

    test('an out-of-date block is a warning that says beak prepare', () async {
      project(version: '0.9.0');
      agents();
      fixture.writeBundle(version: '0.9.1');
      fixture.write(
        'app/.dart_tool/package_config.json',
        File(
          p.join(fixture.project.path, '.dart_tool/package_config.json'),
        ).readAsStringSync(),
      );

      final BeakCheck check = checkMatching(await agentChecks(), 'out-of-date');

      expect(check.status, BeakCheckStatus.warn);
      expect(check.remedy, 'beak prepare');
    });

    test('damaged markers are a warning naming the file', () async {
      project();
      fixture.write('app/AGENTS.md', '<!-- BEGIN:beak-agent-rules -->\n');

      final BeakCheck check = checkMatching(await agentChecks(), 'AGENTS.md: ');

      expect(check.status, BeakCheckStatus.warn);
      expect(check.label, contains('no END marker'));
      expect(check.remedy, contains('markers'));
    });

    test('disabled in beak.yaml is fine', () async {
      project(beakYaml: 'agents:\n  instructions: none\n');

      final List<BeakCheck> checks = await agentChecks();

      expect(
        checkMatching(checks, 'disabled in beak.yaml').status,
        BeakCheckStatus.ok,
      );
      expect(checks.where((c) => c.label.contains('no Beak block')), isEmpty);
    });
  });

  group('Claude pairing', () {
    test('an AGENTS.md no CLAUDE.md reads is a warning', () async {
      project();
      agents();
      File(p.join(fixture.project.path, 'CLAUDE.md')).deleteSync();

      final BeakCheck check = checkMatching(
        await agentChecks(),
        'no CLAUDE.md reads it',
      );

      expect(check.status, BeakCheckStatus.warn);
      expect(check.remedy, 'beak agents');
    });

    test(
      '.claude/CLAUDE.md importing @AGENTS.md is the wrong relative path',
      () async {
        project();
        agents();
        File(p.join(fixture.project.path, 'CLAUDE.md')).deleteSync();
        fixture.write('app/.claude/CLAUDE.md', '@AGENTS.md\n');

        final BeakCheck check = checkMatching(
          await agentChecks(),
          '.claude/CLAUDE.md',
        );

        expect(check.status, BeakCheckStatus.warn);
        expect(check.remedy, contains('@../AGENTS.md'));
      },
    );

    test('is not checked while there is no AGENTS.md', () async {
      project();

      expect(
        (await agentChecks()).where((c) => c.label.contains('CLAUDE')),
        isEmpty,
      );
    });
  });

  group('AGENTS.md size', () {
    test('over 32 KiB is a warning: Codex reads only that much', () async {
      project();
      agents();
      File(p.join(fixture.project.path, 'AGENTS.md')).writeAsStringSync(
        '${File(p.join(fixture.project.path, 'AGENTS.md')).readAsStringSync()}\n${'x' * 33000}\n',
      );

      final BeakCheck check = checkMatching(await agentChecks(), 'KiB');

      expect(check.status, BeakCheckStatus.warn);
      expect(check.label, contains('first 32 KiB'));
    });
  });

  group('docs bundle', () {
    test('no package config says to run pub get', () async {
      project(resolved: false);

      final BeakCheck check = checkMatching(await agentChecks(), 'docs bundle');

      expect(check.status, BeakCheckStatus.warn);
      expect(check.remedy, 'flutter pub get');
    });

    test('resolved but not copied says beak docs', () async {
      project();

      final BeakCheck check = checkMatching(await agentChecks(), 'docs bundle');

      expect(check.status, BeakCheckStatus.warn);
      expect(check.label, contains('not materialized'));
      expect(check.remedy, 'beak docs');
    });

    test('a copy of another version says beak prepare', () async {
      project(version: '0.9.0');
      agents();
      fixture.writeBundle(version: '0.9.1');

      final BeakCheck check = checkMatching(await agentChecks(), 'docs bundle');

      expect(check.status, BeakCheckStatus.warn);
      expect(check.label, allOf(contains('0.9.0'), contains('0.9.1')));
      expect(check.remedy, 'beak prepare');
    });

    test('a copy of the same version with other pages does not claim the '
        'versions differ', () async {
      // The copy is `.dart_tool` state, and the bundle in beak_core changes
      // while a version is still in development: the label said "Beak 0.9.0
      // but the project resolved Beak 0.9.0".
      project(version: '0.9.0');
      agents();
      fixture.writeBundle(
        version: '0.9.0',
        pages: {'ai/new-page.md': '# New\n'},
      );

      final BeakCheck check = checkMatching(await agentChecks(), 'docs bundle');

      expect(check.status, BeakCheckStatus.warn);
      expect(check.label, contains('0.9.0'));
      expect(check.label, contains('out of date'));
      expect(check.label, isNot(contains('but the project resolved')));
      expect(check.remedy, 'beak prepare');
    });

    test('disabled in beak.yaml is fine', () async {
      project(beakYaml: 'agents:\n  docs: false\n');

      expect(
        checkMatching(await agentChecks(), 'docs bundle').status,
        BeakCheckStatus.ok,
      );
    });
  });

  group('skills', () {
    void withSkill({String body = 'v1\n'}) {
      fixture
        ..writeSkill('beak', 'beak-add-resource', body: body)
        ..resolve(['beak_core', 'beak']);
    }

    test('current ones are counted', () async {
      project();
      withSkill();
      agents();

      final BeakCheck check = checkMatching(await agentChecks(), 'Beak skill');

      expect(check.status, BeakCheckStatus.ok);
      expect(check.label, contains('1 Beak skill installed'));
    });

    test('an outdated one is a warning that says beak agents', () async {
      project();
      withSkill();
      agents();
      withSkill(body: 'v2\n');

      final BeakCheck check = checkMatching(await agentChecks(), 'out of date');

      expect(check.status, BeakCheckStatus.warn);
      expect(check.label, contains('beak-add-resource'));
      expect(check.remedy, 'beak agents');
    });

    test('an edited one is only a note', () async {
      project();
      withSkill();
      agents();
      File(
        p.join(
          fixture.project.path,
          '.claude/skills/beak-add-resource/SKILL.md',
        ),
      ).writeAsStringSync('mine\n');

      final BeakCheck check = checkMatching(await agentChecks(), 'edited');

      expect(check.status, BeakCheckStatus.ok);
      expect(check.label, contains('kept'));
    });
  });

  group('CLI version skew', () {
    test(
      'another minor version is a warning with the way to reactivate',
      () async {
        project(version: '0.10.1');

        final BeakCheck check = checkMatching(
          await agentChecks(),
          'CLI $beakCliVersion',
        );

        expect(check.status, BeakCheckStatus.warn);
        expect(check.label, contains('project Beak 0.10.1'));
        expect(
          check.remedy,
          allOf(contains('--git-ref v0.10.1'), contains('packages/beak_cli')),
        );
      },
    );

    test('a patch difference is fine', () async {
      project(version: '0.9.7');

      expect(
        checkMatching(await agentChecks(), 'CLI $beakCliVersion').status,
        BeakCheckStatus.ok,
      );
    });

    test('is not checked without a resolved Beak', () async {
      project(resolved: false);

      expect(
        (await agentChecks()).where((c) => c.label.contains('CLI ')),
        isEmpty,
      );
    });
  });

  test('--json puts the checks in the agents group', () async {
    project();
    final out = StringBuffer();

    await createBeakRunner(
      BeakCliEnvironment(
        out: out,
        rootDirectory: fixture.project,
        now: () => DateTime.utc(2026, 7, 26, 12),
        probe: (host, port) async => false,
      ),
    ).run(['doctor', '--json']);

    final Object? decoded = jsonDecode(out.toString());
    final List<Object?> checks = switch (decoded) {
      {'checks': final List<Object?> checks} => checks,
      _ => fail('expected checks'),
    };
    final grouped = checks.whereType<Map<String, Object?>>().where(
      (check) => check['group'] == 'agents',
    );
    expect(grouped, isNotEmpty);
    expect(
      checks.whereType<Map<String, Object?>>().where((c) => c['group'] == null),
      isNotEmpty,
      reason: 'the other checks carry no group',
    );
  });

  test('a workspace member also checks the root pointer', () async {
    fixture
      ..write('pubspec.yaml', 'name: root\nworkspace:\n  - app\n')
      ..writeProject(member: true)
      ..writeBundle()
      ..resolve(['beak_core'], workspaceRoot: '.');

    final List<BeakCheck> checks = await agentChecks();

    expect(checks.where((c) => c.label.startsWith('../AGENTS.md')), isNotEmpty);
  });
}
