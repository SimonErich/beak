import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'user.dart';

part 'team_member.beak.dart';

/// Membership state of a team member.
enum MembershipStatus {
  /// Active member.
  active,

  /// Invited, not yet joined.
  pending,

  /// Removed from the team.
  banned,
}

/// The team-members resource — users in their team-role context.
@Resource()
final class TeamMember extends BeakSchema {
  /// The underlying user.
  @BelongsTo(searchOn: ['name', 'email'])
  late final User? user;

  /// The member's team role, e.g. "Frontend Dev".
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(80)])
  late final String role;

  /// Membership state, shown as a colored badge.
  @Column(filterable: true, defaultValue: MembershipStatus.active)
  @Badges({
    MembershipStatus.active: BeakColor.success,
    MembershipStatus.pending: BeakColor.warning,
    MembershipStatus.banned: BeakColor.error,
  })
  late final MembershipStatus? status;

  /// When the member joined.
  @Column(label: 'Joined', sortable: true, format: BeakDateFormat.relative)
  late final DateTime? joinedAt;
}
