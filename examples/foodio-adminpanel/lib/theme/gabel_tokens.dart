// Extracted from design/food-ordering-shop.html by tool/extract_reference.py.
import 'package:flutter/painting.dart';

/// Exact light semantic colors from the supplied prototype.
abstract final class GabelLight {
  /// Prototype `canvas` token.
  static const canvas = Color(0xFFF3F3F7);

  /// Prototype `sheet` token.
  static const sheet = Color(0xFFFEFEFF);

  /// Prototype `well` token.
  static const well = Color(0xFFF6F7FA);

  /// Prototype `overlay` token.
  static const overlay = Color(0xFFFFFFFF);

  /// Prototype `line` token.
  static const line = Color(0xFFE5E5EA);

  /// Prototype `line-strong` token.
  static const lineStrong = Color(0xFFD2D3D9);

  /// Prototype `border` token.
  static const border = Color(0xFF88898F);

  /// Prototype `fill-hover` token.
  static const fillHover = Color(0x0D2B2C3D);

  /// Prototype `fill-press` token.
  static const fillPress = Color(0x172B2C3D);

  /// Prototype `scrim` token.
  static const scrim = Color(0x5214151F);

  /// Prototype `ink` token.
  static const ink = Color(0xFF1C1D26);

  /// Prototype `ink-muted` token.
  static const inkMuted = Color(0xFF595A63);

  /// Prototype `ink-subtle` token.
  static const inkSubtle = Color(0xFF7F8086);

  /// Prototype `inverse` token.
  static const inverse = Color(0xFF202128);

  /// Prototype `on-inverse` token.
  static const onInverse = Color(0xFFF6F6F9);

  /// Prototype `inverse-muted` token.
  static const inverseMuted = Color(0xFFB1B2B9);

  /// Prototype `rail-surface` token.
  static const railSurface = Color(0xFF1C1D28);

  /// Prototype `rail-ink` token.
  static const railInk = Color(0xFFB7B8C1);

  /// Prototype `rail-hover` token.
  static const railHover = Color(0x14FCFCFC);

  /// Prototype `rail-line` token.
  static const railLine = Color(0x12FCFCFC);

  /// Prototype `rail-active` token.
  static const railActive = Color(0xFFBABAEA);

  /// Prototype `on-rail-active` token.
  static const onRailActive = Color(0xFF181729);

  /// Prototype `primary` token.
  static const primary = Color(0xFF625FAC);

  /// Prototype `primary-hover` token.
  static const primaryHover = Color(0xFF57559C);

  /// Prototype `primary-press` token.
  static const primaryPress = Color(0xFF4E4C8D);

  /// Prototype `on-primary` token.
  static const onPrimary = Color(0xFFFBFBFE);

  /// Prototype `primary-ink` token.
  static const primaryInk = Color(0xFF5A589F);

  /// Prototype `primary-soft` token.
  static const primarySoft = Color(0xFFEEEFFC);

  /// Prototype `primary-soft-hover` token.
  static const primarySoftHover = Color(0xFFE5E6FB);

  /// Prototype `secondary` token.
  static const secondary = Color(0xFF95C7D9);

  /// Prototype `on-secondary` token.
  static const onSecondary = Color(0xFF11242D);

  /// Prototype `secondary-ink` token.
  static const secondaryInk = Color(0xFF35647A);

  /// Prototype `secondary-soft` token.
  static const secondarySoft = Color(0xFFE7F4F8);

  /// Prototype `highlight` token.
  static const highlight = Color(0xFFF2CE9B);

  /// Prototype `on-highlight` token.
  static const onHighlight = Color(0xFF382515);

  /// Prototype `highlight-ink` token.
  static const highlightInk = Color(0xFF855A31);

  /// Prototype `highlight-soft` token.
  static const highlightSoft = Color(0xFFFDF2E0);

  /// Prototype `focus-halo` token.
  static const focusHalo = Color(0x33625FAC);

  /// Prototype `success` token.
  static const success = Color(0xFF4E966F);

  /// Prototype `on-success` token.
  static const onSuccess = Color(0xFF0A1E13);

  /// Prototype `success-ink` token.
  static const successInk = Color(0xFF286847);

  /// Prototype `success-soft` token.
  static const successSoft = Color(0xFFE7F5EC);

  /// Prototype `warning` token.
  static const warning = Color(0xFFE0A968);

  /// Prototype `on-warning` token.
  static const onWarning = Color(0xFF301D0D);

  /// Prototype `warning-ink` token.
  static const warningInk = Color(0xFF8B572C);

  /// Prototype `warning-soft` token.
  static const warningSoft = Color(0xFFFCF1E1);

  /// Prototype `danger` token.
  static const danger = Color(0xFFB64F4F);

