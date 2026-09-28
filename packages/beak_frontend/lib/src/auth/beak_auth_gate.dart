import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals_flutter.dart';

import '../localization/beak_localizations.dart';
import 'beak_auth_adapter.dart';

/// Protects panel contents while the existing session/permissions resolve.
class BeakAuthGate extends StatelessWidget {
  /// Auth routes belong outside this gate, so their form survives login.
  const BeakAuthGate({required this.adapter, required this.child, super.key});

  /// Existing backend session authority.
  final BeakAuthAdapter adapter;

  /// Protected content rendered only after access has resolved positively.
  final Widget child;

  @override
  Widget build(BuildContext context) => Watch((context) {
    final strings = BeakLocalizations.of(context);
    return switch (adapter.state.value) {
      BeakAuthAuthenticated(:final identity) when identity.canAccessPanel =>
        KeyedSubtree(key: ValueKey(identity.id), child: child),
      BeakAuthFailure(:final error) => Center(
        child: OiColumn(
          breakpoint: context.breakpoint,
          gap: OiResponsive(context.spacing.md),
          children: [
            OiLabel.body(strings.authError(error)),
            OiButton.primary(label: strings.retry, onTap: adapter.refresh),
            OiButton.ghost(
              label: strings.authBackToLogin,
              onTap: adapter.logout,
            ),
          ],
        ),
      ),
      _ => Center(child: OiLabel.body(strings.loading)),
    };
  });
}

/// Bridges the adapter's signal to GoRouter without mirroring session state.
class BeakAuthRouterRefresh extends ChangeNotifier {
  /// Observes the exact committed auth state from [adapter].
  BeakAuthRouterRefresh(this.adapter) {
    _cleanup = effect(() {
      adapter.state.value;
      notifyListeners();
    });
  }

  /// Existing backend session authority.
  final BeakAuthAdapter adapter;
  late final void Function() _cleanup;

  /// Redirect decision shared by standalone and embedded panel routers.
  ///
  /// Loading/failure remain on the requested URL under [BeakAuthGate]. Auth
  /// forms themselves are outside the gate and remain mounted across login.
  String? redirect(String path) {
    final authPath = const {'/login', '/register', '/recover'}.contains(path);
    final publicPath =
        authPath ||
        const {'/500', '/maintenance', '/coming-soon'}.contains(path);
    return switch (adapter.state.value) {
      BeakAuthGuest() when !publicPath => '/login',
      BeakAuthAuthenticated(:final identity)
          when !identity.canAccessPanel && !publicPath && path != '/403' =>
        '/403',
      BeakAuthAuthenticated(:final identity)
          when identity.canAccessPanel && authPath =>
        '/',
      _ => null,
    };
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
