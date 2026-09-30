import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '../tool/build_agent_docs.dart';
import '../tool/src/docs_markdown.dart';
import '../tool/src/docs_snippets.dart';

/// A reader over an in-memory file tree.
SnippetReader readerOf(Map<String, String> files) =>
    (path) => files[path];

/// `text` split into lines, the way the tools see a page.
List<String> linesOf(String text) => text.split('\n');

/// A docs page: front matter, an H1 and [body].
String page(String title, String body, {String? description, String? status}) =>
    '---\n'
    'title: $title\n'
    'description: ${description ?? 'About $title.'}\n'
    '${status == null ? '' : 'status: $status\n'}'
    '---\n'
    '\n'
    '# $title\n'
    '\n'
    '$body\n';

/// The `mkdocs.yml` of the fixture repository.
///
/// `Optional` comes before `Guides` on purpose: the bundle's llms.txt has to
/// put it last regardless.
const String mkdocsYaml = '''
site_name: Test Docs
site_url: https://example.github.io/beak/
repo_url: https://github.com/Example/beak
nav:
  - Start:
      - index.md
      - Guide: guide/guide.md
  - "AI directory":
      - ai/index.md
  - Contributing:
      - contributing/index.md
plugins:
  - search
  - llmstxt:
      markdown_description: >-
        A test site
        for the bundle.
      sections:
        Start:
          - index.md
        Optional:
          - contributing/*.md
        Guides:
          - guide/*.md
        AI directory:
          - ai/*.md
''';

/// A corrections table headed for the fixture's version, 1.2.3.
///
/// [rows] are the table's body lines; the default row names no symbol, so it
/// asks nothing of the fixture's packages.
String correctionsTable([
  String rows = '| A habit | Say the new thing |',
  String heading = 'Beak 1.2 does',
]) => '| You may remember | $heading |\n| --- | --- |\n$rows';

/// The files every fixture repository starts from.
Map<String, String> baseFiles() => {
  'mkdocs.yml': mkdocsYaml,
  'packages/beak_core/pubspec.yaml': 'name: beak_core\nversion: 1.2.3\n',
  'CHANGELOG.md': '# Changelog\n\n## 1.2.3\n\n- Something.\n',
  'docs/index.md': page('Home', 'Welcome.', description: 'The front door.'),
  'docs/guide/guide.md': page('Guide', 'Read this.'),
  'docs/ai/index.md': page('AI directory', correctionsTable(), status: 'draft'),
  'docs/contributing/index.md': page('Contributing', 'Help out.'),
};

/// A throwaway repository holding [baseFiles] with [overrides] on top.
///
/// A `null` override removes the file.
Directory makeRepo([Map<String, String?> overrides = const {}]) {
  final Directory root = Directory.systemTemp.createTempSync('agent_docs_');
  addTearDown(() => root.deleteSync(recursive: true));
  final Map<String, String?> files = {...baseFiles(), ...overrides};
  for (final entry in files.entries) {
    final String? content = entry.value;
    if (content != null) {
      File('${root.path}/${entry.key}')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);
    }
  }
  return root;
}

/// The bundle of a repository built from [overrides], failing on problems.
Map<String, String> bundleOf([Map<String, String?> overrides = const {}]) {
  final AgentDocsBuild build = buildAgentDocs(makeRepo(overrides));
  expect(build.problems, isEmpty);
  return build.files;
}

/// The problems of a repository built from [overrides].
List<String> problemsOf(Map<String, String?> overrides) =>
    buildAgentDocs(makeRepo(overrides)).problems;

/// What one run of [runAgentDocs] reported.
final class Run {
  Run(this.code, this.out, this.err);

  final int code;
  final String out;
  final String err;
}

/// Runs [runAgentDocs] on [root].
Run run(Directory root, {bool check = false}) {
  final out = StringBuffer();
  final err = StringBuffer();
  final int code = runAgentDocs(root: root, check: check, out: out, err: err);
  return Run(code, out.toString(), err.toString());
}

/// Where the bundle lives in [root].
Directory bundleIn(Directory root) =>
    Directory('${root.path}/$agentDocsDirectory');