  /// Prototype `danger-hover` token.
  static const dangerHover = Color(0xFFA74546);

  /// Prototype `on-danger` token.
  static const onDanger = Color(0xFFFEFBFA);

  /// Prototype `danger-ink` token.
  static const dangerInk = Color(0xFFA54344);

  /// Prototype `danger-soft` token.
  static const dangerSoft = Color(0xFFFDEDEC);

  /// Prototype `info` token.
  static const info = Color(0xFF7E8087);

  /// Prototype `info-soft` token.
  static const infoSoft = Color(0xFFF0F1F4);

  /// Prototype `chart-1` token.
  static const chart1 = Color(0xFF6766AA);

  /// Prototype `chart-2` token.
  static const chart2 = Color(0xFFCD8F57);

  /// Prototype `chart-3` token.
  static const chart3 = Color(0xFF6DBBE8);

  /// Prototype `chart-4` token.
  static const chart4 = Color(0xFFAA6386);

  /// Prototype `chart-5` token.
  static const chart5 = Color(0xFF3D5590);

  /// Prototype `chart-6` token.
  static const chart6 = Color(0xFF338D6B);

  /// Catalog vegetable tone: chart-6 mixed26% with sheet in OKLCH.
  static const catalogVegetableSoft = Color(0xFFCDDCEC);

  /// Catalog dessert tone: chart-4 mixed26% with sheet in OKLCH.
  static const catalogDessertSoft = Color(0xFFDDD8EC);

  /// Prototype `chart-muted` token.
  static const chartMuted = Color(0xFFBCBDC3);

  /// Prototype `chart-seq-1` token.
  static const chartSeq1 = Color(0xFFE9EAFA);

  /// Prototype `chart-seq-2` token.
  static const chartSeq2 = Color(0xFFCECFF0);

  /// Prototype `chart-seq-3` token.
  static const chartSeq3 = Color(0xFFAFB1E2);

  /// Prototype `chart-seq-4` token.
  static const chartSeq4 = Color(0xFF8E8FD0);

  /// Prototype `chart-seq-5` token.
  static const chartSeq5 = Color(0xFF706FB9);

  /// Prototype `chart-seq-6` token.
  static const chartSeq6 = Color(0xFF524F93);

  /// Prototype `chart-div-neg` token.
  static const chartDivNeg = Color(0xFFCC8F5C);

  /// Prototype `chart-div-mid` token.
  static const chartDivMid = Color(0xFFDDDEE2);

  /// Prototype `chart-div-pos` token.
  static const chartDivPos = Color(0xFF6766AA);
}

/// Exact dark semantic colors from the supplied prototype.
abstract final class GabelDark {
  /// Prototype `canvas` token.
  static const canvas = Color(0xFF0A0A0D);

  /// Prototype `sheet` token.
  static const sheet = Color(0xFF131417);

  /// Prototype `well` token.
  static const well = Color(0xFF0E0F12);

  /// Prototype `overlay` token.
  static const overlay = Color(0xFF1C1C20);

  /// Prototype `line` token.
  static const line = Color(0xFF242428);

  /// Prototype `line-strong` token.
  static const lineStrong = Color(0xFF323338);

  /// Prototype `border` token.
  static const border = Color(0xFF777880);

  /// Prototype `fill-hover` token.
  static const fillHover = Color(0x0FF0F1F9);

  /// Prototype `fill-press` token.
  static const fillPress = Color(0x1AF0F1F9);

  /// Prototype `scrim` token.
  static const scrim = Color(0x9E010203);

  /// Prototype `ink` token.
  static const ink = Color(0xFFEFF0F3);

  /// Prototype `ink-muted` token.
  static const inkMuted = Color(0xFFB4B5BC);

  /// Prototype `ink-subtle` token.
  static const inkSubtle = Color(0xFF83848B);

  /// Prototype `inverse` token.
  static const inverse = Color(0xFFE5E6E9);

  /// Prototype `on-inverse` token.
  static const onInverse = Color(0xFF18191F);

  /// Prototype `inverse-muted` token.
  static const inverseMuted = Color(0xFF55565D);

  /// Prototype `rail-surface` token.
  static const railSurface = Color(0xFF030406);

  /// Prototype `rail-ink` token.
  static const railInk = Color(0xFF9E9FA6);

  /// Prototype `rail-hover` token.
  static const railHover = Color(0x0FFCFCFC);

  /// Prototype `rail-line` token.
  static const railLine = Color(0x12FCFCFC);

  /// Prototype `rail-active` token.
  static const railActive = Color(0xFFA7A7D6);

  /// Prototype `on-rail-active` token.
  static const onRailActive = Color(0xFF10101E);

  /// Prototype `primary` token.
  static const primary = Color(0xFFADABE7);

