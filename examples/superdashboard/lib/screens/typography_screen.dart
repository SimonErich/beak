import 'package:beak_frontend/beak_frontend.dart';
import 'package:obers_ui/obers_ui.dart';

/// The typography specimen — the full `OiLabel` type ramp exposed through
/// `BeakTextBlock`, from the display size down to the caption.
BeakScreen buildTypographyScreen() => const BeakScreen(
  path: '/typography',
  title: 'Typography',
  icon: BeakIconToken(OiIcons.heading),
  section: 'Showcase',
  body: BeakCardBlock(
    title: 'Type scale',
    child: BeakColumnBlock(
      gapInPixels: 12,
      children: [
        BeakTextBlock('Display', variant: BeakTextVariant.display),
        BeakTextBlock('Heading 1', variant: BeakTextVariant.h1),
        BeakTextBlock('Heading 2', variant: BeakTextVariant.h2),
        BeakTextBlock('Heading 3', variant: BeakTextVariant.h3),
        BeakTextBlock('Heading 4', variant: BeakTextVariant.h4),
        BeakTextBlock('Body — the default paragraph size.'),
        BeakTextBlock(
          'Body strong — emphasized paragraph text.',
          variant: BeakTextVariant.bodyStrong,
        ),
        BeakTextBlock(
          'Small — secondary text.',
          variant: BeakTextVariant.small,
        ),
        BeakTextBlock(
          'Caption — the smallest label.',
          variant: BeakTextVariant.caption,
        ),
      ],
    ),
  ),
);
