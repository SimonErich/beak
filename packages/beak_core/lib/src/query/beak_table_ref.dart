import 'package:meta/meta.dart';

/// A typed reference to a physical table or collection.
///
/// Beak's promise is that a user never writes a field or table name as a
/// string. Column constants covered the fields; this covers the tables. Every
/// query, aggregate and route that used to take a bare `table: 'products'`
/// accepts a ref instead, which comes from the model:
///
/// ```dart
/// // Typed — a typo is a compile error.
/// final spec = const ProductModel().query()
///     .orderBy(ProductColumns.price, descending: true);
///
/// final catalogValue = const ProductModel().sum(ProductColumns.price);
/// ```
///
/// The wire format is unchanged: [name] is what crosses the network, so a
/// `BeakQuerySpec` built from a ref serializes byte-identically to one built
/// from a string.
///
/// Deliberately a value class rather than an `extension type` over [String]:
/// the model registry keys a map on it, which needs real `==`/[hashCode]
/// rather than the identity equality an extension type inherits from
/// [Object].
@immutable
final class BeakTableRef {
  /// Creates a reference to the table physically named [name].
  ///
  /// The deserialization and code-generation path. In application code prefer
  /// a model's `ref` (`const ProductModel().ref`), which cannot disagree with
  /// the model it came from.
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
