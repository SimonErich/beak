import 'package:meta/meta.dart';

/// A typed reference to a physical table or collection.
///
/// Beak's promise is that a user never writes a field or table name as a
/// string. Generated field references cover the fields; the model covers the
/// tables. Queries and aggregates start from the model (`model.query()`,
/// `model.count()`), and an API that takes a table name reads it from
/// `model.table`, so the name is never retyped. A model's `ref` wraps that
/// same name in this typed handle, for code that wants to pass a table
/// around as a value:
///
/// ```dart
/// const products = ProductModel();
///
/// // Typed — a typo is a compile error.
/// final spec = products.query(filter: ProductModel.active.eq(true));
/// final sellable = products.count(filter: ProductModel.active.eq(true));
///
/// final BeakTableRef table = products.ref;
/// ```
///
/// [name] is the table's stored name: the same string `model.table` returns
/// and a query spec carries on the wire.
///
/// Deliberately a value class rather than an `extension type` over [String]:
/// an extension type is erased to its `String` at runtime, so every string
/// would pass an `is BeakTableRef` check and a ref could not be told apart
/// from an arbitrary name.
@immutable
final class BeakTableRef {
  /// Creates a reference to the table physically named [name].
  ///
  /// A model's `ref` builds one from the model's own table. Application code
  /// takes that (`const ProductModel().ref`) rather than naming a table here,
  /// so the ref cannot disagree with the model it came from.
  const BeakTableRef.raw(this.name);

  /// Physical table/collection name, as it crosses the wire.
  final String name;

  @override
  bool operator ==(Object other) => other is BeakTableRef && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}
