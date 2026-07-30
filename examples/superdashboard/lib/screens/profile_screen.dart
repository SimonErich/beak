import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';
import 'package:superdashboard/seeders/seed_ids.dart';
import 'package:beak/ui.dart';

/// The profile page — a seeded hero user's identity, avatar, role, and bio.
BeakScreen buildProfileScreen() => const BeakScreen(
  path: '/profile',
  title: 'Profile',
  icon: BeakIconToken(OiIcons.user),
  section: 'Pages',
  body: BeakProfileBlock(
    model: UserModel(),
    recordId: SeedIds.userAisha,
    nameField: UserColumns.name,
    emailField: UserColumns.email,
    roleField: UserColumns.role,
    avatarField: UserColumns.avatar,
    bioField: UserColumns.bio,
  ),
);
