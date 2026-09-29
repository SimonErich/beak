import 'package:test/test.dart';

import '../tool/check_docs.dart';

/// The repository file the quotation fences below claim to quote.
const String sourcePath = 'packages/beak_core/lib/src/columns/beak_column.dart';

/// What [sourcePath] holds, doc comments and blank lines included.
///
/// Its first line carries an em-dash, the way Beak's real doc comments do, so
/// a fence quoting it shows the ban stopping at the fence.
///
/// Its three symbols cover the three states a section can be in. `BeakColumn`
/// is marked and a page can include it, `BeakSpan` is unmarked and a page can
/// only quote it, and `BeakStyle` is opened and never closed.
const String sourceFile = '''
/// A column, declared once — read by six surfaces.
// --8<-- [start:BeakColumn]
final class BeakColumn {
  const BeakColumn({required this.name});

  /// The name of the underlying database column.
  final String name;
}
// --8<-- [end:BeakColumn]

/// Where a column sits in a grid.
final class BeakSpan {
  const BeakSpan({this.columns = 1});

  /// Number of grid columns covered.
  final int columns;
}

/// How a column paints itself.
// --8<-- [start:BeakStyle]
final class BeakStyle {
  const BeakStyle();
}
''';

/// A reader that knows one file, so any other path is a missing one.
String? readOnlySource(String path) => path == sourcePath ? sourceFile : null;

/// [body] wrapped in the front matter and footer every page needs, so a test
/// sees only the problem it is about.
///
/// The wrapper is 7 lines, so body line 1 is page line 8.
String page(String body) =>
    '---\n'
    'title: A test page\n'
    'description: One sentence a search result can show.\n'
    '---\n'
    '\n'
    '# A test page\n'
    '\n'
    '$body\n'
    '\n'
    '## Continue reading\n'
    '\n'
    '- [Column types](column-types.md) every built-in column.\n';

/// The problems [body] produces as the only content of a page.
List<DocProblem> problemsIn(String body) =>
    checkPage('docs/test/page.md', page(body), readFile: readOnlySource);

/// The messages of [problems], for a readable expectation.
List<String> messagesOf(List<DocProblem> problems) => [
  for (final problem in problems) problem.message,
];

