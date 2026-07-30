import '../field_spec.dart';
import '../project/beak_emitters.dart';
import 'beak_schema_introspection.dart';

/// One generated model file, and anything worth telling the user about it.
final class IntrospectedSchemaFile {
  /// Creates a generated file description.
  const IntrospectedSchemaFile({
    required this.path,
    required this.contents,
    required this.className,
    required this.table,
    this.notes = const [],
  });

  /// Path relative to the output directory.
  final String path;

  /// The Dart source.
  final String contents;

  /// The generated schema class name.
  final String className;

  /// The table it describes.
  final String table;

  /// Warnings: omitted secrets, guesses worth reviewing.
  final List<String> notes;
}

/// Turns an introspected database into the same schema classes a human writes.
///
/// Emitting the *authoring* surface rather than a parallel one is the whole
/// trick: an introspected project is not a second-class citizen with its own
/// dialect, it is an ordinary Beak project whose first draft happened to be
/// written by reading a database. Edit the output and it stays yours.
abstract final class BeakIntrospectionEmitter {
  /// The schema files [tables] generate.
  ///
  /// Pivot tables are folded into the relationships they represent rather
  /// than becoming resources of their own, and each database enum becomes one
  /// Dart enum file the resources that use it import.
  static List<IntrospectedSchemaFile> emitAll(List<IntrospectedTable> tables) {
    final resources = [
      for (final table in tables)
        if (!table.isPivot && !introspectionSkipTables.contains(table.name))
          table,
    ];
    final pivots = [
      for (final table in tables)
        if (table.isPivot) table,
    ];
    final byTable = {for (final table in resources) table.name: table};

    return [
      ...emitEnums(resources),
      for (final table in resources)
        emit(table, byTable: byTable, pivots: pivots),
    ];
  }

