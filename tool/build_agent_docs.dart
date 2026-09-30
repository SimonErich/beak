/// Builds the version-matched docs bundle for coding agents
/// (`melos run agent-docs`).
///
/// An agent's training data is older than the Beak it is asked to write, so
/// the docs it reads have to match the version the project resolved. This
/// tool turns the published site (`docs/`) into plain Markdown an agent can
/// read straight from disk, and commits the result to
/// `packages/beak_core/doc/agent-docs/`. `beak_core` is the one package every
/// project type resolves, so the bundle travels with the code it documents.
///
/// Per page: the front matter goes and its description becomes a `>` line
/// under the H1; `--8<--` includes are expanded like `pymdownx.snippets`
/// does; admonitions become blockquotes and content tabs bold labels;
/// `attr_list` and `md_in_html` markup goes; links are rewritten so the
/// bundle needs nothing outside itself (see `DocsLinkRewriter`).
///
/// Next to the pages the bundle carries `SUMMARY.md` (the nav), `llms.txt`
/// (the site's llms.txt with relative links), `changelog.md` (the root
/// CHANGELOG), `ai-index.md` (the router for agents) and `manifest.json` (a
/// sha256 per file, so a project can tell in one read that its copy is
/// current). The output is deterministic: no timestamps, sorted keys.
///
/// `docs/_agents/blocks/*.md` are the templates of the managed block that
/// `beak agents` writes into a project's `AGENTS.md`. They travel in the
/// bundle (under `_agents/blocks/`), so a project gets the rules of the Beak
/// version it resolved, and they are also compiled into
/// `packages/beak_cli/lib/src/agents/block_templates.g.dart`, the fallback
/// the CLI renders when a project has no bundle yet.
///
/// `--check` builds in memory and fails on any difference from disk. It
/// also checks the corrections table on the AI index page (see
/// [checkCorrectionsTable]) and the block templates (see
/// [checkBlockTemplate]).
///
/// Run from the repo root.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

import 'check_docs.dart';
import 'src/dart_declarations.dart';
import 'src/docs_markdown.dart';
import 'src/docs_snippets.dart';

/// Where the bundle is committed, relative to the repo root.
const String agentDocsDirectory = 'packages/beak_core/doc/agent-docs';

/// The bundle format version written to `manifest.json`.
const int agentDocsFormat = 1;

/// The page every project is sent to first, relative to the bundle.
const String agentDocsIndex = 'ai-index.md';

/// The command that regenerates the bundle, printed by `--check`.
const String regenerateHint = 'run: melos run agent-docs';

/// Where the block templates are written, relative to the repo root.
///
/// The CLI's fallback templates, byte-equal to `docs/_agents/blocks`.
const String blockTemplatesSource =
    'packages/beak_cli/lib/src/agents/block_templates.g.dart';

/// Where the block templates live, relative to `docs/`.
const String _blocksDirectory = '_agents/blocks';

/// The block templates the CLI renders, by file stem, in the order the
/// generated Dart lists them.
const List<String> agentBlockNames = [
  'embedded',
  'serverpod-admin',
  'standalone',
  'workspace-root',
];

/// The `{{name}}` placeholders the CLI's renderer supplies.
const Set<String> blockPlaceholders = {
  'version',
  'docsIndex',
  'schemaGlob',
  'panelEntry',
  'skills',
  'adminDir',
  'serverPkg',
  'clientPkg',
  'schemaPkg',
};

/// The `{{#name}}` / `{{^name}}` sections the CLI's renderer evaluates.
const Set<String> blockSections = {'mainIsGenerated', 'serverpod'};

/// The line that opens a managed block.
const String blockBegin = '<!-- BEGIN:beak-agent-rules -->';

/// The line that closes a managed block.
const String blockEnd = '<!-- END:beak-agent-rules -->';

/// The docs page the AI index is built from, relative to `docs/`.
const String _indexSource = 'ai/index.md';

/// A heading of the column the corrections table's symbols are read from,
/// whatever version it names: `Beak 0.9 does`.
final RegExp _correctionsColumn = RegExp(r'^Beak \S+ does$');

/// The column heading for [version], or `null` when it has no major.minor.
///
/// Derived, not written down twice: `0.9.0` reads `Beak 0.9 does`, and so does
/// `0.9.3-dev.1+4`. After a minor bump the check names the heading to write.
String? correctionsHeading(String version) {
  final RegExpMatch? match = RegExp(r'^(\d+)\.(\d+)').firstMatch(version);
  return match == null ? null : 'Beak ${match[1]}.${match[2]} does';
}

/// What a build produced: the bundle's files, or why it cannot be built.
final class AgentDocsBuild {
  /// A build that produced [files] and found [problems].
  const AgentDocsBuild(this.files, this.problems, {this.companions = const {}});

