import 'package:flutter/painting.dart';

import 'gabel_fonts.dart';

/// The wide heading role shared by section headings and monetary totals.
const gabelHeading2Style = TextStyle(
  fontFamily: gabelSansFamily,
  fontFamilyFallback: gabelSansFallbackFamilies,
  fontSize: 22,
  fontWeight: FontWeight.w600,
  height: 28 / 22,
  fontVariations: [FontVariation('wght', 580), FontVariation('wdth', 106)],
  letterSpacing: -.22,
);

/// Body amounts retain the surrounding typography with equal-width digits.
const gabelNumericBodyStyle = TextStyle(
  fontFeatures: [FontFeature.tabularFigures()],
);

/// Medium monetary values used by compact item rows and remaining budgets.
const gabelNumericMediumStyle = TextStyle(
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
  fontVariations: [FontVariation('wdth', 100)],
  fontFeatures: [FontFeature.tabularFigures()],
);

/// Supporting tax amounts use the design's caption role.
const gabelNumericCaptionStyle = TextStyle(
  fontSize: 12,
  height: 16 / 12,
  fontWeight: FontWeight.w500,
  letterSpacing: .12,
  fontFeatures: [FontFeature.tabularFigures()],
);

/// Compact metric amounts use the design's strong16/24 role.
const gabelNumericMetricStyle = TextStyle(
  fontSize: 16,
  height: 1.5,
  fontWeight: FontWeight.w600,
  fontVariations: [FontVariation('wght', 580), FontVariation('wdth', 100)],
  fontFeatures: [FontFeature.tabularFigures()],
);

/// Tabular figures keep monetary totals stable as their digits change.
final gabelNumericTotalStyle = gabelHeading2Style.copyWith(
  fontFeatures: const [FontFeature.tabularFigures()],
);
