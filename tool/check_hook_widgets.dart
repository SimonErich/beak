/// HookWidget-only guard (`melos run guard-hooks`).
///
/// Beak's widgets are `HookWidget`s: state lives in hooks and signals, never in
/// a `State` object. This tool scans the `lib/` of every gated package (under
/// `packages/` and `examples/`, vendored `worm*` excluded) for a class that
/// extends `StatefulWidget`, `State`, `StatefulHookWidget` or `HookState`, and
/// exits non-zero listing each one.
///
/// It reads tokens rather than lines, so a comment or a string that quotes the
/// rule, or a code generator that writes such a class, is not a violation, and
/// a declaration wrapped over several lines still is. Tests are not scanned.
///
/// Sibling of `tool/check_no_material.dart`, wired into `melos run analyze`
/// next to it.
library;

import 'dart:io';

import 'src/dart_tokens.dart';
import 'src/gated_dart_files.dart';

/// The base classes a Beak widget must not extend.
const Set<String> forbiddenWidgetBases = {
  'StatefulWidget',
  'StatefulHookWidget',
  'State',
  'HookState',
};

/// Each class in [dartSource] that extends a [forbiddenWidgetBases], as
/// `Name extends Base`, in source order.
List<String> statefulClassesIn(String dartSource) {
  final List<String> tokens = dartTokens(dartSource);
  final found = <String>[];
  for (var index = 0; index < tokens.length - 1; index += 1) {
    if (tokens[index] != 'class' || !isIdentifierStart(tokens[index + 1][0])) {
      continue;
    }
    final String name = tokens[index + 1];
    var angleDepth = 0;
    for (var next = index + 2; next < tokens.length; next += 1) {
      final String token = tokens[next];
      if (token == '{' || token == ';' || token == '=') {
        break;
      }
      if (token == '<') {
        angleDepth += 1;
      } else if (token == '>') {
        angleDepth -= 1;
      } else if (token == 'extends' && angleDepth == 0) {
        final String base = tokens[next + 1];
        if (forbiddenWidgetBases.contains(base)) {
          found.add('$name extends $base');
        }
        break;
      }
    }
  }
  return found;
}

/// One line per offending class in the gated `lib/` directories under
/// [repoRoot]: `path: Name extends Base`.
List<String> statefulViolations({String repoRoot = '.'}) => [
  for (final file in gatedDartFiles(repoRoot: repoRoot, subdirectory: 'lib'))
    for (final offender in statefulClassesIn(file.readAsStringSync()))
      '${file.path}: $offender',
];

void main() {
  final List<String> violations = statefulViolations()..sort();
  if (violations.isNotEmpty) {
    stderr.writeln(
      'Stateful widgets found (Beak widgets are HookWidgets; keep state in '
      'hooks and signals):',
    );
    violations.map((violation) => '  $violation').forEach(stderr.writeln);
    exitCode = 1;
    return;
  }
  stdout.writeln('Hook-widget guard passed (no StatefulWidget or State).');
}
