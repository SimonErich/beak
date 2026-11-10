import 'dart:io';

import 'package:path/path.dart' as p;

import '../analyzer_syntax.dart';
import 'definition_model.dart';
import 'definition_syntax.dart';
import 'generate_issue.dart';

/// Reads every `@Resource` class under [package]`/lib`, in path order.
///
/// The classes are the admin's allowlist: a Serverpod field the class does
/// not declare is never read or written. Files `beak generate` writes (parts
/// and `lib/src/generated/`) are skipped. [reportAs] is the package as
/// issues name it, relative to `beak.yaml`.
List<DefinitionClass> readDefinitions(
  Directory package,
  String reportAs,
  BeakIssueSink issues,
) {
  final lib = Directory(p.join(package.path, 'lib'));
  if (!lib.existsSync()) {
    issues.add(reportAs, 'the definitions package has no lib/ folder.');
    return const [];
  }
  final generated = p.join(lib.path, 'src', 'generated');
  final files = [
    for (final entity in lib.listSync(recursive: true))
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.endsWith('.beak.dart') &&
          !p.isWithin(generated, entity.path))
        entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
  final classes = <DefinitionClass>[];
  for (final file in files) {
    final library = p.posix.joinAll(
      p.split(p.relative(file.path, from: lib.path)),
    );
    final unit = parseDart(file.readAsStringSync());
    final imports = [
      for (final directive in unit.directives)
        if (directive is ImportDirective)
          if (directive.uri.stringValue case final String uri) uri,
    ];
    final parts = [
      for (final directive in unit.directives)
        if (directive is PartDirective)
          if (directive.uri.stringValue case final String uri) uri,
    ];
    for (final declaration in unit.declarations) {
      if (declaration is! ClassDeclaration) continue;
      if (annotationOf(declaration.metadata, 'Resource') == null) continue;
      final read = _readClass(
        declaration,
        library: library,
        path: '$reportAs/lib/$library',
        imports: imports,
        parts: parts,
        issues: issues,
      );
      if (read != null) classes.add(read);
    }
  }
  return classes;
}

DefinitionClass? _readClass(
  ClassDeclaration declaration, {
  required String library,
  required String path,
  required List<String> imports,
  required List<String> parts,
  required BeakIssueSink issues,
}) {
  final name = declaration.className;
  final model =
      annotationOf(declaration.metadata, 'ServerpodModel') ??
      annotationOf(declaration.metadata, 'ServerpodModel.editable');
  final input = annotationOf(declaration.metadata, 'CommandInput');
  if (model == null && input == null) {
    issues.add(
      path,
      '$name is a @Resource without @ServerpodModel or @CommandInput. Add '
      '@ServerpodModel() to expose the Serverpod model $name (read only), or '
      '@CommandInput() for a command input.',
    );
    return null;
  }
  final editable = model?.name.name == 'ServerpodModel.editable';
  final args = model == null
      ? const <String, Expression>{}
      : namedArguments(model);
  DefinitionHandling handling(String key, DefinitionHandling fallback) {
    final source = args[key];
    if (source == null) return editable ? DefinitionHandling.stock : fallback;
    final value = source.toSource().split('.').last;
    for (final candidate in DefinitionHandling.values) {
      if (candidate.name == value) return candidate;
    }
    issues.add(path, '$name.$key is "$value", not a BeakHandling value.');
    return fallback;
  }

  final list = handling('list', DefinitionHandling.stock);
  if (list == DefinitionHandling.off || list == DefinitionHandling.derived) {
    issues.add(
      path,
      '$name: list is stock or custom (a custom list narrows the rows).',
    );
  }
  if (handling('delete', DefinitionHandling.off) ==
      DefinitionHandling.derived) {
    issues.add(path, '$name: a delete has no values to derive; use custom.');
  }
  final resource = namedArguments(
    annotationOf(declaration.metadata, 'Resource')!,
  );
  final commands = commandsOf(args['commands'], '$name.commands', path, issues);
  final fields = <DefinitionField>[];
  for (final member in declaration.classMembers) {
    if (member is! FieldDeclaration || member.isStatic) continue;
    final type = member.fields.type;
    if (type is! NamedType) {
      issues.add(path, '$name has a field without a declared type.');
      continue;
    }
    for (final variable in member.fields.variables) {
      final field = readDefinitionField(
        variable.name.lexeme,
        type,
        member,
        '$name.${variable.name.lexeme}',
        path,
        issues,
      );
      if (field != null) fields.add(field);
    }
  }
  return DefinitionClass(
    name: name,
    library: library,
    path: path,
    fields: fields,
    input: input != null,
    inputTable: input == null ? null : stringOf(namedArguments(input)['table']),
    area: stringOf(args['area']),
    list: list,
    create: handling('create', DefinitionHandling.off),
    update: handling('update', DefinitionHandling.off),
    delete: handling('delete', DefinitionHandling.off),
    commands: commands.names,
    commandInputs: commands.inputs,
    access: rolesOf(args['access'], '$name.access', path, issues),
    reason: stringOf(args['reason']),
    restoreKey: args['restoreKey'] == null
        ? null
        : stringsOf(args['restoreKey'], '$name.restoreKey', path, issues),
    labelKey: stringOf(resource['labelKey']),
    hasBehavior: declaresStaticGetter(declaration, 'behavior'),
    hasValidationRules: declaresStaticGetter(declaration, 'validationRules'),
    hasPermissions: declaresStaticGetter(declaration, 'permissions'),
    imports: imports,
    parts: parts,
    docComment: docCommentOf(declaration),
  );
}
