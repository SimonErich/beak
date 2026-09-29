import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'keeper.dart';

part 'keeper_profile.beak.dart';

/// Certification details that belong to exactly one keeper.
@Resource()
final class KeeperProfile extends BeakSchema {
  /// The licence the keeper holds.
  @Display()
  @Column(searchable: true)
  late final String certification;

  /// The number the keeper answers on when a bird escapes.
  @Column(semantic: BeakSemantic.phone())
  late final String? emergencyPhone;

  /// When the keeper was first certified.
  late final DateTime? certifiedSince;

  /// The keeper the profile describes.
  @BelongsTo(onDelete: BeakOnDelete.cascade, inverse: false)
  late final Keeper keeper;
}
