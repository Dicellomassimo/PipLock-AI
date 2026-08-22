import 'package:flutter/material.dart';

/// Design tokens centralizzati — unico source of truth per spacing, radius,
/// durations, curves, shadows, typography scale.
/// Stile: Opal × Trading — minimalismo rotondo, premium, arioso.
class AppTheme {
  AppTheme._();

  // ── Spacing (8pt grid) ──────────────────────────────────────────────────
  static const double sp2  = 2.0;
  static const double sp4  = 4.0;
  static const double sp6  = 6.0;
  static const double sp8  = 8.0;
  static const double sp10 = 10.0;
  static const double sp12 = 12.0;
  static const double sp16 = 16.0;
  static const double sp20 = 20.0;
  static const double sp24 = 24.0;
  static const double sp32 = 32.0;
  static const double sp40 = 40.0;
  static const double sp48 = 48.0;
  static const double sp64 = 64.0;

  // Screen horizontal padding — leggermente più arioso
  static const double pagePadding = 22.0;

  // ── Border radius (più grandi = più rotondo = più Opal) ─────────────────
  static const double radiusXs   = 10.0;
  static const double radiusSm   = 14.0;
  static const double radiusMd   = 18.0;
  static const double radiusLg   = 24.0;
  static const double radiusXl   = 32.0;
  static const double radius2xl  = 40.0;
  static const double radiusFull = 999.0;

  static BorderRadius bXs   = BorderRadius.circular(radiusXs);
  static BorderRadius bSm   = BorderRadius.circular(radiusSm);
  static BorderRadius bMd   = BorderRadius.circular(radiusMd);
  static BorderRadius bLg   = BorderRadius.circular(radiusLg);
  static BorderRadius bXl   = BorderRadius.circular(radiusXl);
  static BorderRadius b2xl  = BorderRadius.circular(radius2xl);
  static BorderRadius bFull = BorderRadius.circular(radiusFull);

  // ── Animation durations ─────────────────────────────────────────────────
  static const Duration dFast   = Duration(milliseconds: 150);
  static const Duration dMedium = Duration(milliseconds: 280);
  static const Duration dSlow   = Duration(milliseconds: 420);
  static const Duration dXSlow  = Duration(milliseconds: 650);
  static const Duration dEntry  = Duration(milliseconds: 800);

  // ── Animation curves ────────────────────────────────────────────────────
  static const Curve cSpring    = Curves.easeOutCubic;
  static const Curve cSnappy    = Curves.easeInOutQuart;
  static const Curve cBounce    = Curves.elasticOut;
  static const Curve cSmooth    = Curves.easeInOutSine;
  static const Curve cDecelerate = Curves.decelerate;

  // ── Icon sizes ──────────────────────────────────────────────────────────
  static const double iconXs = 14.0;
  static const double iconSm = 18.0;
  static const double iconMd = 22.0;
  static const double iconLg = 28.0;
  static const double iconXl = 36.0;

  // ── Typography scale ────────────────────────────────────────────────────
  // Display — hero numbers, killswitch countdown
  static const TextStyle display = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w900,
    letterSpacing: -3.0,
    height: 0.95,
  );

  // Title large — main screen headlines
  static const TextStyle titleLg = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w900,
    letterSpacing: -2.0,
    height: 1.0,
  );

  // Title — section titles, hero card status
  static const TextStyle title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    height: 1.05,
  );

  // Headline — card titles
  static const TextStyle headline = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.2,
  );

  // Body large — primary readable text
  static const TextStyle bodyLg = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    height: 1.5,
  );

  // Body — standard text
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.5,
  );

  // Label — button text, important labels
  static const TextStyle label = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  // Caption — metadata, timestamps
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  // Overline — section headers (ALL CAPS usage)
  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.8,
  );

  // Mono — countdown, numbers, code
  static const TextStyle mono = TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.5,
  );

  // ── Shadow / elevation system ───────────────────────────────────────────
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x18000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x28000000), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x38000000), blurRadius: 48, offset: Offset(0, 16)),
    BoxShadow(color: Color(0x18000000), blurRadius: 16, offset: Offset(0, 6)),
  ];

  // ── Press state scale ───────────────────────────────────────────────────
  static const double pressScale     = 0.97;
  static const double pressScaleHard = 0.94;
}
