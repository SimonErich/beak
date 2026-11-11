import 'definition_model.dart';
import 'generate_issue.dart';

const Set<String> _handlerMembers = {
  'create',
  'update',
  'delete',
  'derive',
  'scope',
  'writes',
};

/// Reports what a definition library needs for its generated part to
/// compile: its `part` directive, the write enum's import, one class per
/// library and command names the handler can declare.
void checkDefinitionLibraries(
  List<DefinitionClass> classes,
  String package,
  BeakIssueSink issues, {
  Set<String> enumNames = const {},
}) {
  final byLibrary = <String, String>{};
  for (final definition in classes) {
    final path = definition.path;
    if (byLibrary[definition.library] case final String other) {
      issues.add(
        path,
        '${definition.name} shares its library with $other; give each '
        'definition class its own file.',
      );
      continue;
    }
    byLibrary[definition.library] = definition.name;
    final part = 'package:$package/${definition.partPath}';
    if (!definition.parts.contains(part)) {
      issues.add(
        path,
        "add `part '$part';` so ${definition.name}'s generated model belongs "
        'to the library.',
      );
    }
    final usesEnums = definition.fields.any(
      (field) => enumNames.contains(field.typeName),
    );
    if ((definition.writes || usesEnums) &&
        !_importsSupport(definition, package)) {
      issues.add(
        path,
        "add `import 'package:$package/src/generated/"
        "definitions_support.dart';`: the generated part of "
        '${definition.name} names its enum or write binding.',
      );
    }
    for (final field in definition.fields) {
      if (field.name == 'record' || field.name == 'raw') {
        issues.add(
          path,
          '${definition.name}.${field.name} cannot be generated: the typed '
          'views use that name.',
        );
      }
    }
    for (final command in definition.commands) {
      if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(command) ||
          _handlerMembers.contains(command)) {
        issues.add(
          path,
          '${definition.name}: the command "$command" becomes a handler '
          'method, so it is a lowerCamelCase name other than '
          '${_handlerMembers.join(', ')}.',
        );
      }
    }
  }
}

bool _importsSupport(DefinitionClass definition, String package) =>
    definition.imports.any(
      (uri) =>
          uri.endsWith('generated/definitions_support.dart') ||
          uri == 'package:$package/$package.dart',
    );
