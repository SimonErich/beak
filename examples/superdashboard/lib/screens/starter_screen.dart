import 'package:beak_frontend/beak_frontend.dart';
import 'package:obers_ui/obers_ui.dart';

/// A blank-canvas starter page — the Tocly `starter-page` reproduced as a
/// single `BeakMarkdownBlock`, the documented starting point for a new screen.
BeakScreen buildStarterScreen() => const BeakScreen(
  path: '/starter',
  title: 'Starter',
  icon: BeakIconToken(OiIcons.filePlus),
  section: 'Showcase',
  body: BeakCardBlock(
    child: BeakMarkdownBlock('''
# Starter page

This is an empty page. Drop any `BeakBlock` into its body to begin — a grid of
KPIs, a chart, a table, a form, or a module block. Everything on every other
screen is built from the same declarative blocks you would use here.
'''),
  ),
);
