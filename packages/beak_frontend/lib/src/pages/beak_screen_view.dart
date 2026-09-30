import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../blocks/beak_block.dart';
import '../blocks/beak_block_host.dart';
import '../panel/beak_screen.dart';

/// Renders a [BeakScreen]: its declarative [BeakBlock] body, optionally
/// inside the standard page chrome.
///
/// A framed screen supplies a page header and gutters without painting a
/// surface behind its body. Blocks own their individual surfaces; an unframed
/// screen renders the body full-bleed for calendars,
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
    return OiPageLayout(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      gap: 16,
      header: OiPageHeader(
        title: screen.title,
        titleVariant: OiLabelVariant.h1,
        padding: EdgeInsets.zero,
      ),
      scrollable: true,
      child: body,
    );
  }
}