  /// Every file of the bundle, keyed by path relative to the bundle root.
  ///
  /// Empty when there are [problems].
  final Map<String, String> files;

  /// One line per thing that stops the bundle from being built.
  final List<String> problems;

  /// Generated files that live outside the bundle, keyed by path relative
  /// to the repo root.
  ///
  /// Empty when there are [problems], and when the repository has no block
  /// templates.
  final Map<String, String> companions;
}

/// Builds the bundle for the repository at [root], in memory.
AgentDocsBuild buildAgentDocs(Directory root) {
  final problems = <String>[];
  String? read(String path) {
    final file = File('${root.path}/$path');
    return file.existsSync()
        ? file.readAsStringSync().replaceAll('\r\n', '\n')
        : null;
  }

  final String? mkdocs = read('mkdocs.yml');
  final String? pubspec = read('packages/beak_core/pubspec.yaml');
  final String? changelog = read('CHANGELOG.md');
  for (final missing in [
    if (mkdocs == null) 'mkdocs.yml',
    if (pubspec == null) 'packages/beak_core/pubspec.yaml',
    if (changelog == null) 'CHANGELOG.md',
  ]) {
    problems.add('$missing: not found; run this from the repo root');
  }
  if (mkdocs == null || pubspec == null || changelog == null) {
    return AgentDocsBuild(const {}, problems);
  }

  final String? version = _stringAt(pubspec, 'version');
  final String? repoUrl = _stringAt(mkdocs, 'repo_url');
  final String? siteUrl = _stringAt(mkdocs, 'site_url');
  final String? siteName = _stringAt(mkdocs, 'site_name');
  for (final missing in [
    if (version == null) 'packages/beak_core/pubspec.yaml: no version',
    if (repoUrl == null) 'mkdocs.yml: no repo_url',
    if (siteUrl == null) 'mkdocs.yml: no site_url',
    if (siteName == null) 'mkdocs.yml: no site_name',
  ]) {
    problems.add(missing);
  }
  if (version == null ||
      repoUrl == null ||
      siteUrl == null ||
      siteName == null) {
    return AgentDocsBuild(const {}, problems);
  }

  final Map<String, String> sources = _publishedPages(root);
  final links = DocsLinkRewriter(
    pages: sources.keys.toSet(),
    repoUrl: repoUrl.replaceAll(RegExp(r'/+$'), ''),
    siteUrl: siteUrl.endsWith('/') ? siteUrl : '$siteUrl/',
    version: version,
    isRepoDirectory: (path) => Directory('${root.path}/$path').existsSync(),
  );

  final files = <String, String>{};
  for (final page in sources.entries) {
    final String? converted = _convertPage(
      docPath: page.key,
      content: page.value,
      outputDirectory: directoryOf(page.key),
      readFile: read,
      links: links,
      problems: problems,
    );
    if (converted != null) {
      files[page.key] = converted;
    }
  }

  final List<NavNode> nav = _navOf(mkdocs);
  final Map<String, SitePage> site = {
    for (final page in sources.entries)
      page.key: SitePage('docs/${page.key}', page.value),
  };
  files
    ..['SUMMARY.md'] = _summary(nav, site, problems)
    ..['llms.txt'] = _llmsTxt(mkdocs, nav, site, siteName, problems)
    ..['changelog.md'] = changelog
    ..[agentDocsIndex] =
        _aiIndex(
          sources,
          version,
          readFile: read,
          links: links,
          problems: problems,
        ) ??
        '';

  final String? indexSource = sources[_indexSource];
  final names = _LibraryNames(root);
  if (indexSource != null) {
    problems.addAll(
      checkCorrectionsTable(
        indexSource,
        version: version,
        libraryIdentifiers: () => names.words,
        declaredNames: () => names.declaredByBeak,
      ),
    );
  }
  final Map<String, String>? blocks = _blockTemplates(root, problems);
  if (problems.isNotEmpty) {
    return AgentDocsBuild(const {}, problems);
  }
  if (blocks != null) {
    for (final block in blocks.entries) {
      files['$_blocksDirectory/${block.key}.md'] = block.value;
    }
  }
  files['manifest.json'] = _manifest(files, version, sources.length);
  return AgentDocsBuild(
    files,
    problems,
    companions: blocks == null
        ? const {}
        : {blockTemplatesSource: _blockTemplatesDart(blocks)},
  );
}

