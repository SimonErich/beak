/// The declarative schema surface: annotations and authoring types.
///
/// Deliberately **not** part of `package:beak_core/beak_core.dart`. The short
/// names that make a schema readable — `@Column`, `@Display`, `@BelongsTo` —
/// are exactly the names Flutter and the panel layer also use: `BeakResource`
/// is already a panel config in `beak_frontend`, and `Column` and `Image` are
/// widgets. Keeping them in their own library means a model file imports them
/// and a panel file never sees them.
///
/// A model file imports both this and the core barrel, since rules and enums
/// live there:
///
/// ```dart
/// import 'package:beak_core/beak_core.dart';
/// import 'package:beak_core/schema.dart';
///
/// part 'product.beak.dart';
///
/// @BeakResource(softDeletes: true, timestamps: true)
/// final class Product extends BeakSchema {
///   @Display()
///   @Column(searchable: true, rules: [BeakMaxLength(255)])
///   late final String name;
/// }
/// ```
library;

export 'src/schema/beak_schema_annotations.dart';
export 'src/schema/beak_schema_types.dart';
