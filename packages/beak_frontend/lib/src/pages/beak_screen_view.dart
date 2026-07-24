import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../blocks/beak_block.dart';
import '../blocks/beak_block_host.dart';
import '../panel/beak_screen.dart';

/// Renders a [BeakScreen]: its declarative [BeakBlock] body, optionally
/// inside the standard page chrome.
///
/// A framed screen wraps the body in an `OiResourcePage` (title header +
/// padding); an unframed screen renders the body full-bleed for calendars,
/// kanban boards, and other screens that own their whole viewport.
class BeakScreenView extends StatelessWidget {
  /// Creates the view for [screen].
  const BeakScreenView({required this.screen, super.key});

  /// The screen to render.
  final BeakScreen screen;

  @override
  Widget build(BuildContext context) {
    final body = BeakBlockHost(block: screen.body);
    if (!screen.framed) {
      return body;
    }
    return OiResourcePage(
      label: screen.effectiveLabel,
      title: screen.title,
      actions: const [],
      child: SingleChildScrollView(child: body),
    );
  }
}
