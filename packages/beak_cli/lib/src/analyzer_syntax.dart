/// The one file of `beak_cli` that imports `package:analyzer`.
///
/// Discovery, the schema reader and the authored-entrypoint reader parse Dart
/// without resolving it, and they read declarations the way the syntax tree
/// spells them today. The analyzer reshapes that tree between majors (a class
/// name moved from `ClassDeclaration.name` to `namePart.typeName`, the members
/// from `members` to `body.members`, named arguments from `NamedExpression` to
/// `NamedArgument`), so every spelling that has moved lives here, as a getter
/// the rest of the package calls. A new analyzer major then changes this file
/// and nothing else.
///
/// The syntax types are re-exported so no other file imports the analyzer.
library;

import 'package:analyzer/dart/analysis/utilities.dart' as analysis;
import 'package:analyzer/dart/ast/ast.dart';

export 'package:analyzer/dart/ast/ast.dart';
export 'package:analyzer/dart/ast/visitor.dart' show RecursiveAstVisitor;

/// Parses [content] into a syntax tree without resolving anything.
///
/// Syntax errors do not throw: a file that is half written still yields the
/// declarations before the mistake, which is what `beak doctor` needs to name
/// the problem instead of failing on it.
CompilationUnit parseDart(String content) =>
    analysis.parseString(content: content, throwIfDiagnostics: false).unit;

/// The declaration of a class, read the way beak_cli needs it.
extension BeakClassSyntax on ClassDeclaration {
  /// The name of the class.
  String get className => namePart.typeName.lexeme;

  /// Every member the class body declares, none for a body written `;`.
  NodeList<ClassMember> get classMembers => body.members;
}

/// The declaration of an enum, read the way beak_cli needs it.
extension BeakEnumSyntax on EnumDeclaration {
  /// The name of the enum.
  String get enumName => namePart.typeName.lexeme;

  /// The names of the enum's values, in declaration order.
  List<String> get valueNames => [
    for (final constant in body.constants) constant.name.lexeme,
  ];
}

/// One argument of a call or an annotation.
extension BeakArgumentSyntax on Argument {
  /// The name of a named argument, or `null` for a positional one.
  String? get argumentName => switch (this) {
    NamedArgument(:final name) => name.lexeme,
    _ => null,
  };
}

/// A parameter of a constructor.
extension BeakParameterSyntax on FormalParameter {
  /// The expression after `=` (or `:`) in the parameter list, if any.
  Expression? get defaultValue => defaultClause?.value;
}