void main() {
  group('expandSnippets', () {
    final Map<String, String> files = {
      'src/whole.dart':
          '// --8<-- [start:A]\n'
          'class A {}\n'
          '// --8<-- [end:A]\n'
          '\n'
          'class B {}\n',
      'src/nested.dart':
          '// --8<-- [start:Outer]\n'
          'class Outer {\n'
          '  // --8<-- [start:Inner]\n'
          '  int inner = 1;\n'
          '  // --8<-- [end:Inner]\n'
          '  int outer = 2;\n'
          '}\n'
          '// --8<-- [end:Outer]\n',
      'src/indented.dart':
          'class Host {\n'
          '  // --8<-- [start:member]\n'
          '  void first() {\n'
          '    body();\n'
          '  }\n'
          '\n'
          '  void second() {}\n'
          '  // --8<-- [end:member]\n'
          '}\n',
      'src/unclosed.dart': '// --8<-- [start:Open]\nclass Open {}\n',
      'src/chain.md': '--8<-- "src/whole.dart:A"\n',
      'src/loop.md': '--8<-- "src/loop.md"\n',
    };

    List<String> expand(String include) =>
        expandSnippets(linesOf(include), readFile: readerOf(files));

    test('a whole-file include is the file without its section markers', () {
      expect(expand('--8<-- "src/whole.dart"'), [
        'class A {}',
        '',
        'class B {}',
      ]);
    });

    test('a section include is the lines between its markers', () {
      expect(expand('--8<-- "src/whole.dart:A"'), ['class A {}']);
    });

    test('markers of a nested section are dropped and its lines kept', () {
      expect(expand('--8<-- "src/nested.dart:Outer"'), [
        'class Outer {',
        '  int inner = 1;',
        '  int outer = 2;',
        '}',
      ]);
      expect(expand('--8<-- "src/nested.dart:Inner"'), ['int inner = 1;']);
    });

    test('a section is dedented together, relative indentation kept', () {
      expect(expand('--8<-- "src/indented.dart:member"'), [
        'void first() {',
        '  body();',
        '}',
        '',
        'void second() {}',
      ]);
    });

    test('the include line indentation goes on every line it produces', () {
      expect(
        expand('- item\n\n    ```dart\n    --8<-- "src/whole.dart:A"\n    ```'),
        ['- item', '', '    ```dart', '    class A {}', '    ```'],
      );
    });

    test('an include inside an included file expands too', () {
      expect(expand('--8<-- "src/chain.md"'), ['class A {}']);
    });

    test('a missing file is a hard error on the include line', () {
      expect(
        () => expand('text\n--8<-- "src/gone.dart"'),
        throwsA(
          isA<SnippetException>()
              .having((e) => e.line, 'line', 1)
              .having(
                (e) => e.message,
                'message',
                'snippet includes "src/gone.dart", which does not exist',
              ),
        ),
      );
    });

    test('a missing section is a hard error', () {
      expect(
        () => expand('--8<-- "src/whole.dart:Nope"'),
        throwsA(
          isA<SnippetException>().having(
            (e) => e.message,
            'message',
            contains('has no "--8<-- [start:Nope]" marker'),
          ),
        ),
      );
    });

    test('a section that never closes is a hard error', () {
      expect(
        () => expand('--8<-- "src/unclosed.dart:Open"'),
        throwsA(
          isA<SnippetException>().having(
            (e) => e.message,
            'message',
            contains('never closes'),
          ),
        ),
      );
    });

    test('a line range is rejected as unsupported', () {
      expect(
        () => expand('--8<-- "src/whole.dart:1:2"'),
        throwsA(
          isA<SnippetException>().having(
            (e) => e.message,
            'message',
            contains('line range'),
          ),
        ),
      );
    });

    test('a page line holding a section marker is dropped, as mkdocs does', () {
      expect(
        expand(
          'before\n'
          '```dart\n'
          '// --8<-- [start:Thing]\n'
          'class Thing {}\n'
          '```\n'
          'after `--8<-- [end:Thing]` gone',
        ),
        ['before', '```dart', 'class Thing {}', '```'],
      );
    });

    test('a marker escaped with a semicolon stays, without the semicolon', () {
      expect(
        expand(
          'Write `;--8<-- [start:Thing]` first.\n'
          '// ;;--8<-- [end:Thing]',
        ),
        ['Write `--8<-- [start:Thing]` first.', '// ;--8<-- [end:Thing]'],
      );
    });

    test('an include cycle is an error, not an infinite loop', () {
      expect(
        () => expand('--8<-- "src/loop.md"'),
        throwsA(isA<SnippetException>()),
      );
    });

    test('a broken include inside an included file names that file', () {
      expect(
        () => expandSnippets([
          '--8<-- "a.md"',
        ], readFile: readerOf({'a.md': '--8<-- "b.md"'})),
        throwsA(
          isA<SnippetException>().having(
            (e) => e.message,
            'message',
            startsWith('in "a.md", '),
          ),
        ),
      );
    });
  });

  group('convertContainers', () {
    List<String> convert(String text) => convertContainers(linesOf(text));

    test('an admonition becomes a titled blockquote', () {
      expect(
        convert(
          '!!! note "What happened"\n    First.\n\n    Second.\n\nAfter.',
        ),
        [
          '> **Note: What happened**',
          '>',
          '> First.',
          '>',
          '> Second.',
          '',
          'After.',
        ],
      );
    });

    test('an untitled or same-titled admonition is labelled by its type', () {
      expect(convert('!!! warning\n    Careful.'), [
        '> **Warning**',
        '>',
        '> Careful.',
      ]);
      expect(convert('!!! tip "Tip"\n    Nice.'), [
        '> **Tip**',
        '>',
        '> Nice.',
      ]);
    });

    test('a collapsible block converts like an admonition', () {
      expect(convert('???+ question "Why?"\n    Because.'), [
        '> **Question: Why?**',
        '>',
        '> Because.',
      ]);
    });

    test('a fenced block inside an admonition stays a fence, quoted', () {
      expect(
        convert('!!! note "Code"\n    ```dart\n    var a = 1;\n\n    ```'),
        ['> **Note: Code**', '>', '> ```dart', '> var a = 1;', '>', '> ```'],
      );
    });

    test('an admonition marker inside a fence is left alone', () {
      const example = '```md\n!!! note "Example"\n    Body.\n```';
      expect(convert(example), linesOf(example));
    });

    test('a tab becomes a bold label over its dedented body', () {
      expect(
        convert(
          '=== "The panel"\n\n    Panel text.\n\n=== "The server"\n\n    Server text.',
        ),
        [
          '**The panel**',
          '',
          'Panel text.',
          '',
          '**The server**',
          '',
          'Server text.',
        ],
      );
    });

    test('tabs and admonitions nest', () {
      expect(convert('=== "A"\n    !!! note "In tab"\n        Inner.'), [
        '**A**',
        '',
        '> **Note: In tab**',
        '>',
        '> Inner.',
      ]);
    });

    test('a block directly followed by text keeps a blank line between', () {
      expect(convert('!!! note "T"\n    Body.\nNext.'), [
        '> **Note: T**',
        '>',
        '> Body.',
        '',
        'Next.',
      ]);
    });
  });

  group('stripSiteMarkup', () {
    test('drops md_in_html wrappers and their closing tags, keeps content', () {
      expect(
        stripSiteMarkup(
          linesOf(
            '<div class="grid cards" markdown>\n'
            '<div class="plain">\n'
            '- one\n'
            '</div>\n'
            '</div>\n'
            'after',
          ),
        ),
        ['<div class="plain">', '- one', '</div>', 'after'],
      );
    });

    test('drops attr_list blocks on headings, links and their own line', () {
      expect(
        stripSiteMarkup(
          linesOf(
            '## Heading { #custom .large }\n'
            '[Go](x.md){ .md-button data-x="1" }\n'
            '{: .annotate }\n'
            '1. item',
          ),
        ),
        ['## Heading', '[Go](x.md)', '1. item'],
      );
    });

    test('leaves braces that are not attributes, and fenced markup', () {
      const lines = [
        'A record is { "values": {...} } here.',
        'Inline `{ .x }` code stays.',
        '```html',
        '<div markdown>',
        '{ .x }',
        '</div>',
        '```',
      ];
      expect(stripSiteMarkup(lines), lines);
    });
  });

  group('DocsLinkRewriter', () {
    final links = DocsLinkRewriter(
      pages: {
        'index.md',
        'guide/guide.md',
        'guide/other.md',
        'models/fields.md',
        'reference/index.md',
        'ai/rules.md',
      },
      repoUrl: 'https://github.com/Example/beak',
      siteUrl: 'https://example.github.io/beak/',
      version: '1.2.3',
      isRepoDirectory: (path) => path == 'examples/shop',
    );

    String rewrite(
      String line, {
      String from = 'guide/guide.md',
      String to = 'guide',
    }) => links.rewrite(line, pagePath: from, outputDirectory: to);

    test('a link to a published page stays relative', () {
      expect(
        rewrite('See [other](other.md#part).'),
        'See [other](other.md#part).',
      );
      expect(
        rewrite('See [fields](../models/fields.md).'),
        'See [fields](../models/fields.md).',
      );
    });

    test('a link to a page that is not published is an error', () {
      expect(
        () => rewrite('[x](missing.md)'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('not a published page'),
          ),
        ),
      );
    });

    test('a link that leaves docs/ becomes a GitHub URL at the tag', () {
      expect(
        rewrite('[src](../../packages/beak_core/lib/a.dart#L3)'),
        '[src](https://github.com/Example/beak/blob/v1.2.3/packages/beak_core/lib/a.dart#L3)',
      );
      expect(
        rewrite('[shop](../../examples/shop)'),
        '[shop](https://github.com/Example/beak/tree/v1.2.3/examples/shop)',
      );
      expect(
        rewrite('![logo](../assets/logo.png)'),
        '![logo](https://github.com/Example/beak/blob/v1.2.3/docs/assets/logo.png)',
      );
    });

    test('a link that climbs out of the repository is an error', () {
      expect(
        () => rewrite('[x](../../../../etc/passwd)'),
        throwsA(isA<FormatException>()),
      );
    });

    test('a tree or blob link on main is pinned to the tag', () {
      expect(
        rewrite('[a](https://github.com/Example/beak/tree/main/examples/shop)'),
        '[a](https://github.com/Example/beak/tree/v1.2.3/examples/shop)',
      );
      expect(
        rewrite(
          'Bare https://github.com/Example/beak/blob/main/README.md here',
        ),
        'Bare https://github.com/Example/beak/blob/v1.2.3/README.md here',
      );
    });

    test(
      'a published-site URL becomes the relative page when there is one',
      () {
        expect(
          rewrite('[f](https://example.github.io/beak/models/fields/#types)'),
          '[f](../models/fields.md#types)',
        );
        expect(
          rewrite('[home](https://example.github.io/beak/)'),
          '[home](../index.md)',
        );
        expect(
          rewrite('[r](https://example.github.io/beak/reference/)'),
          '[r](../reference/index.md)',
        );
        expect(
          rewrite('[llms](https://example.github.io/beak/llms.txt)'),
          '[llms](https://example.github.io/beak/llms.txt)',
        );
      },
    );

    test('other schemes, anchors and inline code are left alone', () {
      expect(
        rewrite('[a](https://dart.dev) [b](#local)'),
        '[a](https://dart.dev) [b](#local)',
      );
      expect(
        rewrite('Use `[x](missing.md)` verbatim.'),
        'Use `[x](missing.md)` verbatim.',
      );
    });

    test('reference-style definitions are rewritten too', () {
      expect(
        rewrite('[src]: ../../packages/a.dart "A"'),
        '[src]: https://github.com/Example/beak/blob/v1.2.3/packages/a.dart "A"',
      );
      expect(rewrite('[^1]: A footnote.'), '[^1]: A footnote.');
    });

    test('links are re-based for a page that moves to another directory', () {
      expect(
        rewrite(
          '[g](../guide/guide.md) [r](rules.md)',
          from: 'ai/index.md',
          to: '',
        ),
        '[g](guide/guide.md) [r](ai/rules.md)',
      );
    });
  });

  group('buildAgentDocs', () {
    test('front matter becomes an H1 with the description under it', () {
      final Map<String, String> files = bundleOf({
        'docs/guide/guide.md':
            '---\n'
            'title: Guide\n'
            'description: >-\n'
            '  Two lines\n'
            '  folded.\n'
            'type: guide\n'
            '---\n'
            '\n'
            '# Guide\n'
            '\n'
            'Text.\n',
      });
      expect(
        files['guide/guide.md'],
        '# Guide\n\n> Two lines folded.\n\nText.\n',
      );
    });

    test('a page without an H1 gets one from its title', () {
      final Map<String, String> files = bundleOf({
        'docs/guide/guide.md':
            '---\ntitle: Guide\ndescription: About it.\n---\n\nText.\n',
      });
      expect(files['guide/guide.md'], '# Guide\n\n> About it.\n\nText.\n');
    });

    test(
      'a page without front matter, or without a description, is refused',
      () {
        expect(problemsOf({'docs/guide/guide.md': '# Guide\n\nText.\n'}), [
          'docs/guide/guide.md: no front matter (needs title and description)',
        ]);
        expect(
          problemsOf({
            'docs/guide/guide.md': '---\ntitle: Guide\n---\n\n# Guide\n',
          }),
          ['docs/guide/guide.md: front matter needs a title and a description'],
        );
      },
    );

    test('snippets expand from the repo root, sections dedented', () {
      final Map<String, String> files = bundleOf({
        'examples/app/lib/a.dart':
            'class Root {\n'
            '  // --8<-- [start:member]\n'
            '  int value = 1;\n'
            '  // --8<-- [end:member]\n'
            '}\n',
        'docs/guide/guide.md': page(
          'Guide',
          '```dart title="examples/app/lib/a.dart"\n'
              '--8<-- "examples/app/lib/a.dart:member"\n'
              '```\n'
              '\n'
              '```dart\n'
              '--8<-- "examples/app/lib/a.dart"\n'
              '```',
        ),
      });
      expect(
        files['guide/guide.md'],
        contains(
          '```dart title="examples/app/lib/a.dart"\n'
          'int value = 1;\n'
          '```\n'
          '\n'
          '```dart\n'
          'class Root {\n'
          '  int value = 1;\n'
          '}\n'
          '```',
        ),
      );
    });

    test('a broken include is reported with the page and the page line', () {
      final List<String> problems = problemsOf({
        'docs/guide/guide.md': page('Guide', 'Text.\n\n--8<-- "nope.dart"'),
      });
      expect(problems, [
        'docs/guide/guide.md:10: '
            'snippet includes "nope.dart", which does not exist',
      ]);
    });

    test('admonitions and tabs are converted, mermaid fences kept', () {
      final Map<String, String> files = bundleOf({
        'docs/guide/guide.md': page(
          'Guide',
          '!!! warning "Careful"\n'
              '    Do not.\n'
              '\n'
              '=== "One"\n'
              '    First.\n'
              '\n'
              '```mermaid\n'
              'graph TD; A-->B;\n'
              '```',
        ),
      });
      expect(
        files['guide/guide.md'],
        contains(
          '> **Warning: Careful**\n'
          '>\n'
          '> Do not.\n'
          '\n'
          '**One**\n'
          '\n'
          'First.\n'
          '\n'
          '```mermaid\n'
          'graph TD; A-->B;\n'
          '```\n',
        ),
      );
    });

    test('links are rewritten in the written pages, not inside fences', () {
      final Map<String, String> files = bundleOf({
        'docs/guide/guide.md': page(
          'Guide',
          'See [home](../index.md), [code](../../packages/a/lib/a.dart) and '
              '[main](https://github.com/Example/beak/tree/main/examples).\n'
              '\n'
              '```md\n'
              '[code](../../packages/a/lib/a.dart)\n'
              '```',
        ),
      });
      expect(
        files['guide/guide.md'],
        contains(
          'See [home](../index.md), '
          '[code](https://github.com/Example/beak/blob/v1.2.3/packages/a/lib/a.dart) and '
          '[main](https://github.com/Example/beak/tree/v1.2.3/examples).\n'
          '\n'
          '```md\n'
          '[code](../../packages/a/lib/a.dart)\n'
          '```',
        ),
      );
    });

    test('a dangling page link is a problem naming the page', () {
      expect(
        problemsOf({'docs/guide/guide.md': page('Guide', '[x](gone.md)')}),
        [
          'docs/guide/guide.md: the link "gone.md" points at "guide/gone.md", '
              'which is not a published page',
        ],
      );
    });

    test('the unpublished folders stay out of the bundle', () {
      final Map<String, String> files = bundleOf({
        'docs/_internal/notes.md': '# Notes\n',
        'docs/_agents/notes.md': '# Notes\n',
        'docs/assets/readme.md': '# Assets\n',
      });
      expect(
        files.keys.where(
          (path) =>
              path.startsWith('_internal') ||
              path.startsWith('_agents') ||
              path.startsWith('assets'),
        ),
        isEmpty,
      );
    });

    test('the bundle mirrors docs plus the generated files', () {
      final Map<String, String> files = bundleOf();
      expect(files.keys.toList()..sort(), [
        'SUMMARY.md',
        'ai-index.md',
        'ai/index.md',
        'changelog.md',
        'contributing/index.md',
        'guide/guide.md',
        'index.md',
        'llms.txt',
        'manifest.json',
      ]);
    });

    test('SUMMARY.md is the nav with relative links', () {
      expect(
        bundleOf()['SUMMARY.md'],
        '# Summary\n'
        '\n'
        '- [Start](index.md)\n'
        '  - [Guide](guide/guide.md)\n'
        '- [AI directory](ai/index.md)\n'
        '- [Contributing](contributing/index.md)\n',
      );
    });

    test('an external nav entry is listed as it is', () {
      final Map<String, String> files = bundleOf({
        'mkdocs.yml': mkdocsYaml.replaceFirst(
          '  - Contributing:\n',
          '  - GitHub: https://github.com/Example/beak\n  - Contributing:\n',
        ),
      });
      expect(
        files['SUMMARY.md'],
        contains('- [GitHub](https://github.com/Example/beak)\n'),
      );
    });

    test(
      'a page missing from the nav, or a nav entry without a page, is refused',
      () {
        expect(problemsOf({'docs/guide/extra.md': page('Extra', 'Text.')}), [
          'docs/guide/extra.md: is not in the mkdocs nav',
        ]);
        expect(problemsOf({'docs/guide/guide.md': null}), [
          'mkdocs.yml: the nav lists "guide/guide.md", which is not a page',
        ]);
      },
    );

    test('llms.txt follows the plugin sections, with relative links', () {
      expect(
        bundleOf()['llms.txt'],
        '# Test Docs\n'
        '\n'
        '> A test site for the bundle.\n'
        '\n'
        '## Start\n'
        '\n'
        '- [Home](index.md): The front door.\n'
        '\n'
        '## Guides\n'
        '\n'
        '- [Guide](guide/guide.md): About Guide.\n'
        '\n'
        '## AI directory\n'
        '\n'
        '- [AI directory](ai/index.md): About AI directory.\n'
        '\n'
        '## Optional\n'
        '\n'
        '- [Contributing](contributing/index.md): About Contributing.\n',
      );
    });

    test('the changelog is a copy of the root CHANGELOG.md', () {
      expect(bundleOf()['changelog.md'], baseFiles()['CHANGELOG.md']);
    });

    test(
      'while the AI index page is a draft, ai-index.md only points at it',
      () {
        final String index = bundleOf()['ai-index.md']!;
        expect(index, startsWith('# Index for AI agents\n'));
        expect(index, contains('Beak 1.2.3'));
        expect(index, contains('[the AI directory](ai/index.md)'));
      },
    );

    test(
      'once the AI index page is written, ai-index.md is a re-based copy',
      () {
        final Map<String, String> files = bundleOf({
          'mkdocs.yml': mkdocsYaml.replaceFirst(
            '      - ai/index.md\n',
            '      - ai/index.md\n      - ai/rules.md\n',
          ),
          'docs/ai/rules.md': page('Rules', 'Follow them.'),
          'docs/ai/index.md': page(
            'AI directory',
            'Read [the guide](../guide/guide.md) and [rules](rules.md).\n\n'
                '${correctionsTable()}',
            status: 'stable',
          ),
        });
        expect(
          files['ai-index.md'],
          '# AI directory\n'
          '\n'
          '> About AI directory.\n'
          '\n'
          'Read [the guide](guide/guide.md) and [rules](ai/rules.md).\n'
          '\n'
          '${correctionsTable()}\n',
        );
        expect(
          files['ai/index.md'],
          contains('[the guide](../guide/guide.md)'),
        );
      },
    );

    test(
      'the manifest lists every file with its sha256, and no timestamps',
      () {
        final Map<String, String> files = bundleOf();
        final Object? manifest = jsonDecode(files['manifest.json']!);
        if (manifest is! Map<String, Object?>) {
          fail('manifest.json is not a JSON object');
        }
        final Map<String, Object?> parsed = manifest;
        expect(parsed.keys.toList(), [
          'format',
          'beak',
          'index',
          'pages',
          'files',
        ]);
        expect(parsed['format'], 1);
        expect(parsed['beak'], '1.2.3');
        expect(parsed['index'], 'ai-index.md');
        expect(parsed['pages'], 4);
        final Object? hashes = parsed['files'];
        if (hashes is! Map<String, Object?>) {
          fail('manifest.json has no files map');
        }
        expect(
          hashes.keys.toList(),
          (files.keys.toList()..sort())..remove('manifest.json'),
        );
        for (final entry in hashes.entries) {
          expect(
            entry.value,
            sha256.convert(utf8.encode(files[entry.key]!)).toString(),
            reason: entry.key,
          );
        }
        expect(
          files['manifest.json'],
          isNot(matches(RegExp(r'\d{4}-\d{2}-\d{2}T'))),
        );
      },
    );

    test('building twice gives identical bytes', () {
      final Directory root = makeRepo();
      final AgentDocsBuild first = buildAgentDocs(root);
      final AgentDocsBuild second = buildAgentDocs(root);
      expect(second.files.keys.toList(), first.files.keys.toList());
      expect(second.files, first.files);
      expect(
        Directory('${root.path}/$agentDocsDirectory').existsSync(),
        isFalse,
      );
    });

    test('a repo without mkdocs.yml or a CHANGELOG cannot be built', () {
      expect(problemsOf({'mkdocs.yml': null, 'CHANGELOG.md': null}), [
        'mkdocs.yml: not found; run this from the repo root',
        'CHANGELOG.md: not found; run this from the repo root',
      ]);
    });
  });

  group('runAgentDocs', () {
    test('writes the bundle, and --check then passes', () {
      final Directory root = makeRepo();
      final Run written = run(root);
      expect(written.code, 0);
      expect(
        written.out,
        'Agent docs bundle: 9 files, 9 written, 0 removed.\n',
      );
      expect(
        File('${bundleIn(root).path}/guide/guide.md').existsSync(),
        isTrue,
      );
      final Run checked = run(root, check: true);
      expect(checked.code, 0);
      expect(checked.err, isEmpty);
    });

    test('a second run writes nothing', () {
      final Directory root = makeRepo();
      run(root);
      expect(
        run(root).out,
        'Agent docs bundle: 9 files, 0 written, 0 removed.\n',
      );
    });

    test('--check reports a stale, a missing and an extra file', () {
      final Directory root = makeRepo();
      run(root);
      final String bundle = bundleIn(root).path;
      File('$bundle/guide/guide.md').writeAsStringSync('edited\n');
      File('$bundle/index.md').deleteSync();
      File('$bundle/old/page.md')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('gone\n');
      final Run checked = run(root, check: true);
      expect(checked.code, 1);
      expect(checked.err.split('\n'), [
        'stale: $agentDocsDirectory/guide/guide.md',
        'missing: $agentDocsDirectory/index.md',
        'extra: $agentDocsDirectory/old/page.md',
        'run: melos run agent-docs',
        '',
      ]);
      expect(File('$bundle/guide/guide.md').readAsStringSync(), 'edited\n');
    });

    test('--check on a repo with no bundle reports every file missing', () {
      final Run checked = run(makeRepo(), check: true);
      expect(checked.code, 1);
      expect(
        checked.err,
        contains('missing: $agentDocsDirectory/manifest.json'),
      );
    });

    test('a run repairs the bundle and removes extras only inside it', () {
      final Directory root = makeRepo({
        'packages/beak_core/doc/api/keep.md': 'not ours\n',
      });
      run(root);
      final String bundle = bundleIn(root).path;
      File('$bundle/guide/guide.md').writeAsStringSync('edited\n');
      File('$bundle/old/deep/page.md')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('gone\n');
      final Run repaired = run(root);
      expect(
        repaired.out,
        'Agent docs bundle: 9 files, 1 written, 1 removed.\n',
      );
      expect(run(root, check: true).code, 0);
      expect(Directory('$bundle/old').existsSync(), isFalse);
      expect(
        File('${root.path}/packages/beak_core/doc/api/keep.md').existsSync(),
        isTrue,
      );
    });

    test('a build with problems prints them and writes nothing', () {
      final Directory root = makeRepo({
        'docs/guide/guide.md': page('Guide', '[x](gone.md)'),
      });
      final Run failed = run(root);
      expect(failed.code, 1);
      expect(
        failed.err,
        startsWith('Agent docs build failed:\n  docs/guide/guide.md: '),
      );
      expect(bundleIn(root).existsSync(), isFalse);
      expect(run(root, check: true).code, 1);
    });
  });

  group('checkCorrectionsTable', () {
    const table =
        '# Index\n'
        '\n'
        '| You may remember | Beak 0.9 does |\n'
        '| --- | --- |\n'
        '| `BeakDataForm`, `FormViewModel` (removed) | `BeakFormScreen` + `BeakFormLayout` |\n'
        '| String keys (`\'name\'`) | `ProductModel.name`; run `beak prepare` |\n'
        '| Registering by hand | `withRelations([...])` and `BeakOverlays` |\n'
        '\n'
        'After the table.\n';

    List<String> check(
      String content,
      Set<String> known, {
      String version = '0.9.0',
      Set<String>? declared,
    }) => checkCorrectionsTable(
      content,
      version: version,
      libraryIdentifiers: () => known,
      declaredNames: declared == null ? null : () => declared,
    );

    test(
      'passes when every symbol exists, ignoring paths, commands and chains',
      () {
        expect(
          check(table, {
            'BeakFormScreen',
            'BeakFormLayout',
            'withRelations',
            'BeakOverlays',
          }),
          isEmpty,
        );
      },
    );

    test('fails on a symbol the packages do not define, with its line', () {
      expect(
        check(table, {'BeakFormScreen', 'withRelations', 'BeakOverlays'}),
        [
          'docs/ai/index.md:5: the corrections table names `BeakFormLayout`, '
              'which no packages/*/lib source contains',
        ],
      );
    });

    test('fails on a symbol tagged (removed) that the packages still have', () {
      expect(
        check(table, {
          'BeakFormScreen',
          'BeakFormLayout',
          'withRelations',
          'BeakOverlays',
          'FormViewModel',
        }),
        [
          'docs/ai/index.md:5: the corrections table marks `FormViewModel` '
              'as removed, but packages/*/lib still declares it',
        ],
      );
    });

    test(
      'proves a removal against the Beak packages, not the vendored ones',
      () {
        // worm_postgres declares its own `fromConfig`; that says nothing about
        // Beak's. The vendored packages count for "exists", not for "removed".
        final Set<String> everything = {
          'BeakFormScreen',
          'BeakFormLayout',
          'withRelations',
          'BeakOverlays',
          'FormViewModel',
        };
        expect(
          check(
            table,
            everything,
            declared: everything.difference({'FormViewModel'}),
          ),
          isEmpty,
        );
        expect(check(table, everything, declared: everything), hasLength(1));
      },
    );

    test('a bold column heading is still the corrections column', () {
      expect(
        check(
          '| Old | **Beak 0.9 does** |\n| --- | --- |\n| `X` | `Missing` |\n',
          {},
        ),
        [
          'docs/ai/index.md:3: the corrections table names `Missing`, '
              'which no packages/*/lib source contains',
        ],
      );
    });

    test('a page without the table fails, and says what to write', () {
      var read = false;
      final List<String> problems = checkCorrectionsTable(
        '# Index\n\n| A | B |\n| --- | --- |\n| `x` | `y` |\n',
        version: '0.9.0',
        libraryIdentifiers: () {
          read = true;
          return {};
        },
      );
      expect(problems, [
        'docs/ai/index.md needs the corrections table: a Markdown table with '
            'a column headed "Beak 0.9 does", one row per habit an agent gets '
            'wrong, symbols in backticks',
      ]);
      expect(read, isFalse);
    });

    test('a heading inside a code fence is not the table', () {
      expect(
        check(
          '```markdown\n| A | Beak 0.9 does |\n| --- | --- |\n| `x` | `y` |\n```\n',
          {},
        ),
        hasLength(1),
      );
    });

    test('the heading follows the version: a stale one is named', () {
      expect(
        check('| Old | Beak 0.9 does |\n| --- | --- |\n| `X` | `Known` |\n', {
          'Known',
        }, version: '0.10.0'),
        [
          'docs/ai/index.md:1: the corrections table column is headed '
              '"Beak 0.9 does", but this is Beak 0.10.0. Rename it '
              '"Beak 0.10 does".',
        ],
      );
    });

    test('a pre-release or build suffix does not change the heading', () {
      const content =
          '| Old | Beak 1.0 does |\n| --- | --- |\n| `X` | `Known` |\n';
      expect(check(content, {'Known'}, version: '1.0.0-dev.3+4'), isEmpty);
      expect(check(content, {'Known'}, version: '1.0'), isEmpty);
    });

    test('a version that is not major.minor accepts any Beak heading', () {
      expect(
        check('| Old | Beak next does |\n| --- | --- |\n| `X` | `Known` |\n', {
          'Known',
        }, version: 'unknown'),
        isEmpty,
      );
    });

    test('the build fails on an AI index with no table', () {
      expect(
        problemsOf({
          'docs/ai/index.md': page('AI directory', 'Draft.', status: 'draft'),
        }),
        [contains('docs/ai/index.md needs the corrections table')],
      );
    });

    test('the build fails on a heading that lags the beak_core version', () {
      expect(
        problemsOf({
          'docs/ai/index.md': page(
            'AI directory',
            correctionsTable(
              '| A habit | Say the new thing |',
              'Beak 0.9 does',
            ),
            status: 'draft',
          ),
        }),
        [contains('headed "Beak 0.9 does", but this is Beak 1.2.3')],
      );
    });

    test('the build runs it against packages/*/lib', () {
      final Map<String, String?> overrides = {
        'docs/ai/index.md': page(
          'AI directory',
          correctionsTable('| `OldThing` (removed) | `NewThing` |'),
          status: 'stable',
        ),
        'packages/demo/lib/demo.dart': 'class NewThing {}\n',
      };
      expect(problemsOf(overrides), isEmpty);
      expect(
        problemsOf({
          ...overrides,
          'packages/demo/lib/legacy.dart': 'class OldThing {}\n',
        }),
        [
          'docs/ai/index.md:11: the corrections table marks `OldThing` as '
              'removed, but packages/*/lib still declares it',
        ],
      );
      expect(problemsOf({...overrides, 'packages/demo/lib/demo.dart': ''}), [
        'docs/ai/index.md:11: the corrections table names `NewThing`, '
            'which no packages/*/lib source contains',
      ]);
    });

    test('a removed name that only survives as text is proven removed', () {
      // The four ways the word outlived the API in the real tree: a doc
      // comment, a message string, a local variable and a private helper.
      final Map<String, String?> overrides = {
        'docs/ai/index.md': page(
          'AI directory',
          correctionsTable('| `OldThing` (removed) | `NewThing` |'),
          status: 'stable',
        ),
        'packages/demo/lib/demo.dart':
            '/// Replaces OldThing.\n'
            'class NewThing {\n'
            "  static const String hint = 'did you mean OldThing?';\n"
            '  void build() {\n'
            '    final OldThing = 1;\n'
            '  }\n'
            '  void _legacy(int OldThing) {}\n'
            '}\n',
      };
      expect(problemsOf(overrides), isEmpty);
    });

    test('a vendored worm package cannot keep a removed Beak name alive', () {
      final Map<String, String?> overrides = {
        'docs/ai/index.md': page(
          'AI directory',
          correctionsTable('| `OldThing` (removed) | `NewThing` |'),
          status: 'stable',
        ),
        'packages/demo/lib/demo.dart': 'class NewThing {}\n',
        'packages/worm_demo/lib/worm_demo.dart': 'class OldThing {}\n',
      };
      expect(problemsOf(overrides), isEmpty);
    });
  });

  group('block templates', () {
    /// A valid template: markers, one placeholder, one section.
    String template(String name, {String body = ''}) =>
        '<!-- BEGIN:beak-agent-rules -->\n'
        '## $name\n'
        '\n'
        'Beak {{version}} at `{{docsIndex}}`.\n'
        '$body'
        '<!-- END:beak-agent-rules -->\n';

    const List<String> names = [
      'embedded',
      'serverpod-admin',
      'standalone',
      'workspace-root',
    ];

    /// The four templates, with [overrides] on top; a `null` removes one.
    Map<String, String?> blocks([
      Map<String, String?> overrides = const {},
    ]) => {
      for (final name in names) 'docs/_agents/blocks/$name.md': template(name),
      ...overrides,
    };

    /// The problems of a repository whose standalone template is [source].
    List<String> problemsOfStandalone(String source) =>
        problemsOf(blocks({'docs/_agents/blocks/standalone.md': source}));

    test('the templates are bundled verbatim next to the pages', () {
      final Map<String, String> files = bundleOf(blocks());
      for (final name in names) {
        expect(files['_agents/blocks/$name.md'], template(name));
      }
      final Object? manifest = jsonDecode(files['manifest.json']!);
      final Object? listed = switch (manifest) {
        {'files': final Map<String, Object?> files} => files,
        _ => null,
      };
      expect(
        listed,
        containsPair(
          '_agents/blocks/standalone.md',
          sha256.convert(utf8.encode(template('standalone'))).toString(),
        ),
      );
      expect(
        switch (manifest) {
          {'pages': final int pages} => pages,
          _ => null,
        },
        4,
        reason: 'the templates are not pages',
      );
    });

    test('a repository without the folder has neither templates nor code', () {
      final AgentDocsBuild build = buildAgentDocs(makeRepo());
      expect(build.files.keys.where((k) => k.startsWith('_agents')), isEmpty);
      expect(build.companions, isEmpty);
    });

    test('a missing template is a problem naming what the CLI needs', () {
      expect(problemsOf(blocks({'docs/_agents/blocks/embedded.md': null})), [
        'docs/_agents/blocks/embedded.md: missing; the CLI needs '
            'embedded, serverpod-admin, standalone and workspace-root',
      ]);
    });

    test('a template the CLI does not know is a problem', () {
      expect(
        problemsOf(blocks({'docs/_agents/blocks/mystery.md': template('m')})),
        [
          'docs/_agents/blocks/mystery.md: not a block template the CLI '
              'knows (embedded, serverpod-admin, standalone, workspace-root)',
        ],
      );
    });

    test('an unknown placeholder is a problem on its line', () {
      expect(problemsOfStandalone(template('s', body: '{{nope}}\n')), [
        'docs/_agents/blocks/standalone.md:5: unknown placeholder {{nope}}',
      ]);
    });

    test('every placeholder the renderer supplies is accepted', () {
      final String body = [
        for (final name in blockPlaceholders) '{{$name}}\n',
      ].join();
      expect(problemsOfStandalone(template('s', body: body)), isEmpty);
    });

    test('section tags must be known, alone on their line and balanced', () {
      expect(
        problemsOfStandalone(
          template('s', body: '{{#mystery}}\n{{/mystery}}\n'),
        ),
        [
          'docs/_agents/blocks/standalone.md:5: unknown section {{#mystery}}',
          'docs/_agents/blocks/standalone.md:6: unknown section {{/mystery}}',
        ],
      );
      expect(
        problemsOfStandalone(
          template('s', body: 'text {{#serverpod}}\n{{/serverpod}}\n'),
        ),
        [
          'docs/_agents/blocks/standalone.md:5: a section tag must be alone '
              'on its line',
        ],
      );
      expect(problemsOfStandalone(template('s', body: '{{#serverpod}}\nx\n')), [
        'docs/_agents/blocks/standalone.md:5: the section '
            '{{#serverpod}} is never closed',
      ]);
      expect(problemsOfStandalone(template('s', body: '{{/serverpod}}\n')), [
        'docs/_agents/blocks/standalone.md:5: {{/serverpod}} closes '
            'nothing',
      ]);
      expect(
        problemsOfStandalone(
          template(
            's',
            body: '{{#serverpod}}\n{{^mainIsGenerated}}\n{{/serverpod}}\n',
          ),
        ),
        [
          'docs/_agents/blocks/standalone.md:7: {{/serverpod}} closes the '
              'section {{^mainIsGenerated}}',
        ],
      );
      expect(
        problemsOfStandalone(
          template(
            's',
            body:
                '{{#serverpod}}\nx\n{{/serverpod}}\n'
                '{{^serverpod}}\ny\n{{/serverpod}}\n',
          ),
        ),
        isEmpty,
      );
    });

    test('the markers are required, first and last', () {
      expect(problemsOfStandalone('## No markers\n'), [
        'docs/_agents/blocks/standalone.md: must open with '
            '<!-- BEGIN:beak-agent-rules --> and end with '
            '<!-- END:beak-agent-rules -->',
      ]);
      expect(
        problemsOfStandalone(
          '<!-- BEGIN:beak-agent-rules -->\n'
          '<!-- BEGIN:beak-agent-rules -->\n'
          '<!-- END:beak-agent-rules -->\n',
        ),
        [
          'docs/_agents/blocks/standalone.md: the markers must appear '
              'exactly once each',
        ],
      );
    });

    test('an em-dash or a triple quote is a problem on its line', () {
      expect(problemsOfStandalone(template('s', body: 'a \u2014 b\n')), [
        'docs/_agents/blocks/standalone.md:5: no em-dashes in the templates',
      ]);
      expect(problemsOfStandalone(template('s', body: "it's ''' here\n")), [
        'docs/_agents/blocks/standalone.md:5: a triple quote cannot go in '
            'the generated Dart string',
      ]);
    });

    test('the CLI fallback is generated byte for byte from the templates', () {
      final AgentDocsBuild build = buildAgentDocs(makeRepo(blocks()));
      expect(build.companions.keys, [blockTemplatesSource]);
      final String source = build.companions[blockTemplatesSource]!;
      expect(source, startsWith('// GENERATED CODE'));
      for (final (constant, name) in [
        ('beakEmbeddedBlockTemplate', 'embedded'),
        ('beakServerpodAdminBlockTemplate', 'serverpod-admin'),
        ('beakStandaloneBlockTemplate', 'standalone'),
        ('beakWorkspaceRootBlockTemplate', 'workspace-root'),
      ]) {
        expect(
          source,
          contains("const String $constant = r'''\n${template(name)}''';"),
        );
      }
    });

    test('a run writes the fallback, and --check then covers it', () {
      final Directory root = makeRepo(blocks());
      final Run written = run(root);
      expect(written.code, 0);
      expect(
        written.out,
        'Agent docs bundle: 13 files, 13 written, 0 removed.\n'
        'Block templates: $blockTemplatesSource written.\n',
      );
      final File fallback = File('${root.path}/$blockTemplatesSource');
      expect(fallback.existsSync(), isTrue);
      expect(run(root, check: true).code, 0);
      expect(
        run(root).out,
        'Agent docs bundle: 13 files, 0 written, 0 removed.\n'
        'Block templates: $blockTemplatesSource up to date.\n',
      );

      fallback.writeAsStringSync('// edited\n');
      final Run stale = run(root, check: true);
      expect(stale.code, 1);
      expect(stale.err, contains('stale: $blockTemplatesSource'));
      fallback.deleteSync();
      expect(
        run(root, check: true).err,
        contains('missing: $blockTemplatesSource'),
      );
      expect(run(root).code, 0);
      expect(run(root, check: true).code, 0);
    });

    test('the template bytes in the bundle follow an edit', () {
      final Directory root = makeRepo(blocks());
      run(root);
      File(
        '${root.path}/docs/_agents/blocks/standalone.md',
      ).writeAsStringSync(template('standalone', body: 'Changed.\n'));
      final Run checked = run(root, check: true);
      expect(checked.code, 1);
      expect(
        checked.err,
        allOf(
          contains('stale: $agentDocsDirectory/_agents/blocks/standalone.md'),
          contains('stale: $blockTemplatesSource'),
          contains('stale: $agentDocsDirectory/manifest.json'),
        ),
      );
    });
  });
}