void main() {
  group('page structure', () {
    test('a wrapped page is clean, so every other test starts from zero', () {
      expect(problemsIn('Plain prose about a column.'), isEmpty);
    });

    test('reports missing front matter and a missing footer', () {
      final problems = checkPage(
        'docs/test/page.md',
        '# A test page\n\nProse.\n',
        readFile: readOnlySource,
      );
      expect(
        messagesOf(problems),
        containsAll(<Matcher>[
          contains('no front matter'),
          contains('Continue reading'),
        ]),
      );
    });

    test('reports front matter without a description', () {
      final problems = checkPage(
        'docs/test/page.md',
        '---\ntitle: A test page\n---\n\n## Continue reading\n',
        readFile: readOnlySource,
      );
      expect(messagesOf(problems), ['front matter has no "description:"']);
    });
  });

  group('fence titles and snippet includes', () {
    test('reports a fence titled with a file that is not there', () {
      final problems = problemsIn(
        '```dart title="packages/beak_core/lib/src/columns/gone.dart"\n'
        'final class Gone {}\n'
        '```',
      );
      // One report, not two: the quotation check leaves a missing file alone.
      expect(messagesOf(problems), [
        'fence titled "packages/beak_core/lib/src/columns/gone.dart", '
            'which does not exist',
      ]);
    });

    test('names the apps/ to examples/ move rather than the missing file', () {
      final problems = problemsIn(
        '```dart title="apps/retired_example/lib/main.dart"\n'
        'void main() {}\n'
        '```',
      );
      expect(messagesOf(problems), [
        'fence titled "apps/retired_example/lib/main.dart" — apps/ is now '
            'examples/',
      ]);
    });

    test('leaves a title that names no repository path alone', () {
      // A generated project's own file, which this repository does not hold.
      expect(
        problemsIn('```dart title="lib/main.dart"\nvoid main() {}\n```'),
        isEmpty,
      );
    });

    test('reports a snippet include pointing at a moved file', () {
      final problems = problemsIn('--8<-- "packages/beak_core/lib/moved.dart"');
      expect(messagesOf(problems), [
        'snippet includes "packages/beak_core/lib/moved.dart", which does '
            'not exist',
      ]);
    });

    test('resolves a snippet include with a section marker', () {
      expect(problemsIn('--8<-- "$sourcePath:BeakColumn"'), isEmpty);
    });

    test(
      'accepts a whole-file include and a line range, which mark nothing',
      () {
        expect(problemsIn('--8<-- "$sourcePath"'), isEmpty);
        expect(problemsIn('--8<-- "$sourcePath:3:8"'), isEmpty);
      },
    );

    test('reports an include naming a section the file no longer marks', () {
      // How an include rots: the symbol is renamed or deleted and its markers
      // go with it, and the page publishes an empty block.
      final problems = problemsIn('--8<-- "$sourcePath:BeakSpan"');
      expect(problems, hasLength(1));
      expect(
        problems.single.message,
        contains('snippet includes section "BeakSpan" of "$sourcePath"'),
      );
      expect(problems.single.message, contains('[start:BeakSpan]'));
    });

    test('reports a section that is opened and never closed', () {
      // The quiet half of the same rot: mkdocs reads an unclosed section to
      // the end of the file, so the page publishes the rest of it.
      final problems = problemsIn('--8<-- "$sourcePath:BeakStyle"');
      expect(problems, hasLength(1));
      expect(problems.single.message, contains('never closes it'));
      expect(problems.single.message, contains('[end:BeakStyle]'));
    });

    test('leaves a fence whose body is an include alone', () {
      // mkdocs substitutes the file at build time, so the page holds a
      // directive and not a copy. Checking it as a quotation would report the
      // directive as a line that is not in the file.
      expect(
        problemsIn(
          '```dart title="$sourcePath"\n'
          '--8<-- "$sourcePath:BeakColumn"\n'
          '```',
        ),
        isEmpty,
      );
    });

    test('still checks a fence mixing an include with hand-written lines', () {
      final problems = problemsIn(
        '```dart title="$sourcePath"\n'
        '--8<-- "$sourcePath:BeakColumn"\n'
        'final int precision;\n'
        '```',
      );
      expect(problems, hasLength(1));
      expect(problems.single.message, contains('does not quote it'));
    });
  });

  group('quotation fences', () {
    test('accepts a faithful quotation, blank lines and indent aside', () {
      expect(
        problemsIn(
          '```dart title="$sourcePath"\n'
          '/// A column, declared once — read by six surfaces.\n'
          'final class BeakColumn {\n'
          '  const BeakColumn({required this.name});\n'
          '  /// The name of the underlying database column.\n'
          '  final String name;\n'
          '}\n'
          '```',
        ),
        isEmpty,
      );
    });

    test('reads past a section marker, which mkdocs strips too', () {
      // A page quoting two neighbouring symbols straddles the markers another
      // page put around the first one. It quotes the code the reader sees, so
      // it must not have to paste a build directive to stay faithful.
      expect(
        problemsIn(
          '```dart title="$sourcePath"\n'
          'final class BeakColumn {\n'
          '  const BeakColumn({required this.name});\n'
          '  final String name;\n'
          '}\n'
          '\n'
          '/// Where a column sits in a grid.\n'
          'final class BeakSpan {\n'
          '  const BeakSpan({this.columns = 1});\n'
          '  final int columns;\n'
          '}\n'
          '```',
        ),
        isEmpty,
      );
    });

    test('accepts a quotation that leaves the source comments out', () {
      expect(
        problemsIn(
          '```dart title="$sourcePath"\n'
          'final class BeakColumn {\n'
          '  const BeakColumn({required this.name});\n'
          '  final String name;\n'
          '}\n'
          '```',
        ),
        isEmpty,
      );
    });

    test('reports a quotation that reorders the members', () {
      final problems = problemsIn(
        '```dart title="$sourcePath"\n'
        'final class BeakColumn {\n'
        '  final String name;\n'
        '  const BeakColumn({required this.name});\n'
        '}\n'
        '```',
      );
      expect(problems, hasLength(1));
      expect(problems.single.message, contains('not together'));
      expect(problems.single.message, contains('reorders or interrupts'));
    });

    test('names the line that is nowhere in the file', () {
      final problems = problemsIn(
        '```dart title="$sourcePath"\n'
        'final class BeakColumn {\n'
        '  final int precision;\n'
        '}\n'
        '```',
      );
      expect(problems, hasLength(1));
      expect(
        problems.single.message,
        contains('"final int precision;" is not in that file'),
      );
    });

    test('checks each side of an elision marker on its own', () {
      expect(
        problemsIn(
          '```dart title="$sourcePath"\n'
          'final class BeakColumn {\n'
          '  const BeakColumn({required this.name});\n'
          '  // ...\n'
          '  final String name;\n'
          '}\n'
          '```',
        ),
        isEmpty,
      );
    });

    test('still checks the run after an elision marker', () {
      final problems = problemsIn(
        '```dart title="$sourcePath"\n'
        'final class BeakColumn {\n'
        '  const BeakColumn({required this.name});\n'
        '  // ...\n'
        '  final int precision;\n'
        '  final String unit;\n'
        '}\n'
        '```',
      );
      expect(problems, hasLength(1));
      expect(
        problems.single.message,
        contains('"final int precision;" is not in that file'),
      );
    });

    test('leaves a transcript fence alone, whatever it is titled', () {
      for (final language in transcriptLanguages) {
        expect(
          problemsIn(
            '```$language title="$sourcePath"\n'
            'dart run tool/check_docs.dart\n'
            'Docs check passed.\n'
            '```',
          ),
          isEmpty,
          reason: '`$language` shows output, not the file',
        );
      }
    });

    test('reports the line the fence opens on', () {
      final problems = problemsIn(
        '```dart title="$sourcePath"\n'
        'final class BeakColumn {\n'
        '  final String name;\n'
        '  const BeakColumn({required this.name});\n'
        '}\n'
        '```',
      );
      // The wrapper is 7 lines, so the fence opens on page line 8.
      expect(problems.single.line, 8);
    });
  });

  group('containsRun', () {
    const source = [
      'final class BeakColumn {',
      '/// The name of the underlying database column.',
      'final String name;',
      '}',
    ];

    test('finds a run that is there in order', () {
      expect(containsRun(source, ['final String name;', '}']), isTrue);
    });

    test('walks over a comment the run omits', () {
      expect(
        containsRun(source, ['final class BeakColumn {', 'final String name;']),
        isTrue,
      );
    });

    test('will not walk over a comment the run claims to quote', () {
      expect(
        containsRun(source, [
          'final class BeakColumn {',
          '/// A column, declared once — read by six surfaces.',
        ]),
        isFalse,
      );
    });

    test('rejects a reordered run and an empty one', () {
      expect(containsRun(source, ['}', 'final String name;']), isFalse);
      expect(containsRun(source, const []), isFalse);
    });

    test('rejects a run longer than the source', () {
      expect(containsRun(const ['a'], ['a', 'b']), isFalse);
    });
  });

  group('chunksOf', () {
    test('splits on every elision spelling', () {
      final chunks = chunksOf([
        'one',
        'two',
        '// ...',
        'three',
        'four',
        '# ... the rest of the config ...',
        'five',
        'six',
        '...',
        'seven',
        'eight',
      ]);
      expect(chunks, [
        ['one', 'two'],
        ['three', 'four'],
        ['five', 'six'],
        ['seven', 'eight'],
      ]);
    });

    test('drops a one-line run that sits between elisions', () {
      // A line lifted out of its surroundings is as likely to be a
      // paraphrase of a signature as a quotation of one.
      expect(chunksOf(['one', '// ...', 'two']), isEmpty);
      expect(chunksOf(['// ...', 'alone', '// ...']), isEmpty);
    });

    test('keeps a body that is one line and elides nothing', () {
      // That body claims to be the whole of what it quotes, so it is checked
      // like any other. Skipping it let a fence quoting
      // `BeakAlertBlock('Saved', ...)` sit there having dropped the `const`
      // its source carries.
      expect(chunksOf(['alone']), [
        ['alone'],
      ]);
    });

    test('drops blank lines and indentation before comparing', () {
      expect(chunksOf(['  one', '', '  two']), [
        ['one', 'two'],
      ]);
    });
  });

  group('fencedLineIndices', () {
    test('covers the body of a fence but not its markers', () {
      expect(fencedLineIndices(['prose', '```dart', 'code', '```', 'prose']), {
        2,
      });
    });

    test('keeps a longer fence open across the fences it quotes', () {
      final lines = [
        '````markdown',
        '```mermaid',
        'flowchart LR',
        '```',
        '````',
        'prose',
      ];
      expect(fencedLineIndices(lines), {1, 2, 3});
    });

    test('treats an unterminated fence as running to the end', () {
      expect(fencedLineIndices(['```dart', 'code', 'more code']), {1, 2});
    });
  });

  group('proseOf', () {
    test('drops inline code, where a banned word is a symbol', () {
      expect(
        proseOf('The `onUnlock` callback runs first.'),
        isNot(contains('onUnlock')),
      );
    });

    test('drops the admonition and image markers, keeping the indent', () {
      expect(
        proseOf('!!! note "What just happened"'),
        ' note "What just happened"',
      );
      expect(proseOf('    ??? tip "More"'), '     tip "More"');
      expect(
        proseOf('![A panel](../assets/panel.png)'),
        '[A panel](../assets/panel.png)',
      );
    });
  });

  group('the enforced bans', () {
    test('cover every marketing word the style guide lists', () {
      expect(marketingWordBans.map((ban) => ban.label), [
        '"seamless"',
        '"effortless"',
        '"powerful"',
        '"blazing"',
        '"robust"',
        '"simply"',
        '"supercharge"',
        '"delightful"',
        '"magic"',
        '"revolutionary"',
      ]);
    });

    test('catch each word and the forms built on it', () {
      const offenders = <String, String>{
        'The wiring is seamless.': '"seamless"',
        'Effortlessly define a model.': '"effortless"',
        'A powerful table widget.': '"powerful"',
        'Blazing fast exports.': '"blazing"',
        'A robust migration story.': '"robust"',
        'You simply add a column.': '"simply"',
        'Supercharge your panel.': '"supercharge"',
        'A delightful editing experience.': '"delightful"',
        'The relation is wired magically.': '"magic"',
        'A revolutionary admin panel.': '"revolutionary"',
        'To wire it up, just call the builder.': '"just" in front of a verb',
        'Wow!! Two exclamation points.': 'an exclamation-point storm',
        '## Already have a database?': 'a heading written as a question',
        'One idea — then another.': 'the em-dash',
      };
      for (final offender in offenders.entries) {
        expect(messagesOf(problemsIn(offender.key)), [
          contains(offender.value),
        ], reason: offender.key);
      }
    });

    test('leave the senses the style guide allows alone', () {
      const allowed = [
        'The server listens on every interface, not just loopback.',
        '!!! note "What just happened"',
        'Fill the tables you just created with demo data.',
        'A trailing `!` means required.',
        '## What a column is',
        '# What is Beak?',
        '# Why Beak?',
        'There is a use case for a raw column.',
        'Its comment reads `declared once — read six times`.',
      ];
      for (final line in allowed) {
        expect(problemsIn(line), isEmpty, reason: line);
      }
    });

    test('read the prose, not the code it quotes', () {
      expect(
        problemsIn(
          '```dart title="$sourcePath"\n'
          '/// Simply put, a powerful column. Wow!! Magic.\n'
          'final class BeakColumn {\n'
          '  const BeakColumn({required this.name});\n'
          '  final String name;\n'
          '}\n'
          '```',
        ),
        // The fence body is not a faithful quotation either, so the one
        // problem reported is the quotation, never the wording.
        [
          predicate<DocProblem>(
            (problem) => problem.message.contains('does not quote it'),
            'a quotation problem',
          ),
        ],
      );
    });

    test('report the line the writer has to open', () {
      final problems = problemsIn('You simply add a column.');
      // The wrapper is 7 lines, so the body starts on page line 8.
      expect(problems.single.line, 8);
    });
  });

  group('the UseCase ban', () {
    test('fires on a page that has the architecture wrong', () {
      expect(
        problemsIn('Some architectures slot a UseCase between the two.'),
        hasLength(1),
      );
    });

    test('spares the pages whose subject is that there is none', () {
      // A page teaching "there is no UseCase layer" has to be able to write
      // the words, or the ban fires on the one page stating the rule.
      for (final path in const [
        'docs/concepts/the-four-layers.md',
        'docs/contributing/code-guardrails.md',
      ]) {
        expect(
          checkBannedPhrases(
            path,
            page('Reaching for a UseCase means the Repository.').split('\n'),
            bans: enforcedBans,
          ),
          isEmpty,
          reason: path,
        );
      }
    });
  });

  group('the unlock ban', () {
    test('fires on the marketing sense', () {
      for (final line in const [
        'Unlock the power of your data.',
        'It unlocks the full potential of the panel.',
        'Unlocking hidden insights from every table.',
      ]) {
        expect(problemsIn(line), hasLength(1), reason: line);
      }
    });

    test('spares the lock screen, which really does unlock', () {
      // The panel has an `onUnlock` callback and an unlock password. A ban on
      // the bare word fired on the page documenting them and nowhere else.
      for (final line in const [
        'The `onUnlock` callback validates the unlock password.',
        'Any password unlocks the panel.',
      ]) {
        expect(problemsIn(line), isEmpty, reason: line);
      }
    });
  });

  group('every style-guide ban', () {
    test('is enforced, with no reported-only backlog', () {
      // The tool used to carry a `pendingBans` list for rules that fired on
      // published pages. Both were false positives rather than a backlog, and
      // narrowing them emptied it.
      expect(enforcedBans, contains(useCaseLayer));
      expect(enforcedBans, contains(marketingUnlock));
      expect(enforcedBans, contains(emDash));
    });
  });

  group('a section marker', () {
    test('may name a private symbol', () {
      // `file.dart:_helper` used to be misread as a whole-file include, which
      // skipped the marker check on exactly the sections nothing else
      // watches.
      expect(sectionOf('lib/thing.dart:_helper'), '_helper');
      expect(sectionOf('lib/thing.dart:BeakColumn'), 'BeakColumn');
      expect(sectionOf('lib/thing.dart'), isNull);
    });

    test('is reported when its end sits above its start', () {
      // Both markers present, so the presence checks pass; pymdownx then
      // publishes nothing and the page silently loses its example.
      final problems = checkInclude(
        'docs/test/page.md',
        'lib/thing.dart:Inverted',
        4,
        readFile: (path) =>
            '// --8<-- [end:Inverted]\nclass Inverted {}\n'
            '// --8<-- [start:Inverted]\n',
      );

      expect(problems, hasLength(1));
      expect(problems.single.toString(), contains('sits above its "start"'));
    });

    test('in the right order is accepted', () {
      expect(
        checkInclude(
          'docs/test/page.md',
          'lib/thing.dart:Ordered',
          4,
          readFile: (path) =>
              '// --8<-- [start:Ordered]\nclass Ordered {}\n'
              '// --8<-- [end:Ordered]\n',
        ),
        isEmpty,
      );
    });
  });

  group('which titles are checked as repo quotations', () {
    /// A fence titled [title], quoting a line no file contains.
    List<DocProblem> problemsForTitle(String title) => checkPage(
      'docs/test/page.md',
      page('```dart title="$title"\nnot in any file\nand nor is this\n```'),
      readFile: (path) => null,
    );

    test('a root config file this repository owns is checked', () {
      // `melos.yaml` went unchecked for as long as the rule was a prefix
      // allowlist, and the page quoting its `analyze` script drifted three
      // sub-scripts behind.
      for (final title in const [
        'melos.yaml',
        'mkdocs.yml',
        'CONTRIBUTING.md',
      ]) {
        expect(problemsForTitle(title), isNotEmpty, reason: title);
      }
    });

    test('deploy/ is checked', () {
      expect(problemsForTitle('deploy/Dockerfile.server'), isNotEmpty);
    });

    test('a git-ignored directory is left alone', () {
      // PLAN/ exists only in a working tree: it is git-ignored, so a fresh
      // clone and CI have no such directory. Checking it made `melos run
      // analyze` pass locally and fail on every checkout that mattered.
      expect(problemsForTitle('PLAN/PHASES.md'), isEmpty);
    });

    test('a path in the reader\'s own project is left alone', () {
      // `beak.yaml` and `lib/models/product.dart` name files in the project
      // the reader is building, not in this repository. Checking those would
      // fail the day someone adds a file with the same name at the root.
      expect(problemsForTitle('beak.yaml'), isEmpty);
      expect(problemsForTitle('lib/models/product.dart'), isEmpty);
      expect(problemsForTitle('.env'), isEmpty);
    });
  });

  group('page metadata', () {
    test('a page with complete metadata is clean', () {
      expect(metadataProblems(guide()), isEmpty);
    });

    test('leaves a page with no front matter to checkPage', () {
      expect(metadataProblems('# A test page\n\nProse.\n'), isEmpty);
    });

    test('reports a missing type, audience and status', () {
      final problems = metadataProblems(
        '---\ntitle: A test page\ndescription: Short.\n---\n\n# A test page\n',
      );
      expect(messagesOf(problems), [
        contains('no "type:"'),
        contains('no "audience:"'),
        contains('no "status:"'),
      ]);
    });

    test('reports values outside the allowed sets', () {
      final problems = metadataProblems(
        guide(type: 'essay', audience: '[reader]', status: 'final'),
      );
      expect(messagesOf(problems), [
        contains('type "essay" is not one of'),
        contains('audience "reader" is not one of'),
        contains('status "final" is not one of'),
      ]);
    });

    test('reports front matter that is not valid YAML', () {
      final problems = metadataProblems(
        '---\ntitle: A test page\ndescription: Two: colons\n---\n',
      );
      expect(messagesOf(problems), [contains('not valid YAML')]);
    });

    test('reports a description longer than a search result shows', () {
      final problems = metadataProblems(guide(description: 'x' * 161));
      expect(messagesOf(problems), [contains('161 characters')]);
      expect(metadataProblems(guide(description: 'x' * 160)), isEmpty);
    });

    test('reports an H1 that differs from the title', () {
      final problems = metadataProblems(guide(heading: 'Another title'));
      expect(messagesOf(problems), [
        'the H1 "Another title" differs from the title "A test page"',
      ]);
    });

    test('reads the H1 past a comment in a fence and ignores later H1s', () {
      final content = guide(
        body: '```bash\n# not a heading\n```\n\n# A second H1\n',
      );
      expect(metadataProblems(content), isEmpty);
    });
  });

  group('the headings a stable page needs', () {
    test('cover exactly the allowed types', () {
      expect(requiredHeadings.keys.toSet(), pageTypes);
    });

    for (final entry in requiredHeadings.entries) {
      test('a stable ${entry.key} page reports each one it lacks', () {
        final problems = metadataProblems(
          guide(type: entry.key, status: 'stable'),
        );
        expect(problems, hasLength(entry.value.length));
        for (final heading in entry.value) {
          expect(
            messagesOf(problems),
            contains(contains('needs the heading "$heading"')),
          );
        }
      });

      test('a stable ${entry.key} page with them is clean', () {
        final body = entry.value
            .map((heading) => '$heading\n\nText.\n')
            .join('\n');
        expect(
          metadataProblems(
            guide(type: entry.key, status: 'stable', body: body),
          ),
          isEmpty,
        );
      });
    }

    test('are not asked of a draft or preview page', () {
      expect(metadataProblems(guide(status: 'draft')), isEmpty);
      expect(metadataProblems(guide(status: 'preview')), isEmpty);
    });

    test('do not count when they sit inside a fence', () {
      final body = requiredHeadings['guide']!
          .map((heading) => '```markdown\n$heading\n```\n')
          .join('\n');
      final problems = metadataProblems(guide(status: 'stable', body: body));
      expect(problems, hasLength(requiredHeadings['guide']!.length));
    });
  });

  group('repository paths named in prose', () {
    bool onlyKnown(String path) => path == 'packages/beak_core/pubspec.yaml';

    List<DocProblem> proseProblems(String body) => checkPageMetadata(
      'docs/test/page.md',
      guide(body: body),
      pathExists: onlyKnown,
    );

    test('accepts a path the repository has', () {
      expect(proseProblems('Open `packages/beak_core/pubspec.yaml`.'), isEmpty);
    });

    test('reports a path it does not have, on its line', () {
      final problems = proseProblems('Open `examples/store/README.md`.');
      expect(problems.single.message, contains('`examples/store/README.md`'));
      expect(problems.single.message, contains('does not exist'));
      // guide() puts the H1 on page line 9 and the body from line 11.
      expect(problems.single.line, 11);
    });

    test('checks all four roots, and a directory written with a slash', () {
      for (final path in const [
        'packages/gone/',
        'examples/gone',
        'tool/gone.dart',
        'deploy/gone.yaml',
      ]) {
        expect(proseProblems('See `$path`.'), hasLength(1), reason: path);
      }
    });

    test('leaves fences, placeholders and other roots alone', () {
      const untouched = [
        '```bash\ncat packages/gone/file.dart\n```',
        'Use `examples/serverpod_<domain>/` as a name.',
        'Pass `packages/*/pubspec.yaml` to the glob.',
        'Your own `lib/models/note.dart` is not the repository.',
        'A path with words, `packages/gone and more`, is prose.',
      ];
      for (final body in untouched) {
        expect(proseProblems(body), isEmpty, reason: body);
      }
    });
  });

  group('the nav', () {
    test('is cut out of a file whose other blocks carry python tags', () {
      final block = topLevelBlock(mkdocs(), 'nav')!;
      expect(block, startsWith('nav:'));
      expect(block, isNot(contains('python/name')));
      final nav = parseNav(block);
      expect(nav.map((node) => node.label), ['Start', 'Guides']);
      expect(topLevelBlock('site_name: A\n', 'nav'), isNull);
    });

    test('a consistent site is clean', () {
      expect(siteProblems(), isEmpty);
    });

    test('reports a label that differs from the page title', () {
      final problems = siteProblems(
        yaml: mkdocs().replaceFirst(
          '"Quickstart": start-here/quickstart.md',
          '"Start quickly": start-here/quickstart.md',
        ),
      );
      expect(messagesOf(problems), [
        'the nav label "Start quickly" differs from the title "Quickstart" of '
            '"start-here/quickstart.md"',
      ]);
    });

    test('lets the home page serve a tab called something else', () {
      // "Start" is the tab and "Beak" is the title of docs/index.md.
      expect(siteProblems(), isEmpty);
      final problems = siteProblems(
        yaml: mkdocs().replaceFirst('- Guides:', '- Manuals:'),
      );
      expect(messagesOf(problems), [
        'the section label "Manuals" differs from the title "Guides" of its '
            'index "guides/index.md"',
      ]);
    });

    test('reports a title two pages share', () {
      final problems = siteProblems(
        pages: {
          ...sitePages(),
          'docs/start-here/quickstart.md': guide(title: 'Fields'),
        },
        yaml: mkdocs().replaceFirst(
          '"Quickstart": start-here/quickstart.md',
          '"Fields": start-here/quickstart.md',
        ),
      );
      expect(messagesOf(problems), [contains('the title "Fields" belongs to')]);
    });

    test('reports a section that does not open on an index page', () {
      final problems = siteProblems(
        yaml: mkdocs().replaceFirst(
          '          - models/index.md\n          - "Fields": models/fields.md',
          '          - "Fields": models/fields.md\n          - models/index.md',
        ),
      );
      expect(messagesOf(problems), [
        contains('"Models" does not open on an index.md page'),
      ]);
    });

    test('reports an index with no routing table', () {
      final problems = siteProblems(
        pages: {
          ...sitePages(),
          'docs/models/index.md': indexPage('Models', [
            'fields.md',
          ]).replaceFirst('## Which page to read', '## Contents'),
        },
      );
      expect(messagesOf(problems), [
        contains('index of "Models" has no "## Which page to read"'),
      ]);
    });

    test('reports an index that leaves out a child', () {
      final problems = siteProblems(
        pages: {...sitePages(), 'docs/index.md': indexPage('Beak', const [])},
      );
      expect(messagesOf(problems), [
        contains('does not link "start-here/quickstart.md"'),
      ]);
    });

    test('links a child section through its own index, however written', () {
      // guides/index.md links models/index.md; a differently written link to
      // the same page counts, and a link to the wrong page does not.
      expect(
        siteProblems(
          pages: {
            ...sitePages(),
            'docs/guides/index.md': indexPage('Guides', [
              '../guides/../models/index.md#top',
            ]),
          },
        ),
        isEmpty,
      );
      expect(
        siteProblems(
          pages: {
            ...sitePages(),
            'docs/guides/index.md': indexPage('Guides', [
              '../models/fields.md',
            ]),
          },
        ),
        isNotEmpty,
      );
    });

    test('reports a page the nav leaves out, and a nav entry with no page', () {
      final problems = siteProblems(
        pages: {
          ...sitePages(),
          'docs/models/orphan.md': guide(title: 'Orphan'),
        },
        yaml: mkdocs().replaceFirst(
          '          - "Fields": models/fields.md\n',
          '          - "Fields": models/fields.md\n'
              '          - "Ghost": models/ghost.md\n',
        ),
      );
      expect(messagesOf(problems), [
        contains('does not link "models/ghost.md"'),
        'the nav lists "models/ghost.md", which is not a page',
        'is not in the nav',
      ]);
    });
  });

  group('the URL manifest', () {
    test('is read one entry per line, skipping comments and blanks', () {
      expect(manifestEntries('# note\n\na.md\n  b.md  \n# more\n'), [
        'a.md',
        'b.md',
      ]);
    });

    test('accepts a page and a redirect key', () {
      expect(
        siteProblems(manifest: 'models/fields.md\nold/fields.md\n'),
        isEmpty,
      );
    });

    test('reports a published path that is neither', () {
      final problems = siteProblems(
        manifest: 'models/fields.md\nlost/page.md\n',
      );
      expect(problems, hasLength(1));
      expect(problems.single.path, urlManifestPath);
      expect(problems.single.message, contains('"lost/page.md"'));
    });

    test('reports a missing manifest', () {
      final problems = checkSite(
        pages: sitePages(),
        mkdocsYaml: mkdocs(),
        manifest: null,
      );
      expect(messagesOf(problems), ['is missing']);
    });

    test('reports a redirect to a page that does not exist', () {
      final problems = siteProblems(
        yaml: mkdocs().replaceFirst(
          'old/fields.md: models/fields.md',
          'old/fields.md: models/gone.md',
        ),
      );
      expect(messagesOf(problems), [
        'the redirect "old/fields.md" points at "models/gone.md", which is not '
            'a page',
      ]);
    });

    test('ignores the fragment when it checks a redirect target', () {
      expect(
        siteProblems(
          yaml: mkdocs().replaceFirst(
            'old/fields.md: models/fields.md',
            'old/fields.md: models/fields.md#types',
          ),
        ),
        isEmpty,
      );
    });

    test('reports a redirect key that is also a page', () {
      final problems = siteProblems(
        yaml: mkdocs().replaceFirst(
          'old/fields.md: models/fields.md',
          'models/fields.md: index.md',
        ),
        manifest: 'models/fields.md\n',
      );
      expect(messagesOf(problems), [
        contains('"models/fields.md" is also a page'),
      ]);
    });
  });

  group('the llmstxt sections', () {
    test('are read from the plugin, and null when it is absent', () {
      final plugins = topLevelBlock(mkdocs(), 'plugins')!;
      expect(parseLlmsGlobs(plugins), [
        'index.md',
        'start-here/*.md',
        'guides/index.md',
        'models/*.md',
      ]);
      expect(parseLlmsGlobs('plugins:\n  - search\n'), isNull);
    });

    test('report a page no section lists', () {
      final problems = siteProblems(
        yaml: mkdocs().replaceFirst('          - models/*.md\n', ''),
      );
      // models/index.md and models/fields.md, and the glob is gone.
      expect(messagesOf(problems), [
        'is in no llmstxt section of mkdocs.yml, so /llms.txt omits it',
        'is in no llmstxt section of mkdocs.yml, so /llms.txt omits it',
      ]);
    });

    test('report a glob that matches nothing', () {
      final problems = siteProblems(
        yaml: mkdocs().replaceFirst('models/*.md', 'modles/*.md'),
      );
      expect(
        messagesOf(problems),
        contains('the llmstxt glob "modles/*.md" matches no page'),
      );
    });
  });

  group('the release ratchet', () {
    final drafts = {
      ...sitePages(),
      'docs/models/fields.md': guide(title: 'Fields'),
    };

    test('lets a draft page through on an ordinary run', () {
      expect(siteProblems(pages: drafts), isEmpty);
    });

    test('fails on a draft page with --release', () {
      final problems = siteProblems(pages: drafts, release: true);
      expect(problems, hasLength(1));
      expect(problems.single.path, 'docs/models/fields.md');
      expect(problems.single.message, contains('status is draft'));
    });

    test('passes stable and preview pages with --release', () {
      final previews = {
        ...sitePages(),
        'docs/models/fields.md': guide(title: 'Fields', status: 'preview'),
      };
      expect(siteProblems(pages: previews, release: true), isEmpty);
      expect(siteProblems(release: true), isEmpty);
    });
  });
}

