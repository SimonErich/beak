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
        '```dart title="apps/reference_admin/lib/main.dart"\n'
        'void main() {}\n'
        '```',
      );
      expect(messagesOf(problems), [
        'fence titled "apps/reference_admin/lib/main.dart" — apps/ is now '
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

    test('drops a chunk of one line, which proves nothing on its own', () {
      expect(chunksOf(['alone']), isEmpty);
      expect(chunksOf(['one', '// ...', 'two']), isEmpty);
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
}
