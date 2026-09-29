import 'beak_managed_block.dart';
import 'block_templates.g.dart';

/// A template `beak agents` cannot render.
///
/// It names an unknown placeholder or section, a placeholder this project has
/// no value for, or a section left open. The templates ship in the docs
/// bundle, so a bundle newer than the CLI can ask for something it does not
/// know; the caller falls back to the templates compiled into the CLI.
final class BeakTemplateException implements Exception {
  /// Creates an exception described by [message].
  const BeakTemplateException(this.message);

  /// What is wrong with the template.
  final String message;

  @override
  String toString() => 'block template: $message';
}

/// The kind of project a managed block is written for.
enum BeakBlockKind {
  /// A `beak create` app, on Beak's own server.
  standalone('standalone'),

  /// An existing Flutter app with Beak added beside its own code.
  embedded('embedded'),

  /// A Beak admin panel over a Serverpod server.
  serverpodAdmin('serverpod-admin'),

  /// The pointer written to a workspace root's `AGENTS.md`.
  workspaceRoot('workspace-root');

  const BeakBlockKind(this.templateName);

  /// The template's file stem in `docs/_agents/blocks` and in the bundle.
  final String templateName;

  /// The template compiled into the CLI, for a project with no bundle.
  String get fallbackTemplate => switch (this) {
    standalone => beakStandaloneBlockTemplate,
    embedded => beakEmbeddedBlockTemplate,
    serverpodAdmin => beakServerpodAdminBlockTemplate,
    workspaceRoot => beakWorkspaceRootBlockTemplate,
  };
}

/// The values a block template is filled with.
///
/// Only [version], [docsIndex] and [skills] are always known. A template that
/// uses a placeholder whose value is `null` cannot be rendered for this
/// project, which [renderBlock] reports rather than printing a hole.
final class BeakBlockValues {
  /// Creates the values for one project.
  const BeakBlockValues({
    required this.version,
    required this.docsIndex,
    required this.skills,
    this.schemaGlob,
    this.panelEntry,
    this.adminDir,
    this.serverPkg,
    this.clientPkg,
    this.schemaPkg,
    this.mainIsGenerated = false,
  });

  /// The Beak version, from the docs bundle.
  final String version;

  /// The path from the `AGENTS.md` to the bundle's `ai-index.md`.
  final String docsIndex;

  /// The installed workflow skills, or the line that says how to get them.
  final String skills;

  /// Where the schema classes are, as a glob.
  final String? schemaGlob;

  /// The file that boots the panel.
  final String? panelEntry;

  /// The Beak package's path from the workspace root.
  final String? adminDir;

  /// The Serverpod server package.
  final String? serverPkg;

  /// The generated Serverpod client package.
  final String? clientPkg;

  /// The package holding the Beak schema classes that mirror the server's
  /// models.
  final String? schemaPkg;

  /// Whether `lib/main.dart` is Beak's own generated file.
  final bool mainIsGenerated;

  /// Whether the project sits on a Serverpod server.
  bool get isServerpod => serverPkg != null;

  String? _valueOf(String placeholder) => switch (placeholder) {
    'version' => version,
    'docsIndex' => docsIndex,
    'skills' => skills,
    'schemaGlob' => schemaGlob,
    'panelEntry' => panelEntry,
    'adminDir' => adminDir,
    'serverPkg' => serverPkg,
    'clientPkg' => clientPkg,
    'schemaPkg' => schemaPkg,
    _ => throw BeakTemplateException('unknown placeholder {{$placeholder}}'),
  };

  bool _holds(String section) => switch (section) {
    'mainIsGenerated' => mainIsGenerated,
    'serverpod' => isServerpod,
    _ => throw BeakTemplateException('unknown section {{#$section}}'),
  };
}

/// [template] filled with [values], from the BEGIN marker to the END marker.
///
/// `{{name}}` is replaced by the value of that name. A line holding only
/// `{{#name}}` or `{{^name}}` opens a section that is kept when the named
/// flag holds (or does not, for `^`), and one holding only `{{/name}}`
/// closes it; the tag lines themselves are dropped. Line breaks in the
/// result are LF and there is no final newline.
///
/// Throws a [BeakTemplateException] for anything it cannot fill.
String renderBlock(String template, BeakBlockValues values) {
  final List<String> lines = template.replaceAll('\r\n', '\n').split('\n');
  if (lines.first != BeakManagedBlock.begin ||
      !lines.any((line) => line == BeakManagedBlock.end)) {
    throw const BeakTemplateException(
      'a template runs from the BEGIN marker to the END marker',
    );
  }
  final sections = <({String name, bool keeps})>[];
  final kept = <String>[];
  final tag = RegExp(r'^\{\{([#^/])(\w+)\}\}$');
  final placeholder = RegExp(r'\{\{(\w+)\}\}');
  for (final line in lines) {
    if (tag.firstMatch(line) case final match?) {
      final String name = match[2]!;
      switch (match[1]) {
        case '/':
          if (sections.isEmpty || sections.last.name != name) {
            throw BeakTemplateException('{{/$name}} closes nothing');
          }
          sections.removeLast();
        case final String kind:
          final bool holds = values._holds(name) == (kind == '#');
          sections.add((name: name, keeps: holds));
      }
      continue;
    }
    if (sections.every((section) => section.keeps)) {
      kept.add(
        line.replaceAllMapped(placeholder, (match) {
          final String name = match[1]!;
          return values._valueOf(name) ??
              (throw BeakTemplateException(
                'no value for {{$name}} in this project',
              ));
        }),
      );
    }
  }
  if (sections.isNotEmpty) {
    throw BeakTemplateException(
      'the section {{#${sections.last.name}}} is never closed',
    );
  }
  final String block = kept.join('\n').trimRight();
  return block;
}
