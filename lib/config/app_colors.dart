import 'package:flutter/material.dart';

class AppColors {
  // ── Dark theme (default) ─────────────────────────────────────────────────
  // Near-black neutral (no blue/purple bias — più pulito, stile Opal)
  static const Color background  = Color(0xFF0A0A0F);
  static const Color surface     = Color(0xFF111116);
  static const Color cardBg      = Color(0xFF17171D);
  static const Color cardBg2     = Color(0xFF1C1C24);

  // Brand — Silver Chrome (il lucchetto, la P dell'icona)
  static const Color accent       = Color(0xFFC4D0DC); // silver chrome principale
  static const Color accentDark   = Color(0xFF6B7A88); // silver scuro (hover, dim)
  static const Color accentBright = Color(0xFFE8F0F6); // silver brillante (highlight)

  // Mantenuti per compatibilità — ora accent = silver
  static const Color silver       = Color(0xFF8B98AA);
  static const Color silverBright = Color(0xFFC4D0DC); // == accent
  static const Color silverDim    = Color(0xFF4A5568);

  // States
  static const Color success     = Color(0xFF00C896); // teal-mint (profitto, premium trading)
  static const Color successDark = Color(0xFF009E78);
  static const Color warning     = Color(0xFFF5A623);
  static const Color warningDark = Color(0xFFD4891A);
  static const Color fomo        = Color(0xFFFF6B9D);
  static const Color danger      = Color(0xFFFF4455);
  static const Color dangerDark  = Color(0xFFC42030);

  // Text
  static const Color textPrimary   = Color(0xFFF0F4F8);
  static const Color textSecondary = Color(0xFF7A8699);
  static const Color textTertiary  = Color(0xFF3D4560);

  // UI
  static const Color divider = Color(0xFF161620);
  static const Color border  = Color(0xFF1E1E28);

  // ── Glass system ─────────────────────────────────────────────────────────
  static const Color glass01           = Color(0x05FFFFFF);
  static const Color glass03           = Color(0x08FFFFFF);
  static const Color glass06           = Color(0x10FFFFFF);
  static const Color glassBorder       = Color(0x14FFFFFF);
  static const Color glassBorderStrong = Color(0x22FFFFFF);

  // ── Shadow / glow system ─────────────────────────────────────────────────
  static List<BoxShadow> glowAccent({double intensity = 1.0}) => [
    BoxShadow(
      color: accent.withValues(alpha: 0.18 * intensity),
      blurRadius: 28,
      spreadRadius: -4,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> glowSilver({double intensity = 1.0}) => [
    BoxShadow(
      color: silverBright.withValues(alpha: 0.16 * intensity),
      blurRadius: 24,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> glowDanger({double intensity = 1.0}) => [
    BoxShadow(
      color: danger.withValues(alpha: 0.30 * intensity),
      blurRadius: 32,
      spreadRadius: -4,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> glowWarning({double intensity = 1.0}) => [
    BoxShadow(
      color: warning.withValues(alpha: 0.22 * intensity),
      blurRadius: 24,
      spreadRadius: -4,
      offset: const Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x28000000), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x10000000), blurRadius: 8,  offset: Offset(0, 2)),
  ];

  // ── Hero card gradients ──────────────────────────────────────────────────
  static const LinearGradient heroGradientOk = LinearGradient(
    colors: [Color(0xFF1C2E45), Color(0xFF0F1D2E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient heroGradientWarning = LinearGradient(
    colors: [Color(0xFF2E1E08), Color(0xFF1C1205)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient heroGradientDanger = LinearGradient(
    colors: [Color(0xFFC91C1C), Color(0xFF7A1616)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Killswitch background gradient
  static const LinearGradient killswitchGradient = LinearGradient(
    colors: [Color(0xFF1A0000), Color(0xFF3D0000), Color(0xFF1A0000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Logo / brand gradient — silver chrome
  static const LinearGradient logoGradient = LinearGradient(
    colors: [Color(0xFFE8F0F6), Color(0xFF8B98AA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // CTA button gradient — dark steel premium
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF2C3E55), Color(0xFF1A2A3D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Silver metallic gradient (badge Pro, bordi speciali)
  static const LinearGradient silverGradient = LinearGradient(
    colors: [Color(0xFF8B98AA), Color(0xFFE8F0F6), Color(0xFF8B98AA)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Success / profit gradient (teal)
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00C896), Color(0xFF007A5C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Ambient background blob gradients ────────────────────────────────────
  static RadialGradient blobAccent({double opacity = 0.06}) => RadialGradient(
    colors: [accent.withValues(alpha: opacity), Colors.transparent],
    radius: 0.8,
  );
  static RadialGradient blobSilver({double opacity = 0.04}) => RadialGradient(
    colors: [silverBright.withValues(alpha: opacity), Colors.transparent],
    radius: 0.8,
  );
  static RadialGradient blobFomo({double opacity = 0.04}) => RadialGradient(
    colors: [fomo.withValues(alpha: opacity), Colors.transparent],
    radius: 0.8,
  );
  static RadialGradient blobDanger({double opacity = 0.05}) => RadialGradient(
    colors: [danger.withValues(alpha: opacity), Colors.transparent],
    radius: 0.8,
  );

  // ── Light theme ──────────────────────────────────────────────────────────
  static const Color lightBackground    = Color(0xFFF2F4FA);
  static const Color lightSurface       = Color(0xFFFFFFFF);
  static const Color lightCardBg        = Color(0xFFFFFFFF);
  static const Color lightCardBg2       = Color(0xFFF0F2FA);
  static const Color lightTextPrimary   = Color(0xFF0F1629);
  static const Color lightTextSecondary = Color(0xFF6B7489);
  static const Color lightTextTertiary  = Color(0xFF9EA8BC);
  static const Color lightDivider       = Color(0xFFE3E6EE);
  static const Color lightBorder        = Color(0xFFD8DCE9);

  // ── Per-page accent tints (background gradient overlay, very subtle) ──────
  // Dashboard: default background — no override
  // AI Planner: indigo/purple tint (intelligence, AI)
  static const Color pageAiTint      = Color(0xFF1A1035); // deep indigo bg overlay
  static const LinearGradient pageAiGradient = LinearGradient(
    colors: [Color(0xFF13102A), Color(0xFF0A0A0F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const Color pageAiAccent    = Color(0xFF9B7EF8); // soft violet

  // History/Stats: teal/emerald tint (growth, profit)
  static const Color pageHistoryTint = Color(0xFF0A1F1A);
  static const LinearGradient pageHistoryGradient = LinearGradient(
    colors: [Color(0xFF0D1F1A), Color(0xFF0A0A0F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const Color pageHistoryAccent = Color(0xFF00C896); // teal-mint

  // Settings: neutral charcoal — no accent override, same as default
  static const Color pageSettingsTint = Color(0xFF0F0F14);
}
