/// The annotations a model file is written with.
///
/// Kept out of `package:beak/beak.dart` on purpose: `@Resource`, `@Column`
/// and `@Image` are deliberately short names that would collide with Flutter's
/// `Column` and `Image` widgets. A model file imports both libraries — this
/// one for the annotations, the panel one for the types its generated part
/// file names — and nothing else needs this at all.
///
/// ```dart
/// import 'package:beak/beak.dart';
/// import 'package:beak/schema.dart';
///
/// part 'product.beak.dart';
///
/// @Resource(softDeletes: true)
/// final class Product extends BeakSchema {
///   /// What the product is called.
///   @Display()
///   @Column(searchable: true)
///   late final String name;
/// }
/// ```
library;

export 'package:beak_core/schema.dart';
