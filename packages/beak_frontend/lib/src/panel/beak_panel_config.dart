import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../data/beak_data_changes.dart';
import '../localization/beak_localizations.dart';
import '../formatting/beak_formatting.dart';
import '../presentation/beak_action_presentation.dart';
import 'beak_auth_config.dart';
import 'beak_destination.dart';
import 'beak_maintenance_config.dart';
import 'beak_notifications.dart';
import 'beak_navigation.dart';
import 'beak_resource.dart';
import 'beak_screen.dart';
import 'beak_resource_screen.dart';

export 'beak_resource.dart';

/// Everything a Beak panel needs at startup: the resources, the backend
/// origin, and optional theming.
///
/// This is the single declarative entry point of a Beak admin app — hand it
/// to a [BeakPanel] and the whole UI (navigation, routing, generated CRUD
/// pages) is stood up from it. Compose it once, typically in a builder so
/// tests can vary the API origin. A [BeakScreen] mounted at `/` is the
/// panel's landing page; without one, `/` forwards to [home] or the first
/// navigation destination.
///
/// ```dart
/// BeakPanelConfig buildPanelConfig({
///   String apiBaseUrl = 'http://localhost:8080',
/// }) => BeakPanelConfig(
///   title: 'Beak Admin',
///   apiBaseUrl: apiBaseUrl,
///   resources: const [
///     BeakResource(
///       model: ProductModel(),
///       icon: BeakIconToken(OiIcons.package),
///     ),
///     BeakResource(
///       model: UserModel(),
///       icon: BeakIconToken(OiIcons.users),
///     ),
///   ],
///   pages: [
///     BeakScreen(
///       path: '/',
///       title: 'Overview',
///       icon: const BeakIconToken(OiIcons.layoutDashboard),
///       body: BeakGridBlock(
///         columns: 12,
///         children: [
///           BeakMetricBlock(
///             label: 'Products',
///             aggregate: const ProductModel().count(),
///           ),
///         ],
///       ),
///     ),
///   ],
/// );
/// ```
final class BeakPanelConfig {
  /// Creates a panel configuration.
  // --8<-- [start:BeakPanelConfig]
  const BeakPanelConfig({
    required this.title,
    required this.resources,
    this.apiBaseUrl = 'http://localhost:8080',
    this.pages = const [],
    this.auth,
    this.maintenance,
    this.theme,
    this.darkTheme,
    this.initialThemeMode = OiThemeMode.system,
    this.locale,
    this.formatting,
    this.supportedLocales = BeakLocalizations.supportedLocales,
    this.localizationsDelegates = const [],
    this.sidebarCollapsible = true,
    this.sidebarDefaultCollapsed = false,
    this.home,
    this.notifications,
    this.navigation,
    this.refreshPolicy,
    this.shellActions,
    this.mapException,
  });
  // --8<-- [end:BeakPanelConfig]

  /// The panel title, shown in the shell and the login screen.
  final String title;

  /// The resources the panel exposes, in navigation order.
  final List<BeakResource> resources;

  /// Resources in navigation order, retaining declaration order for equal ranks.
  List<BeakResource> get navigationResources {
    final indexed = resources.indexed.toList()
      ..sort((left, right) {
        final rank = left.$2.navigationRank.compareTo(right.$2.navigationRank);
        return rank == 0 ? left.$1.compareTo(right.$1) : rank;
      });
    return [for (final entry in indexed) entry.$2];
  }

  /// Origin of the `beak_backend` server (e.g. `http://localhost:8080`).
  final String apiBaseUrl;

  /// Custom, non-resource screens, in navigation order.
  final List<BeakScreen> pages;

  /// Authentication routes; `null` mounts only a default `/login`.
  final BeakAuthConfig? auth;

  /// Maintenance / coming-soon routes; `null` mounts neither.
  final BeakMaintenanceConfig? maintenance;

  /// The light theme (defaults to `OiThemeData.light()`).
  final OiThemeData? theme;

  /// The dark theme (defaults to `OiThemeData.dark()`).
  final OiThemeData? darkTheme;

  /// The theme mode the panel starts in; toggled live from the shell.
  final OiThemeMode initialThemeMode;

  /// Explicit app locale; `null` follows the platform's supported locale.
  final Locale? locale;

  /// Shared date, number and currency display policy.
  final BeakFormatting? formatting;

  /// Locales supported by the panel and its application-owned labels.
  final Iterable<Locale> supportedLocales;

  /// Application translation delegates, installed before Beak's default.
  ///
  /// Beak always appends its delegate. A custom delegate for [BeakLocalizations]
  /// may override that default when translating framework text into another
  /// language; application resource labels use their own delegate.
  final Iterable<LocalizationsDelegate<Object?>> localizationsDelegates;

  /// Whether the sidebar can collapse to an icon rail.
  final bool sidebarCollapsible;

  /// Whether the sidebar starts collapsed (an icon-only rail).
  final bool sidebarDefaultCollapsed;

