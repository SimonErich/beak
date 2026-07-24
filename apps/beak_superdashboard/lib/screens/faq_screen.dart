import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_superdashboard/models/models.dart';
import 'package:obers_ui/obers_ui.dart';

/// The FAQ / help-center page — a searchable, categorized list built from the
/// seeded `faqs`.
BeakScreen buildFaqScreen() => const BeakScreen(
  path: '/faq',
  title: 'FAQ',
  icon: BeakIconToken(OiIcons.helpCircle),
  section: 'Pages',
  body: BeakFaqBlock(
    model: FaqModel(),
    questionField: FaqColumns.question,
    answerField: FaqColumns.answer,
  ),
);
