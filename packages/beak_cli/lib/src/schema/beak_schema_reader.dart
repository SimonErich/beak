import 'dart:io';
import 'dart:math' as math;

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

  /// Reads every schema class under `lib/`, including resource-local models.
  ///
  /// Issues are returned rather than thrown, so `beak prepare` can report all
  /// of them at once instead of one per run.
  (List<BeakSchemaIr>, List<BeakDiscoveryIssue>) read() {
    final schemas = <BeakSchemaIr>[];
    final issues = <BeakDiscoveryIssue>[];
    // Enums declared anywhere under lib/. An unresolved parse cannot
    // tell `ProductStatus` from `Uri` by name alone, so collect the real
    // declarations and treat anything else as an error the author can fix.
    final enums = <String>{};
    final root = Directory('${projectRoot.path}/lib');
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
                  !file.path.endsWith('.g.dart') &&
                  !file.path.endsWith('.freezed.dart') &&
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
    return (_resolveForeignKeyTypes(schemas), issues);
  }

  /// Foreign keys use the target identity's declared storage type.
  List<BeakSchemaIr> _resolveForeignKeyTypes(List<BeakSchemaIr> schemas) {
    final byClass = {for (final schema in schemas) schema.className: schema};
    return [
      for (final schema in schemas)
        BeakSchemaIr(
          className: schema.className,
          table: schema.table,
          libraryPath: schema.libraryPath,
          columns: [
            for (final column in schema.columns)
              _resolveForeignKey(column, schema, byClass),
          ],
          relations: schema.relations,
          displayColumnKey: schema.displayColumnKey,
          softDeletes: schema.softDeletes,
          timestamps: schema.timestamps,
          managesSchema: schema.managesSchema,
          hasValidationRules: schema.hasValidationRules,
          hasBehavior: schema.hasBehavior,
          hasPermissions: schema.hasPermissions,
          hasCapabilities: schema.hasCapabilities,
          docComment: schema.docComment,
        ),
    ];
  }

  BeakColumnIr _resolveForeignKey(
    BeakColumnIr column,
    BeakSchemaIr schema,
    Map<String, BeakSchemaIr> byClass,
  ) {
    for (final relation in schema.relations) {
      if (relation.kind != BeakRelationKind.belongsTo ||
          relation.foreignKey != column.columnKey) {
        continue;
      }
      final related = byClass[relation.relatedSchema];
      if (related == null) return column;
      final identity = related.columns
          .where((field) => field.columnKey == 'id')
          .first;
      return BeakColumnIr(
        fieldName: column.fieldName,
        columnKey: column.columnKey,
        label: column.label,
        kind: identity.kind,
        isRequired: relation.isRequired,
        enumTypeName: identity.enumTypeName,
        declaredValueType: identity.declaredValueType,
        arguments: column.arguments,
        docComment: column.docComment,
      );
    }
    return column;
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
      if (!columns.any((column) => column.columnKey == 'id'))
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
        if (relation.kind == BeakRelationKind.belongsTo &&
            !columns.any((column) => column.columnKey == relation.foreignKey))
          BeakColumnIr(
            // `categoryId`, not `category`: the relationship constant already
            // owns that name, and a column and a relationship that look alike
            // are the thing this surface exists to stop conflating.
            fieldName: '${relation.fieldName}Id',
            columnKey: relation.foreignKey!,
            label: relation.label,
            kind: BeakColumnKind.string,
            isRequired: relation.isRequired,
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

    for (final column in allColumns) {
      final reference = column.arguments['currencyFrom'];
      if (reference == null) continue;
      final member = reference.startsWith('#') ? reference.substring(1) : '';
      final targets = allColumns.where(
        (candidate) => candidate.fieldName == member,
      );
      if (targets.isEmpty ||
          targets.first.kind != BeakColumnKind.string ||
          column.declaredValueType != 'BeakDecimal' ||
          !(column.arguments['semantic']?.contains('BeakSemantic.money(') ??
              false)) {
        issues.add(
          BeakDiscoveryIssue(
            path: 'lib/$path',
            message:
                '$className.${column.fieldName}: currencyFrom $reference must name a String schema field on a BeakDecimal money column.',
          ),
        );
      }
    }

    final String display =
        displayColumnKey ??
        columns
            .firstWhere(
              (column) =>
                  column.kind == BeakColumnKind.string &&
                  !(column.arguments['semantic']?.contains(
                        'BeakSemantic.password(',
                      ) ??
                      false),
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
        hasValidationRules: _declaresStaticGetter(
          declaration,
          'validationRules',
        ),
        hasBehavior: _declaresStaticGetter(declaration, 'behavior'),
        hasPermissions: _declaresStaticGetter(declaration, 'permissions'),
        hasCapabilities: _declaresStaticGetter(declaration, 'capabilities'),
        docComment: _docCommentOf(declaration),
      ),
      issues,
    );
  }

  /// Whether [declaration] has a `static get [name]`, which the generated
  /// model forwards to so shared rules live on the schema class.
  static bool _declaresStaticGetter(
    ClassDeclaration declaration,
    String name,
  ) => declaration.members.whereType<MethodDeclaration>().any(
    (member) =>
        member.isStatic && member.isGetter && member.name.lexeme == name,
  );

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
    final Annotation? enumLabels = _annotation(metadata, 'EnumLabels');
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

    final listElement =
        typeName == 'List' &&
            type.typeArguments?.arguments.singleOrNull?.question == null
        ? _listElementName(type)
        : null;
    final primitiveType = switch (listElement) {
      'String' => 'string',
      'int' => 'integer',
      'double' => 'decimal',
      'bool' => 'boolean',
      _ => null,
    };
    final semanticType = switch (typeName) {
      'BeakJson' ||
      'BeakDate' ||
      'BeakTime' ||
      'Duration' ||
      'BeakDecimal' ||
      'BeakJsonObject' => typeName,
      'List' when primitiveType != null => 'List<$listElement>',
      _ => null,
    };
    // An upload or custom annotation names the kind; otherwise the type does.
    final BeakColumnKind? kind = image != null
        ? BeakColumnKind.image
        : fileField != null
        ? BeakColumnKind.file
        : custom != null
        ? BeakColumnKind.custom
        : (primitiveType == null
                  ? BeakColumnKind.ofType(typeName)
                  : BeakColumnKind.json) ??
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

    final semanticName = RegExp(
      r'BeakSemantic\.(\w+)\(',
    ).firstMatch(options['semantic'] ?? '')?.group(1);
    final validSemantic = switch (semanticName) {
      'email' ||
      'url' ||
      'phone' ||
      'slug' ||
      'password' ||
      'uuid' => typeName == 'String',
      'calendarDate' => typeName == 'BeakDate',
      'time' => typeName == 'BeakTime',
      'duration' => typeName == 'Duration',
      'exactDecimal' || 'money' => typeName == 'BeakDecimal',
      'percentage' || 'quantity' => typeName == 'int' || typeName == 'double',
      'fileSize' => typeName == 'int',
      'object' => typeName == 'BeakJsonObject',
      'list' => typeName == 'List' && primitiveType != null,
      _ => true,
    };
    if (!validSemantic) {
      return _FieldIssue(
        BeakDiscoveryIssue(
          path: 'lib/$path',
          message:
              '$className.$fieldName: BeakSemantic.$semanticName is incompatible with $typeName. Use its semantic Dart value type.',
        ),
      );
    }

    final password =
        options['semantic']?.contains('BeakSemantic.password(') ?? false;
    if (password &&
        (_annotation(metadata, 'Display') != null ||
            options['searchable'] == 'true')) {
      return _FieldIssue(
        BeakDiscoveryIssue(
          path: 'lib/$path',
          message:
              '$className.$fieldName is a password and cannot be @Display or searchable.',
        ),
      );
    }

    // Bounds used to be `@Column` options as well as rules, and the two
    // disagreed: `maxLength:` sized the column without validating it. A rule
    // is now the one place a bound is written, so the old spelling says
    // which rule replaces it rather than failing inside the part file.
    for (final (option, rule) in const [
      ('maxLength', 'BeakMaxLength'),
      ('min', 'BeakMin'),
      ('max', 'BeakMax'),
    ]) {
      if (options[option] case final String value) {
        return _FieldIssue(
          BeakDiscoveryIssue(
            path: 'lib/$path',
            message:
                '$className.$fieldName: @Column($option:) was removed. '
                'Declare the bound as a rule instead: rules: [$rule($value)].',
          ),
        );
      }
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

    final inferredSemantic = switch (typeName) {
      'BeakDate' => 'BeakSemantic.calendarDate()',
      'BeakTime' => 'BeakSemantic.time()',
      'Duration' => 'BeakSemantic.duration()',
      'BeakDecimal' => 'BeakSemantic.exactDecimal()',
      'BeakJsonObject' =>
        'BeakSemantic.object(BeakObjectSchema(columns: [], allowUnknown: true))',
      'List' when primitiveType != null =>
        'BeakSemantic.list(BeakPrimitiveType.$primitiveType)',
      _ => null,
    };
    final arguments = <String, String>{
      'semantic': ?inferredSemantic,
      if (kind == BeakColumnKind.boolean && nullable) 'tristate': 'true',
      if (password) 'visibleOn': '{BeakContext.form}',
      if (typeName == 'double' &&
          semanticName == 'percentage' &&
          RegExp(
            r'scale:\s*1(?:\.0)?\s*[,)]',
          ).hasMatch(options['semantic'] ?? ''))
        'precision': '4',
      for (final entry in options.entries)
        if (!const {'columnName', 'label'}.contains(entry.key))
          entry.key: entry.value,
      if (image != null) ..._namedArguments(image),
      if (fileField != null) ..._namedArguments(fileField),
      if (custom != null)
        'tag': 'BeakColumnTag(${_positionalArguments(custom).first})',
      if (badges != null) 'badgeColors': _positionalArguments(badges).first,
      if (enumLabels != null) 'labels': _positionalArguments(enumLabels).first,
      if (kind == BeakColumnKind.enumeration) 'values': '$typeName.values',
      ..._boundsOf(options['rules'], kind, typeName),
    };

    return _FieldColumn(
      column: BeakColumnIr(
        fieldName: fieldName,
        columnKey: columnKey,
        label: label,
        kind: kind,
        isRequired: !nullable,
        enumTypeName: kind == BeakColumnKind.enumeration ? typeName : null,
        declaredValueType: semanticType,
        arguments: arguments,
        docComment: docComment,
      ),
      isDisplay: _annotation(metadata, 'Display') != null,
    );
  }

  /// The column sizing a field's [rules] imply, as column arguments.
  ///
  /// A bound is declared once, as a rule, and means the same thing in every
  /// layer: `BeakMaxLength` on a `String` also sets the stored length, and
  /// `BeakMin`/`BeakMax` on an `int` also bound the form's stepper. When a
  /// list repeats a rule, the tightest bound wins, since that is the one a
  /// value has to satisfy anyway. Anything that is not an integer literal is
  /// left to validation alone.
  static Map<String, String> _boundsOf(
    String? rules,
    BeakColumnKind kind,
    String typeName,
  ) {
    if (rules == null) {
      return const {};
    }
    List<int> valuesOf(String rule) => [
      for (final match in RegExp(
        '\\b$rule\\(\\s*(-?\\d+)\\s*\\)',
      ).allMatches(rules))
        int.parse(match.group(1)!),
    ];
    int? tightest(List<int> values, int Function(int, int) pick) =>
        values.isEmpty ? null : values.reduce(pick);

    return switch ((kind, typeName)) {
      (BeakColumnKind.string, 'String') => {
        if (tightest(valuesOf('BeakMaxLength'), math.min) case final int length)
          'maxLength': '$length',
      },
      (BeakColumnKind.integer, 'int') => {
        if (tightest(valuesOf('BeakMin'), math.max) case final int min)
          'min': '$min',
        if (tightest(valuesOf('BeakMax'), math.min) case final int max)
          'max': '$max',
      },
      _ => const {},
    };
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
        'placeholder' => kind == BeakColumnKind.string,
        'format' => kind == BeakColumnKind.dateTime,
        'trueLabel' || 'falseLabel' => kind == BeakColumnKind.boolean,
        'defaultValue' => true,
        _ => true,
      };

  /// Where [option] does belong, for the error message.
  static String _optionHint(String option) => switch (option) {
    'prefix' || 'suffix' => 'Units belong on a number column.',
    'precision' => 'Decimal places belong on a `double` field.',
    'totalDigits' => 'A stored width belongs on a `double` field.',
    'placeholder' => 'That belongs on a `String` field.',
    'format' => 'A date format belongs on a `DateTime` field.',
    'trueLabel' || 'falseLabel' => 'State labels belong on a `bool` field.',
    'defaultValue' => 'A default must match the declared field type.',
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
    final String? searchOn = options['searchOn'];
    if (searchOn != null && RegExp('[\'"]').hasMatch(searchOn)) {
      final symbols = _stringList(searchOn).map(_camelCaseOf).map((f) => '#$f');
      return _FieldIssue(
        BeakDiscoveryIssue(
          path: 'lib/$path',
          message:
              '$className.$fieldName: searchOn takes the related schema\'s '
              'fields as symbols, not column keys as strings. Write '
              'searchOn: [${symbols.join(', ')}].',
        ),
      );
    }
    return _FieldRelation(
      BeakRelationIr(
        fieldName: fieldName,
        key: fieldName,
        label: _unquote(options['label']) ?? titleCaseOf(fieldName),
        searchOn: _symbolList(searchOn),
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
          if (kind == BeakRelationKind.belongsTo &&
              type.question == null &&
              !options.containsKey('onDelete'))
            'onDelete': 'BeakOnDelete.restrict',
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
        isRequired: !isCollection && type.question == null,
      ),
    );
  }

  /// The strings of a `['a', 'b']` literal.
  static List<String> _stringList(String source) => [
    for (final match in RegExp('[\'"]([^\'"]*)[\'"]').allMatches(source))
      match.group(1)!,
  ];

  /// The names of a `[#a, #b]` symbol list, or empty.
  static List<String> _symbolList(String? source) {
    if (source == null) {
      return const [];
    }
    return [
      for (final match in RegExp(r'#(\w+)').allMatches(source)) match.group(1)!,
    ];
  }

  /// `first_name` -> `firstName`, for the hint that replaces a column key.
  static String _camelCaseOf(String snake) =>
      snake.replaceAllMapped(RegExp('_([a-z0-9])'), (m) => m[1]!.toUpperCase());

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
                  'under lib/.',
            ),
          );
          continue;
        }
        // `searchOn` is the one place a schema class names a field of
        // another schema. A symbol is not checked by the compiler, so it is
        // checked here, like `currencyFrom`: a typo is an error at the
        // declaration rather than a picker that quietly finds nothing.
        final Set<String> fields = {
          for (final column in related.columns) column.fieldName,
        };
        for (final field in relation.searchOn) {
          if (fields.contains(field)) {
            continue;
          }
          issues.add(
            BeakDiscoveryIssue(
              path: 'lib/${schema.libraryPath}',
              message:
                  '${schema.className}.${relation.fieldName} searches '
                  '#$field, which is not a field of ${related.className}. '
                  'Its fields are: ${(fields.toList()..sort()).join(', ')}.',
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
