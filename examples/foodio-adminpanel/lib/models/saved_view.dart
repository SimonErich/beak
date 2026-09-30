import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'saved_view.beak.dart';

// --8<-- [start:foodioSavedViewSchema]
/// SavedView configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class SavedView extends BeakSchema {
  /// Name.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Resource.
  @Column(defaultValue: 'orders')
  late final String resource;

  /// Complete versioned query, sort, pagination and column preferences.
  @Column(defaultValue: '{}')
  late final String state;

  /// Owner.
  @Column(defaultValue: 'Marie Novak')
  late final String owner;

  /// Shared.
  @Column(defaultValue: true)
  late final bool shared;
}
// --8<-- [end:foodioSavedViewSchema]
