import 'dart:io';

import 'package:beak_cli/src/agents/beak_agent_files.dart';
import 'package:beak_cli/src/agents/beak_docs_bundle.dart';
import 'package:beak_cli/src/agents/beak_managed_block.dart';
import 'package:beak_cli/src/agents/beak_skill_installer.dart';
import 'package:beak_cli/src/templates.dart';
import 'package:beak_cli/src/field_spec.dart';
import 'package:beak_cli/src/version.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../support/agents_fixture.dart';

void main() {
  late AgentsFixture fixture;

  setUp(() {
    fixture = AgentsFixture();
  });

  /// A resolved standalone project with a docs bundle.
  void standalone({String? beakYaml, String version = '0.9.0'}) {
    fixture
      ..writeProject(beakYaml: beakYaml)
      ..writeBundle(version: version)
      ..resolve(['beak_core']);
  }

  BeakAgentReport sync([BeakAgentOptions options = const BeakAgentOptions()]) =>
      syncAgentFiles(fixture.project, options: options)!;

  Map<String, BeakFileAction> actions(BeakAgentReport report) => {
    for (final change in report.files) change.label: change.action,
  };

  test('a project without a Beak dependency has nothing to write', () {
    fixture.writeProject(dependencies: const ['flutter']);

    expect(syncAgentFiles(fixture.project), isNull);
    expect(fixture.exists('AGENTS.md'), isFalse);
  });

  group('a standalone project', () {
    test('gets AGENTS.md with the block and a CLAUDE.md that imports it', () {
      standalone();
      final BeakAgentReport report = sync(
        const BeakAgentOptions(installSkills: false),
      );

      expect(actions(report), {
        'AGENTS.md': BeakFileAction.created,
        'CLAUDE.md': BeakFileAction.created,
      });
      expect(fixture.read('CLAUDE.md'), '@AGENTS.md\n');
      final String agents = fixture.read('AGENTS.md');
      expect(agents, startsWith('# App\n\n${BeakManagedBlock.begin}\n'));
      expect(agents, contains('This is a Beak 0.9.0 admin panel'));
      expect(agents, contains('`.dart_tool/beak/docs/ai-index.md`'));
      expect(agents, contains('`lib/resources/*/models/*.dart`'));
      expect(agents, contains('`lib/main.dart` is generated'));
      expect(
        agents,
        contains('Workflow skills: run `beak agents` to install them.'),
      );
      expect(agents, contains('## This project'));
      expect(report.docs, isA<BeakDocsReady>());
    });

    test('a second run writes nothing', () {
      standalone();
      sync();
      final File agents = File(p.join(fixture.project.path, 'AGENTS.md'))
        ..setLastModifiedSync(DateTime(2020));

      final BeakAgentReport again = sync();

      expect(actions(again), {'AGENTS.md': BeakFileAction.unchanged});
      expect(again.hasChanges, isFalse);
      expect(agents.lastModifiedSync(), DateTime(2020));
    });

    test('--check reports the changes and writes nothing, then finds none', () {
      standalone();

      final BeakAgentReport planned = sync(const BeakAgentOptions(check: true));

      expect(planned.hasChanges, isTrue);
      expect(fixture.exists('AGENTS.md'), isFalse);
      expect(fixture.exists('CLAUDE.md'), isFalse);
      expect(
        Directory(
          p.join(fixture.project.path, '.dart_tool/beak/docs'),
        ).existsSync(),
        isFalse,
      );
      expect(fixture.exists('.claude/skills'), isFalse);

      sync();

      expect(sync(const BeakAgentOptions(check: true)).hasChanges, isFalse);
    });

    test('--dry-run describes the plan in the future tense', () {
      standalone();

      final BeakAgentReport planned = sync(
        const BeakAgentOptions(dryRun: true),
      );

      expect(
        planned.describe(planned: true),
        containsAll(['  would create AGENTS.md', '  would create CLAUDE.md']),
      );
      expect(fixture.exists('AGENTS.md'), isFalse);
    });

    test('a run describes itself in the past tense', () {
      standalone();

      expect(
        sync(
          const BeakAgentOptions(installSkills: false),
        ).describe(planned: false),
        [
          '  agents   AGENTS.md created · CLAUDE.md created',
          '  docs     Beak 0.9.0',
        ],
      );
      expect(
        sync(
          const BeakAgentOptions(installSkills: false),
        ).describe(planned: false),
        ['  agents   up to date', '  docs     Beak 0.9.0'],
      );
    });

    test(
      'appends to an AGENTS.md the user wrote, keeping every byte of it',
      () {
        standalone();
        const String mine = '# Acme\n\nOur rules.\n\n\tKeep this.  \n';
        fixture.write('app/AGENTS.md', mine);

        final BeakAgentReport report = sync();

        expect(actions(report)['AGENTS.md'], BeakFileAction.appended);
        expect(
          fixture.read('AGENTS.md'),
          startsWith('$mine\n${BeakManagedBlock.begin}'),
        );
      },
    );

    test('replaces an out-of-date block and nothing around it', () {
      standalone(version: '0.9.0');
      fixture.write('app/AGENTS.md', '# Acme\n\nintro\n');
      sync();
      final String before = fixture.read('AGENTS.md');
      fixture.writeBundle(version: '0.9.1');

      final BeakAgentReport report = sync();

      expect(actions(report)['AGENTS.md'], BeakFileAction.updated);
      final String after = fixture.read('AGENTS.md');
      expect(after, contains('Beak 0.9.1 admin panel'));
      expect(after, startsWith('# Acme\n\nintro\n\n'));
      expect(after.replaceAll('0.9.1', '0.9.0'), before);
    });

    test('refuses damaged markers and leaves the file as it was', () {
      standalone();
      const String damaged =
          '# Acme\n\n<!-- BEGIN:beak-agent-rules -->\nno end\n';
      fixture.write('app/AGENTS.md', damaged);

      final BeakAgentReport report = sync();

      expect(report.isDamaged, isTrue);
      expect(report.problems.single, startsWith('AGENTS.md: '));
      expect(fixture.read('AGENTS.md'), damaged);
    });

    test('leaves a file that is not UTF-8 alone', () {
      standalone();
      File(
        p.join(fixture.project.path, 'AGENTS.md'),
      ).writeAsBytesSync([0xFF, 0xFE, 0x41]);

      final BeakAgentReport report = sync();

      expect(report.problems.single, contains('not valid UTF-8'));
      expect(
        File(p.join(fixture.project.path, 'AGENTS.md')).readAsBytesSync(),
        [0xFF, 0xFE, 0x41],
      );
    });

    test(
      'carries the block into a CLAUDE.md that does not import AGENTS.md',
      () {
        standalone();
        fixture.write('app/CLAUDE.md', '# My Claude notes\n');

        final BeakAgentReport report = sync();

        expect(actions(report)['CLAUDE.md'], BeakFileAction.appended);
        expect(
          fixture.read('CLAUDE.md'),
          startsWith('# My Claude notes\n\n<!-- BEGIN'),
        );
        expect(fixture.read('CLAUDE.md'), contains('This is a Beak 0.9.0'));
        expect(report.files.last.isClaude, isTrue);
      },
    );

    test('leaves a CLAUDE.md that already imports AGENTS.md', () {
      standalone();
      fixture.write('app/CLAUDE.md', '# Notes\n\n@AGENTS.md\n');

      final BeakAgentReport report = sync();

      expect(actions(report).containsKey('CLAUDE.md'), isFalse);
      expect(fixture.read('CLAUDE.md'), '# Notes\n\n@AGENTS.md\n');
    });

    test('leaves the Claude setup of a project that keeps it in .claude/', () {
      standalone();
      fixture.write('app/.claude/CLAUDE.md', '# Mine\n');

      sync();

      expect(fixture.exists('CLAUDE.md'), isFalse);
    });

    test('lists the schema folder the reader found', () {
      standalone();
      fixture.write(
        'app/lib/models/note.dart',
        generateSchemaClass('Note', BeakFieldSpec.parseList('title:string!')),
      );

      sync();

      expect(fixture.read('AGENTS.md'), contains('`lib/models/*.dart`'));
    });

    test('lists both folders when a project has both', () {
      standalone();
      fixture
        ..write(
          'app/lib/models/note.dart',
          generateSchemaClass('Note', BeakFieldSpec.parseList('title:string!')),
        )
        ..write(
          'app/lib/resources/tags/models/tag.dart',
          generateSchemaClass('Tag', BeakFieldSpec.parseList('label:string!')),
        );

      sync();

      expect(
        fixture.read('AGENTS.md'),
        contains('`lib/resources/*/models/*.dart`, `lib/models/*.dart`'),
      );
    });

    test(
      'says where lib/main.dart registers resources once it is authored',
      () {
        standalone();
        fixture.write('app/lib/main.dart', 'void main() {}\n');

        sync();

        final String agents = fixture.read('AGENTS.md');
        expect(
          agents,
          contains('`lib/main.dart` registers each `BeakResource`'),
        );
        expect(agents, isNot(contains('is generated')));
      },
    );
  });

  group('the settings', () {
    test('instructions: none writes no agent files, only docs', () {
      standalone(beakYaml: 'agents:\n  instructions: none\n');

      final BeakAgentReport report = sync();

      expect(report.files, isEmpty);
      expect(fixture.exists('AGENTS.md'), isFalse);
      expect(report.docs, isA<BeakDocsReady>());
    });

    test('--instructions overrides instructions: none', () {
      standalone(beakYaml: 'agents:\n  instructions: none\n');

      sync(const BeakAgentOptions(instructions: true));

      expect(fixture.exists('AGENTS.md'), isTrue);
    });

    test('--no-instructions writes none, whatever the settings', () {
      standalone();

      expect(sync(const BeakAgentOptions(instructions: false)).files, isEmpty);
    });

    test('docs: false leaves the docs out', () {
      standalone(beakYaml: 'agents:\n  docs: false\n');

      final BeakAgentReport report = sync();

      expect(report.docs, isNull);
      expect(
        Directory(
          p.join(fixture.project.path, '.dart_tool/beak/docs'),
        ).existsSync(),
        isFalse,
      );
      expect(fixture.exists('AGENTS.md'), isTrue);
    });

    test('--docs overrides docs: false', () {
      standalone(beakYaml: 'agents:\n  docs: false\n');

      expect(
        sync(const BeakAgentOptions(docs: true)).docs,
        isA<BeakDocsReady>(),
      );
    });

    test('--no-docs leaves the docs out', () {
      standalone();

      expect(sync(const BeakAgentOptions(docs: false)).docs, isNull);
    });
  });

  group('without pub get', () {
    test(
      'the block is still written, from the CLI\'s templates and version',
      () {
        fixture.writeProject();

        final BeakAgentReport report = sync();

        expect(report.docs, isA<BeakDocsUnavailable>());
        expect(
          fixture.read('AGENTS.md'),
          contains('Beak $beakCliVersion admin panel'),
        );
        expect(
          report.describe(planned: false),
          contains(startsWith('  docs     not materialized: ')),
        );
        expect(report.notes, contains(contains('skills   not installed')));
      },
    );
  });

  group('the templates', () {
    test('come from the resolved bundle when it has them', () {
      fixture
        ..writeProject()
        ..writeBundle(
          templates: {
            for (final name in [
              'standalone',
              'embedded',
              'serverpod-admin',
              'workspace-root',
            ])
              name:
                  '${BeakManagedBlock.begin}\nCUSTOM {{version}} for $name\n${BeakManagedBlock.end}\n',
          },
        )
        ..resolve(['beak_core']);

      sync();

      expect(
        fixture.read('AGENTS.md'),
        contains('CUSTOM 0.9.0 for standalone'),
      );
    });

    test('fall back to the CLI\'s when the bundle has none', () {
      fixture
        ..writeProject()
        ..writeBundle(templates: const {})
        ..resolve(['beak_core']);

      sync();

      expect(
        fixture.read('AGENTS.md'),
        contains('This is a Beak 0.9.0 admin panel'),
      );
    });

    test(
      'fall back, with a note, when the bundle asks for something unknown',
      () {
        fixture
          ..writeProject()
          ..writeBundle(
            templates: {
              'standalone':
                  '${BeakManagedBlock.begin}\n{{from_the_future}}\n${BeakManagedBlock.end}\n',
            },
          )
          ..resolve(['beak_core']);

        final BeakAgentReport report = sync();

        expect(
          fixture.read('AGENTS.md'),
          contains('This is a Beak 0.9.0 admin panel'),
        );
        expect(report.notes.single, contains('from_the_future'));
      },
    );

    test('are read from the workspace copy before the CLI\'s', () {
      fixture
        ..writeProject()
        ..write(
          'app/.dart_tool/beak/docs/_agents/blocks/standalone.md',
          '${BeakManagedBlock.begin}\nCOPY {{version}}\n${BeakManagedBlock.end}\n',
        );

      sync();

      expect(fixture.read('AGENTS.md'), contains('COPY $beakCliVersion'));
    });
  });

  group('kinds', () {
    test('an embedded app names its own entrypoint', () {
      fixture
        ..writeProject(beakYaml: 'panel:\n  entrypoint: lib/admin_main.dart\n')
        ..writeBundle()
        ..resolve(['beak_core']);

      final BeakAgentReport report = sync();

      expect(report.kind, isNotNull);
      final String agents = fixture.read('AGENTS.md');
      expect(agents, contains('This app contains a Beak 0.9.0 admin panel'));
      expect(agents, contains('flutter run -t lib/admin_main.dart'));
    });

    test(
      'a Serverpod admin names the server, the client and the schema package',
      () {
        fixture
          ..writeProject(
            name: 'acme_admin',
            dependencies: const [
              'beak',
              'beak_serverpod_flutter',
              'acme_client',
              'acme_beak',
            ],
          )
          ..writeBundle()
          ..resolve(['beak_core']);

        sync();

        final String agents = fixture.read('AGENTS.md');
        expect(agents, contains('# Acme Admin'));
        expect(
          agents,
          contains('Beak 0.9.0 admin panel for the `acme_server`'),
        );
        expect(agents, contains('`acme_client`'));
        expect(agents, contains('in `acme_beak`'));
        expect(agents, contains('run `beak prepare` in `acme_beak`'));
      },
    );

    test(
      'a Serverpod admin without client and schema dependencies uses the naming convention',
      () {
        fixture
          ..writeProject(
            name: 'shop_admin',
            dependencies: const ['beak_serverpod_flutter'],
          )
          ..writeBundle()
          ..resolve(['beak_core']);

        sync();

        expect(fixture.read('AGENTS.md'), contains('`shop_client`'));
        expect(fixture.read('AGENTS.md'), contains('`shop_beak`'));
      },
    );
  });

  group('in a pub workspace', () {
    void member({
      String? beakYaml,
      List<String> dependencies = const ['beak'],
    }) {
      fixture
        ..write('pubspec.yaml', 'name: root\nworkspace:\n  - app\n')
        ..writeProject(
          beakYaml: beakYaml,
          member: true,
          dependencies: dependencies,
        )
        ..writeBundle()
        ..resolve(['beak_core'], workspaceRoot: '.');
    }

    test('the docs and the pointer go to the workspace root', () {
      member();

      final BeakAgentReport report = sync();

      expect(actions(report), {
        'AGENTS.md': BeakFileAction.created,
        'CLAUDE.md': BeakFileAction.created,
        '../AGENTS.md': BeakFileAction.created,
        '../CLAUDE.md': BeakFileAction.created,
      });
      expect(
        File(p.join(fixture.tmp.path, 'AGENTS.md')).readAsStringSync(),
        allOf(
          contains('## Admin panel (Beak)'),
          contains('`app/` is a Beak 0.9.0 admin panel'),
          contains('`app/AGENTS.md`'),
        ),
      );
      expect(
        fixture.read('AGENTS.md'),
        contains('`../.dart_tool/beak/docs/ai-index.md`'),
      );
      expect(
        Directory(
          p.join(fixture.tmp.path, '.dart_tool/beak/docs'),
        ).existsSync(),
        isTrue,
      );
      expect(fixture.exists('.dart_tool/beak'), isFalse);
    });

    test('a Serverpod admin adds the server to the root pointer', () {
      member(dependencies: const ['beak_serverpod_flutter', 'app_client']);

      sync();

      expect(
        File(p.join(fixture.tmp.path, 'AGENTS.md')).readAsStringSync(),
        contains(
          'starts in `app_server`'.replaceAll('starts in', 'shows starts in'),
        ),
      );
    });

    test('instructions: package leaves the workspace root alone', () {
      member(beakYaml: 'agents:\n  instructions: package\n');

      final BeakAgentReport report = sync();

      expect(actions(report).keys, ['AGENTS.md', 'CLAUDE.md']);
      expect(File(p.join(fixture.tmp.path, 'AGENTS.md')).existsSync(), isFalse);
    });

    test('keeps what the workspace root\'s AGENTS.md already says', () {
      member();
      File(
        p.join(fixture.tmp.path, 'AGENTS.md'),
      ).writeAsStringSync('# Serverpod\n\nNEVER start the server.\n');

      sync();

      expect(
        File(p.join(fixture.tmp.path, 'AGENTS.md')).readAsStringSync(),
        startsWith('# Serverpod\n\nNEVER start the server.\n\n<!-- BEGIN'),
      );
    });

    test(
      'a workspace root CLAUDE.md that does not import AGENTS.md carries the pointer',
      () {
        member();
        File(
          p.join(fixture.tmp.path, 'CLAUDE.md'),
        ).writeAsStringSync('# Root\n');

        sync();

        expect(
          File(p.join(fixture.tmp.path, 'CLAUDE.md')).readAsStringSync(),
          allOf(
            startsWith('# Root\n\n<!-- BEGIN'),
            contains('`app/AGENTS.md`'),
          ),
        );
      },
    );
  });

  group('skills', () {
    test('are installed, and listed in the block', () {
      standalone();
      fixture
        ..writeSkill('beak', 'beak-add-resource')
        ..resolve(['beak_core', 'beak']);

      final BeakAgentReport report = sync();

      expect(report.skills!.changes.map((c) => c.name), [
        'beak-add-resource',
        'beak-add-resource',
      ]);
      expect(
        fixture.exists('.claude/skills/beak-add-resource/SKILL.md'),
        isTrue,
      );
      expect(
        fixture.exists('.agents/skills/beak-add-resource/SKILL.md'),
        isTrue,
      );
      expect(
        fixture.read('AGENTS.md'),
        contains('Workflow skills: `beak-add-resource`.'),
      );
      expect(
        report.describe(planned: false),
        contains('  skills   .claude/skills: 1 installed'),
      );
    });

    test('are left out by a run that does not install them', () {
      standalone();
      fixture
        ..writeSkill('beak', 'beak-add-resource')
        ..resolve(['beak_core', 'beak']);

      final BeakAgentReport report = sync(
        const BeakAgentOptions(installSkills: false),
      );

      expect(report.skills, isNull);
      expect(fixture.exists('.claude/skills'), isFalse);
      expect(
        fixture.read('AGENTS.md'),
        contains('run `beak agents` to install them'),
      );
    });

    test('a plan of the install lists the same skills the run then writes', () {
      standalone();
      fixture
        ..writeSkill('beak', 'beak-add-resource')
        ..resolve(['beak_core', 'beak']);

      sync(const BeakAgentOptions(check: true));
      sync();

      expect(sync(const BeakAgentOptions(check: true)).hasChanges, isFalse);
    });

    test('a run that does not install leaves the list as installed', () {
      standalone();
      fixture
        ..writeSkill('beak', 'beak-add-resource')
        ..resolve(['beak_core', 'beak']);
      sync();

      final BeakAgentReport report = sync(
        const BeakAgentOptions(installSkills: false),
      );

      expect(report.hasChanges, isFalse);
    });

    test('--skills picks the targets, and beak.yaml the rest', () {
      standalone(beakYaml: 'agents:\n  skills: [cursor]\n');
      fixture
        ..writeSkill('beak', 'beak-add-resource')
        ..resolve(['beak_core', 'beak']);

      sync();

      expect(
        fixture.exists('.cursor/skills/beak-add-resource/SKILL.md'),
        isTrue,
      );
      expect(fixture.exists('.claude/skills'), isFalse);

      sync(const BeakAgentOptions(skills: [BeakSkillTarget.claude]));

      expect(
        fixture.exists('.claude/skills/beak-add-resource/SKILL.md'),
        isTrue,
      );
    });

    test('an empty target list installs none', () {
      standalone();
      fixture
        ..writeSkill('beak', 'beak-add-resource')
        ..resolve(['beak_core', 'beak']);

      expect(sync(const BeakAgentOptions(skills: [])).skills, isNull);
    });
  });

  group('--print', () {
    test('renders the block and writes nothing', () {
      standalone();

      final BeakAgentReport report = sync(const BeakAgentOptions(print: true));

      expect(report.printedBlock, startsWith(BeakManagedBlock.begin));
      expect(report.printedBlock, endsWith(BeakManagedBlock.end));
      expect(report.files, isEmpty);
      expect(fixture.exists('AGENTS.md'), isFalse);
      expect(
        Directory(
          p.join(fixture.project.path, '.dart_tool/beak/docs'),
        ).existsSync(),
        isFalse,
      );
    });

    test('works for a project that opted out of instructions', () {
      standalone(beakYaml: 'agents:\n  instructions: none\n');

      expect(
        sync(const BeakAgentOptions(print: true)).printedBlock,
        contains('Beak 0.9.0'),
      );
    });
  });

  group('--remove', () {
    test(
      'strips the block, deletes the import-only CLAUDE.md, uninstalls skills',
      () {
        standalone();
        fixture
          ..writeSkill('beak', 'beak-add-resource')
          ..resolve(['beak_core', 'beak']);
        fixture.write('app/AGENTS.md', '# Mine\n\nKeep me.\n');
        sync();

        final BeakAgentReport report = sync(
          const BeakAgentOptions(remove: true),
        );

        expect(actions(report), {
          'CLAUDE.md': BeakFileAction.deleted,
          'AGENTS.md': BeakFileAction.stripped,
        });
        expect(fixture.exists('CLAUDE.md'), isFalse);
        expect(fixture.read('AGENTS.md'), '# Mine\n\nKeep me.\n');
        expect(fixture.exists('.claude/skills/beak-add-resource'), isFalse);
      },
    );

    test(
      'a file Beak created keeps its title and the section for the project',
      () {
        standalone();
        sync();

        sync(const BeakAgentOptions(remove: true));

        expect(
          fixture.read('AGENTS.md'),
          startsWith('# App\n\n## This project'),
        );
      },
    );

    test('deletes an AGENTS.md that held nothing but the block', () {
      standalone();
      fixture.write(
        'app/AGENTS.md',
        '${BeakManagedBlock.begin}\nx\n${BeakManagedBlock.end}\n',
      );

      final BeakAgentReport report = sync(const BeakAgentOptions(remove: true));

      expect(actions(report)['AGENTS.md'], BeakFileAction.deleted);
      expect(fixture.exists('AGENTS.md'), isFalse);
    });

    test(
      'strips a block carried in a CLAUDE.md that does more than import',
      () {
        standalone();
        fixture.write('app/CLAUDE.md', '# Notes\n');
        sync();

        sync(const BeakAgentOptions(remove: true));

        expect(fixture.read('CLAUDE.md'), '# Notes\n');
      },
    );

    test('leaves a symlinked CLAUDE.md alone', () {
      standalone();
      fixture.write('app/AGENTS.md', '# Mine\n');
      Link(p.join(fixture.project.path, 'CLAUDE.md')).createSync('AGENTS.md');
      sync();

      final BeakAgentReport report = sync(const BeakAgentOptions(remove: true));

      expect(
        FileSystemEntity.isLinkSync(p.join(fixture.project.path, 'CLAUDE.md')),
        isTrue,
      );
      expect(actions(report)['AGENTS.md'], BeakFileAction.stripped);
    }, testOn: '!windows');

    test('needs no Beak dependency', () {
      fixture.writeProject(dependencies: const ['flutter']);
      fixture.write(
        'app/AGENTS.md',
        '# X\n\n${BeakManagedBlock.begin}\nx\n${BeakManagedBlock.end}\n',
      );

      final BeakAgentReport report = sync(const BeakAgentOptions(remove: true));

      expect(report.kind, isNull);
      expect(actions(report)['AGENTS.md'], BeakFileAction.stripped);
    });

    test('refuses damaged markers', () {
      standalone();
      fixture.write('app/AGENTS.md', '${BeakManagedBlock.begin}\n');

      expect(sync(const BeakAgentOptions(remove: true)).isDamaged, isTrue);
    });

    test('a plan removes nothing', () {
      standalone();
      sync();

      final BeakAgentReport planned = sync(
        const BeakAgentOptions(remove: true, check: true),
      );

      expect(planned.hasChanges, isTrue);
      expect(fixture.exists('CLAUDE.md'), isTrue);
    });

    test('also strips the workspace root pointer', () {
      fixture
        ..write('pubspec.yaml', 'name: root\nworkspace:\n  - app\n')
        ..writeProject(member: true)
        ..writeBundle()
        ..resolve(['beak_core'], workspaceRoot: '.');
      sync();

      sync(const BeakAgentOptions(remove: true));

      expect(
        File(p.join(fixture.tmp.path, 'AGENTS.md')).readAsStringSync(),
        isNot(contains('BEGIN:beak-agent-rules')),
      );
      expect(File(p.join(fixture.tmp.path, 'CLAUDE.md')).existsSync(), isFalse);
    });
  });

  group('the report', () {
    test('names refused files and notes last', () {
      standalone();
      fixture.write('app/AGENTS.md', '${BeakManagedBlock.begin}\n');

      final List<String> lines = sync().describe(planned: false);

      expect(lines.any((line) => line.startsWith('  ! AGENTS.md: ')), isTrue);
    });

    test('summarises skills per target, in a plan too', () {
      standalone();
      fixture
        ..writeSkill('beak', 'beak-add-resource')
        ..writeSkill('beak', 'beak-upgrade')
        ..resolve(['beak_core', 'beak']);

      expect(
        sync(const BeakAgentOptions(check: true)).describe(planned: true),
        containsAll([
          '  skills   .claude/skills: 2 to be installed',
          '  skills   .agents/skills: 2 to be installed',
        ]),
      );
      sync();
      fixture.write('app/.claude/skills/beak-upgrade/SKILL.md', 'edited\n');
      expect(
        sync().describe(planned: false),
        contains('  skills   .claude/skills: 1 edited, kept, 1 up to date'),
      );
    });

    test('says a pending docs copy would be made', () {
      standalone();

      expect(
        sync(const BeakAgentOptions(check: true)).describe(planned: true),
        contains(startsWith('  would copy the docs of Beak 0.9.0 to ')),
      );
    });
  });
}
