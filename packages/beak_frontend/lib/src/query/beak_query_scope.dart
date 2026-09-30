import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals_flutter.dart';

import '../data/beak_run.dart';
import '../localization/beak_localizations.dart';
import 'beak_query_controller.dart';

/// Supplies one controller to list, filters, summaries, charts and export.
class BeakQueryScope extends HookWidget {
  /// URL synchronization is optional for embedded lists without a router.
  const BeakQueryScope({
    required this.controller,
    required this.child,
    this.persistInUrl = false,
    super.key,
  });

  /// Framework-owned controller, shared without transferring disposal ownership.
  final BeakQueryController controller;

  /// Composed content using the same active query.
  final Widget child;

  /// Reflects applied query state in the current resource URL.
  final bool persistInUrl;

  /// Finds the nearest composed list.
  static BeakQueryController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_QueryScope>()?.controller;

  /// Requires an enclosing query scope.
  static BeakQueryController of(BuildContext context) =>
      maybeOf(context) ??
      (throw const BeakConfigurationException(
        'This surface requires a BeakQueryScope.',
      ));

  @override
  Widget build(BuildContext context) {
    final initial = useMemoized(() => controller.state.peek(), [controller]);
    final error = useState<BeakException?>(null);
    final ready = useState(false);
    final router = persistInUrl ? GoRouter.of(context) : null;
    final uri = persistInUrl ? GoRouterState.of(context).uri : null;
    useEffect(() {
      var active = true;
      if (uri == null) return null;
      beakRun(() async {
        final restored = BeakQueryController.readUri(uri);
        controller.restore(restored ?? initial);
      }).then((result) {
        if (!active || !context.mounted) return;
        error.value = switch (result) {
          BeakErr(:final error) => error,
          _ => null,
        };
        ready.value = true;
      });
      return () => active = false;
    }, [controller, uri]);
    useEffect(() {
      if (router == null || !ready.value || error.value != null) return null;
      return effect(() {
        controller.state.value;
        final current = router.routeInformationProvider.value.uri;
        final next = controller.writeUri(current);
        if (current == next) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted &&
              router.routeInformationProvider.value.uri == current) {
            router.replace<void>(next.toString());
          }
        });
      });
    }, [controller, router, ready.value, error.value]);
    return _QueryScope(
      controller: controller,
      child: error.value == null
          ? child
          : OiEmptyState.error(
              description: BeakLocalizations.of(
                context,
              ).errorMessage(error.value!),
              actionLabel: BeakLocalizations.of(context).resetView,
              onAction: () {
                error.value = null;
                if (router != null && uri != null) {
                  final params = {...uri.queryParameters}..remove('list');
                  router.replace<void>(
                    uri.replace(queryParameters: params).toString(),
                  );
                }
              },
            ),
    );
  }
}

class _QueryScope extends InheritedWidget {
  const _QueryScope({required this.controller, required super.child});
  final BeakQueryController controller;
  @override
  bool updateShouldNotify(_QueryScope oldWidget) =>
      oldWidget.controller != controller;
}
