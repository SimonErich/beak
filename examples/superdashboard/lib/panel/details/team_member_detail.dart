import 'package:beak_frontend/beak_frontend.dart';
import 'package:superdashboard/models/models.dart';

/// The team-member show page: a headline strip of role, status, and user,
/// then a two-column body separating the membership timeline from the linked
/// user account.
const BeakBlock teamMemberDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Team member',
      child: BeakFieldGroupBlock([
        TeamMemberColumns.role,
        TeamMemberColumns.status,
        TeamMemberColumns.userId,
      ], columnCount: 3),
    ),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 7),
          title: 'Membership',
          child: BeakFieldGroupBlock([
            TeamMemberColumns.status,
            TeamMemberColumns.joinedAt,
          ], columnCount: 2),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 5),
          title: 'User',
          child: BeakFieldBlock(TeamMemberColumns.userId),
        ),
      ],
    ),
  ],
);
