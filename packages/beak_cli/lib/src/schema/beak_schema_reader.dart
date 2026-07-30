import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../field_spec.dart';
import '../project/beak_discovery.dart';
import 'beak_schema_ir.dart';

/// Reads `@Resource` schema classes into the generator's IR.
///
/// Works on an *unresolved* parse, which is the whole reason generation stays
/// in the millisecond range. That is possible because everything the emitter
/// needs is written literally at the declaration site: the field's type name
/// is a token, its nullability is a `?`, and an annotation's arguments are
/// source text that can be re-emitted verbatim rather than evaluated. The one
/// thing that needs cross-file knowledge — which class a relationship points
/// at — is resolved by matching class names across the scanned set.
final class BeakSchemaReader {
  /// Creates a reader over [projectRoot].
  const BeakSchemaReader(this.projectRoot);

  /// The project directory holding `lib/`.
  final Directory projectRoot;

  /// Reads every schema class under `lib/models/`.
  ///
  /// Issues are returned rather than thrown, so `beak prepare` can report all
  /// of them at once instead of one per run.
  (List<BeakSchemaIr>, List<BeakDiscoveryIssue>) read() {
    final schemas = <BeakSchemaIr>[];
    final issues = <BeakDiscoveryIssue>[];
    // Enums declared anywhere under lib/models/. An unresolved parse cannot
    // tell `ProductStatus` from `Uri` by name alone, so collect the real
    // declarations and treat anything else as an error the author can fix.
    final enums = <String>{};
    final root = Directory(
      '${projectRoot.path}/lib/${BeakProjectScanner.modelsDir}',
    );
    if (!root.existsSync()) {
      return (schemas, issues);
    }

    final files =
        root
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where(
              (file) =>
                  file.path.endsWith('.dart') &&
                  !file.path.endsWith('.beak.dart') &&
                  !file.uri.pathSegments.last.startsWith('_'),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final units = <(String, CompilationUnit)>[];
    for (final file in files) {
      final unit = parseString(
        content: file.readAsStringSync(),
        throwIfDiagnostics: false,
      ).unit;
      units.add((_libRelative(file), unit));
      for (final declaration in unit.declarations) {
        if (declaration is EnumDeclaration) {
          enums.add(declaration.name.lexeme);
        }
      }
    }

    for (final (path, unit) in units) {
      for (final declaration in unit.declarations) {
        if (declaration is! ClassDeclaration) {
          continue;
        }
        final Annotation? resource = _annotation(
          declaration.metadata,
          'Resource',
        );
        if (resource == null) {
          continue;
        }
        final (schema, classIssues) = _readClass(
          declaration,
          resource,
          path,
          enums,
        );
        issues.addAll(classIssues);
        if (schema != null) {
          schemas.add(schema);
        }
      }
    }

    issues.addAll(_validateRelations(schemas));
    return (schemas, issues);
  }

  /// Reads one annotated class.
  (BeakSchemaIr?, List<BeakDiscoveryIssue>) _readClass(
    ClassDeclaration declaration,
    Annotation resource,
    String path,
    Set<String> enums,
  ) {
    final issues = <BeakDiscoveryIssue>[];
    final String className = declaration.name.lexeme;
    final Map<String, String> options = _namedArguments(resource);
    final columns = <BeakColumnIr>[];
    final relations = <BeakRelationIr>[];
    String? displayColumnKey;

    for (final member in declaration.members) {
      if (member is! FieldDeclaration || member.isStatic) {
        continue;
      }
      final TypeAnnotation? type = member.fields.type;
      if (type is! NamedType) {
        issues.add(
          BeakDiscoveryIssue(
            path: 'lib/$path',
            message:
                '$className has a field with no declared type. Beak reads the '
                'type to choose a column, so every field needs one.',
          ),
        );
        continue;
      }
      for (final variable in member.fields.variables) {
        final String fieldName = variable.name.lexeme;
        final result = _readField(
          className: className,
          path: path,
          fieldName: fieldName,
          type: type,
          metadata: member.metadata,
          docComment: _docCommentOf(member),
          enums: enums,
        );
        switch (result) {
          case _FieldIssue(:final issue):
            issues.add(issue);
          case _FieldColumn(:final column, :final isDisplay):
            columns.add(column);
            if (isDisplay) {
              displayColumnKey = column.columnKey;
            }
          case _FieldRelation(:final relation):
            relations.add(relation);
        }
      }
    }

    final bool timestamps = options['timestamps'] == 'true';
    final bool softDeletes = options['softDeletes'] == 'true';
    final String table = _unquote(options['table']) ?? tableNameOf(className);

    // The primary key and the stamps are implied, never declared: writing
    // them out per schema is the boilerplate this whole surface removes.
    final allColumns = <BeakColumnIr>[
      const BeakColumnIr(
        fieldName: 'id',
        columnKey: 'id',
        label: 'Id',
        kind: BeakColumnKind.string,
        isRequired: false,
        arguments: {'visibleOn': '{BeakContext.detail}'},
        docComment: 'Primary key.',
      ),
      ...columns,
      for (final relation in relations)
        if (relation.kind == BeakRelationKind.belongsTo)
          BeakColumnIr(
            // `categoryId`, not `category`: the relationship constant already
            // owns that name, and a column and a relationship that look alike
            // are the thing this surface exists to stop conflating.
            fieldName: '${relation.fieldName}Id',
            columnKey: relation.foreignKey!,
            label: relation.label,
            kind: BeakColumnKind.string,
            isRequired: false,
            arguments: const {'visibleOn': '{BeakContext.form}'},
            docComment: 'Foreign key backing [${relation.fieldName}].',
          ),
      if (timestamps) ...const [
        BeakColumnIr(
          fieldName: 'createdAt',
          columnKey: 'created_at',
          label: 'Created',
          kind: BeakColumnKind.dateTime,
          isRequired: false,
          arguments: {'sortable': 'true', 'visibleOn': '{BeakContext.detail}'},
          docComment: 'When the record was created.',
        ),
        BeakColumnIr(
          fieldName: 'updatedAt',
          columnKey: 'updated_at',
          label: 'Updated',
          kind: BeakColumnKind.dateTime,
          isRequired: false,
          arguments: {
            'sortable': 'true',
            'format': 'BeakDateFormat.relative',
            'visibleOn': '{BeakContext.table, BeakContext.detail}',
          },
          docComment: 'When the record was last updated.',
        ),
      ],
      if (softDeletes)
        const BeakColumnIr(
          fieldName: 'deletedAt',
          columnKey: 'deleted_at',
          label: 'Deleted',
          kind: BeakColumnKind.dateTime,
          isRequired: false,
          arguments: {'visibleOn': '{BeakContext.detail}'},
          docComment: 'When the record was soft-deleted, if it was.',
        ),
    ];

    final String display =
        displayColumnKey ??
        columns
            .firstWhere(
              (column) => column.kind == BeakColumnKind.string,
              orElse: () => allColumns.first,
            )
            .columnKey;

    // Only worth saying when nothing else already explains the emptiness:
    // a field that failed to map has already been reported by name.
    if (displayColumnKey == null && columns.isEmpty && issues.isEmpty) {
      issues.add(
        BeakDiscoveryIssue(
          path: 'lib/$path',
          message:
              '$className declares no fields, so it has nothing to display. '
              'Add at least one column field.',
        ),
      );
      return (null, issues);
    }

    return (
      BeakSchemaIr(
        className: className,
        table: table,
        libraryPath: path,
        columns: allColumns,
        relations: relations,
        displayColumnKey: display,
        softDeletes: softDeletes,
        timestamps: timestamps,
        managesSchema: options['managesSchema'] != 'false',
        docComment: _docCommentOf(declaration),
      ),
      issues,
    );
  }

  /// Reads one field as a column, a relationship, or an issue.
  _FieldResult _readField({
    required String className,
    required String path,
    required String fieldName,
    required NamedType type,
    required NodeList<Annotation> metadata,
    required String? docComment,
    required Set<String> enums,
  }) {
    final String typeName = type.name.lexeme;
    final bool nullable = type.question != null;
    final Annotation? column = _annotation(metadata, 'Column');
    final Annotation? custom = _annotation(metadata, 'Custom');
    final Annotation? image = _annotation(metadata, 'Image');
    final Annotation? fileField = _annotation(metadata, 'FileField');
    final Annotation? badges = _annotation(metadata, 'Badges');
    final relationAnnotation = _relationAnnotationOf(metadata);

    if (relationAnnotation != null) {
      final (kind, annotation) = relationAnnotation;
      return _readRelation(
        className: className,
        path: path,
        fieldName: fieldName,
        type: type,
        kind: kind,
        annotation: annotation,
        docComment: docComment,
      );
    }

    final Map<String, String> options = column == null
        ? const {}
        : _namedArguments(column);
    final String columnKey =
        _unquote(options['columnName']) ?? snakeCaseOf(fieldName);
    final String label = _unquote(options['label']) ?? titleCaseOf(fieldName);

    // An upload or custom annotation names the kind; otherwise the type does.
    final BeakColumnKind? kind = image != null
        ? BeakColumnKind.image
        : fileField != null
        ? BeakColumnKind.file
        : custom != null
        ? BeakColumnKind.custom
        : BeakColumnKind.ofType(typeName) ??
              (enums.contains(typeName) ? BeakColumnKind.enumeration : null);

    if (kind == null) {
      return _FieldIssue(
        BeakDiscoveryIssue(
          path: 'lib/$path',
          message:
              '$className.$fieldName is a $typeName, which Beak cannot map to '
              'a column. Use a supported type, annotate it with @BelongsTo / '
              '@HasMany for a relationship, or @Custom for an opaque value.',
        ),
      );
    }

    // An option the kind cannot take would compile-error inside the part
    // file, which is a file the project is told never to edit. Name it here
    // instead, at the declaration that asked for it.
    for (final option in options.keys) {
      if (_optionAppliesTo(option, kind)) {
        continue;
      }
      return _FieldIssue(
        BeakDiscoveryIssue(
          path: 'lib/$path',
          message:
              '$className.$fieldName is a ${kind.name} column, which has no '
              '"$option". ${_optionHint(option)}',
        ),
      );
    }

    final arguments = <String, String>{
      for (final entry in options.entries)
        if (!const {'columnName', 'label'}.contains(entry.key))
          entry.key: entry.value,
      if (image != null) ..._namedArguments(image),
      if (fileField != null) ..._namedArguments(fileField),
      if (custom != null)
        'tag': 'BeakColumnTag(${_positionalArguments(custom).first})',
      if (badges != null) 'badgeColors': _positionalArguments(badges).first,
      if (kind == BeakColumnKind.enumeration) 'values': '$typeName.values',
    };

    return _FieldColumn(
      column: BeakColumnIr(
        fieldName: fieldName,
        columnKey: columnKey,
        label: label,
        kind: kind,
        isRequired: !nullable,
        enumTypeName: kind == BeakColumnKind.enumeration ? typeName : null,
        arguments: arguments,
        docComment: docComment,
      ),
      isDisplay: _annotation(metadata, 'Display') != null,
    );
  }

  /// Whether `@Column`'s [option] means anything for a [kind] column.
  ///
  /// Everything not listed here is shared by every kind.
  static bool _optionAppliesTo(String option, BeakColumnKind kind) =>
      switch (option) {
        'prefix' || 'suffix' => const {
          BeakColumnKind.integer,
          BeakColumnKind.decimal,
        }.contains(kind),
        'precision' || 'totalDigits' => kind == BeakColumnKind.decimal,
        'min' || 'max' => kind == BeakColumnKind.integer,
        'maxLength' || 'placeholder' => kind == BeakColumnKind.string,
        'format' => kind == BeakColumnKind.dateTime,
        'trueLabel' || 'falseLabel' => kind == BeakColumnKind.boolean,
        'defaultValue' => kind == BeakColumnKind.enumeration,
        _ => true,
      };

  /// Where [option] does belong, for the error message.
  static String _optionHint(String option) => switch (option) {
    'prefix' || 'suffix' => 'Units belong on a number column.',
    'precision' => 'Decimal places belong on a `double` field.',
    'totalDigits' => 'A stored width belongs on a `double` field.',
    'min' || 'max' => 'Bounds belong on an `int` field; use rules otherwise.',
    'maxLength' || 'placeholder' => 'That belongs on a `String` field.',
    'format' => 'A date format belongs on a `DateTime` field.',
    'trueLabel' || 'falseLabel' => 'State labels belong on a `bool` field.',
    'defaultValue' => 'A default belongs on an enum field.',
    _ => '',
  };

  /// Reads a relationship field.
  _FieldResult _readRelation({
    required String className,
    required String path,
    required String fieldName,
    required NamedType type,
    required BeakRelationKind kind,
    required Annotation annotation,
    required String? docComment,
  }) {
    final bool isCollection =
        kind == BeakRelationKind.hasMany ||
        kind == BeakRelationKind.belongsToMany;
    final String? related = isCollection
        ? _listElementName(type)
        : type.name.lexeme;

    if (related == null) {
      return _FieldIssue(
        BeakDiscoveryIssue(
          path: 'lib/$path',
          message:
              '$className.$fieldName is a to-many relationship, so it must be '
              'declared as a List of the related schema.',
        ),
      );
    }

    final Map<String, String> options = _namedArguments(annotation);
    return _FieldRelation(
      BeakRelationIr(
        fieldName: fieldName,
        key: fieldName,
        label: _unquote(options['label']) ?? titleCaseOf(fieldName),
        searchOn: _stringList(options['searchOn']),
        kind: kind,
        relatedSchema: related,
        foreignKey:
            _unquote(options['foreignKey']) ??
            _defaultForeignKey(
              kind: kind,
              fieldName: fieldName,
              ownerClass: className,
            ),
        pivotTable: _unquote(options['pivotTable']),
        foreignPivotKey: _unquote(options['foreignPivotKey']),
        relatedPivotKey: _unquote(options['relatedPivotKey']),
        arguments: {
          for (final entry in options.entries)
            if (!const {
              'label',
              'foreignKey',
              'pivotTable',
              'foreignPivotKey',
              'relatedPivotKey',
              'searchOn',
              'inverse',
            }.contains(entry.key))
              entry.key: entry.value,
        },
        docComment: docComment,
        generateInverse: options['inverse'] != 'false',
      ),
    );
  }

  /// The strings of a `['a', 'b']` literal, or empty.
  static List<String> _stringList(String? source) {
    if (source == null) {
      return const [];
    }
    return [
      for (final match in RegExp(r"'([^']*)'").allMatches(source))
        match.group(1)!,
    ];
  }

  /// The conventional foreign key for [kind].
  String? _defaultForeignKey({
    required BeakRelationKind kind,
    required String fieldName,
    required String ownerClass,
  }) => switch (kind) {
    BeakRelationKind.belongsTo => '${snakeCaseOf(fieldName)}_id',
    BeakRelationKind.hasOne ||
    BeakRelationKind.hasMany => '${snakeCaseOf(ownerClass)}_id',
    BeakRelationKind.belongsToMany => null,
  };

  /// Checks every relationship against the schema on the other side.
  ///
  /// Both checks are here rather than at the field, because both need a
  /// schema this file has not read yet.
  List<BeakDiscoveryIssue> _validateRelations(List<BeakSchemaIr> schemas) {
    final byClass = {for (final schema in schemas) schema.className: schema};
    final issues = <BeakDiscoveryIssue>[];
    for (final schema in schemas) {
      for (final relation in schema.relations) {
        final BeakSchemaIr? related = byClass[relation.relatedSchema];
        if (related == null) {
          issues.add(
            BeakDiscoveryIssue(
              path: 'lib/${schema.libraryPath}',
              message:
                  '${schema.className}.${relation.fieldName} points at '
                  '${relation.relatedSchema}, which is not a @Resource '
                  'under lib/models/.',
            ),
          );
          continue;
        }
        // `searchOn` is the one place a schema class names a column of
        // another table by key. Checking it here is what keeps that from
        // being a string that can be quietly wrong.
        final Set<String> keys = {
          for (final column in related.columns) column.columnKey,
        };
        for (final key in relation.searchOn) {
          if (keys.contains(key)) {
            continue;
          }
          issues.add(
            BeakDiscoveryIssue(
              path: 'lib/${schema.libraryPath}',
              message:
                  '${schema.className}.${relation.fieldName} searches '
                  '"$key", which ${related.className} has no column for. '
                  'Its columns are: ${(keys.toList()..sort()).join(', ')}.',
            ),
          );
        }
      }
    }
    return issues;
  }

  /// The `List<X>` element name, or `null` when [type] is not a list.
  String? _listElementName(NamedType type) {
    if (type.name.lexeme != 'List') {
      return null;
    }
    final arguments = type.typeArguments?.arguments;
    if (arguments == null || arguments.length != 1) {
      return null;
    }
    final argument = arguments.single;
    return argument is NamedType ? argument.name.lexeme : null;
  }

  /// The relationship annotation on [metadata], with its kind.
  (BeakRelationKind, Annotation)? _relationAnnotationOf(
    NodeList<Annotation> metadata,
  ) {
    for (final entry in const {
      'BelongsTo': BeakRelationKind.belongsTo,
      'HasOne': BeakRelationKind.hasOne,
      'HasMany': BeakRelationKind.hasMany,
      'BelongsToMany': BeakRelationKind.belongsToMany,
    }.entries) {
      final Annotation? found = _annotation(metadata, entry.key);
      if (found != null) {
        return (entry.value, found);
      }
    }
    return null;
  }

  Annotation? _annotation(NodeList<Annotation> metadata, String name) {
    for (final annotation in metadata) {
      if (annotation.name.name == name) {
        return annotation;
      }
    }
    return null;
  }

  /// Named arguments as source text, keyed by parameter name.
  Map<String, String> _namedArguments(Annotation annotation) => {
    for (final argument in _argumentsOf(annotation))
      if (argument is NamedExpression)
        argument.name.label.name: argument.expression.toSource(),
  };

  /// The annotation's argument expressions, or none when it takes no
  /// arguments.
  List<Expression> _argumentsOf(Annotation annotation) =>
      annotation.arguments?.arguments.toList() ?? const <Expression>[];

  /// Positional arguments as source text.
  List<String> _positionalArguments(Annotation annotation) => [
    for (final argument in _argumentsOf(annotation))
      if (argument is! NamedExpression) argument.toSource(),
  ];

  /// The doc comment text of [node], without the `///` markers.
  String? _docCommentOf(AnnotatedNode node) {
    final Comment? comment = node.documentationComment;
    if (comment == null) {
      return null;
    }
    final lines = [
      for (final token in comment.tokens)
        token.lexeme.replaceFirst(RegExp(r'^///\s?'), ''),
    ];
    return lines.join('\n');
  }

  String _libRelative(File file) {
    final String prefix = '${projectRoot.path}/lib/';
    return file.path.startsWith(prefix)
        ? file.path.substring(prefix.length)
        : file.path;
  }

  /// Strips the quotes from a string-literal source fragment.
  static String? _unquote(String? source) {
    if (source == null) {
      return null;
    }
    final match = RegExp("^['\"](.*)['\"]\$").firstMatch(source);
    return match?.group(1) ?? source;
  }
}

/// `unitPrice` -> `Unit Price`.
String titleCaseOf(String identifier) {
  final spaced = identifier.replaceAllMapped(
    RegExp('([a-z0-9])([A-Z])'),
    (match) => '${match[1]} ${match[2]}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// What reading one field produced.
sealed class _FieldResult {
  const _FieldResult();
}

final class _FieldColumn extends _FieldResult {
  const _FieldColumn({required this.column, required this.isDisplay});

  final BeakColumnIr column;
  final bool isDisplay;
}

final class _FieldRelation extends _FieldResult {
  const _FieldRelation(this.relation);

  final BeakRelationIr relation;
}

final class _FieldIssue extends _FieldResult {
  const _FieldIssue(this.issue);

  final BeakDiscoveryIssue issue;
}
