import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../../habitats/models/habitat.dart';
import 'keeper_profile.dart';

part 'keeper.beak.dart';

/// How senior a keeper is.
enum KeeperRole {
  /// Runs the aviary.
  head,

  /// Leads a habitat.
  senior,

  /// Learns on the job.
  apprentice,

  /// Helps on weekends.
  volunteer,
}

/// A person who looks after birds.
// --8<-- [start:Keeper]
@Resource(softDeletes: true)
final class Keeper extends BeakSchema {
  /// Full name.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// Work email.
  @Column(semantic: BeakSemantic.email(), unique: true)
  late final String email;

  /// Seniority.
  @Column(defaultValue: KeeperRole.apprentice, filterable: true)
  @Badges<KeeperRole>({
    KeeperRole.head: BeakColor.primary,
    KeeperRole.senior: BeakColor.info,
    KeeperRole.apprentice: BeakColor.warning,
    KeeperRole.volunteer: BeakColor.muted,
  })
  late final KeeperRole role;

  /// A portrait.
  @Image(
    storagePath: 'keepers',
    maxSizeInBytes: 2097152,
    allowedTypes: [BeakFileType.png, BeakFileType.jpeg],
  )
  late final BeakImageRef? avatar;

  /// A short biography.
  late final BeakText? bio;

  /// The keeper's certification details (has-one relationship).
  @HasOne(owned: true)
  late final KeeperProfile? profile;

  /// The habitats the keeper looks after (many-to-many, through a pivot table).
  @BelongsToMany(pivotTable: 'habitat_keeper', searchOn: [#name])
  late final List<Habitat> habitats;
}
// --8<-- [end:Keeper]
