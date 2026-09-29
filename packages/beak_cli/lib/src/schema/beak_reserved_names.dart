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

  /// Names the generated record view cannot declare a getter for.
  ///
  /// The view is an extension type over a `BeakRecord` named `record`, so a
  /// getter of that name would redeclare the representation. Unlike the
  /// other lists there is no alias to skip: the getter is the view, so a
  /// field named like this is a `beak prepare` issue instead.
  static const Set<String> recordView = {'record'};
}
