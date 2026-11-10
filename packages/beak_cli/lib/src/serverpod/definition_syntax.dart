import '../analyzer_syntax.dart';
import 'definition_model.dart';
import 'generate_issue.dart';

/// The annotation called [name] (`Resource`, `ServerpodModel.editable`).
Annotation? annotationOf(NodeList<Annotation> metadata, String name) {
  for (final annotation in metadata) {
    if (annotation.name.name == name) return annotation;
  }
  return null;
}

/// The named arguments of [annotation], by name.
Map<String, Expression> namedArguments(Annotation annotation) => {
  for (final argument in annotation.arguments?.arguments ?? <Argument>[])
    if (argument.argumentName case final String name)
      name: argument.argumentExpression,
};

/// The value of a string literal (adjacent literals joined), or `null`.
String? stringOf(Expression? expression) =>
    expression is StringLiteral ? expression.stringValue : null;

/// The strings of a list literal of string literals.
List<String> stringsOf(
  Expression? expression,
  String what,
  String path,
  BeakIssueSink issues,
) {
  if (expression == null) return const [];
  if (expression is ListLiteral) {
    final values = <String>[];
    for (final element in expression.elements) {
      if (element is SimpleStringLiteral) {
        values.add(element.value);
      } else {
        issues.add(path, '$what lists only string literals.');
      }
    }
    return values;
  }
  issues.add(path, '$what is a list literal of strings.');
  return const [];
}

/// The command names and their optional `@CommandInput` class names.
({List<String> names, Map<String, String> inputs}) commandsOf(
  Expression? expression,
  String what,
  String path,
  BeakIssueSink issues,
) {
  if (expression == null) return (names: const [], inputs: const {});
  if (expression is! ListLiteral) {
    issues.add(path, '$what is a list literal.');
    return (names: const [], inputs: const {});
  }
  final names = <String>[];
  final inputs = <String, String>{};
  for (final element in expression.elements) {
    if (element is SimpleStringLiteral) {
      names.add(element.value);
      continue;
    }
    if (element is MethodInvocation &&
        element.methodName.name == 'BeakCommand') {
      final arguments = element.argumentList.arguments;
      final name = arguments.where((a) => a.argumentName == null).firstOrNull;
      if (name is! SimpleStringLiteral) {
        issues.add(path, '$what needs a command name as its first argument.');
        continue;
      }
      names.add(name.value);
      for (final argument in arguments) {
        if (argument.argumentName != 'input') continue;
        final input = argument.argumentExpression.toSource();
        if (!RegExp(r'^[A-Z]\w*$').hasMatch(input)) {
          issues.add(path, '$what input must be a command input class.');
        } else {
          inputs[name.value] = input;
        }
      }
      continue;
    }
    issues.add(path, '$what lists only BeakCommand values.');
  }
  return (names: names, inputs: inputs);
}

/// A `{'operation': ['role', ...]}` literal.
Map<String, List<String>> rolesOf(
  Expression? expression,
  String what,
  String path,
  BeakIssueSink issues,
) {
  if (expression == null) return const {};
  if (expression is! SetOrMapLiteral) {
    issues.add(path, '$what is a map literal of role lists.');
    return const {};
  }
  final roles = <String, List<String>>{};
  for (final element in expression.elements) {
    if (element case MapLiteralEntry(
      key: SimpleStringLiteral(value: final key),
      :final value,
    )) {
      if (!const {
        'read',
        'write',
        'create',
        'update',
        'delete',
      }.contains(key)) {
        issues.add(path, '$what names "$key", which is not an operation.');
        continue;
      }
      roles[key] = stringsOf(value, '$what.$key', path, issues);
    } else {
      issues.add(path, '$what is a map literal of role lists.');
    }
  }
  return roles;
}

/// A literal's value, for a default: a string, number, bool or `null`.
(Object?,)? literalOf(Expression expression) => switch (expression) {
  SimpleStringLiteral(:final value) => (value,),
  IntegerLiteral(:final value) => (value,),
  DoubleLiteral(:final value) => (value,),
  BooleanLiteral(:final value) => (value,),
  NullLiteral() => (null,),
  PrefixExpression(:final operator, operand: IntegerLiteral(:final value))
      when operator.lexeme == '-' =>
    (-(value ?? 0),),
  _ => null,
};

/// Whether [declaration] has a `static get [name]`.
bool declaresStaticGetter(ClassDeclaration declaration, String name) =>
    declaration.classMembers.whereType<MethodDeclaration>().any(
      (member) =>
          member.isStatic && member.isGetter && member.name.lexeme == name,
    );

/// The doc comment of [node] without the `///` markers.
String? docCommentOf(AnnotatedNode node) {
  final comment = node.documentationComment;
  if (comment == null) return null;
  return [
    for (final token in comment.tokens)
      token.lexeme.replaceFirst(RegExp(r'^///\s?'), ''),
  ].join('\n');
}

/// Reads one declared field of a definition class.
DefinitionField? readDefinitionField(
  String name,
  NamedType type,
  FieldDeclaration member,
  String what,
  String path,
  BeakIssueSink issues,
) {
  final metadata = member.metadata;
  final typeName = '${type.name.lexeme}${type.typeArguments?.toSource() ?? ''}';
  DefinitionRelation? relation;
  for (final (annotation, kind) in [
    ('BelongsTo', DefinitionRelationKind.belongsTo),
    ('HasOne', DefinitionRelationKind.hasOne),
    ('HasMany', DefinitionRelationKind.hasMany),
  ]) {
    final found = annotationOf(metadata, annotation);
    if (found == null) continue;
    final args = namedArguments(found);
    final element = type.typeArguments?.arguments.firstOrNull;
    relation = DefinitionRelation(
      kind: kind,
      target: kind == DefinitionRelationKind.hasMany && element is NamedType
          ? element.name.lexeme
          : type.name.lexeme,
      owned: args['owned']?.toSource() == 'true',
      label: stringOf(args['label']),
    );
  }
  if (annotationOf(metadata, 'BelongsToMany') != null) {
    issues.add(
      path,
      '$what: a many-to-many relationship is a Serverpod pivot model; expose '
      'the pivot class with its two @BelongsTo fields instead.',
    );
    return null;
  }
  final column = annotationOf(metadata, 'Column');
  final columnArgs = column == null
      ? const <String, Expression>{}
      : namedArguments(column);
  final hidden = annotationOf(metadata, 'Hidden');
  Object? hiddenDefault;
  if (hidden != null) {
    if (namedArguments(hidden)['defaultValue'] case final Expression value) {
      final literal = literalOf(value);
      if (literal == null) {
        issues.add(path, '$what: @Hidden(defaultValue:) takes a literal.');
      } else {
        hiddenDefault = literal.$1;
      }
    }
  }
  for (final key in const ['columnName', 'indexed', 'unique']) {
    if (columnArgs.containsKey(key)) {
      issues.add(path, '$what: @Column($key:) is Serverpod\'s to decide.');
    }
  }
  return DefinitionField(
    name: name,
    typeName: typeName,
    nullable: type.question != null,
    display: annotationOf(metadata, 'Display') != null,
    readOnly: annotationOf(metadata, 'ReadOnly') != null,
    hidden: hidden != null,
    hiddenDefault: hiddenDefault,
    columnArguments: {
      for (final entry in columnArgs.entries)
        if (entry.key != 'label') entry.key: entry.value.toSource(),
    },
    label: stringOf(columnArgs['label']),
    relation: relation,
    docComment: docCommentOf(member),
  );
}
