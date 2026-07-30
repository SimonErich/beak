import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'tag.beak.dart';

/// A free-form label products are tagged with.
@Resource()
final class Tag extends BeakSchema {
  /// What the tag is called.
  @Display()
  @Column(
    searchable: true,
    sortable: true,
    unique: true,
    rules: [BeakMaxLength(60)],
  )
  late final String name;
}
