import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';
import 'package:beak/ui.dart';

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
