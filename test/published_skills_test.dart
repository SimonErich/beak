import 'dart:io';

import 'package:test/test.dart';

import '../tool/published_skills.dart';

/// A `SKILL.md` with the given front matter values and [body] lines.
String skill({
  String name = 'beak-add-resource',
  String? description = 'Adds a resource.',
  List<String> body = const ['# Add a resource', '', 'Do the steps.'],
}) =>
    '---\n'
    'name: $name\n'
    '${description == null ? '' : 'description: $description\n'}'
    '---\n'
    '\n'
    '${body.join('\n')}\n';

/// A repository holding [files], and `docs/models/fields.md`.
///
/// It has the `beak` CLI's runner too, registering `prepare` and
/// `make:migration`, one command class in the runner's own file and one in
/// another.
Directory makeRepo(Map<String, String> files) {
  final Directory root = Directory.systemTemp.createTempSync('skills_');
  addTearDown(() => root.deleteSync(recursive: true));
  final Map<String, String> all = {
    'docs/models/fields.md': '# Fields\n',
    'packages/beak_cli/lib/src/cli_runner.dart':
        'CommandRunner<int> createBeakRunner(BeakCliEnvironment environment) =>\n'
        '    _BeakCommandRunner(environment)\n'
        '      ..addCommand(PrepareCommand(environment))\n'
        '      ..addCommand(MakeMigrationCommand(environment));\n'
        '\n'
        'final class MakeMigrationCommand extends Command<int> {\n'
        "  String get name => 'make:migration';\n"
        '}\n',
    'packages/beak_cli/lib/src/commands/prepare_command.dart':
        'final class PrepareCommand extends Command<int> {\n'
        "  @override\n  String get name => 'prepare';\n"
        '}\n',
    ...files,
  };
  for (final entry in all.entries) {
    File('${root.path}/${entry.key}')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(entry.value);
  }
  return root;
}

/// The problem messages of a repo with the skill at
/// `packages/<package>/skills/<folder>/SKILL.md`.
List<String> messagesOf(
  String content, {
  String package = 'beak',
  String folder = 'beak-add-resource',
  Map<String, String> more = const {},
}) => [
  for (final problem in checkPublishedSkills(
    makeRepo({'packages/$package/skills/$folder/SKILL.md': content, ...more}),
  ))
    problem.message,
];

