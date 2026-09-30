/// The shared half of Beak: typed columns, models, relationships, the
/// serializable query spec, and the storage abstraction.
///
/// This is what a model file, the generated registry, a screen and the server
/// all have in common, and it depends on neither Flutter nor `dart:io`. The
/// panel widgets live in `package:beak/panel.dart`, the Shelf host in
/// `package:beak/server.dart`.
///
/// Keeping the widgets out of here is not tidiness: `bin/serve.dart` reaches
/// the registry, the registry reaches the models, and if either of those
/// pulled in `dart:ui` the server would stop compiling ahead-of-time.
///
/// A resource is written once, as an annotated schema class. `beak prepare`
/// reads it and writes the part file next to it: the `ProductModel`
/// descriptor and one typed field reference per property. Everything after
/// that is built from those references, so no table or column name is ever
/// typed as a string:
///
/// ```dart
/// import 'package:beak/beak.dart';
/// import 'package:beak/schema.dart';
///
/// part 'product.beak.dart';
///
/// @Resource()
/// final class Product extends BeakSchema {
///   /// What the product is called.
///   @Display()
///   @Column(searchable: true, sortable: true)
///   late final String name;
///
///   /// Net unit price in euros.
///   @Column(sortable: true, rules: [BeakMin(0)])
///   late final double price;
///
///   /// Whether the product can be sold.
///   @Column(defaultValue: true)
///   late final bool active;
/// }
///
/// // ProductModel and its field references come from the generated part.
/// final cheap = const ProductModel().query(
///   filter: BeakFilter.allOf([
///     ProductModel.active.eq(true),
///     ProductModel.price.lt(10),
///   ]),
/// );
/// ```
library;

export 'package:beak_core/beak_core.dart';
