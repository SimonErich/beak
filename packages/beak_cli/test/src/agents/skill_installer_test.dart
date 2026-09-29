import 'dart:convert';
import 'dart:io';

import 'package:beak_cli/src/agents/beak_package_config.dart';
import 'package:beak_cli/src/agents/beak_skill_installer.dart';
import 'package:beak_cli/src/agents/beak_workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late Directory project;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('beak_skills_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    project = Directory(p.join(tmp.path, 'app'))..createSync();
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('name: app\n');
  });

  BeakWorkspace workspace() => BeakWorkspace.locate(project);

  File write(String path, String content) => File(p.join(tmp.path, path))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);

  /// A package `<name>` with `skills/<dir>/SKILL.md` for each of [skills]
  /// (directory name to the `name:` in its front matter, when different).
  void package(
    String name,
    Map<String, String?> skills, {
    String version = '0.9.0',
    String body = 'Do the thing.\n',
  }) {
    write('pkgs/$name/pubspec.yaml', 'name: $name\nversion: $version\n');
    for (final skill in skills.entries) {
      write(
        'pkgs/$name/skills/${skill.key}/SKILL.md',
        '---\nname: ${skill.value ?? skill.key}\n'
            'description: A skill.\n---\n$body',
      );
    }
  }

  BeakPackageConfig resolve(List<String> names) {
    final file = File(p.join(project.path, '.dart_tool', 'package_config.json'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            for (final name in names)
              {
                'name': name,
                'rootUri': Directory(
                  p.join(tmp.path, 'pkgs', name),
                ).uri.toString(),
              },
          ],
        }),
      );
    return BeakPackageConfig.read(file)!;
  }

  BeakSkillReport install(
    BeakPackageConfig config, {
    List<BeakSkillTarget> targets = const [BeakSkillTarget.claude],
    bool force = false,
    bool dryRun = false,
  }) => installSkills(
    workspace: workspace(),
    config: config,
    targets: targets,
    force: force,
    dryRun: dryRun,
  );

  String skillPath(String target, String skill, [String file = 'SKILL.md']) =>
      p.join(project.path, target, 'skills', skill, file);

  Map<BeakSkillOutcome, List<String>> outcomes(BeakSkillReport report) => {
    for (final outcome in BeakSkillOutcome.values)
      if (report.changes.any((c) => c.outcome == outcome))
        outcome: [
          for (final c in report.changes)
            if (c.outcome == outcome) c.name,
        ],
  };

  group('installing', () {
    test('copies each skill folder with a sidecar', () {
      package('beak', {'beak-add-resource': null});
      write('pkgs/beak/skills/beak-add-resource/references/notes.md', 'ref\n');
      final BeakSkillReport report = install(resolve(['beak']));

      expect(outcomes(report), {
        BeakSkillOutcome.installed: ['beak-add-resource'],
      });
      expect(
        File(skillPath('.claude', 'beak-add-resource')).readAsStringSync(),
        contains('name: beak-add-resource'),
      );
      expect(
        File(
          skillPath('.claude', 'beak-add-resource', 'references/notes.md'),
        ).readAsStringSync(),
        'ref\n',
      );
      final Object? sidecar = jsonDecode(
        File(
          skillPath('.claude', 'beak-add-resource', '.beak-skill.json'),
        ).readAsStringSync(),
      );
      expect(sidecar, {
        'package': 'beak',
        'version': '0.9.0',
        'sha256': matches(RegExp(r'^[0-9a-f]{64}$')),
      });
    });

    test('takes skills from several packages, and every target', () {
      package('beak', {'beak-add-resource': null});
      package('beak_frontend', {'beak-frontend-build-screens': null});
      package('beak_serverpod', {'beak-serverpod-add-resource': null});
      final BeakSkillReport report = install(
        resolve(['beak', 'beak_frontend']),
        targets: BeakSkillTarget.values,
      );

      expect(report.changes, hasLength(6));
      for (final target in ['.claude', '.agents', '.cursor']) {
        expect(
          File(skillPath(target, 'beak-add-resource')).existsSync(),
          isTrue,
        );
        expect(
          File(skillPath(target, 'beak-frontend-build-screens')).existsSync(),
          isTrue,
        );
        expect(
          Directory(
            p.join(
              project.path,
              target,
              'skills',
              'beak-serverpod-add-resource',
            ),
          ).existsSync(),
          isFalse,
          reason: 'beak_serverpod is not resolved',
        );
      }
      expect(report.countIn(BeakSkillTarget.agents), 2);
    });

    test(
      'a package name with underscores prefixes its skills with hyphens',
      () {
        package('beak_serverpod', {'beak-serverpod-add-resource': null});
        final BeakSkillReport report = install(resolve(['beak_serverpod']));

        expect(report.warnings, isEmpty);
        expect(report.changes.single.name, 'beak-serverpod-add-resource');
      },
    );

    test('a skill named exactly like its package is accepted', () {
      package('beak', {'beak': null});

      expect(install(resolve(['beak'])).changes.single.name, 'beak');
    });

    test('a second run is unchanged and writes nothing', () {
      package('beak', {'beak-add-resource': null});
      final BeakPackageConfig config = resolve(['beak']);
      install(config);
      final File skill = File(skillPath('.claude', 'beak-add-resource'));
      skill.setLastModifiedSync(DateTime(2020));

      final BeakSkillReport again = install(config);

      expect(outcomes(again), {
        BeakSkillOutcome.unchanged: ['beak-add-resource'],
      });
      expect(again.writes, isFalse);
      expect(skill.lastModifiedSync(), DateTime(2020));
    });

    test('a changed shipped skill replaces an unedited copy', () {
      package('beak', {'beak-add-resource': null}, body: 'v1\n');
      final BeakPackageConfig config = resolve(['beak']);
      install(config);
      package(
        'beak',
        {'beak-add-resource': null},
        version: '0.9.1',
        body: 'v2\n',
      );
      write('pkgs/beak/skills/beak-add-resource/extra.md', 'new file\n');

      final BeakSkillReport report = install(config);

      expect(outcomes(report), {
        BeakSkillOutcome.updated: ['beak-add-resource'],
      });
      expect(
        File(skillPath('.claude', 'beak-add-resource')).readAsStringSync(),
        endsWith('v2\n'),
      );
      expect(
        File(
          skillPath('.claude', 'beak-add-resource', 'extra.md'),
        ).existsSync(),
        isTrue,
      );
    });

    test('an update removes files the new version dropped', () {
      package('beak', {'beak-add-resource': null});
      write('pkgs/beak/skills/beak-add-resource/old.md', 'old\n');
      final BeakPackageConfig config = resolve(['beak']);
      install(config);
      File(
        p.join(tmp.path, 'pkgs/beak/skills/beak-add-resource/old.md'),
      ).deleteSync();
      package('beak', {'beak-add-resource': null}, body: 'changed\n');

      install(config);

      expect(
        File(skillPath('.claude', 'beak-add-resource', 'old.md')).existsSync(),
        isFalse,
      );
    });

    test('an edited skill is kept, and --force replaces it', () {
      package('beak', {'beak-add-resource': null}, body: 'v1\n');
      final BeakPackageConfig config = resolve(['beak']);
      install(config);
      final File skill = File(skillPath('.claude', 'beak-add-resource'));
      skill.writeAsStringSync('my own steps\n');
      package('beak', {'beak-add-resource': null}, body: 'v2\n');

      final BeakSkillReport kept = install(config);

      expect(outcomes(kept), {
        BeakSkillOutcome.keptEdited: ['beak-add-resource'],
      });
      expect(skill.readAsStringSync(), 'my own steps\n');

      final BeakSkillReport forced = install(config, force: true);

      expect(outcomes(forced), {
        BeakSkillOutcome.updated: ['beak-add-resource'],
      });
      expect(skill.readAsStringSync(), endsWith('v2\n'));
    });

    test('an added file counts as an edit', () {
      package('beak', {'beak-add-resource': null});
      final BeakPackageConfig config = resolve(['beak']);
      install(config);
      write('app/.claude/skills/beak-add-resource/mine.md', 'mine\n');

      expect(outcomes(install(config)), {
        BeakSkillOutcome.keptEdited: ['beak-add-resource'],
      });
    });

    test(
      'a folder with the name but no sidecar is not Beak\'s to overwrite',
      () {
        package('beak', {'beak-add-resource': null});
        write('app/.claude/skills/beak-add-resource/SKILL.md', 'theirs\n');

        final BeakSkillReport report = install(resolve(['beak']));

        expect(outcomes(report), {
          BeakSkillOutcome.keptEdited: ['beak-add-resource'],
        });
        expect(
          File(skillPath('.claude', 'beak-add-resource')).readAsStringSync(),
          'theirs\n',
        );
      },
    );

    test('a skill the skills CLI manages is skipped', () {
      package('beak', {'beak-add-resource': null, 'beak-upgrade': null});
      write(
        'app/.dart_skills/skills_config.json',
        jsonEncode({
          'version': 1,
          'installations': {
            'claude': {
              'beak': {
                'skills': [
                  {'name': 'beak-add-resource'},
                ],
              },
            },
          },
        }),
      );

      final BeakSkillReport report = install(
        resolve(['beak']),
        targets: [BeakSkillTarget.claude, BeakSkillTarget.agents],
      );

      expect(
        report.changes
            .where((c) => c.outcome == BeakSkillOutcome.ownedBySkillsCli)
            .map((c) => '${c.target.label}:${c.name}'),
        ['claude:beak-add-resource'],
      );
      expect(
        File(skillPath('.claude', 'beak-add-resource')).existsSync(),
        isFalse,
      );
      expect(File(skillPath('.claude', 'beak-upgrade')).existsSync(), isTrue);
      expect(
        File(skillPath('.agents', 'beak-add-resource')).existsSync(),
        isTrue,
        reason: 'the skills CLI installed it for claude only',
      );
    });

    test('an unreadable skills CLI config owns nothing', () {
      package('beak', {'beak-add-resource': null});
      write('app/.dart_skills/skills_config.json', 'not json');

      expect(outcomes(install(resolve(['beak']))), {
        BeakSkillOutcome.installed: ['beak-add-resource'],
      });
    });

    test('a dry run reports the plan and writes nothing', () {
      package('beak', {'beak-add-resource': null});

      final BeakSkillReport report = install(resolve(['beak']), dryRun: true);

      expect(outcomes(report), {
        BeakSkillOutcome.installed: ['beak-add-resource'],
      });
      expect(report.writes, isTrue);
      expect(Directory(p.join(project.path, '.claude')).existsSync(), isFalse);
    });
  });

  group('invalid skills', () {
    test('are skipped with a warning naming why', () {
      package('beak', {
        'beak-good': null,
        'other-skill': null,
        'beak-Upper': null,
        'beak-mismatch': 'beak-else',
      });
      write('pkgs/beak/skills/beak-no-front/SKILL.md', 'no front matter\n');
      write(
        'pkgs/beak/skills/beak-no-name/SKILL.md',
        '---\ndescription: x\n---\n',
      );
      write('pkgs/beak/skills/beak-unclosed/SKILL.md', '---\ndescription: x\n');
      Directory(
        p.join(tmp.path, 'pkgs/beak/skills/beak-empty'),
      ).createSync(recursive: true);
      write('pkgs/beak/skills/README.md', 'not a skill\n');

      final BeakSkillReport report = install(resolve(['beak']));

      expect(report.changes.map((c) => c.name), ['beak-good']);
      expect(report.warnings, hasLength(7));
      expect(
        report.warnings,
        containsAll([
          contains('other-skill'),
          contains('beak-Upper'),
          contains('beak-mismatch'),
          contains('beak-no-front'),
          contains('beak-no-name'),
          contains('beak-unclosed'),
          contains('beak-empty'),
        ]),
      );
    });

    test('a quoted front matter name is read', () {
      write('pkgs/beak/pubspec.yaml', 'name: beak\nversion: 0.9.0\n');
      write(
        'pkgs/beak/skills/beak-quoted/SKILL.md',
        '---\nname: "beak-quoted"\n---\nbody\n',
      );

      expect(install(resolve(['beak'])).changes.single.name, 'beak-quoted');
    });
  });

  group('pruning', () {
    test('removes an unedited Beak skill that is no longer shipped', () {
      package('beak', {'beak-add-resource': null, 'beak-old': null});
      final BeakPackageConfig config = resolve(['beak']);
      install(config);
      Directory(
        p.join(tmp.path, 'pkgs/beak/skills/beak-old'),
      ).deleteSync(recursive: true);

      final BeakSkillReport report = install(config);

      expect(outcomes(report), {
        BeakSkillOutcome.unchanged: ['beak-add-resource'],
        BeakSkillOutcome.removed: ['beak-old'],
      });
      expect(
        Directory(p.join(project.path, '.claude/skills/beak-old')).existsSync(),
        isFalse,
      );
    });

    test('keeps an edited one, and --force removes it', () {
      package('beak', {'beak-add-resource': null, 'beak-old': null});
      final BeakPackageConfig config = resolve(['beak']);
      install(config);
      File(skillPath('.claude', 'beak-old')).writeAsStringSync('mine\n');
      Directory(
        p.join(tmp.path, 'pkgs/beak/skills/beak-old'),
      ).deleteSync(recursive: true);

      expect(outcomes(install(config))[BeakSkillOutcome.keptEdited], [
        'beak-old',
      ]);
      expect(outcomes(install(config, force: true))[BeakSkillOutcome.removed], [
        'beak-old',
      ]);
    });

    test('never touches a folder Beak did not install', () {
      package('beak', {'beak-add-resource': null});
      write('app/.claude/skills/their-skill/SKILL.md', 'theirs\n');

      install(resolve(['beak']));

      expect(File(skillPath('.claude', 'their-skill')).existsSync(), isTrue);
    });

    test('a dry run reports the removal and keeps the folder', () {
      package('beak', {'beak-old': null});
      final BeakPackageConfig config = resolve(['beak']);
      install(config);
      package('beak', {'beak-add-resource': null});
      Directory(
        p.join(tmp.path, 'pkgs/beak/skills/beak-old'),
      ).deleteSync(recursive: true);

      final BeakSkillReport report = install(config, dryRun: true);

      expect(outcomes(report)[BeakSkillOutcome.removed], ['beak-old']);
      expect(File(skillPath('.claude', 'beak-old')).existsSync(), isTrue);
    });

    test('leaves a skill the skills CLI owns, even one Beak installed', () {
      package('beak', {'beak-add-resource': null});
      final BeakPackageConfig config = resolve(['beak']);
      install(config);
      Directory(
        p.join(tmp.path, 'pkgs/beak/skills/beak-add-resource'),
      ).deleteSync(recursive: true);
      package('beak', {'beak-upgrade': null});
      write(
        'app/.dart_skills/skills_config.json',
        jsonEncode({
          'installations': {
            'claude': {
              'beak': {
                'skills': [
                  {'name': 'beak-add-resource'},
                ],
              },
            },
          },
        }),
      );

      install(config);

      expect(
        File(skillPath('.claude', 'beak-add-resource')).existsSync(),
        isTrue,
      );
    });
  });

  group('uninstalling', () {
    test(
      'removes unedited Beak skills from every target, keeps edited ones',
      () {
        package('beak', {'beak-add-resource': null, 'beak-upgrade': null});
        install(resolve(['beak']), targets: BeakSkillTarget.values);
        File(skillPath('.agents', 'beak-upgrade')).writeAsStringSync('mine\n');
        write('app/.claude/skills/theirs/SKILL.md', 'theirs\n');

        final BeakSkillReport report = uninstallSkills(workspace: workspace());

        expect(
          report.changes
              .where((c) => c.outcome == BeakSkillOutcome.keptEdited)
              .map((c) => '${c.target.label}:${c.name}'),
          ['agents:beak-upgrade'],
        );
        expect(report.changes.where((c) => c.writes), hasLength(5));
        expect(
          File(skillPath('.claude', 'beak-add-resource')).existsSync(),
          isFalse,
        );
        expect(File(skillPath('.agents', 'beak-upgrade')).existsSync(), isTrue);
        expect(File(skillPath('.claude', 'theirs')).existsSync(), isTrue);
      },
    );

    test('a dry run removes nothing', () {
      package('beak', {'beak-add-resource': null});
      install(resolve(['beak']));

      final BeakSkillReport report = uninstallSkills(
        workspace: workspace(),
        dryRun: true,
      );

      expect(report.writes, isTrue);
      expect(
        File(skillPath('.claude', 'beak-add-resource')).existsSync(),
        isTrue,
      );
    });

    test('--force removes edited ones too', () {
      package('beak', {'beak-add-resource': null});
      install(resolve(['beak']));
      File(
        skillPath('.claude', 'beak-add-resource'),
      ).writeAsStringSync('mine\n');

      uninstallSkills(workspace: workspace(), force: true);

      expect(
        File(skillPath('.claude', 'beak-add-resource')).existsSync(),
        isFalse,
      );
    });
  });

  group('installedSkills', () {
    test('compares each installed skill with what is shipped', () {
      package('beak', {
        'beak-current': null,
        'beak-outdated': null,
        'beak-modified': null,
        'beak-orphan': null,
      });
      final BeakPackageConfig config = resolve(['beak']);
      install(config);
      package('beak', {'beak-outdated': null}, body: 'v2\n');
      write(
        'pkgs/beak/skills/beak-current/SKILL.md',
        '---\nname: beak-current\ndescription: A skill.\n---\nDo the thing.\n',
      );
      write(
        'pkgs/beak/skills/beak-modified/SKILL.md',
        '---\nname: beak-modified\ndescription: A skill.\n---\nDo the thing.\n',
      );
      File(skillPath('.claude', 'beak-modified')).writeAsStringSync('mine\n');
      Directory(
        p.join(tmp.path, 'pkgs/beak/skills/beak-orphan'),
      ).deleteSync(recursive: true);

      final Map<String, BeakInstalledSkillStatus> status = {
        for (final skill in installedSkills(workspace(), config))
          skill.name: skill.status,
      };

      expect(status, {
        'beak-current': BeakInstalledSkillStatus.current,
        'beak-outdated': BeakInstalledSkillStatus.outdated,
        'beak-modified': BeakInstalledSkillStatus.modified,
        'beak-orphan': BeakInstalledSkillStatus.orphaned,
      });
    });

    test('without a package config every unedited skill counts as current', () {
      package('beak', {'beak-a': null});
      install(resolve(['beak']));

      final List<BeakInstalledSkill> skills = installedSkills(
        workspace(),
        null,
      );

      expect(skills.single.status, BeakInstalledSkillStatus.current);
      expect(skills.single.package, 'beak');
      expect(skills.single.target, BeakSkillTarget.claude);
    });

    test('is empty when nothing was installed', () {
      expect(installedSkills(workspace(), null), isEmpty);
    });
  });

  group('targets', () {
    test('parse from their labels', () {
      expect(BeakSkillTarget.parse('claude'), BeakSkillTarget.claude);
      expect(BeakSkillTarget.parse(' cursor '), BeakSkillTarget.cursor);
      expect(BeakSkillTarget.parse('vim'), isNull);
    });

    test('default to .claude and .agents in a bare workspace', () {
      expect(defaultSkillTargets(workspace()), [
        BeakSkillTarget.claude,
        BeakSkillTarget.agents,
      ]);
    });

    test('default to the agent folders the workspace already has', () {
      Directory(p.join(project.path, '.cursor')).createSync();
      expect(defaultSkillTargets(workspace()), [BeakSkillTarget.cursor]);

      Directory(p.join(project.path, '.claude')).createSync();
      expect(defaultSkillTargets(workspace()), [
        BeakSkillTarget.claude,
        BeakSkillTarget.cursor,
      ]);
    });

    test('follow beak.yaml when it says, even to none', () {
      Directory(p.join(project.path, '.cursor')).createSync();
      expect(
        defaultSkillTargets(workspace(), configured: [BeakSkillTarget.agents]),
        [BeakSkillTarget.agents],
      );
      expect(defaultSkillTargets(workspace(), configured: []), isEmpty);
    });
  });
}
