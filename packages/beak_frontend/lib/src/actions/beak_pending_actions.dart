import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals_flutter.dart';

import '../localization/beak_localizations.dart';
import 'beak_model_action_runner.dart';

/// Keeps uncertain command recovery reachable after navigation or state changes.
class BeakPendingActions extends HookWidget {
  /// Displays only commands owned by the current principal.
  const BeakPendingActions({
    required this.runner,
    required this.principal,
    required this.child,
    super.key,
  });

  /// Panel-owned recovery sessions.
  final BeakModelActionRunner runner;

  /// Current authenticated identity, or null for an anonymous panel.
  final Object? principal;

  /// The regular route content.
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final busy = useState(false);
    final failure = useState<BeakException?>(null);
    return Watch((context) {
      final pending = runner.unresolved.value
          .where((entry) => entry.principal == principal)
          .toList();
      if (pending.isEmpty) return child;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OiLabel.body(
                  BeakLocalizations.of(context).pendingActionsNotice,
                ),
                for (final entry in pending)
                  OiButton.secondary(
                    label: BeakLocalizations.of(
                      context,
                    ).checkPendingAction(entry.action.label),
                    loading: busy.value,
                    onTap: busy.value
                        ? null
                        : () async {
                            busy.value = true;
                            final result = await runner.execute(
                              model: entry.model,
                              source: entry.source,
                              recordId: entry.recordId,
                              action: entry.action,
                              principal: entry.principal,
                              registry: entry.registry,
                              prepare: (_) async => null,
                            );
                            if (!context.mounted) return;
                            failure.value = result.error;
                            busy.value = false;
                          },
                  ),
                if (failure.value case final BeakException error)
                  OiLabel.caption(
                    BeakLocalizations.of(context).errorMessage(error),
                  ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      );
    });
  }
}