/// The block templates of `docs/_agents/blocks`, by file stem, or `null`
/// when the repository has none.
///
/// Every template the CLI renders must be there, and each must pass
/// [checkBlockTemplate]; whatever is wrong is added to [problems].
Map<String, String>? _blockTemplates(Directory root, List<String> problems) {
  final directory = Directory('${root.path}/docs/$_blocksDirectory');
  if (!directory.existsSync()) {
    return null;
  }
  final List<File> files = [
    for (final entity in directory.listSync(followLinks: false))
      if (entity is File && entity.path.endsWith('.md')) entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
  final templates = <String, String>{};
  for (final file in files) {
    final String stem = file.uri.pathSegments.last.replaceAll(
      RegExp(r'\.md$'),
      '',
    );
    final String path = 'docs/$_blocksDirectory/$stem.md';
    if (!agentBlockNames.contains(stem)) {
      problems.add(
        '$path: not a block template the CLI knows '
        '(${agentBlockNames.join(', ')})',
      );
      continue;
    }
    final String source = file.readAsStringSync().replaceAll('\r\n', '\n');
    problems.addAll(checkBlockTemplate(path, source));
    templates[stem] = source;
  }
  for (final name in agentBlockNames.where((n) => !templates.containsKey(n))) {
    if (!files.any((file) => file.path.endsWith('/$name.md'))) {
      problems.add(
        'docs/$_blocksDirectory/$name.md: missing; the CLI needs '
        '${agentBlockNames.sublist(0, agentBlockNames.length - 1).join(', ')} '
        'and ${agentBlockNames.last}',
      );
    }
  }
  return templates;
}

/// The problems in the block template [source] found at [path].
///
/// A template is the managed block itself: it opens with [blockBegin] and
/// ends with [blockEnd], each appearing once. Inside it, `{{name}}` must be a
/// placeholder in [blockPlaceholders]; `{{#name}}`, `{{^name}}` and
/// `{{/name}}` are sections over [blockSections], alone on their line and
/// balanced. The templates go into a Dart raw string and into a Markdown
/// file whose house style bans the em-dash, so neither `'''` nor U+2014 may
/// appear.
List<String> checkBlockTemplate(String path, String source) {
  final problems = <String>[];
  final List<String> lines = source.split('\n');
  final String last = lines.lastWhere(
    (line) => line.trim().isNotEmpty,
    orElse: () => '',
  );
  if (lines.first != blockBegin || last != blockEnd) {
    return ['$path: must open with $blockBegin and end with $blockEnd'];
  }
  for (final marker in [blockBegin, blockEnd]) {
    if (lines.where((line) => line == marker).length != 1) {
      return ['$path: the markers must appear exactly once each'];
    }
  }
  final tag = RegExp(r'\{\{([#^/]?)\s*([^}]*?)\s*\}\}');
  final open = <({String written, String name, int line})>[];
  for (var index = 0; index < lines.length; index += 1) {
    final String line = lines[index];
    final int number = index + 1;
    if (line.contains('\u2014')) {
      problems.add('$path:$number: no em-dashes in the templates');
    }
    if (line.contains("'''")) {
      problems.add(
        '$path:$number: a triple quote cannot go in the generated Dart string',
      );
    }
    for (final match in tag.allMatches(line)) {
      final String kind = match[1]!;
      final String name = match[2]!;
      final String written = match[0]!;
      if (kind.isEmpty) {
        if (!blockPlaceholders.contains(name)) {
          problems.add('$path:$number: unknown placeholder $written');
        }
        continue;
      }
      if (!blockSections.contains(name)) {
        problems.add('$path:$number: unknown section $written');
        continue;
      }
      if (line.trim() != written) {
        problems.add('$path:$number: a section tag must be alone on its line');
      }
      if (kind != '/') {
        open.add((written: written, name: name, line: number));
        continue;
      }
      final int position = open.lastIndexWhere((entry) => entry.name == name);
      if (position == -1) {
        problems.add('$path:$number: $written closes nothing');
        continue;
      }
      if (position != open.length - 1) {
        problems.add(
          '$path:$number: $written closes the section '
          '${open.last.written}',
        );
      }
      open.removeRange(position, open.length);
    }
  }
  for (final entry in open) {
    problems.add(
      '$path:${entry.line}: the section ${entry.written} is never closed',
    );
  }
  return problems;
}

/// `block_templates.g.dart`: one raw-string constant per template.
String _blockTemplatesDart(Map<String, String> blocks) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln(
      '// Source: docs/$_blocksDirectory/*.md. Regenerate: melos run agent-docs.',
    )
    ..writeln()
    ..writeln('/// The block templates compiled into the CLI.')
    ..writeln('///')
    ..writeln(
      '/// `beak agents` renders the templates that ship in the project\'s',
    )
    ..writeln(
      '/// docs bundle, so its rules match the Beak version the project',
    )
    ..writeln('/// resolved. These are what it renders when there is no bundle')
    ..writeln('/// yet, and each is byte-equal to its file in the repository.')
    ..writeln('library;');
  for (final name in agentBlockNames) {
    final String? source = blocks[name];
    if (source == null) {
      continue;
    }
    buffer
      ..writeln()
      ..writeln('/// The `$name` block template.')
      ..writeln("const String ${_blockConstantOf(name)} = r'''")
      ..write(source)
      ..writeln("''';");
  }
  return buffer.toString();
}

