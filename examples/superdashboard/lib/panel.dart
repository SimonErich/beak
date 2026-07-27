import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import 'models/showcase/notification.dart';
import 'screens/charts_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/email_screen.dart';
import 'screens/faq_screen.dart';
import 'screens/files_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/icons_screen.dart';
import 'screens/invoice_screen.dart';
import 'screens/maps_screen.dart';
import 'screens/pricing_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/starter_screen.dart';
import 'screens/typography_screen.dart';
import 'screens/ui_kit_screen.dart';

/// The last word on this panel's configuration.
///
/// [defaults] already carries the 17 navigable resources, their icons and
/// their sections from `beak.yaml`, each one adjusted by its own file under
/// `lib/resources/`. What is added here is what `beak.yaml` deliberately does
/// not describe: the app screens, the notification feed, and the auth and
/// maintenance behaviour.
BeakPanelConfig beakPanel(BeakPanelConfig defaults) => defaults.copyWith(
  initialThemeMode: OiThemeMode.light,
  notifications: const BeakNotificationSource(
    model: NotificationModel(),
    titleField: NotificationColumns.title,
    bodyField: NotificationColumns.body,
    timeField: NotificationColumns.createdAt,
    readField: NotificationColumns.isRead,
    categoryField: NotificationColumns.level,
  ),
  // The generated dashboard at `/` comes from `lib/dashboard.dart`; these are
  // the fifteen app screens beside it.
  pages: [
    ...defaults.pages,
    buildEmailScreen(),
    buildChatScreen(),
    buildFilesScreen(),
    buildInvoiceScreen(),
    buildProfileScreen(),
    buildPricingScreen(),
    buildFaqScreen(),
    buildChartsScreen(),
    buildGalleryScreen(),
    buildUiKitScreen(),
    buildTypographyScreen(),
    buildIconsScreen(),
    buildMapsScreen(),
    buildStarterScreen(),
  ],
  auth: BeakAuthConfig(
    // Demo sign-in is cosmetic — the panel is not guarded.
    onLogin: (email, password) async => true,
    onRegister: (name, email, password) async => true,
    onRecover: (email) async => true,
    // Auto-lock after inactivity; the lock screen is also always at /lock.
    idleLockTimeout: const Duration(minutes: 10),
    lockUserName: 'Aisha Rahman',
    onUnlock: (password) async => true,
  ),
  maintenance: BeakMaintenanceConfig(
    maintenanceTitle: 'Under maintenance',
    maintenanceDescription:
        'We are performing scheduled maintenance and will be back shortly.',
    estimatedReturn: DateTime.utc(2026, 7, 8, 12),
    comingSoonTitle: 'Coming soon',
    comingSoonDescription: 'Something great is on the way.',
    launchAt: DateTime.utc(2026, 8, 1),
  ),
);
