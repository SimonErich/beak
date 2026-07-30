/// The declarative schema surface: annotations and authoring types.
///
/// Deliberately **not** part of `package:beak_core/beak_core.dart`. The short
/// names that make a schema readable — `@Resource`, `@Column`, `@Display`,
/// `@BelongsTo` — are exactly the names Flutter and the panel layer also use:
/// `Column` and `Image` are widgets, and `BeakResource` is already the panel
/// config in `beak_frontend`. Keeping them in their own library means a model
/// file imports them and a panel file never sees them.
///
/// A model file imports both this and the core barrel, since the generated
/// part file names column and relationship types that live there:
///
/// ```dart
/// import 'package:beak_core/beak_core.dart';
/// import 'package:beak_core/schema.dart';
///
/// part 'product.beak.dart';
///
/// @Resource(softDeletes: true, timestamps: true)
/// final class Product extends BeakSchema {
///   @Display()
///   @Column(searchable: true, rules: [BeakMaxLength(255)])
///   late final String name;
/// }
/// ```
library;

export 'src/schema/beak_schema_annotations.dart';
export 'src/schema/beak_schema_types.dart';