/// A guide page whose front matter and body are set by the parameters.
///
/// The H1 defaults to [title] and sits on page line 9, so a body starts on
/// page line 11.
String guide({
  String title = 'A test page',
  String? heading,
  String type = 'guide',
  String audience = '[beginner]',
  String status = 'draft',
  String description = 'One sentence a search result can show.',
  String body = 'Plain prose.',
}) =>
    '---\n'
    'title: $title\n'
    'description: $description\n'
    'type: $type\n'
    'audience: $audience\n'
    'status: $status\n'
    '---\n'
    '\n'
    '# ${heading ?? title}\n'
    '\n'
    '$body\n'
    '\n'
    '## Continue reading\n'
    '\n'
    '- [Column types](column-types.md) every built-in column.\n';

/// The problems [checkPageMetadata] finds in [content].
List<DocProblem> metadataProblems(String content) =>
    checkPageMetadata('docs/test/page.md', content, pathExists: (_) => true);

/// A stable section index called [title] that links every path in [links].
String indexPage(String title, List<String> links) => guide(
  title: title,
  type: 'index',
  status: 'stable',
  body:
      '## Which page to read\n\n'
      '${links.map((link) => '- [Page]($link)').join('\n')}',
);

/// The pages of a two-tab site, keyed by repository path.
Map<String, String> sitePages() => {
  'docs/index.md': indexPage('Beak', ['start-here/quickstart.md']),
  'docs/start-here/quickstart.md': guide(title: 'Quickstart', status: 'stable'),
  'docs/guides/index.md': indexPage('Guides', ['../models/index.md']),
  'docs/models/index.md': indexPage('Models', ['fields.md']),
  'docs/models/fields.md': guide(title: 'Fields', status: 'stable'),
};

/// A `mkdocs.yml` for [sitePages], with a python tag outside the two blocks
/// the checks read, the way the real file has.
String mkdocs() => '''
site_name: Test
markdown_extensions:
  - pymdownx.emoji:
      emoji_index: !!python/name:material.extensions.emoji.twemoji
plugins:
  - search
  - llmstxt:
      sections:
        Start:
          - index.md
          - start-here/*.md
        Guides:
          - guides/index.md
          - models/*.md
  - redirects:
      redirect_maps:
        old/fields.md: models/fields.md
extra:
  social: []
nav:
  - Start:
      - index.md
      - "Quickstart": start-here/quickstart.md
  - Guides:
      - guides/index.md
      - Models:
          - models/index.md
          - "Fields": models/fields.md
''';

/// The site-level problems in [pages] under [yaml] and [manifest].
List<DocProblem> siteProblems({
  Map<String, String>? pages,
  String? yaml,
  String manifest = 'index.md\nmodels/fields.md\nold/fields.md\n',
  bool release = false,
}) => checkSite(
  pages: pages ?? sitePages(),
  mkdocsYaml: yaml ?? mkdocs(),
  manifest: manifest,
  release: release,
);