/// `serverpod-admin` -> `beakServerpodAdminBlockTemplate`.
String _blockConstantOf(String name) {
  final String pascal = name
      .split('-')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join();
  return 'beak${pascal}BlockTemplate';
}

/// The scalar at top-level [key] of the YAML file [yaml], or `null`.
String? _stringAt(String yaml, String key) {
  final String? block = topLevelBlock(yaml, key);
  if (block == null) {
    return null;
  }
  final Object? node = loadYaml(block);
  final Object? value = node is YamlMap ? node[key] : null;
  return value is String ? value : null;
}

/// The nav tree of `mkdocs.yml`, empty when it has none.
List<NavNode> _navOf(String mkdocs) {
  final String? block = topLevelBlock(mkdocs, 'nav');
  return block == null ? const [] : parseNav(block);
}

/// Every published page under `docs/`, keyed by its path relative to `docs/`.
Map<String, String> _publishedPages(Directory root) {
  final docs = Directory('${root.path}/docs');
  final pages = <String, String>{};
  if (!docs.existsSync()) {
    return pages;
  }
  final List<File> files = [
    for (final entity in docs.listSync(recursive: true, followLinks: false))
      if (entity is File && entity.path.endsWith('.md')) entity,
  ];
  for (final file in files) {
    final String relative = file.path
        .substring(docs.path.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    if (relative.split('/').any(unpublishedDirs.contains)) {
      continue;
    }
    pages[relative] = file.readAsStringSync().replaceAll('\r\n', '\n');
  }
  return Map.fromEntries(
    pages.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

/// The page at [docPath] as plain Markdown for a file that sits in
/// [outputDirectory], or `null` (after recording why in [problems]).
String? _convertPage({
  required String docPath,
  required String content,
  required String outputDirectory,
  required SnippetReader readFile,
  required DocsLinkRewriter links,
  required List<String> problems,
}) {
  final String path = 'docs/$docPath';
  final FrontMatter? front = parseFrontMatter(content);
  final String? title = front?.title?.trim();
  final String? description = front?.description
      ?.replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (front == null || front.error != null) {
    problems.add(
      '$path: ${front?.error ?? 'no front matter (needs title and '
              'description)'}',
    );
    return null;
  }
  if (title == null ||
      title.isEmpty ||
      description == null ||
      description.isEmpty) {
    problems.add('$path: front matter needs a title and a description');
    return null;
  }

  final List<String> lines = content.split('\n');
  final int bodyStart = lines.indexOf('---', 1) + 1;
  final List<String> expanded;
  try {
    expanded = expandSnippets(lines.sublist(bodyStart), readFile: readFile);
  } on SnippetException catch (exception) {
    problems.add(
      '$path:${bodyStart + exception.line + 1}: ${exception.message}',
    );
    return null;
  }

  final List<String> stripped = stripSiteMarkup(expanded);
  final Set<int> fenced = fencedLineIndices(stripped);
  final linked = <String>[];
  for (var index = 0; index < stripped.length; index += 1) {
    final String line = stripped[index];
    if (fenced.contains(index) || fenceMarker.hasMatch(line)) {
      linked.add(line);
      continue;
    }
    try {
      linked.add(
        links.rewrite(
          line,
          pagePath: docPath,
          outputDirectory: outputDirectory,
        ),
      );
    } on FormatException catch (exception) {
      problems.add('$path: ${exception.message}');
      linked.add(line);
    }
  }

  final List<String> titled = _withDescription(linked, title, description);
  final String body = convertContainers(titled).join('\n').trim();
  return '$body\n';
}

/// [lines] with `> [description]` under the H1, adding the H1 from [title]
/// when the page has none.
List<String> _withDescription(
  List<String> lines,
  String title,
  String description,
) {
  final Set<int> fenced = fencedLineIndices(lines);
  final int heading = lines.indexWhere(
    (line) => RegExp(r'^# \S').hasMatch(line),
  );
  final bool found = heading != -1 && !fenced.contains(heading);
  final List<String> before = found ? lines.sublist(0, heading) : const [];
  final List<String> after = found ? lines.sublist(heading + 1) : lines;
  final int next = after.indexWhere((line) => line.trim().isNotEmpty);
  return [
    ...before,
    found ? lines[heading] : '# $title',
    '',
    '> $description',
    '',
    ...(next == -1 ? const <String>[] : after.sublist(next)),
  ];
}

/// The router page: the AI index as written, once it is more than a draft.
///
/// While `docs/ai/index.md` is still a `status: draft` stub the bundle's
/// index only points at it, so an agent is never sent to an empty router.
String? _aiIndex(
  Map<String, String> sources,
  String version, {
  required SnippetReader readFile,
  required DocsLinkRewriter links,
  required List<String> problems,
}) {
  final String? source = sources[_indexSource];
  if (source == null) {
    problems.add('docs/$_indexSource: not found; the bundle needs its index');
    return null;
  }
  if (parseFrontMatter(source)?.status != 'draft') {
    return _convertPage(
      docPath: _indexSource,
      content: source,
      outputDirectory: '',
      readFile: readFile,
      links: links,
      problems: problems,
    );
  }
  return '# Index for AI agents\n'
      '\n'
      '> Beak $version. The routing page is still a draft; start from the AI '
      'directory.\n'
      '\n'
      'Read [the AI directory](ai/index.md), then find pages in '
      '[SUMMARY.md](SUMMARY.md) or [llms.txt](llms.txt). Read files by path.\n';
}

/// The nav as a nested list of links, in nav order.
String _summary(
  List<NavNode> nav,
  Map<String, SitePage> site,
  List<String> problems,
) {
  final buffer = StringBuffer('# Summary\n\n');
  final listed = <String>{};

  String link(String label, String path) => '[$label]($path)';

  void write(NavNode node, int depth) {
    final String indent = '  ' * depth;
    switch (node) {
      case NavPage(:final label, :final path):
        final SitePage? page = site[path];
        if (path.contains('://')) {
          buffer.writeln('$indent- ${link(label ?? path, path)}');
          return;
        }
        if (page == null) {
          problems.add(
            'mkdocs.yml: the nav lists "$path", which is not a page',
          );
          return;
        }
        listed.add(path);
        buffer.writeln('$indent- ${link(label ?? page.title ?? path, path)}');
      case NavSection(:final label, :final children):
        final NavNode? first = children.isEmpty ? null : children.first;
        final bool opensOnIndex =
            first is NavPage &&
            first.label == null &&
            first.path.split('/').last == 'index.md' &&
            site.containsKey(first.path);
        if (opensOnIndex) {
          listed.add(first.path);
          buffer.writeln('$indent- ${link(label!, first.path)}');
        } else {
          buffer.writeln('$indent- $label');
        }
        for (final child in children.skip(opensOnIndex ? 1 : 0)) {
          write(child, depth + 1);
        }
    }
  }

  for (final node in nav) {
    write(node, 0);
  }
  for (final path in site.keys.where((path) => !listed.contains(path))) {
    problems.add('docs/$path: is not in the mkdocs nav');
  }
  return buffer.toString();
}

/// The llmstxt.org index of the bundle: an H1, a summary, then one list of
/// links per section, `Optional` last.
///
/// Sections and their globs come from the `llmstxt` plugin of `mkdocs.yml`,
/// so the bundle and the published `/llms.txt` list the same pages. Within a
/// glob, pages are in nav order. A page appears once, under the first
/// section that lists it.
String _llmsTxt(
  String mkdocs,
  List<NavNode> nav,
  Map<String, SitePage> site,
  String siteName,
  List<String> problems,
) {
  final String? pluginsBlock = topLevelBlock(mkdocs, 'plugins');
  final _LlmsConfig? config = pluginsBlock == null
      ? null
      : _parseLlmsConfig(pluginsBlock);
  if (config == null) {
    problems.add('mkdocs.yml: no llmstxt plugin with sections');
    return '';
  }
  final order = <String, int>{};
  void collect(List<NavNode> nodes) {
    for (final node in nodes) {
      switch (node) {
        case NavPage(:final path):
          order.putIfAbsent(path, () => order.length);
        case NavSection(:final children):
          collect(children);
      }
    }
  }

  collect(nav);
  int byNav(String a, String b) {
    final int position = (order[a] ?? order.length).compareTo(
      order[b] ?? order.length,
    );
    return position != 0 ? position : a.compareTo(b);
  }

  final buffer = StringBuffer('# $siteName\n\n> ${config.description}\n');
  final listed = <String>{};
  final sections = [
    ...config.sections.where((section) => section.title != 'Optional'),
    ...config.sections.where((section) => section.title == 'Optional'),
  ];
  for (final section in sections) {
    final entries = <String>[];
    for (final entry in section.entries) {
      final RegExp glob = RegExp(
        '^${entry.glob.split('*').map(RegExp.escape).join('.*')}\$',
      );
      final List<String> matches = [
        for (final path in site.keys)
          if (glob.hasMatch(path) && !listed.contains(path)) path,
      ]..sort(byNav);
      for (final path in matches) {
        listed.add(path);
        final SitePage page = site[path]!;
        final String detail = _collapse(
          entry.description ?? page.front?.description ?? '',
        );
        entries.add(
          '- [${page.title ?? path}]($path)${detail.isEmpty ? '' : ': $detail'}',
        );
      }
    }
    if (entries.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## ${section.title}')
        ..writeln()
        ..writeAll(entries.map((entry) => '$entry\n'));
    }
  }
  return buffer.toString();
}

/// [text] on one line.
String _collapse(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// The `llmstxt` plugin's settings.
final class _LlmsConfig {
  const _LlmsConfig(this.description, this.sections);

  final String description;
  final List<_LlmsSection> sections;
}

/// One `sections:` entry of the `llmstxt` plugin.
final class _LlmsSection {
  const _LlmsSection(this.title, this.entries);

  final String title;
  final List<({String glob, String? description})> entries;
}

/// The `llmstxt` settings in the `plugins:` [block], or `null` without them.
_LlmsConfig? _parseLlmsConfig(String block) {
  final Object? root = loadYaml(block);
  final Object? plugins = root is YamlMap ? root['plugins'] : null;
  if (plugins is! YamlList) {
    return null;
  }
  for (final Object? plugin in plugins) {
    if (plugin is! YamlMap || !plugin.containsKey('llmstxt')) {
      continue;
    }
    final Object? config = plugin['llmstxt'];
    final Object? sections = config is YamlMap ? config['sections'] : null;
    if (config is! YamlMap || sections is! YamlMap) {
      return null;
    }
    final Object? description = config['markdown_description'];
    return _LlmsConfig(description is String ? _collapse(description) : '', [
      for (final section in sections.entries)
        _LlmsSection('${section.key}', _globsOf(section.value)),
    ]);
  }
  return null;
}

/// The globs, with the optional description override, in one section.
List<({String glob, String? description})> _globsOf(Object? entries) => [
  if (entries is YamlList)
    for (final Object? entry in entries)
      if (entry is String)
        (glob: entry, description: null)
      else if (entry is YamlMap && entry.length == 1)
        (glob: '${entry.keys.single}', description: '${entry.values.single}'),
];

/// `manifest.json`: the format, the Beak version, the page count and a sha256
/// per file, keys sorted and nothing time-dependent.
String _manifest(Map<String, String> files, String version, int pages) {
  final List<String> paths = files.keys.toList()..sort();
  const encoder = JsonEncoder.withIndent('  ');
  return '${encoder.convert({
    'format': agentDocsFormat,
    'beak': version,
    'index': agentDocsIndex,
    'pages': pages,
    'files': {for (final path in paths) path: sha256.convert(utf8.encode(files[path]!)).toString()},
  })}\n';
}

/// The problems in the corrections table of the AI index page [content].
///
/// The table is the one whose header row has a column headed for the Beak
/// version, "Beak 0.9 does" for [version] `0.9.x`. A page with no such table
/// is a problem, not a pass: a check that finds nothing to check when the
/// heading is renamed has stopped checking. A column headed for another
/// version is a problem that names the heading to write.
///
/// Every backticked identifier in that column (a name on its own, or a call
/// such as `withRelations([...])`) must appear in the source of some
/// `packages/*/lib`. It may be a name Beak uses rather than declares, such as
/// Flutter's `runApp` or an obers_ui widget.
///
/// A row whose left cell says `(removed)` names symbols that are gone, and
/// those must be declared in none of the Beak packages ([publicNamesIn]). The
/// stricter test is what makes a removal provable: a doc comment, a message
/// string, a local variable or a private helper keeps the word in the source
/// long after the API is gone, and a vendored `worm*` package declaring the
/// same word says nothing about Beak's API. Paths, commands and dotted chains
/// such as `ProductModel.name` are not identifiers here: generated code and
/// other projects' APIs are not in `packages/`.
///
/// [libraryIdentifiers] is every word of the Beak sources, and
/// [declaredNames] the public names the Beak packages declare (it defaults to
/// [libraryIdentifiers]). Each is called at most once, and only when there is
/// something to look up.
List<String> checkCorrectionsTable(
  String content, {
  required String version,
  required Set<String> Function() libraryIdentifiers,
  Set<String> Function()? declaredNames,
}) {
  final String? heading = correctionsHeading(version);
  final List<String> lines = content.split('\n');
  final Set<int> fenced = fencedLineIndices(lines);
  final expected = <({String name, int line})>[];
  final removed = <({String name, int line})>[];
  var found = false;
  for (var header = 0; header < lines.length - 1 && !found; header += 1) {
    final List<String>? cells = fenced.contains(header)
        ? null
        : _tableCells(lines[header]);
    final int column =
        cells?.indexWhere(
          (cell) => _correctionsColumn.hasMatch(
            cell.replaceAll(RegExp(r'[*`_]'), '').trim(),
          ),
        ) ??
        -1;
    final List<String>? divider = _tableCells(lines[header + 1]);
    if (column == -1 ||
        divider == null ||
        !divider.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell))) {
      continue;
    }
    found = true;
    final String written = cells![column]
        .replaceAll(RegExp(r'[*`_]'), '')
        .trim();
    if (heading != null && written != heading) {
      return [
        'docs/$_indexSource:${header + 1}: the corrections table column is '
            'headed "$written", but this is Beak $version. Rename it '
            '"$heading".',
      ];
    }
    for (var row = header + 2; row < lines.length; row += 1) {
      final List<String>? rowCells = _tableCells(lines[row]);
      if (rowCells == null) {
        break;
      }
      expected.addAll([
        for (final name in _identifiersIn(
          rowCells.length > column ? rowCells[column] : '',
        ))
          (name: name, line: row + 1),
      ]);
      if (rowCells.first.contains('(removed)')) {
        removed.addAll([
          for (final name in _identifiersIn(rowCells.first))
            (name: name, line: row + 1),
        ]);
      }
    }
  }
  if (!found) {
    return [
      'docs/$_indexSource needs the corrections table: a Markdown table with a '
          'column headed "${heading ?? 'Beak <version> does'}", one row per '
          'habit an agent gets wrong, symbols in backticks',
    ];
  }
  if (expected.isEmpty && removed.isEmpty) {
    return const [];
  }
  final Set<String> known = libraryIdentifiers();
  final Set<String> declared = removed.isEmpty
      ? const {}
      : (declaredNames ?? libraryIdentifiers)();
  return [
    for (final symbol in expected)
      if (!known.contains(symbol.name))
        'docs/$_indexSource:${symbol.line}: the corrections table names '
            '`${symbol.name}`, which no packages/*/lib source contains',
    for (final symbol in removed)
      if (declared.contains(symbol.name))
        'docs/$_indexSource:${symbol.line}: the corrections table marks '
            '`${symbol.name}` as removed, but packages/*/lib still declares it',
  ];
}

