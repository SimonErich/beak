import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';
import 'beak_schema_test.dart' show categorySchema, readSchemas, schemaNamed;

/// The public instance members [className] declares in [relativePath] of
/// `beak_core`, read from source so a new member cannot go unnoticed.
Set<String> publicMembersOf(String relativePath, String className) {
  final file = File('../beak_core/lib/src/$relativePath');
  final unit = parseString(
    content: file.readAsStringSync(),
    throwIfDiagnostics: false,
  ).unit;
  final declaration = unit.declarations
      .whereType<ClassDeclaration>()
      .singleWhere((candidate) => candidate.name.lexeme == className);
  return {
    for (final member in declaration.members)
      if (member is MethodDeclaration &&
          !member.isStatic &&
          !member.isOperator &&
          !member.name.lexeme.startsWith('_'))
        member.name.lexeme,
    for (final member in declaration.members)
      if (member is FieldDeclaration && !member.isStatic)
        for (final variable in member.fields.variables)
          if (!variable.name.lexeme.startsWith('_')) variable.name.lexeme,
  };
}

const Set<String> objectMembers = {
  'hashCode',
  'runtimeType',
  'toString',
  'noSuchMethod',
};

void main() {
  group('reserved names', () {
    test(
      'cover every public member of BeakModel, so no alias redeclares one',
      () {
        final members = publicMembersOf('model/beak_model.dart', 'BeakModel');

        expect(members, contains('summary'), reason: 'the source was read');
        expect(
          members.difference(BeakReservedNames.model),
          isEmpty,
          reason:
              'BeakModel gained a member the generated model would redeclare '
              'as a static alias. Add it to BeakReservedNames.model.',
        );
        expect(objectMembers.difference(BeakReservedNames.model), isEmpty);
      },
    );

    test('cover every public member of a to-one relationship path', () {
      final members = {
        ...publicMembersOf('model/beak_field_ref.dart', 'BeakFieldRef'),
        ...publicMembersOf('model/beak_field_ref.dart', 'BeakToOneField'),
      };

      expect(members, contains('relationLoad'), reason: 'the source was read');
      expect(
        members.difference(BeakReservedNames.relation),
        isEmpty,
        reason:
            'BeakToOneField or BeakFieldRef gained a member the generated '
            'path class would redeclare. Add it to BeakReservedNames.relation.',
      );
      expect(objectMembers.difference(BeakReservedNames.relation), isEmpty);
    });
  });

  group('a field named after a BeakModel member', () {
    test('keeps its typed field and gets no static alias', () {
      final (schemas, issues) = readSchemas({
        'category.dart': categorySchema.replaceFirst(
          'late final String name;',
          'late final String name;\n  late final String? summary;\n'
              '  late final String? sumDecimal;',
        ),
      });
      expect(issues, isEmpty);

      final source = BeakSchemaEmitter.emit(
        schemaNamed(schemas, 'Category'),
        schemas,
      );

      expect(source, contains('BeakScalarField<String> get summary'));
      expect(source, isNot(contains('static final summary =')));
      expect(source, isNot(contains('static final sumDecimal =')));
    });

    test('is reported when it is named after the record view', () {
      final (_, issues) = readSchemas({
        'category.dart': categorySchema.replaceFirst(
          'late final String name;',
          'late final String name;\n  late final String? record;',
        ),
      });

      expect(issues, hasLength(1));
      expect(issues.single.path, 'lib/models/category.dart');
      expect(issues.single.message, contains('Category.record'));
      expect(issues.single.message, contains('Rename the field'));
      expect(issues.single.message, contains("columnName: 'record'"));
    });
  });
}
