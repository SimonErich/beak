import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Membership state of a team member.
enum MembershipStatus {
  /// Active member.
  active,

  /// Invited, not yet joined.
  pending,

  /// Removed from the team.
  banned,
}

/// Typed columns of the team-members resource.
abstract final class TeamMemberColumns {
  /// The member's user.
  static const userId = BeakStringColumn(
    key: 'user_id',
    label: 'User',
    visibleOn: {BeakContext.form},
  );

  /// The member's team role, e.g. "Frontend Dev".
  static const role = BeakStringColumn(
    key: 'role',
    label: 'Role',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(80)],
  );

  /// Membership state, shown as a colored badge.
  static const status = BeakEnumColumn<MembershipStatus>(
    key: 'status',
    label: 'Status',
    values: MembershipStatus.values,
    defaultValue: MembershipStatus.active,
    filterable: true,
    badgeColors: {
      MembershipStatus.active: BeakColor.success,
      MembershipStatus.pending: BeakColor.warning,
      MembershipStatus.banned: BeakColor.error,
    },
  );

  /// When the member joined.
  static const joinedAt = BeakDateTimeColumn(
    key: 'joined_at',
    label: 'Joined',
    format: BeakDateFormat.relative,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    userId,
    role,
    status,
    joinedAt,
  ];
}

/// Typed relationships of the team-members resource.
abstract final class TeamMemberRelations {
  /// The underlying user.
  static const user = BeakBelongsTo(
    key: 'user',
    label: 'User',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'user_id',
    searchColumnKeys: ['name', 'email'],
  );
}

/// The team-members resource — users in their team-role context.
final class TeamMemberModel extends BeakModel {
  /// Creates the team-members model.
  const TeamMemberModel();

  @override
  String get table => 'team_members';

  @override
  String get displayColumnKey => 'role';

  @override
  List<BeakColumn> get columns => TeamMemberColumns.values;

  @override
  List<BeakRelationship> get relationships => const [TeamMemberRelations.user];
}