/// The cells of a Markdown table row, or `null` for a line that is not one.
///
/// A `|` inside a code span or written `\|` belongs to the cell.
List<String>? _tableCells(String line) {
  final String row = line.trim();
  if (!row.startsWith('|')) {
    return null;
  }
  final cells = <String>[];
  final cell = StringBuffer();
  var inCode = false;
  for (var index = 1; index < row.length; index += 1) {
    final String char = row[index];
    if (char == r'\' && index + 1 < row.length && row[index + 1] == '|') {
      cell.write('|');
      index += 1;
      continue;
    }
    if (char == '`') {
      inCode = !inCode;
    }
    if (char == '|' && !inCode) {
      cells.add(cell.toString().trim());
      cell.clear();
      continue;
    }
    cell.write(char);
  }
  if (cell.toString().trim().isNotEmpty) {
    cells.add(cell.toString().trim());
  }
  return cells;
}

/// The Dart identifiers named by the code spans of [cell].
///
/// A span counts when it is one identifier, optionally called:
/// `BeakFormScreen`, `withRelations([...])`.
List<String> _identifiersIn(String cell) => [
  for (final span in RegExp('`([^`]+)`').allMatches(cell))
    ?RegExp(r'^([A-Za-z_]\w*)(?:\(.*\))?$').firstMatch(span[1]!.trim())?[1],
];