  /// One Dart enum file per database enum the [resources] actually use.
  ///
  /// Two tables sharing `order_status` share the one declaration, so the
  /// generated project has a single source of truth for the labels — the same
  /// thing a human would have written.
  static List<IntrospectedSchemaFile> emitEnums(
    List<IntrospectedTable> resources,
  ) {
    final byType = <String, List<String>>{};
    for (final table in resources) {
      for (final column in table.columns) {
        if (column.enumTypeName case final String type
            when column.enumValues.isNotEmpty && _isRepresentable(column)) {
          byType[type] ??= column.enumValues;
        }
      }
    }
    return [
      for (final entry
          in byType.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        _emitEnum(entry.key, entry.value),
    ];
  }

  static IntrospectedSchemaFile _emitEnum(String type, List<String> values) {
    final String className = pascalCaseOf(type);
    final buffer = StringBuffer()
      ..writeln('/// The values the `$type` database enum defines.')
      ..writeln('///')
      ..writeln('/// Stored by name, so renaming a value here renames it in')
      ..writeln('/// every row — change the database with a migration first.')
      ..writeln('enum $className {');
    for (final value in values) {
      buffer
        ..writeln('  /// `$value`.')
        ..writeln('  $value,')
        ..writeln();
    }
    buffer.writeln('}');
    return IntrospectedSchemaFile(
      path: '${_snake(type)}.dart',
      contents: BeakEmitters.format(buffer.toString()),
      className: className,
      table: type,
    );
  }

  /// The schema file for one [table].
  static IntrospectedSchemaFile emit(
    IntrospectedTable table, {
    required Map<String, IntrospectedTable> byTable,
    required List<IntrospectedTable> pivots,
  }) {
    final notes = <String>[];
    final String className = classNameOf(table.name);
    final buffer = StringBuffer()
      ..writeln("import 'package:beak/beak.dart';")
      ..writeln("import 'package:beak/schema.dart';");

    final relatedImports = <String>{
      for (final fk in table.foreignKeys)
        if (byTable.containsKey(fk.referencedTable))
          '${fileNameOf(fk.referencedTable)}.dart',
      for (final pivot in _pivotsFor(table, pivots))
        if (_otherSideOf(pivot, table) case final String other)
          if (byTable.containsKey(other)) '${fileNameOf(other)}.dart',
      for (final column in table.columns)
        if (column.enumTypeName case final String type
            when _isRepresentable(column))
          '${_snake(type)}.dart',
    }..remove('${fileNameOf(table.name)}.dart');
    if (relatedImports.isNotEmpty) {
      buffer.writeln();
      for (final import in relatedImports.toList()..sort()) {
        buffer.writeln("import '$import';");
      }
    }

    buffer
      ..writeln()
      ..writeln("part '${fileNameOf(table.name)}.beak.dart';")
      ..writeln()
      ..writeln('/// The ${table.name} resource, read from the database.')
      ..writeln('@Resource(');
    if (table.name != tableNameOf(className)) {
      buffer.writeln("  table: '${table.name}',");
    }
    if (table.softDeletes) {
      buffer.writeln('  softDeletes: true,');
    }
    if (table.timestamps) {
      buffer.writeln('  timestamps: true,');
    }
    buffer
      ..writeln(')')
      ..writeln('final class $className extends BeakSchema {');

    final foreignKeyColumns = {for (final fk in table.foreignKeys) fk.column};
    var wroteDisplay = false;
    for (final column in table.columns) {
      if (column.name == table.primaryKey ||
          foreignKeyColumns.contains(column.name) ||
          const {
            'created_at',
            'updated_at',
            'deleted_at',
          }.contains(column.name)) {
        continue;
      }
      if (introspectionSecretColumns.contains(column.name)) {
        notes.add(
          '${table.name}.${column.name} looks like a secret and was omitted; '
          'add it deliberately if the panel really should show it',
        );
        continue;
      }
      final String? type = _dartTypeOf(column);
      if (type == null) {
        notes.add(
          '${table.name}.${column.name} is ${column.dataType}, which has no '
          'Beak column; it was omitted',
        );
        continue;
      }
      if (column.enumValues.isNotEmpty && !_isRepresentable(column)) {
        notes.add(
          '${table.name}.${column.name} is the '
          '${column.enumTypeName} enum, but '
          '${column.enumValues.where((v) => !_isDartIdentifier(v)).join(', ')} '
          'cannot be a Dart enum value; it was read as text',
        );
      }
      final bool isDisplay = !wroteDisplay && _isDisplayCandidate(column);
      wroteDisplay = wroteDisplay || isDisplay;

      buffer.writeln('  /// ${_labelOf(column.name)}.');
      if (isDisplay) {
        buffer.writeln('  @Display()');
      }
      buffer.writeln('  @Column(${_columnOptionsOf(column).join(', ')})');
      final bool nullable = column.isNullable || column.hasDefault;
      buffer
        ..writeln(
          '  late final $type${nullable ? '?' : ''} '
          '${camelCaseOf(column.name)};',
        )
        ..writeln();
    }

    for (final fk in table.foreignKeys) {
      final IntrospectedTable? related = byTable[fk.referencedTable];
      if (related == null) {
        notes.add(
          '${table.name}.${fk.column} points at ${fk.referencedTable}, which '
          'was not introspected; the relationship was omitted',
        );
        continue;
      }
      final String field = camelCaseOf(
        fk.column.endsWith('_id')
            ? fk.column.substring(0, fk.column.length - 3)
            : fk.column,
      );
      final IntrospectedColumn? column = _columnNamed(table, fk.column);
      buffer
        ..writeln('  /// The ${_labelOf(fk.referencedTable)} this belongs to.')
        ..writeln(
          '  @BelongsTo('
          "${fk.column == '${_snake(field)}_id' ? '' : "foreignKey: '${fk.column}'"}"
          ')',
        )
        ..writeln(
          '  late final ${classNameOf(related.name)}'
          '${column?.isNullable ?? true ? '?' : ''} $field;',
        )
        ..writeln();
    }

    for (final pivot in _pivotsFor(table, pivots)) {
      final String? other = _otherSideOf(pivot, table);
      final IntrospectedTable? related = other == null ? null : byTable[other];
      if (related == null) {
        continue;
      }
      final String field = camelCaseOf(related.name);
      buffer
        ..writeln('  /// The ${_labelOf(related.name)} linked to this record.')
        ..writeln("  @BelongsToMany(pivotTable: '${pivot.name}')")
        ..writeln('  late final List<${classNameOf(related.name)}> $field;')
        ..writeln();
    }

    buffer.writeln('}');

    return IntrospectedSchemaFile(
      path: '${fileNameOf(table.name)}.dart',
      contents: BeakEmitters.format(buffer.toString()),
      className: className,
      table: table.name,
      notes: notes,
    );
  }

  /// The `@Column` options a described column implies.
  ///
  /// `indexed` and `unique` are read from the database rather than guessed:
  /// an index it already has is a decision somebody made about how the table
  /// is queried, and dropping it on the way through would hand back a schema
  /// that looks right and runs slowly. Foreign keys never reach here — the
  /// relationship declares them, and Beak indexes every one unasked.
  static List<String> _columnOptionsOf(IntrospectedColumn column) => [
    if (_isDisplayCandidate(column) || column.dataType == 'text')
      'searchable: true',
    if (_isSortable(column)) 'sortable: true',
    if (column.enumValues.isNotEmpty || column.dataType == 'boolean')
      'filterable: true',
    if (column.isIndexed && !column.isUnique) 'indexed: true',
    if (column.isUnique) 'unique: true',
    if (_lengthOf(column) case final int length) 'maxLength: $length',
    ..._numericWidthOf(column),
    if (_extraRulesOf(column) case final String rules) 'rules: [$rules]',
  ];

  /// The declared `NUMERIC(precision, scale)` width, when it is not the
  /// default one the migration would produce anyway.
  ///
  /// Emitting the default would put `precision: 2, totalDigits: 10` on every
  /// money column in a generated schema, which reads as a decision rather
  /// than as the absence of one.
  ///
  /// Only a fixed-point type carries one at all. A float reports a width too
  /// (`double precision` says 53), but that is bits of mantissa: writing it
  /// out would convert the column to `NUMERIC(53, 2)` on the next migration.
  /// And Postgres 15 accepts declarations Beak's own column cannot, a
  /// negative scale or a scale above the precision, so those are skipped
  /// rather than emitted into a class that fails its constructor assert.
  static List<String> _numericWidthOf(IntrospectedColumn column) {
    if (!const {'numeric', 'decimal'}.contains(column.dataType)) {
      return const [];
    }
    final int? scale = column.numericScale;
    final int? precision = column.numericPrecision;
    if (scale != null &&
        (scale < 0 || (precision != null && scale > precision))) {
      return const [];
    }
    return [
      if (scale != null && scale != 2) 'precision: $scale',
      if (precision != null && precision != 10) 'totalDigits: $precision',
    ];
  }

  /// The declared length, when it constrains something the user types.
  ///
  /// An upload column's `varchar` holds a storage key Beak writes, not text
  /// the user enters, so its length says nothing about valid input.
  static int? _lengthOf(IntrospectedColumn column) =>
      _isUploadType(_dartTypeOf(column)) ? null : column.maxLength;

  /// Rules a column name or type implies beyond required-ness.
  static String? _extraRulesOf(IntrospectedColumn column) {
    final rules = <String>[];
    if (column.name.contains('email')) {
      rules.add('BeakEmail()');
    }
    if (RegExp(r'url|link|website').hasMatch(column.name)) {
      rules.add('BeakUrl()');
    }
    if (_lengthOf(column) case final int length) {
      rules.add('BeakMaxLength($length)');
    }
    return rules.isEmpty ? null : rules.join(', ');
  }

  /// Whether [dartType] is one of the upload marker types.
  static bool _isUploadType(String? dartType) =>
      const {'BeakImageRef', 'BeakFileRef'}.contains(dartType);

  /// Whether a column's enum labels can each be a Dart enum constant.
  ///
  /// Beak stores an enum value by its Dart `name`, so a label the language
  /// cannot spell — `in progress`, `2xl`, `class` — has no representation
  /// that round-trips. Those columns stay `String`, which is correct and
  /// editable, rather than becoming a file that does not compile.
  static bool _isRepresentable(IntrospectedColumn column) =>
      column.enumValues.every(_isDartIdentifier);

  static bool _isDartIdentifier(String value) =>
      RegExp(r'^[a-z_][A-Za-z0-9_]*$').hasMatch(value) &&
      !_dartReservedWords.contains(value);

  /// The reserved words that cannot be an enum constant name.
  static const Set<String> _dartReservedWords = {
    'assert', 'break', 'case', 'catch', 'class', 'const', 'continue',
    'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally',
    'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
    'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
    // Not reserved, but every enum already declares them.
    'index', 'values', 'hashCode', 'runtimeType', 'toString', 'noSuchMethod',
  };

  /// Whether [dataType] is a string column, and so could be a storage key.
  static bool _isTextual(String dataType) => const {
    'text',
    'character varying',
    'varchar',
    'character',
    'citext',
  }.contains(dataType);

  static bool _isDisplayCandidate(IntrospectedColumn column) =>
      const {
        'name',
        'title',
        'label',
        'email',
        'subject',
      }.contains(column.name) &&
      _dartTypeOf(column) == 'String';

  static bool _isSortable(IntrospectedColumn column) => const {
    'integer',
    'bigint',
    'smallint',
    'numeric',
    'decimal',
    'real',
    'double precision',
    'timestamp with time zone',
    'timestamp without time zone',
    'date',
  }.contains(column.dataType);

  /// The authoring Dart type a described column maps to, or `null` when Beak
  /// has no column for it.
  static String? _dartTypeOf(IntrospectedColumn column) {
    if (column.enumValues.isNotEmpty) {
      // An enum whose labels Dart cannot spell still holds text, and reading
      // it as text keeps the column — and the panel — rather than dropping a
      // field the database plainly has.
      return _isRepresentable(column)
          ? pascalCaseOf(column.enumTypeName ?? column.name)
          : 'String';
    }
    if (_isTextual(column.dataType)) {
      // A `varchar` holding a storage key is still a `varchar` to the
      // database, so the column name is the only signal there is. Guessing
      // here is worth it: an image column rendered as a text field is the
      // single most obvious thing wrong with a freshly introspected panel,
      // and correcting a wrong guess is one word in a file the user owns.
      if (RegExp(
        'image|photo|picture|avatar|thumbnail',
      ).hasMatch(column.name)) {
        return 'BeakImageRef';
      }
      if (RegExp('file|attachment|document').hasMatch(column.name)) {
        return 'BeakFileRef';
      }
    }
    return switch (column.dataType) {
      'text' => 'BeakText',
      'character varying' ||
      'varchar' ||
      'character' ||
      'uuid' ||
      'citext' => 'String',
      'integer' || 'bigint' || 'smallint' => 'int',
      'numeric' || 'decimal' || 'real' || 'double precision' => 'double',
      'boolean' => 'bool',
      'timestamp with time zone' ||
      'timestamp without time zone' ||
      'date' => 'DateTime',
      'json' || 'jsonb' => 'BeakJson',
      _ => null,
    };
  }

  static IntrospectedColumn? _columnNamed(
    IntrospectedTable table,
    String name,
  ) {
    for (final column in table.columns) {
      if (column.name == name) {
        return column;
      }
    }
    return null;
  }

  /// Pivot tables one side of which is [table].
  static List<IntrospectedTable> _pivotsFor(
    IntrospectedTable table,
    List<IntrospectedTable> pivots,
  ) => [
    for (final pivot in pivots)
      if (pivot.foreignKeys.any((fk) => fk.referencedTable == table.name))
        pivot,
  ];

  /// The table on the far side of [pivot] from [table].
  static String? _otherSideOf(
    IntrospectedTable pivot,
    IntrospectedTable table,
  ) {
    for (final fk in pivot.foreignKeys) {
      if (fk.referencedTable != table.name) {
        return fk.referencedTable;
      }
    }
    return null;
  }

  static String _labelOf(String name) {
    final words = name.split('_').where((word) => word.isNotEmpty);
    return words
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  static String _snake(String camel) => camel
      .replaceAllMapped(
        RegExp('([a-z0-9])([A-Z])'),
        (match) => '${match[1]}_${match[2]}',
      )
      .toLowerCase();
}

/// `order_items` -> `OrderItem`, the conventional schema class name.
String classNameOf(String table) => pascalCaseOf(_singularOf(table));

/// `product_status` -> `ProductStatus`, without singularizing.
///
/// A table name is plural and its class is singular; a type name — a Postgres
/// enum, say — is already singular, and running it through the singularizer
/// turns `product_status` into `ProductStatu`.
String pascalCaseOf(String snake) => snake
    .split('_')
    .where((word) => word.isNotEmpty)
    .map((word) => word[0].toUpperCase() + word.substring(1))
    .join();

/// `order_items` -> `order_item`, the conventional file name.
String fileNameOf(String table) => _singularOf(table);

/// `created_at` -> `createdAt`.
String camelCaseOf(String snake) {
  final parts = snake.split('_').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) {
    return snake;
  }
  return parts.first +
      parts
          .skip(1)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join();
}

String _singularOf(String table) {
  if (table.endsWith('ies')) {
    return '${table.substring(0, table.length - 3)}y';
  }
  if (table.endsWith('ses') ||
      table.endsWith('xes') ||
      table.endsWith('ches') ||
      table.endsWith('shes')) {
    return table.substring(0, table.length - 2);
  }
  // `status`, `address`, `class` and friends end in `s` but are already
  // singular — stripping it produces `statu`, which no user would ever type.
  if (table.endsWith('ss') || table.endsWith('us') || table.endsWith('is')) {
    return table;
  }
  return table.endsWith('s') ? table.substring(0, table.length - 1) : table;
}
