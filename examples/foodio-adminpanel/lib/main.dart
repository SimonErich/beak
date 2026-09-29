import 'package:beak/panel.dart';
import 'package:flutter/widgets.dart';
import 'foodio_resources.dart';
import 'navigation.dart';
import 'models/models.dart';
import 'pages/operations.dart';
import 'theme/gabel_theme.dart';

/// The application is one themed panel and declarative resource definitions.
void main() => runApp(BeakPanel(config: foodioPanel()));

/// Public composition seam for widget tests and alternate backend environments.
BeakPanelConfig foodioPanel({
  String apiBaseUrl = const String.fromEnvironment(
    'BEAK_API_BASE_URL',
    defaultValue: 'http://localhost:8081',
  ),
}) => BeakPanelConfig(
  // --8<-- [start:foodioPanelConfig]
  title: 'Gabel Admin',
  // --8<-- [start:foodioThemes]
  theme: gabelTheme(),
  darkTheme: gabelTheme(dark: true),
  // --8<-- [end:foodioThemes]
  apiBaseUrl: apiBaseUrl,
  locale: const Locale('en'),
  // --8<-- [start:foodioFormatting]
  formatting: const BeakFormatting(
    locale: 'en_US',
    currency: 'EUR',
    datePattern: 'EEE d MMM',
    dateInputPattern: 'd MMM yyyy',
    timeZoneOffsetMinutes: 120,
    dateTimePattern: 'dd MMM yyyy · HH:mm',
  ),
  // --8<-- [end:foodioFormatting]
  resources: foodioResources(),
  pages: foodioPages(),
  navigation: foodioNavigation,
  sidebarCollapsible: false,
  shellActions: foodioShellActions,
  notifications: BeakNotificationSource(
    titleField: NotificationModel.title,
    bodyField: NotificationModel.body,
    timeField: NotificationModel.occurredAt,
    readField: NotificationModel.isRead,
  ),
  refreshPolicy: const BeakRefreshPolicy(
    interval: Duration(seconds: 30),
    onResume: true,
  ),
  // --8<-- [end:foodioPanelConfig]
);
