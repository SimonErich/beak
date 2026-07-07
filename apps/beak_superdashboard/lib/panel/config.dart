import 'package:beak_frontend/beak_frontend.dart';
import 'package:obers_ui/obers_ui.dart';

import '../screens/charts_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/email_screen.dart';
import '../screens/faq_screen.dart';
import '../screens/files_screen.dart';
import '../screens/gallery_screen.dart';
import '../screens/icons_screen.dart';
import '../screens/invoice_screen.dart';
import '../screens/pricing_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/starter_screen.dart';
import '../screens/typography_screen.dart';
import '../screens/ui_kit_screen.dart';
import 'dashboard.dart';
import 'resources.dart';

/// Builds the whole superdashboard panel: a custom analytics dashboard at
/// `/`, every model as a navigable resource, and config-driven auth and
/// maintenance routes — the single declarative entry point of the demo.
///
/// [apiBaseUrl] points the panel's HTTP data source at the running
/// superdashboard server (`bin/server.dart`).
BeakPanelConfig buildSuperdashboardConfig({
  String apiBaseUrl = 'http://localhost:8080',
}) => BeakPanelConfig(
  title: 'Beak Superdashboard',
  apiBaseUrl: apiBaseUrl,
  initialThemeMode: OiThemeMode.light,
  resources: buildResources(),
  pages: [
    buildDashboardScreen(),
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
    buildStarterScreen(),
  ],
  auth: BeakAuthConfig(
    // Demo sign-in is cosmetic — the panel is not guarded.
    onLogin: (email, password) async => true,
    onRegister: (name, email, password) async => true,
    onRecover: (email) async => true,
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