void main() {
  test("the repository's own skills follow the publishing rules", () {
    expect(checkPublishedSkills(Directory.current), isEmpty);
  });

  test('the real runner registers the commands skills may name', () {
    expect(
      registeredCommands(Directory.current),
      containsAll([
        'create',
        'prepare',
        'doctor',
        'migrate',
        'make:resource',
        'make:migration',
      ]),
    );
  });

  test('a repository without skills passes', () {
    expect(checkPublishedSkills(makeRepo({})), isEmpty);
  });

  test('a valid skill passes, mentions of real commands and pages included', () {
    expect(
      messagesOf(
        skill(
          body: [
            '# Add a resource',
            '',
            'Read `.dart_tool/beak/docs/models/fields.md#types` and `docs/models/fields.md`.',
            'Run `beak prepare` then `beak make:migration Name --from-drift`.',
            '',
            '```sh',
            r'$ beak prepare',
            '```',
          ],
        ),
      ),
      isEmpty,
    );
  });

  test('the bundle root files count as docs pages under .dart_tool', () {
    expect(
      messagesOf(
        skill(
          body: [
            'Start at `.dart_tool/beak/docs/ai-index.md`, read '
                '`.dart_tool/beak/docs/changelog.md`.',
          ],
        ),
      ),
      isEmpty,
    );
  });

  test('a skill for another package needs that package prefix', () {
    expect(
      messagesOf(
        skill(name: 'beak-frontend-build-screens'),
        package: 'beak_frontend',
        folder: 'beak-frontend-build-screens',
      ),
      isEmpty,
    );
    expect(
      messagesOf(
        skill(name: 'beak-add-resource'),
        package: 'beak_frontend',
        folder: 'beak-add-resource',
      ),
      [
        'the name "beak-add-resource" must start with "beak-frontend-" (the package name)',
      ],
    );
  });

  test('the name must equal the folder', () {
    expect(messagesOf(skill(name: 'beak-other'), folder: 'beak-add-resource'), [
      'the name "beak-other" differs from the folder "beak-add-resource"',
    ]);
  });

  test('the name must be lowercase letters, digits and hyphens', () {
    expect(
      messagesOf(skill(name: 'beak-Add_Resource'), folder: 'beak-Add_Resource'),
      ['the name "beak-Add_Resource" must match [a-z0-9-]+'],
    );
  });

  test('the name is at most 64 characters', () {
    final String name = 'beak-${'a' * 60}';
    expect(messagesOf(skill(name: name), folder: name), [
      'the name is ${name.length} characters, over 64',
    ]);
  });

  test('the description is required and at most 1024 characters', () {
    expect(messagesOf(skill(description: null)), [
      'front matter has no description',
    ]);
    expect(messagesOf(skill(description: 'x' * 1025)), [
      'the description is 1025 characters, over 1024',
    ]);
    expect(messagesOf(skill(description: 'x' * 1024)), isEmpty);
  });

  test('front matter is required', () {
    expect(messagesOf('# Just a body\n'), [
      'has no front matter (needs name and description)',
    ]);
  });

  test('the body is at most 150 lines, references excepted', () {
    List<String> body(int lines) => [
      for (var i = 0; i < lines; i += 1) 'Step $i.',
    ];
    expect(messagesOf(skill(body: body(150))), isEmpty);
    expect(messagesOf(skill(body: body(151))), [
      'the body is 151 lines, over 150; move detail to references/',
    ]);
    expect(
      messagesOf(
        skill(),
        more: {
          'packages/beak/skills/beak-add-resource/references/detail.md': body(
            400,
          ).join('\n'),
        },
      ),
      isEmpty,
    );
  });

  test('a beak command the CLI does not register is a problem', () {
    expect(
      messagesOf(
        skill(
          body: [
            'Run `beak sync-everything --now` and `beak prepare`.',
            '',
            '```sh',
            'beak launch',
            '```',
          ],
        ),
      ),
      [
        'runs `beak launch`, which createBeakRunner does not register',
        'runs `beak sync-everything`, which createBeakRunner does not register',
      ],
    );
  });

  test('flags, other tools and prose are not commands', () {
    expect(
      messagesOf(
        skill(
          body: [
            'Run `beak --version`, `beak.yaml`, `dart run beak_cli` and beak docs.',
          ],
        ),
      ),
      isEmpty,
    );
  });

  test('a docs page that does not exist is a problem', () {
    expect(
      messagesOf(
        skill(
          body: [
            'Read `docs/models/gone.md` and `.dart_tool/beak/docs/models/gone.md`, '
                'not `docs/ai-index.md`.',
          ],
        ),
      ),
      [
        'names `.dart_tool/beak/docs/models/gone.md`, which is not a docs page',
        'names `docs/ai-index.md`, which is not a docs page',
        'names `docs/models/gone.md`, which is not a docs page',
      ],
    );
  });

  test('references are checked for commands and pages as well', () {
    expect(
      messagesOf(
        skill(),
        more: {
          'packages/beak/skills/beak-add-resource/references/detail.md':
              'Run `beak nonsense`, read `docs/nope.md`.\n',
        },
      ),
      [
        'runs `beak nonsense`, which createBeakRunner does not register',
        'names `docs/nope.md`, which is not a docs page',
      ],
    );
  });

  test('command mentions cannot be checked without the CLI source', () {
    final Directory root = makeRepo({
      'packages/beak/skills/beak-add-resource/SKILL.md': skill(
        body: ['Run `beak prepare`.'],
      ),
    });
    File('${root.path}/packages/beak_cli/lib/src/cli_runner.dart').deleteSync();
    expect(
      [for (final problem in checkPublishedSkills(root)) problem.message],
      [
        'mentions `beak` commands, but createBeakRunner cannot be read from '
            'packages/beak_cli/lib/src/cli_runner.dart',
      ],
    );
  });

  test('problems name the skill file relative to the repo', () {
    final Directory root = makeRepo({
      'packages/beak/skills/beak-add-resource/SKILL.md': skill(
        description: null,
      ),
    });
    expect(
      checkPublishedSkills(root).single.toString(),
      'packages/beak/skills/beak-add-resource/SKILL.md: '
      'front matter has no description',
    );
  });
}