  /// Where `/` sends the user when no [BeakScreen] claims it, for example a
  /// resource's list page or an overview screen. Sign-in and the error pages'
  /// back actions land here. `null` picks the first visible navigation
  /// destination. Ignored while its resource is not visible.
  final BeakDestination? home;

  /// Shared opt-in periodic and foreground refresh for remote changes.
  final BeakRefreshPolicy? refreshPolicy;

  /// Optional primary rail and contextual navigation.
  final BeakNavigation? navigation;

  /// Binds a model's rows to the shell's notification bell; `null` shows no
  /// bell.
  final BeakNotificationSource? notifications;

  /// Host-owned shell controls, such as sign out or a locale selector.
  final List<Widget> Function(BuildContext context)? shellActions;

  /// Maps known host transport/domain failures for every bound resource.
  /// Unknown exceptions propagate so programming failures are not hidden.
  final BeakException? Function(Exception exception, StackTrace stackTrace)?
  mapException;

  /// Returns a copy with the given parts replaced.
  ///
  /// Keeps a shared configuration and changes one thing about it, such as a
  /// staging title or a maintenance window.
  ///
  /// ```dart
  /// final staging = config.copyWith(
  ///   title: 'Acme — staging',
  ///   maintenance: const BeakMaintenanceConfig(),
  /// );
  /// ```
  BeakPanelConfig copyWith({
    String? title,
    List<BeakResource>? resources,
    String? apiBaseUrl,
    List<BeakScreen>? pages,
    BeakAuthConfig? auth,
    BeakMaintenanceConfig? maintenance,
    OiThemeData? theme,
    OiThemeData? darkTheme,
    OiThemeMode? initialThemeMode,
    Locale? locale,
    BeakFormatting? formatting,
    Iterable<Locale>? supportedLocales,
    Iterable<LocalizationsDelegate<Object?>>? localizationsDelegates,
    bool? sidebarCollapsible,
    bool? sidebarDefaultCollapsed,
    BeakDestination? home,
    BeakNotificationSource? notifications,
    BeakNavigation? navigation,
    BeakRefreshPolicy? refreshPolicy,
    List<Widget> Function(BuildContext context)? shellActions,
    BeakException? Function(Exception exception, StackTrace stackTrace)?
    mapException,
  }) => BeakPanelConfig(
    title: title ?? this.title,
    resources: resources ?? this.resources,
    apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
    pages: pages ?? this.pages,
    auth: auth ?? this.auth,
    maintenance: maintenance ?? this.maintenance,
    theme: theme ?? this.theme,
    darkTheme: darkTheme ?? this.darkTheme,
    initialThemeMode: initialThemeMode ?? this.initialThemeMode,
    locale: locale ?? this.locale,
    formatting: formatting ?? this.formatting,
    supportedLocales: supportedLocales ?? this.supportedLocales,
    localizationsDelegates:
        localizationsDelegates ?? this.localizationsDelegates,
    sidebarCollapsible: sidebarCollapsible ?? this.sidebarCollapsible,
    sidebarDefaultCollapsed:
        sidebarDefaultCollapsed ?? this.sidebarDefaultCollapsed,
    home: home ?? this.home,
    notifications: notifications ?? this.notifications,
    navigation: navigation ?? this.navigation,
    refreshPolicy: refreshPolicy ?? this.refreshPolicy,
    shellActions: shellActions ?? this.shellActions,
    mapException: mapException ?? this.mapException,
  );

  void _checkDestinations() {
    if (resources.isEmpty && pages.isEmpty) {
      throw const BeakConfigurationException(
        'A panel needs at least one resource or page to show.',
      );
    }
    _checkNavigation();
    _checkAuth();
    final home = this.home;
    if (home == null) return;
    final declared = switch (home) {
      final BeakResource resource => resources.any(
        (candidate) => candidate.model.table == resource.model.table,
      ),
      final BeakScreen screen => pages.any(
        (candidate) => candidate.path == screen.path,
      ),
      _ => false,
    };
    if (!declared) {
      throw BeakConfigurationException(
        'The home destination "${home.location}" must be one of the '
        "panel's resources or pages.",
      );
    }
    if (home.location != '/' && pages.any((page) => page.path == '/')) {
      throw BeakConfigurationException(
        'The home destination "${home.location}" is unreachable: a screen '
        'already claims "/".',
      );
    }
  }

  /// Registration and recovery are flows of a [BeakAuthAdapter]; the default
  /// session store offers neither, so asking for them without an adapter would
  /// mount no route at all.
  void _checkAuth() {
    final auth = this.auth;
    if (auth == null || auth.adapter != null) return;
    for (final (name, requested) in [
      ('register', auth.register),
      ('recover', auth.recover),
    ]) {
      if (requested) {
        throw BeakConfigurationException(
          'BeakAuthConfig sets `$name: true`, but the default session store '
          'has no $name flow. Give the config an `adapter` that offers it, '
          'or leave `$name` off.',
        );
      }
    }
  }