/// What the Dart source of `packages/*/lib` says, read once on first use
/// because most builds never look anything up.
final class _LibraryNames {
  _LibraryNames(this._root);

  final Directory _root;

  late final ({Set<String> words, Set<String> declared}) _sets = _read();

  /// Every word of every package, so a name Beak uses but does not declare
  /// (`runApp`, an obers_ui widget) still counts as present.
  Set<String> get words => _sets.words;

  /// The public names the Beak packages declare: everything but the vendored
  /// `worm` packages, whose API is not Beak's.
  Set<String> get declaredByBeak => _sets.declared;

  ({Set<String> words, Set<String> declared}) _read() {
    final words = <String>{};
    final declared = <String>{};
    final packages = Directory('${_root.path}/packages');
    if (!packages.existsSync()) {
      return (words: words, declared: declared);
    }
    final word = RegExp(r'[A-Za-z_$][\w$]*');
    for (final package in packages.listSync(followLinks: false)) {
      final lib = Directory('${package.path}/lib');
      if (!lib.existsSync()) {
        continue;
      }
      final String name = package.uri.pathSegments.lastWhere(
        (segment) => segment.isNotEmpty,
      );
      final bool vendored = name == 'worm' || name.startsWith('worm_');
      for (final file in lib.listSync(recursive: true, followLinks: false)) {
        if (file is! File || !file.path.endsWith('.dart')) {
          continue;
        }
        final String source = utf8.decode(
          file.readAsBytesSync(),
          allowMalformed: true,
        );
        words.addAll(word.allMatches(source).map((match) => match[0]!));
        if (!vendored) {
          declared.addAll(publicNamesIn(source));
        }
      }
    }
    return (words: words, declared: declared);
  }
}

