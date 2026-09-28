import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals_flutter.dart';

import '../localization/beak_localizations.dart';
import '../overlays/beak_overlays.dart';
import 'beak_auth_adapter.dart';
import 'beak_auth_view_model.dart';

/// Standard localized logout action for a configured authentication adapter.
class BeakLogoutButton extends HookWidget {
  /// Calls the existing session authority rather than clearing a second store.
  const BeakLogoutButton({required this.adapter, super.key});

  /// Backend session authority.
  final BeakAuthAdapter adapter;

  @override
  Widget build(BuildContext context) {
    final strings = BeakLocalizations.of(context);
    final vm = useMemoized(() => BeakAuthViewModel(adapter: adapter), [
      adapter,
    ]);
    useEffect(() => vm.dispose, [vm]);
    return Watch(
      (context) => OiButton.ghost(
        label: strings.authSignOut,
        loading: vm.busy.value,
        enabled: !vm.busy.value,
        onTap: () async {
          final succeeded = await vm.logout();
          if (!succeeded && context.mounted && !vm.isDisposed) {
            final error = vm.error.value;
            if (error != null) {
              BeakOverlays(
                context,
              ).toast(strings.authError(error), level: OiToastLevel.error);
            }
          }
        },
      ),
    );
  }
}
