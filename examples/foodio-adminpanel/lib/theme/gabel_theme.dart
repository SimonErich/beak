import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import 'gabel_icons.dart';
import 'gabel_tokens.dart';

/// The wide heading role shared by section headings and monetary totals.
const gabelHeading2Style = TextStyle(
  fontFamily: 'Mona Sans',
  fontFamilyFallback: ['Mona Sans Extended'],
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

/// The supplied Gabel design, entirely through Obers' public theme contract.
OiThemeData gabelTheme({bool dark = false}) {
  Color color(Color light, Color night) => dark ? night : light;
  final canvas = color(GabelLight.canvas, GabelDark.canvas);
  final sheet = color(GabelLight.sheet, GabelDark.sheet);
  final ink = color(GabelLight.ink, GabelDark.ink);
  final muted = color(GabelLight.inkMuted, GabelDark.inkMuted);
  final subtle = color(GabelLight.inkSubtle, GabelDark.inkSubtle);
  final line = color(GabelLight.line, GabelDark.line);
  final border = color(GabelLight.border, GabelDark.border);
  final primary = color(GabelLight.primary, GabelDark.primary);
  final primaryInk = color(GabelLight.primaryInk, GabelDark.primaryInk);
  final primarySoft = color(GabelLight.primarySoft, GabelDark.primarySoft);
  final onPrimary = color(GabelLight.onPrimary, GabelDark.onPrimary);
  final base = dark
      ? OiThemeData.dark(
          fontFamily: 'Mona Sans',
          monoFontFamily: 'JetBrains Mono',
        )
      : OiThemeData.light(
          fontFamily: 'Mona Sans',
          monoFontFamily: 'JetBrains Mono',
        );
  OiColorSwatch swatch(Color value, Color soft, Color foreground) =>
      OiColorSwatch(
        base: value,
        light: soft,
        dark: value,
        muted: soft,
        foreground: foreground,
      );
  TextStyle text(
    double size,
    double height, {
    double weight = 400,
    double width = 100,
    double? tracking,
    Color? foreground,
  }) => TextStyle(
    fontFamily: 'Mona Sans',
    fontFamilyFallback: const ['Mona Sans Extended'],
    fontSize: size,
    fontWeight: FontWeight.values[(weight / 100).round().clamp(1, 9) - 1],
    height: height / size,
    color: foreground ?? ink,
    fontVariations: [
      // Native hundred-step weights must remain overridable by components.
      // A fixed wght axis otherwise silently defeats copyWith(fontWeight: ...).
      if (weight % 100 != 0) FontVariation('wght', weight),
      FontVariation('wdth', width),
    ],
    letterSpacing: tracking,
  );
  final body = text(14, 20);
  final small = text(13, 18, foreground: muted);
  final colors = base.colors.copyWith(
    background: canvas,
    surface: sheet,
    surfaceSubtle: color(GabelLight.well, GabelDark.well),
    surfaceHover: color(GabelLight.fillHover, GabelDark.fillHover),
    surfaceActive: color(GabelLight.fillPress, GabelDark.fillPress),
    overlay: color(GabelLight.scrim, GabelDark.scrim),
    text: ink,
    textSubtle: subtle,
    textMuted: muted,
    textInverse: color(GabelLight.onInverse, GabelDark.onInverse),
    textOnPrimary: onPrimary,
    border: border,
    borderSubtle: line,
    borderFocus: primaryInk,
    borderError: color(GabelLight.dangerInk, GabelDark.dangerInk),
    primary: swatch(primary, primarySoft, onPrimary).copyWith(dark: primaryInk),
    accent: swatch(
      color(GabelLight.secondary, GabelDark.secondary),
      color(GabelLight.secondarySoft, GabelDark.secondarySoft),
      color(GabelLight.onSecondary, GabelDark.onSecondary),
    ),
    success: swatch(
      color(GabelLight.successInk, GabelDark.successInk),
      color(GabelLight.successSoft, GabelDark.successSoft),
      color(GabelLight.onSuccess, GabelDark.onSuccess),
    ),
    warning: swatch(
      color(GabelLight.warningInk, GabelDark.warningInk),
      color(GabelLight.warningSoft, GabelDark.warningSoft),
      color(GabelLight.onWarning, GabelDark.onWarning),
    ),
    error: swatch(
      color(GabelLight.dangerInk, GabelDark.dangerInk),
      color(GabelLight.dangerSoft, GabelDark.dangerSoft),
      color(GabelLight.onDanger, GabelDark.onDanger),
    ),
    info: swatch(
      color(GabelLight.secondaryInk, GabelDark.secondaryInk),
      color(GabelLight.secondarySoft, GabelDark.secondarySoft),
      color(GabelLight.onSecondary, GabelDark.onSecondary),
    ),
    chart: dark
        ? const [
            GabelDark.chart1,
            GabelDark.chart2,
            GabelDark.chart3,
            GabelDark.chart4,
            GabelDark.chart5,
            GabelDark.chart6,
          ]
        : const [
            GabelLight.chart1,
            GabelLight.chart2,
            GabelLight.chart3,
            GabelLight.chart4,
            GabelLight.chart5,
            GabelLight.chart6,
          ],
  );
  return base.copyWith(
    colors: colors,
    shadows: base.shadows.copyWith(
      lg: const [
        BoxShadow(color: Color(0x121D1E29), spreadRadius: 1),
        BoxShadow(
          color: Color(0x141D1E29),
          offset: Offset(0, 4),
          blurRadius: 8,
          spreadRadius: -2,
        ),
        BoxShadow(
          color: Color(0x381D1E29),
          offset: Offset(0, 18),
          blurRadius: 36,
          spreadRadius: -12,
        ),
      ],
    ),
    decoration: base.decoration.copyWith(
      defaultBorder: base.decoration.defaultBorder.copyWith(color: border),
      focusBorder: base.decoration.focusBorder.copyWith(color: primaryInk),
      errorBorder: base.decoration.errorBorder.copyWith(
        color: color(GabelLight.danger, GabelDark.danger),
      ),
    ),
    textTheme: base.textTheme.copyWith(
      headingScale: const OiResponsive<double>(1),
      display: text(40, 48, weight: 560, width: 106, tracking: -.8),
      h1: text(34, 40, weight: 560, width: 106, tracking: -.68),
      h2: gabelHeading2Style.copyWith(color: ink),
      h3: text(18, 24, weight: 580),
      h4: text(16, 24, weight: 580),
      body: body,
      bodyStrong: text(14, 20, weight: 580),
      small: small,
      smallStrong: text(13, 18, weight: 580),
      tiny: text(12, 16, weight: 500, tracking: .12),
      caption: text(12, 16, weight: 500, tracking: .12, foreground: muted),
      code: const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: ['JetBrains Mono Extended'],
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w500,
      ),
      overline: text(11, 16, weight: 600, tracking: .5, foreground: muted),
      link: text(14, 20, foreground: primaryInk),
    ),
    radius: const OiRadiusScale(
      none: BorderRadius.zero,
      xs: BorderRadius.all(Radius.circular(4)),
      sm: BorderRadius.all(Radius.circular(6)),
      md: BorderRadius.all(Radius.circular(8)),
      lg: BorderRadius.all(Radius.circular(10)),
      xl: BorderRadius.all(Radius.circular(14)),
      full: BorderRadius.all(Radius.circular(9999)),
    ),
    componentSizes: const OiComponentSizeScale(
      small: 32,
      medium: 36,
      large: 44,
    ),
    animations: const OiAnimationConfig(
      fast: Duration(milliseconds: 120),
      normal: Duration(milliseconds: 200),
      slow: Duration(milliseconds: 320),
      reducedMotion: false,
    ),
    components: OiComponentThemes(
      sheet: OiSheetThemeData(
        inset: const EdgeInsets.all(8),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        barrierColor: color(GabelLight.scrim, GabelDark.scrim),
      ),
      icon: OiIconThemeData(sources: gabelIconSources, size: 18),
      appShell: OiAppShellThemeData(
        breadcrumbLinkStyle: text(14, 20, foreground: muted),
        breadcrumbSeparatorIcon: OiIcons.chevronRight,
        breadcrumbSpacing: 8,
        topBarHeight: 64,
        primaryNavigationWidth: 64,
        searchMaxWidth: 360,
        actionSpacing: 12,
        titleStyle: text(14, 20, weight: 500),
        topBarPadding: const EdgeInsets.symmetric(horizontal: 32),
        backgroundColor: canvas,
        borderColor: const Color(0x00000000),
      ),
      navigationRail: OiNavigationRailThemeData(
        width: 64,
        itemWidth: 40,
        itemHeight: 40,
        iconSize: 20,
        itemSpacing: 4,
        itemPadding: EdgeInsets.zero,
        borderWidth: 0,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        backgroundColor: color(GabelLight.railSurface, GabelDark.railSurface),
        indicatorColor: color(GabelLight.railActive, GabelDark.railActive),
        hoverColor: color(GabelLight.railHover, GabelDark.railHover),
        hoverIconColor: color(GabelLight.railInk, GabelDark.railInk),
        selectedIconColor: color(
          GabelLight.onRailActive,
          GabelDark.onRailActive,
        ),
        unselectedIconColor: color(GabelLight.railInk, GabelDark.railInk),
      ),
      stepper: OiStepperThemeData(
        indicatorBorderColor: border,
        indicatorBorderWidth: 1,
        connectorColor: color(GabelLight.lineStrong, GabelDark.lineStrong),
        stepSpacing: 20,
        detailsSpacing: 2,
      ),
      sidebar: OiSidebarThemeData(
        contextBranchColor: color(GabelLight.lineStrong, GabelDark.lineStrong),
        headerHeight: 64,
        headerPadding: const EdgeInsets.fromLTRB(24, 16, 20, 16),
        headerTextStyle: text(16, 24, weight: 580),
        labelGap: 8,
        itemSpacing: 2,
        plainBadges: true,
        badgeTextStyle: text(12, 16, weight: 500).copyWith(color: muted),
        selectedIconColor: primary,
        selectedBorderColor: line,
        width: 264,
        itemHeight: 36,
        iconSize: 18,
        iconWidth: 24,
        itemPadding: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
        itemRadius: const BorderRadius.all(Radius.circular(8)),
        backgroundColor: canvas,
        foreground: ink,
        iconColor: muted,
        selectedBackground: sheet,
        selectedForeground: ink,
        textStyle: body,
        selectedTextStyle: text(14, 20, weight: 580),
      ),
      card: OiCardThemeData(
        headerAlignment: CrossAxisAlignment.start,
        subtitleGap: 2,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        padding: const EdgeInsets.all(24),
        backgroundColor: sheet,
        borderColor: const Color(0x00000000),
        borderWidth: 0,
        shadow: [
          BoxShadow(
            color: dark ? GabelDark.line : const Color(0x0E1D1E29),
            spreadRadius: 1,
          ),
          const BoxShadow(
            color: Color(0x0A1D1E29),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
          const BoxShadow(
            color: Color(0x121D1E29),
            offset: Offset(0, 3),
            blurRadius: 8,
            spreadRadius: -4,
          ),
        ],
      ),
      table: OiTableThemeData(
        rowBorderRadius: const BorderRadius.all(Radius.circular(4)),
        headerHeight: 40,
        rowHeight: 56,
        headerBackground: sheet,
        borderColor: line,
        selectedBackground: primarySoft,
        hoverBackground: color(GabelLight.well, GabelDark.well),
        headerTextStyle: text(
          12,
          16,
          weight: 500,
          tracking: .12,
          foreground: muted,
        ),
        cellTextStyle: body,
        cellPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      capacity: OiCapacityThemeData(
        warningGap: 2,
        columnGap: 12,
        trackRadius: 2,
        stripeColor: color(GabelLight.lineStrong, GabelDark.lineStrong),
        labelStyle: body.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        valueStyle: body.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        valueWidth: 68,
        warningIcon: OiIcons.triangleAlert,
        alignWarningWithTrack: true,
      ),
      bulkBar: OiBulkBarThemeData(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        labelStyle: text(14, 20, weight: 500, foreground: GabelLight.onInverse),
        compactSeparator: true,
        actionStyle: OiButtonVariantStyle(
          background: GabelLight.onInverse.withValues(alpha: .12),
          foreground: GabelLight.onInverse,
          backgroundHover: GabelLight.onInverse.withValues(alpha: .18),
          backgroundPressed: GabelLight.onInverse.withValues(alpha: .24),
        ),
        destructiveActionStyle: OiButtonVariantStyle(
          background: GabelLight.onInverse.withValues(alpha: .12),
          foreground: GabelDark.dangerInk,
          backgroundHover: GabelLight.onInverse.withValues(alpha: .18),
          backgroundPressed: GabelLight.onInverse.withValues(alpha: .24),
        ),
      ),
      actionBar: const OiActionBarThemeData(
        menuMinWidth: 232,
        menuIconGap: 10,
        menuRadius: BorderRadius.all(Radius.circular(10)),
        menuItemRadius: BorderRadius.all(Radius.circular(8)),
        menuPadding: EdgeInsets.all(4),
        menuItemPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      chart: OiChartThemeData(
        grid: OiChartGridTheme(
          color: line,
          width: 1,
          dashPattern: const [1, 1],
        ),
        centerValueStyle: text(28, 32, weight: 560),
        legend: OiChartLegendTheme(
          iconSize: 8,
          valueIconSize: 10,
          markerGap: 6,
          valueLabelStyle: body,
          valueStyle: text(
            14,
            20,
            weight: 500,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        axis: OiChartAxisTheme(
          labelGap: 8,
          labelStyle: text(12, 16, weight: 500, tracking: .12),
          labelColor: muted,
        ),
        density: const OiChartDensityTheme(
          padding: EdgeInsets.fromLTRB(40, 8, 0, 38),
          radialInset: 7,
          barWidth: 18,
          sectionSpacing: 24,
        ),
      ),
      checkbox: OiCheckboxThemeData(
        borderWidth: 1,
        size: 16,
        borderRadius: const BorderRadius.all(Radius.circular(2)),
        disabledColor: line,
      ),
      radio: OiRadioThemeData(
        optionSpacing: 24,
        optionPadding: EdgeInsets.zero,
        size: 16,
        dotSize: 6,
        borderWidth: 1,
        borderColor: color(GabelLight.border, GabelDark.border),
        selectedBorderColor: primary,
        selectedFillColor: sheet,
        selectedDotColor: primary,
        labelStyle: body,
        groupLabelSpacing: 12,
        groupLabelStyle: text(16, 24, weight: 580),
      ),
      radioTile: OiRadioTileThemeData(
        titleStyle: text(14, 20, weight: 500),
        controlGap: 12,
        bodyGap: 16,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        borderWidth: 1,
        selectedBorderWidth: 2,
        minHeight: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderColor: border,
        selectedBorderColor: primary,
        backgroundColor: sheet,
        selectedBackgroundColor: primarySoft,
      ),
      tabs: OiTabsThemeData(
        labelStyle: text(14, 20, weight: 500),
        indicatorColor: primary,
        tabPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
        tabSpacing: 24,
        activeLabelColor: ink,
        inactiveLabelColor: muted,
      ),
      switchTheme: OiSwitchThemeData(
        width: 36,
        height: 20,
        activeTrackColor: primary,
        inactiveTrackColor: muted,
        thumbColor: sheet,
      ),
      segmentedControl: OiSegmentedControlThemeData(
        labelStyle: text(14, 20, weight: 500),
        spacing: 2,
        height: 32,
        inset: 2,
        innerRadius: const BorderRadius.all(Radius.circular(6)),
        backgroundColor: color(GabelLight.well, GabelDark.well),
        selectedColor: sheet,
        selectedTextColor: ink,
        unselectedTextColor: muted,
        borderColor: const Color(0x00000000),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      pagination: OiPaginationThemeData(
        distributed: true,
        showFirstLast: false,
        siblingCount: 2,
        activeBackground: primarySoft,
        activeForeground: primary,
        buttonRadius: const BorderRadius.all(Radius.circular(8)),
        buttonSize: 32,
        buttonSpacing: 2,
        perPageWidth: 72,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        labelStyle: body.copyWith(
          color: muted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        pageStyle: body.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        activePageStyle: text(
          14,
          20,
          weight: 500,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
      badge: OiBadgeThemeData(
        useSwatchColors: true,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        textStyle: text(12, 16, weight: 500, tracking: .12),
        height: 24,
      ),
      banner: OiBannerThemeData(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        iconSize: 18,
        warningBackground: color(GabelLight.warningSoft, GabelDark.warningSoft),
        warningBorder: const Color(0x00000000),
        errorBackground: color(GabelLight.dangerSoft, GabelDark.dangerSoft),
        errorBorder: const Color(0x00000000),
        successBackground: color(GabelLight.successSoft, GabelDark.successSoft),
        successBorder: const Color(0x00000000),
        infoBackground: color(
          GabelLight.secondarySoft,
          GabelDark.secondarySoft,
        ),
        infoBorder: const Color(0x00000000),
        neutralBackground: color(GabelLight.well, GabelDark.well),
        neutralBorder: const Color(0x00000000),
      ),
      button: OiButtonThemeData(
        smallHeight: 32,
        mediumHeight: 36,
        largeHeight: 44,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        iconLabelPadding: const EdgeInsetsDirectional.fromSTEB(12, 0, 14, 0),
        textStyle: text(14, 20, weight: 500),
        iconSize: 16,
        iconGap: 8,
        smallIconGap: 6,
        primaryStyle: OiButtonVariantStyle(
          background: primary,
          foreground: onPrimary,
          backgroundHover: color(
            GabelLight.primaryHover,
            GabelDark.primaryHover,
          ),
          backgroundPressed: color(
            GabelLight.primaryPress,
            GabelDark.primaryPress,
          ),
        ),
        secondaryStyle: OiButtonVariantStyle(
          background: sheet,
          border: border,
          foreground: ink,
          backgroundHover: color(GabelLight.well, GabelDark.well),
        ),
        outlineStyle: OiButtonVariantStyle(
          background: sheet,
          border: border,
          foreground: ink,
        ),
        softStyle: OiButtonVariantStyle(
          background: primarySoft,
          foreground: primaryInk,
        ),
      ),
      textInput: OiTextInputThemeData(
        labelStyle: text(14, 20, weight: 500),
        labelGap: 6,
        supportingGap: 6,
        multilineContentPadding: const EdgeInsets.all(12),
        textStyle: body,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        height: 36,
        borderColor: border,
        focusBorderColor: primaryInk,
        validationErrorColor: color(GabelLight.danger, GabelDark.danger),
        placeholderColor: subtle,
        backgroundColor: sheet,
      ),
      searchTrigger: OiSearchTriggerThemeData(
        height: 36,
        foreground: muted,
        textStyle: body,
        decoration: BoxDecoration(
          color: sheet,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F1D1E29),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    ),
  );
}
