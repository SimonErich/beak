/// The member names a generated class already owns.
///
/// A schema field named after one of them cannot become a static alias on the
/// generated model (or a getter on a relationship path): the alias would
/// redeclare an inherited member and the part file would not compile. Such a
/// field stays reachable through the typed `fields` object, which is why the
/// emitter skips the alias rather than rejecting the field.
///
/// `test/src/schema/beak_reserved_names_test.dart` reads `BeakModel`,
/// `BeakToOneField` and `BeakFieldRef` from `beak_core` and fails when one of
/// them gains a public member that is missing here, so the lists cannot fall
/// behind the classes they mirror.
abstract final class BeakReservedNames {
  /// Members of `BeakModel` and `Object`, which the generated
  /// `final class XModel extends BeakModel` inherits.
  static const Set<String> model = {
    'fields',
    'options',
    'search',
    'table',
    'displayColumnKey',
    'columns',
    'permissions',
    'validationRules',
    'behavior',
    'capabilities',
    'dataSource',
    'createModel',
    'editModel',
    'relationships',
    'relatedModels',
    'softDeletes',
    'formSlots',
    'primaryKey',
    'ref',
    'query',
    'count',
    'sum',
    'avg',
    'sumDecimal',
    'avgDecimal',
    'summary',
    'record',
    'primaryKeyOf',
    'columnsFor',
    'columnByKey',
    'relationshipByKey',
    'toString',
    'noSuchMethod',
    'hashCode',
    'runtimeType',
  };

  /// Members of `BeakToOneField`, `BeakFieldRef` and `Object`, which the
  /// generated `XToOneField` inherits.
  static const Set<String> relation = {
    'fields',
    'model',
    'path',
    'isRequired',
    'key',
    'label',
    'qualifiedKey',
    'readFrom',
    'ownerRecord',
    'relation',
    'target',
    'relationLoad',
    'linkTo',
    'invalid',
    'eq',
    'equalsId',
    'matches',
    'options',
    'hashCode',
    'runtimeType',
    'toString',
    'noSuchMethod',
  };

  /// The words Dart reserves, which no field can be named.
  ///
  /// A schema class is Dart, so `late final String class;` is a syntax error
  /// however the column is spelled. Such a column keeps its stored name with
  /// `@Column(columnName:)` under a field name of another spelling.
  static const Set<String> dartKeywords = {
    'assert',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'else',
    'enum',
    'extends',
    'false',
    'final',
    'finally',
    'for',
    'if',
    'in',
    'is',
    'new',
    'null',
    'rethrow',
    'return',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'var',
    'void',
    'while',
    'with',
  };

  /// The names a schema class cannot take, because the part file generated
  /// for it, or the create-table migration written for it, uses them for
  /// something else in the same library.
  ///
  /// `List`, `String`, `Future`, `Function`, `Enum` and `DateTime` are read by
  /// the generated code as the Dart types; `Schema` and `Migration` are the
  /// worm types every migration extends and takes; `BeakSchema` is what the
  /// class extends; `Resource`, `Column`, `Display`, `BelongsTo`, `HasOne`,
  /// `HasMany` and `BelongsToMany` are the annotations on the class itself. A
  /// class declared under one of them shadows the real one, and the error the
  /// analyzer gives never mentions the class.
  static const Set<String> generatedCodeTypes = {
    'List',
    'String',
    'Future',
    'Function',
    'Enum',
    'DateTime',
    'Schema',
    'Migration',
    'BeakSchema',
    'Resource',
    'Column',
    'Display',
    'BelongsTo',
    'HasOne',
    'HasMany',
    'BelongsToMany',
  };

  /// Names the generated record view cannot declare a getter for.
  ///
  /// The view is an extension type over a `BeakRecord` named `record`, so a
  /// getter of that name would redeclare the representation. Unlike the
  /// other lists there is no alias to skip: the getter is the view, so a
  /// field named like this is a `beak prepare` issue instead.
  static const Set<String> recordView = {'record'};
}
