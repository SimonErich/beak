import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'profile.beak.dart';

/// Profile schema; all metadata and typed helpers are generated.
@Resource()
final class Profile extends BeakSchema {
  /// A reusable delivery profile.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// Delivery address for this profile.
  late final String address;
}
