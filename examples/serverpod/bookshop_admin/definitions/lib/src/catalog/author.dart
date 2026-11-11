import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/schema.dart';
import '../generated/definitions_support.dart';

part 'package:bookshop_definitions/src/generated/models/catalog/author.beak.dart';

/// Someone whose books the shop sells.
@Resource()
@ServerpodAdminModel(
  area: 'catalog',
  create: BeakHandling.stock,
  update: BeakHandling.stock,
)
final class Author extends BeakSchema {
  /// The name printed on the cover.
  @Display()
  late final String name;

  /// A short biography for the author page.
  late final String? bio;

  /// The author's own website.
  late final String? website;
}
