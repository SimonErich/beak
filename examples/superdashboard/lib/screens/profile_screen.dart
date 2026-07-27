import 'package:beak_frontend/beak_frontend.dart';
import 'package:superdashboard/models/models.dart';
import 'package:superdashboard/seeders/seed_ids.dart';
import 'package:obers_ui/obers_ui.dart';

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