  /// A composed list refers to actions by key. A key that matches nothing the
  /// resource offers would be dropped without a word, so it is refused here.
  void _checkActionPresentations(BeakResource resource) {
    final modelKeys = [
      for (final action in resource.model.behavior.actions)
        BeakActionPresentation.keyOfModelAction(action),
    ];
    final rowKeys = {
      'view',
      'edit',
      resource.deleteAction.key,
      'duplicate',
      for (final action in resource.recordActions) action.key,
      ...modelKeys,
    };
    final bulkKeys = {
      'export',
      for (final action in resource.bulkActions) action.key,
      ...modelKeys,
    };
    for (final screen in resource.screens) {
      if (screen is! BeakTableScreen) continue;
      final definition = screen.definition;
      if (definition == null) continue;
      final checks = <(String, List<BeakActionPresentation>?, Set<String>)>[
        ('rowActions', definition.rowActions, rowKeys),
        ('bulkActions', definition.bulkActions, bulkKeys),
      ];
      for (final (name, presentations, known) in checks) {
        for (final presentation
            in presentations ?? const <BeakActionPresentation>[]) {
          if (!known.contains(presentation.key)) {
            throw BeakConfigurationException(
              'The "${resource.model.table}" list names the action '
              '"${presentation.key}" in $name, but the resource offers only '
              '${(known.toList()..sort()).join(', ')}.',
            );
          }
        }
      }
    }
  }

  /// Every navigation item must lead somewhere the panel has: a resource item
  /// names a declared resource, a screen item one of the [pages]. Otherwise the
  /// item links to the not-found page, or silently vanishes.
  void _checkNavigation() {
    for (final section
        in navigation?.sections ?? const <BeakNavigationSection>[]) {
      for (final item in section.items) {
        if (item.model case final BeakModel model
            when !resources.any(
              (resource) => resource.model.table == model.table,
            )) {
          throw BeakConfigurationException(
            'The "${section.label}" navigation section lists "${model.table}", '
            'but the panel declares no resource for it.',
          );
        }
        if (item.screen case final BeakScreen screen
            when !pages.any((page) => page.path == screen.path)) {
          throw BeakConfigurationException(
            'The "${section.label}" navigation section lists the screen at '
            '"${screen.path}", but it is not among the panel\'s pages.',
          );
        }
      }
    }
  }

  /// Builds a [BeakModelRegistry] over every resource model, in declaration
  /// order.
  ///
  /// Called once at startup so the data layer can resolve a table name back
  /// to its model (primary-key metadata, relations). Registering the same
  /// table twice is a configuration error surfaced by the registry.
  BeakModelRegistry buildRegistry() {
    final registry = BeakModelRegistry();
    _checkDestinations();
    for (final resource in resources) {
      for (final role in BeakScreenRole.values) {
        resource.screenFor(role);
      }
      for (final field in resource.globalSearchSources) {
        if (field.model.table != resource.model.table ||
            field is! BeakScalarField<Object>) {
          throw BeakConfigurationException(
            'Global search for "${resource.model.table}" requires scalar fields rooted at that model.',
          );
        }
      }
      final filterKeys = <String>{};
      for (final filter in resource.filters) {
        if (!filterKeys.add(filter.key)) {
          throw BeakConfigurationException(
            'The "${resource.model.table}" resource declares two filters on '
            '"${filter.key}". They would share one state, so each field takes '
            'a single filter; use a choice filter for several predicates.',
          );
        }
      }
      _checkActionPresentations(resource);
      for (final screen in resource.screens) {
        if (screen is BeakTableScreen &&
            screen.query != null &&
            screen.query!.table != resource.model.table) {
          throw BeakConfigurationException(
            'Table screen query must target "${resource.model.table}".',
          );
        }
        if (screen is BeakFormScreen &&
            screen.roles.contains(BeakScreenRole.list)) {
          throw const BeakConfigurationException(
            'A form screen cannot serve the list route.',
          );
        }
      }
      registry.register(resource.model);
    }
    void registerRelated(BeakModel model, Set<String> visited) {
      if (!visited.add(model.table)) return;
      for (final related in model.relatedModels) {
        final existing = registry.byTable(related.table);
        if (existing == null) {
          registry.register(related);
        } else if (existing.runtimeType != related.runtimeType) {
          throw BeakConfigurationException(
            'Conflicting models for related table "${related.table}".',
          );
        }
        registerRelated(existing ?? related, visited);
      }
    }

    final visited = <String>{};
    for (final resource in resources) {
      registerRelated(resource.model, visited);
    }
    // A list that saves views writes them to the store's model, which is
    // usually no resource of the panel and so is registered here.
    for (final resource in resources) {
      for (final screen in resource.screens) {
        if (screen is! BeakTableScreen) continue;
        if (screen.definition?.savedViews?.model case final BeakModel views
            when registry.byTable(views.table) == null) {
          registry.register(views);
          registerRelated(views, visited);
        }
      }
    }
    return registry;
  }
}