  /// Prototype `primary-hover` token.
  static const primaryHover = Color(0xFFB6B5EE);

  /// Prototype `primary-press` token.
  static const primaryPress = Color(0xFFA3A2DD);

  /// Prototype `on-primary` token.
  static const onPrimary = Color(0xFF161524);

  /// Prototype `primary-ink` token.
  static const primaryInk = Color(0xFFB8B7EF);

  /// Prototype `primary-soft` token.
  static const primarySoft = Color(0xFF252537);

  /// Prototype `primary-soft-hover` token.
  static const primarySoftHover = Color(0xFF2E2D46);

  /// Prototype `secondary` token.
  static const secondary = Color(0xFF8ABACB);

  /// Prototype `on-secondary` token.
  static const onSecondary = Color(0xFF081A21);

  /// Prototype `secondary-ink` token.
  static const secondaryInk = Color(0xFF9AC6D6);

  /// Prototype `secondary-soft` token.
  static const secondarySoft = Color(0xFF1B282D);

  /// Prototype `highlight` token.
  static const highlight = Color(0xFFD7B88D);

  /// Prototype `on-highlight` token.
  static const onHighlight = Color(0xFF261708);

  /// Prototype `highlight-ink` token.
  static const highlightInk = Color(0xFFE8CB9D);

  /// Prototype `highlight-soft` token.
  static const highlightSoft = Color(0xFF332719);

  /// Prototype `focus-halo` token.
  static const focusHalo = Color(0x4CADABE7);

  /// Prototype `success` token.
  static const success = Color(0xFF71B48E);

  /// Prototype `on-success` token.
  static const onSuccess = Color(0xFF091A11);

  /// Prototype `success-ink` token.
  static const successInk = Color(0xFF91CCA9);

  /// Prototype `success-soft` token.
  static const successSoft = Color(0xFF1A2A21);

  /// Prototype `warning` token.
  static const warning = Color(0xFFE3B371);

  /// Prototype `on-warning` token.
  static const onWarning = Color(0xFF251508);

  /// Prototype `warning-ink` token.
  static const warningInk = Color(0xFFE9C28A);

  /// Prototype `warning-soft` token.
  static const warningSoft = Color(0xFF342619);

  /// Prototype `danger` token.
  static const danger = Color(0xFFDB8A87);

  /// Prototype `danger-hover` token.
  static const dangerHover = Color(0xFFE29491);

  /// Prototype `on-danger` token.
  static const onDanger = Color(0xFF221010);

  /// Prototype `danger-ink` token.
  static const dangerInk = Color(0xFFEEA7A4);

  /// Prototype `danger-soft` token.
  static const dangerSoft = Color(0xFF371F1E);

  /// Prototype `info` token.
  static const info = Color(0xFF84858D);

  /// Prototype `info-soft` token.
  static const infoSoft = Color(0xFF212226);

  /// Prototype `chart-1` token.
  static const chart1 = Color(0xFF7877BD);

  /// Prototype `chart-2` token.
  static const chart2 = Color(0xFFC0834A);

  /// Prototype `chart-3` token.
  static const chart3 = Color(0xFF439CCC);

  /// Prototype `chart-4` token.
  static const chart4 = Color(0xFFBA7295);

  /// Prototype `chart-5` token.
  static const chart5 = Color(0xFF47609F);

  /// Prototype `chart-6` token.
  static const chart6 = Color(0xFF338D6B);

  /// Catalog vegetable tone: chart-6 mixed26% with sheet in OKLCH.
  static const catalogVegetableSoft = Color(0xFF202D3B);

  /// Catalog dessert tone: chart-4 mixed26% with sheet in OKLCH.
  static const catalogDessertSoft = Color(0xFF322D3E);

  /// Prototype `chart-muted` token.
  static const chartMuted = Color(0xFF4C4D53);

  /// Prototype `chart-seq-1` token.
  static const chartSeq1 = Color(0xFF2B2A46);

  /// Prototype `chart-seq-2` token.
  static const chartSeq2 = Color(0xFF413F69);

  /// Prototype `chart-seq-3` token.
  static const chartSeq3 = Color(0xFF59568E);

  /// Prototype `chart-seq-4` token.
  static const chartSeq4 = Color(0xFF7471B3);

  /// Prototype `chart-seq-5` token.
  static const chartSeq5 = Color(0xFF9290CF);

  /// Prototype `chart-seq-6` token.
  static const chartSeq6 = Color(0xFFB5B5E8);

  /// Prototype `chart-div-neg` token.
  static const chartDivNeg = Color(0xFFC48A5A);

  /// Prototype `chart-div-mid` token.
  static const chartDivMid = Color(0xFF3C3D42);

  /// Prototype `chart-div-pos` token.
  static const chartDivPos = Color(0xFF807DC0);
}
