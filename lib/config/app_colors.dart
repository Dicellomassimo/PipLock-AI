import 'package:flutter/material.dart';

class AppColors {
  // ── Dark theme (default) ─────────────────────────────────────────────────
  static const Color background  = Color(0xFF07080D);
  static const Color surface     = Color(0xFF0C0E16);
  static const Color cardBg      = Color(0xFF111420);
  static const Color cardBg2     = Color(0xFF171B27);

  // Brand — Electric Violet (premium, unique nel trading space)
  static const Color accent       = Color(0xFF7B61FF);
  static const Color accentDark   = Color(0xFF5B3FCC);
  static const Color accentBright = Color(0xFF9D87FF); // glow trails

  // Silver / Metallic (il lucchetto)
  static const Color silver       = Color(0xFF8B98AA);
  static const Color silverBright = Color(0xFFC4D0DC);
  static const Color silverDim    = Color(0xFF4A5568);

  // States
  static const Color warning     = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFD97706);
  static const Color fomo        = Color(0xFFEC4899);
  static const Color danger      = Color(0xFFEF4444);
  static const Color dangerDark  = Color(0xFFB91C1C);
  static const Color success     = Color(0xFF22C55E);

  // Text
  static const Color textPrimary   = Color(0xFFECEFF8);
  static const Color textSecondary = Color(0xFF7B8699);
  static const Color textTertiary  = Color(0xFF3D4865);

  // UI
  static const Color divider = Color(0xFF141728);
  static const Color border  = Color(0xFF1C2038);

  // ── Glass system ─────────────────────────────────────────────────────────
  static const Color glass01          = Color(0x05FFFFFF);
  static const Color glass03          = Color(0x08FFFFFF);
  static const Color glass06          = Color(0x10FFFFFF);
  static const Color glassBorder      = Color(0x12FFFFFF);
  static const Color glassBorderStrong = Color(0x20FFFFFF);

  // ── Shadow / glow system ─────────────────────────────────────────────────
  static List<BoxShadow> glowAccent({double intensity = 1.0}) => [
    BoxShadow(
      color: accent.withValues(alpha: 0.28 * intensity),
      blurRadius: 32,
      spreadRadius: -4,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> glowSilver({double intensity = 1.0}) => [
    BoxShadow(
      color: silverBright.withValues(alpha: 0.18 * intensity),
      blurRadius: 24,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> glowDanger({double intensity = 1.0}) => [
    BoxShadow(
      color: danger.withValues(alpha: 0.32 * intensity),
      blurRadius: 32,
      spreadRadius: -4,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> glowWarning({double intensity = 1.0}) => [
    BoxShadow(
      color: warning.withValues(alpha: 0.24 * intensity),
      blurRadius: 24,
      spreadRadius: -4,
      offset: const Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x30000000), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x12000000), blurRadius: 8,  offset: Offset(0, 2)),
  ];

  // Hero card gradients
  static const LinearGradient heroGradientOk = LinearGradient(
    colors: [Color(0xFF6B4FE8), Color(0xFF3730A3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient heroGradientWarning = LinearGradient(
    colors: [Color(0xFFE07830), Color(0xFFAA3D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient heroGradientDanger = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFF7F1D1D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Killswitch background gradient
  static const LinearGradient killswitchGradient = LinearGradient(
    colors: [Color(0xFF1A0000), Color(0xFF3D0000), Color(0xFF1A0000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Logo / brand gradient — silver → violet (il lucchetto)
  static const LinearGradient logoGradient = LinearGradient(
    colors: [Color(0xFFC4D0DC), Color(0xFF7B61FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // CTA buttons gradient
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF9D87FF), Color(0xFF5B3FCC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Silver metallic gradient (per bordi pro, badge)
  static const LinearGradient silverGradient = LinearGradient(
    colors: [Color(0xFF8B98AA), Color(0xFFC4D0DC), Color(0xFF8B98AA)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Ambient background blob gradients
  static RadialGradient blobAccent({double opacity = 0.08}) => RadialGradient(
    colors: [accent.withValues(alpha: opacity), Colors.transparent],
    radius: 0.8,
  );
  static RadialGradient blobSilver({double opacity = 0.05}) => RadialGradient(
    colors: [silverBright.withValues(alpha: opacity), Colors.transparent],
    radius: 0.8,
  );
  static RadialGradient blobFomo({double opacity = 0.05}) => RadialGradient(
    colors: [fomo.withValues(alpha: opacity), Colors.transparent],
    radius: 0.8,
  );
  static RadialGradient blobDanger({double opacity = 0.06}) => RadialGradient(
    colors: [danger.withValues(alpha: opacity), Colors.transparent],
    radius: 0.8,
  );

  // ── Light theme ──────────────────────────────────────────────────────────
  static const Color lightBackground  = Color(0xFFF2F4FA);
  static const Color lightSurface     = Color(0xFFFFFFFF);
  static const Color lightCardBg      = Color(0xFFFFFFFF);
  static const Color lightCardBg2     = Color(0xFFF0F2FA);
  static const Color lightTextPrimary  = Color(0xFF0F1629);
  static const Color lightTextSecondary = Color(0xFF6B7489);
  static const Color lightTextTertiary  = Color(0xFF9EA8BC);
  static const Color lightDivider = Color(0xFFE3E6EE);
  static const Color lightBorder  = Color(0xFFD8DCE9);
}
