import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_superdashboard/models/models.dart';

/// The user show page: an identity strip, an about/contact column beside a
/// stats sidebar, and a tab per relation (orders, invoices, activity,
/// skills) — everything about one person in one readable screen.
const BeakBlock userDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Profile',
      child: BeakFieldGroupBlock([
        UserColumns.name,
        UserColumns.role,
        UserColumns.status,
        UserColumns.online,
      ], columnCount: 4),
    ),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 8),
          title: 'About',
          child: BeakColumnBlock(
            children: [
              BeakFieldBlock(UserColumns.bio),
              BeakFieldGroupBlock([
                UserColumns.email,
                UserColumns.phone,
                UserColumns.company,
                UserColumns.city,
                UserColumns.country,
                UserColumns.countryCode,
              ]),
            ],
          ),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 4),
          title: 'Metrics',
          child: BeakColumnBlock(
            children: [
              BeakFieldBlock(UserColumns.avatar),
              BeakFieldGroupBlock([
                UserColumns.balance,
                UserColumns.tasksDone,
                UserColumns.projectsDone,
              ]),
            ],
          ),
        ),
      ],
    ),
    BeakTabsBlock(
      tabs: [
        BeakTabBlockItem(
          label: 'Orders',
          content: BeakRelationBlock(UserRelations.orders),
        ),
        BeakTabBlockItem(
          label: 'Invoices',
          content: BeakRelationBlock(UserRelations.invoices),
        ),
        BeakTabBlockItem(
          label: 'Activity',
          content: BeakRelationBlock(UserRelations.activities),
        ),
        BeakTabBlockItem(
          label: 'Skills',
          content: BeakRelationBlock(UserRelations.skills),
        ),
      ],
    ),
  ],
);