/// The files of the bundle on disk, keyed by path relative to it.
Map<String, List<int>> _readBundle(Directory bundle) {
  final files = <String, List<int>>{};
  if (!bundle.existsSync()) {
    return files;
  }
  for (final entity in bundle.listSync(recursive: true, followLinks: false)) {
    if (entity is File) {
      final String relative = entity.path
          .substring(bundle.path.length + 1)
          .replaceAll(Platform.pathSeparator, '/');
      files[relative] = entity.readAsBytesSync();
    }
  }
  return files;
}

/// Whether [a] and [b] hold the same bytes.
bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}

/// Builds the bundle for the repository at [root] and writes it, or, with
/// [check], only compares it with what is on disk.
///
/// Returns the exit code: 0 on success, 1 when the build has problems or
/// `--check` found a difference. Only files inside the bundle directory are
/// ever written or deleted.
int runAgentDocs({
  required Directory root,
  required bool check,
  required StringSink out,
  required StringSink err,
}) {
  final AgentDocsBuild build = buildAgentDocs(root);
  if (build.problems.isNotEmpty) {
    err.writeln('Agent docs build failed:');
    for (final problem in build.problems) {
      err.writeln('  $problem');
    }
    return 1;
  }
  final bundle = Directory('${root.path}/$agentDocsDirectory');
  final Map<String, List<int>> onDisk = _readBundle(bundle);
  final stale = <String>[];
  final missing = <String>[];
  for (final file in build.files.entries) {
    final List<int>? existing = onDisk[file.key];
    if (existing == null) {
      missing.add(file.key);
    } else if (!_sameBytes(existing, utf8.encode(file.value))) {
      stale.add(file.key);
    }
  }
  final List<String> extra = [
    for (final path in onDisk.keys)
      if (!build.files.containsKey(path)) path,
  ]..sort();
  // Generated files outside the bundle: named by their repo-relative path.
  final staleCompanions = <String>[];
  final missingCompanions = <String>[];
  for (final companion in build.companions.entries) {
    final file = File('${root.path}/${companion.key}');
    if (!file.existsSync()) {
      missingCompanions.add(companion.key);
    } else if (!_sameBytes(
      file.readAsBytesSync(),
      utf8.encode(companion.value),
    )) {
      staleCompanions.add(companion.key);
    }
  }

  if (check) {
    for (final entry in {
      'stale': [
        for (final path in stale) '$agentDocsDirectory/$path',
        ...staleCompanions,
      ],
      'missing': [
        for (final path in missing) '$agentDocsDirectory/$path',
        ...missingCompanions,
      ],
      'extra': [for (final path in extra) '$agentDocsDirectory/$path'],
    }.entries) {
      for (final path in entry.value) {
        err.writeln('${entry.key}: $path');
      }
    }
    final bool clean =
        stale.isEmpty &&
        missing.isEmpty &&
        extra.isEmpty &&
        staleCompanions.isEmpty &&
        missingCompanions.isEmpty;
    if (!clean) {
      err.writeln(regenerateHint);
    }
    return clean ? 0 : 1;
  }

  for (final path in [...missing, ...stale]) {
    final file = File('${bundle.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(utf8.encode(build.files[path]!));
  }
  for (final path in extra) {
    File('${bundle.path}/$path').deleteSync();
  }
  _pruneEmptyDirectories(bundle);
  out.writeln(
    'Agent docs bundle: ${build.files.length} files, '
    '${missing.length + stale.length} written, ${extra.length} removed.',
  );
  for (final companion in build.companions.entries) {
    final bool changed =
        missingCompanions.contains(companion.key) ||
        staleCompanions.contains(companion.key);
    if (changed) {
      File('${root.path}/${companion.key}')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(utf8.encode(companion.value));
    }
    out.writeln(
      'Block templates: ${companion.key} ${changed ? 'written' : 'up to date'}.',
    );
  }
  return 0;
}

/// Deletes the empty directories under [bundle], leaving [bundle] itself.
void _pruneEmptyDirectories(Directory bundle) {
  if (!bundle.existsSync()) {
    return;
  }
  final List<Directory> directories = [
    for (final entity in bundle.listSync(recursive: true, followLinks: false))
      if (entity is Directory) entity,
  ]..sort((a, b) => b.path.length.compareTo(a.path.length));
  for (final directory in directories) {
    if (directory.listSync().isEmpty) {
      directory.deleteSync();
    }
  }
}

void main(List<String> args) {
  final Set<String> known = {'--check'};
  final List<String> unknown = args
      .where((arg) => !known.contains(arg))
      .toList();
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown arguments: ${unknown.join(' ')}');
    stderr.writeln('Usage: dart run tool/build_agent_docs.dart [--check]');
    exit(64);
  }
  if (!Directory('docs').existsSync()) {
    stderr.writeln('No docs/ directory; run this from the repo root.');
    exit(2);
  }
  exit(
    runAgentDocs(
      root: Directory.current,
      check: args.contains('--check'),
      out: stdout,
      err: stderr,
    ),
  );
}
