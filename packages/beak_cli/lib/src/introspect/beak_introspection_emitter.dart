import 'package:path/path.dart' as p;

import '../field_spec.dart';
import '../inflection.dart';
import '../project/beak_emitters.dart';
import 'beak_schema_introspection.dart';

/// Where introspected schema files are laid out.
///
/// Both are relative to whichever directory the command writes into.
enum BeakIntrospectionLayout {
  /// One folder per table, the layout `beak make:resource` writes:
  /// `<table>/models/<name>.dart`, relative to `lib/resources`.
  ///
  /// A database enum sits in the folder of the first table (by name) that
  /// uses it, and the other tables import it from there.
  featureFolders,

  /// Every file side by side in one directory: `<name>.dart`.
  flat,
}

/// Who owns the schema of the database `beak introspect` reads.
///
/// The answer decides whether `beak prepare` and `beak migrate` may ever touch
/// it, so it is a choice the user makes rather than something guessed.
enum BeakIntrospectionOwnership {
  /// Beak takes the schema over. The classes own their tables, and a
  /// baseline migration records that they already exist: on this database it
  /// changes nothing, and on an empty one it builds them.
  adopt,

  /// Another system keeps the schema. The classes are marked
  /// `managesSchema: false`, and Beak writes no migration for them.
  external,
}

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

  /// Path relative to the output directory, in the chosen
  /// [BeakIntrospectionLayout].
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
  ///
  /// [layout] decides where each file goes, and so how the files import one
  /// another. The default is the feature-folder layout every scaffolded
  /// project uses.
  static List<IntrospectedSchemaFile> emitAll(
    List<IntrospectedTable> tables, {
    BeakIntrospectionLayout layout = BeakIntrospectionLayout.featureFolders,
    BeakIntrospectionOwnership ownership = BeakIntrospectionOwnership.adopt,
  }) {
    final resources = _resourcesOf(tables);
    final pivots = _pivotsIn(tables);
    final byTable = {for (final table in resources) table.name: table};

    return [
      ...emitEnums(resources, layout: layout),
      for (final table in resources)
        emit(
          table,
          byTable: byTable,
          pivots: pivots,
          layout: layout,
          ownership: ownership,
        ),
    ];
  }

  /// The tables of [tables] that become resources: not a join table, and not
  /// migration bookkeeping.
  static List<IntrospectedTable> _resourcesOf(List<IntrospectedTable> tables) =>
      [
        for (final table in tables)
          if (!table.isPivot && !introspectionSkipTables.contains(table.name))
            table,
      ];

  /// The join tables of [tables], which become relationships.
  static List<IntrospectedTable> _pivotsIn(List<IntrospectedTable> tables) => [
    for (final table in tables)
      if (table.isPivot) table,
  ];

  /// The source of the migration that adopts the database [tables] describe.
  ///
  /// A `BeakBaselineMigration` listing every resource model in foreign-key
  /// order and every many-to-many pivot, so that on the database the classes
  /// were read from it changes nothing and is recorded as applied, and on an
  /// empty database it builds all of it.
  ///
  /// [migrationName] is the migration's `name`, and [schemaRoot] the
  /// directory the schema files were written to, relative to
  /// `lib/migrations/`, which is where the migration itself is written.
  static String emitBaseline(
    List<IntrospectedTable> tables, {
    required String migrationName,
    required String schemaRoot,
    BeakIntrospectionLayout layout = BeakIntrospectionLayout.featureFolders,
  }) {
    final resources = _inForeignKeyOrder(_resourcesOf(tables));
    final pivots = _pivotsIn(tables);
    final byTable = {for (final table in resources) table.name: table};

    final declaredPivots = <String>[];
    final seenPivotTables = <String>{};
    for (final table in resources) {
      for (final pivot in _pivotsFor(table, pivots)) {
        final String? other = _otherSideOf(pivot, table);
        if (other == null ||
            !byTable.containsKey(other) ||
            !seenPivotTables.add(pivot.name)) {
          continue;
        }
        declaredPivots.add(
          '${classNameOf(table.name)}Relations.${camelCaseOf(other)}',
        );
      }
    }

    final imports = [
      for (final table in resources)
        "import '$schemaRoot/${_tablePath(table.name, layout)}';",
    ]..sort();
    final buffer = StringBuffer()
      ..writeln("import 'package:beak/migrations.dart';")
      ..writeln();
    imports.forEach(buffer.writeln);
    buffer
      ..writeln()
      ..writeln('/// Brings the tables `beak introspect` read under Beak.')
      ..writeln('///')
      ..writeln(
        '/// Where the tables already exist this changes nothing and is',
      )
      ..writeln('/// recorded as applied; on an empty database it creates them')
      ..writeln('/// from the models. It never alters a table that is there.')
      ..writeln(
        'final class AdoptExistingSchema extends BeakBaselineMigration {',
      )
      ..writeln('  /// Creates the migration.')
      ..writeln('  const AdoptExistingSchema();')
      ..writeln()
      ..writeln('  @override')
      ..writeln("  String get name => '$migrationName';")
      ..writeln()
      ..writeln('  @override')
      ..writeln('  List<BeakModel> get models => const [');
    for (final table in resources) {
      buffer.writeln('    ${classNameOf(table.name)}Model(),');
    }
    buffer.writeln('  ];');
    if (declaredPivots.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('  @override')
        ..writeln(
          '  List<BeakBelongsToMany> get pivots => const '
          '[${declaredPivots.join(', ')}];',
        );
    }
    buffer.writeln('}');
    return BeakEmitters.format(buffer.toString());
  }

  /// [resources] ordered so a table follows every table it references.
  ///
  /// A stable walk. Tables that reference each other cannot both follow the
  /// other, so the walk lists the one it reaches second first, and the
  /// migration leaves out the foreign key that would point forward.
  static List<IntrospectedTable> _inForeignKeyOrder(
    List<IntrospectedTable> resources,
  ) {
    final byName = {for (final table in resources) table.name: table};
    final ordered = <IntrospectedTable>[];
    final placed = <String>{};

    void visit(IntrospectedTable table, Set<String> visiting) {
      if (placed.contains(table.name) || !visiting.add(table.name)) {
        return;
      }
      for (final fk in table.foreignKeys) {
        if (byName[fk.referencedTable] case final IntrospectedTable target) {
          visit(target, visiting);
        }
      }
      visiting.remove(table.name);
      if (placed.add(table.name)) {
        ordered.add(table);
      }
    }

    for (final table in resources) {
      visit(table, <String>{});
    }
    return ordered;
  }

  /// One Dart enum file per database enum the [resources] actually use.
  ///
  /// Two tables sharing `order_status` share the one declaration, so the
  /// generated project has a single source of truth for the labels — the same
  /// thing a human would have written.
  static List<IntrospectedSchemaFile> emitEnums(
    List<IntrospectedTable> resources, {
    BeakIntrospectionLayout layout = BeakIntrospectionLayout.featureFolders,
  }) {
    final byType = <String, List<String>>{};
    for (final table in resources) {
      for (final column in table.columns) {
        if (column.enumTypeName case final String type
            when column.enumValues.isNotEmpty && _isRepresentable(column)) {
          byType[type] ??= column.enumValues;
        }
      }
    }
    final owners = _enumOwners(resources);
    return [
      for (final entry
          in byType.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        _emitEnum(
          entry.key,
          entry.value,
          path: _enumPath(entry.key, owners[entry.key], layout),
        ),
    ];
  }

  /// The first table, by name, that uses each enum type.
  ///
  /// Two tables sharing `order_status` share the one declaration, and it has
  /// to live in one feature folder. Choosing by name keeps the choice the
  /// same however the database happens to order its tables.
  static Map<String, String> _enumOwners(Iterable<IntrospectedTable> tables) {
    final owners = <String, String>{};
    for (final table in [...tables]..sort((a, b) => a.name.compareTo(b.name))) {
      for (final column in table.columns) {
        if (column.enumTypeName case final String type
            when column.enumValues.isNotEmpty && _isRepresentable(column)) {
          owners.putIfAbsent(type, () => table.name);
        }
      }
    }
    return owners;
  }

  /// Where the schema class of the table [table] is written.
  static String _tablePath(String table, BeakIntrospectionLayout layout) =>
      switch (layout) {
        BeakIntrospectionLayout.featureFolders =>
          '$table/models/${fileNameOf(table)}.dart',
        BeakIntrospectionLayout.flat => '${fileNameOf(table)}.dart',
      };

  /// Where the enum [type], first used by [owner], is written.
  static String _enumPath(
    String type,
    String? owner,
    BeakIntrospectionLayout layout,
  ) => switch (layout) {
    BeakIntrospectionLayout.featureFolders when owner != null =>
      '$owner/models/${_snake(type)}.dart',
    _ => '${_snake(type)}.dart',
  };

  static IntrospectedSchemaFile _emitEnum(
    String type,
    List<String> values, {
    required String path,
  }) {
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
      path: path,
      contents: BeakEmitters.format(buffer.toString()),
      className: className,
      table: type,
    );
  }

  /// The schema file for one [table], laid out and importing its neighbours
  /// as [layout] says.
  static IntrospectedSchemaFile emit(
    IntrospectedTable table, {
    required Map<String, IntrospectedTable> byTable,
    required List<IntrospectedTable> pivots,
    BeakIntrospectionLayout layout = BeakIntrospectionLayout.featureFolders,
    BeakIntrospectionOwnership ownership = BeakIntrospectionOwnership.adopt,
  }) {
    final notes = <String>[];
    final String className = classNameOf(table.name);
    final String ownPath = _tablePath(table.name, layout);
    final owners = _enumOwners(byTable.values);
    // What this file imports, as a path relative to the file itself.
    String importOf(String path) =>
        p.posix.relative(path, from: p.posix.dirname(ownPath));
    final buffer = StringBuffer()
      ..writeln("import 'package:beak/beak.dart';")
      ..writeln("import 'package:beak/schema.dart';");

    final relatedImports = <String>{
      for (final fk in table.foreignKeys)
        if (byTable.containsKey(fk.referencedTable))
          _tablePath(fk.referencedTable, layout),
      for (final pivot in _pivotsFor(table, pivots))
        if (_otherSideOf(pivot, table) case final String other)
          if (byTable.containsKey(other)) _tablePath(other, layout),
      for (final column in table.columns)
        if (column.enumTypeName case final String type
            when _isRepresentable(column))
          _enumPath(type, owners[type], layout),
    }.map(importOf).toSet()..remove(importOf(ownPath));
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
    // Something else created the table and keeps it. Owning its schema would
    // have `beak prepare` write a create migration for a table that exists.
    if (ownership == BeakIntrospectionOwnership.external) {
      buffer.writeln('  managesSchema: false,');
    }
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
    final String? displayColumn = _displayColumnOf(table, foreignKeyColumns);
    // A serial key is declared as the integer it is. The server mints a string
    // id only for a string key and leaves an integer one to the database, and
    // every foreign key that points here takes the key's type.
    if (_hasIntegerKey(table)) {
      buffer
        ..writeln('  /// The primary key.')
        ..writeln('  late final int? id;')
        ..writeln();
    }
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
      if (_isNumeric(column)) {
        notes.add(
          '${table.name}.${column.name} is ${_numericTypeOf(column)}, read as '
          'a double, which can round. An exact amount is a BeakDecimal, which '
          'Beak stores as integer units, so switching means converting the '
          'column in a migration',
        );
      }
      buffer.writeln('  /// ${_labelOf(column.name)}.');
      if (column.name == displayColumn) {
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
      path: ownPath,
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

  /// The columns that name a record, best first.
  ///
  /// A picker or a relation shows this column in place of an id, so the
  /// convention is worth guessing: `name` says what a thing is called more
  /// often than `title` does, and a person's `email` says more than a `code`.
  static const List<String> _displayNames = [
    'name',
    'title',
    'label',
    'email',
    'code',
    'subject',
  ];

  /// Whether [column] holds text a person could recognise a record by.
  ///
  /// Text is `String` for a `varchar` and `BeakText` for a `text`, and SQLite
  /// declares nearly every string as `TEXT`, so requiring `String` left the
  /// zero-setup default without a single display column.
  static bool _isDisplayCandidate(IntrospectedColumn column) =>
      _displayNames.contains(column.name) &&
      const {'String', 'BeakText'}.contains(_dartTypeOf(column));

  /// The column of [table] the schema class marks `@Display()`, or `null`
  /// when none of its columns is a candidate.
  ///
  /// The best-named candidate wins wherever it sits in the table. Declaration
  /// order alone would pick the `code` that happens to come first over the
  /// `name` beside it.
  static String? _displayColumnOf(
    IntrospectedTable table,
    Set<String> foreignKeyColumns,
  ) {
    final Set<String> candidates = {
      for (final column in table.columns)
        if (column.name != table.primaryKey &&
            !foreignKeyColumns.contains(column.name) &&
            _isDisplayCandidate(column))
          column.name,
    };
    for (final name in _displayNames) {
      if (candidates.contains(name)) {
        return name;
      }
    }
    return null;
  }

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

  /// Whether [table]'s primary key is a serial `id` column.
  static bool _hasIntegerKey(IntrospectedTable table) {
    final IntrospectedColumn? key = _columnNamed(table, table.primaryKey);
    return key != null &&
        key.name == 'id' &&
        const {'integer', 'bigint', 'smallint'}.contains(key.dataType);
  }

  /// Whether [column] is a fixed-point `numeric` or `decimal`.
  static bool _isNumeric(IntrospectedColumn column) =>
      const {'numeric', 'decimal'}.contains(column.dataType);

  /// `numeric(12,2)`, or `numeric` when the database declares no width.
  static String _numericTypeOf(IntrospectedColumn column) {
    final int? precision = column.numericPrecision;
    final int? scale = column.numericScale;
    if (precision == null) {
      return column.dataType;
    }
    return '${column.dataType}($precision${scale == null ? '' : ',$scale'})';
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
String classNameOf(String table) => pascalCaseOf(singularOf(table));

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
String fileNameOf(String table) => singularOf(table);

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
