// lib/config/prop_firm_presets.dart
// Prop firm presets for PipLock AI — verified August 2026.
// Pure Dart — no external imports required.

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class PropFirmPreset {
  final String id;
  final String firmName;
  final String modelName;
  final String assetClass; // 'forex_cfd' | 'futures'
  final int phases; // 1 or 2
  final double profitTargetPct; // phase-1 target (or sole target)
  final double? profitTargetP2Pct; // phase-2 target; null if 1-phase
  final double maxDailyLossPct;
  final double maxDrawdownPct;
  final String drawdownType; // 'static' | 'trailing_eod'
  final int minTradingDays; // 0 = no minimum
  final bool hasConsistencyRule;
  final double? consistencyRulePct; // % cap; null when rule exists but threshold not published
  final String? consistencyRuleNote;
  final bool newsRestriction;
  final String? newsRestrictionNote;
  final bool overnightRestriction;
  final String? notes;
  final DateTime lastVerifiedAt;

  const PropFirmPreset({
    required this.id,
    required this.firmName,
    required this.modelName,
    this.assetClass = 'forex_cfd',
    required this.phases,
    required this.profitTargetPct,
    this.profitTargetP2Pct,
    required this.maxDailyLossPct,
    required this.maxDrawdownPct,
    required this.drawdownType,
    this.minTradingDays = 0,
    required this.hasConsistencyRule,
    this.consistencyRulePct,
    this.consistencyRuleNote,
    required this.newsRestriction,
    this.newsRestrictionNote,
    required this.overnightRestriction,
    this.notes,
    required this.lastVerifiedAt,
  });
}

class PropFirmConfig {
  final String firmId;
  final String firmName;
  final String logoAsset;
  final List<int> accountSizes;
  final List<PropFirmPreset> presets;

  const PropFirmConfig({
    required this.firmId,
    required this.firmName,
    required this.logoAsset,
    required this.accountSizes,
    required this.presets,
  });
}

// ---------------------------------------------------------------------------
// Shared sentinel date — update whenever rules are re-verified
// ---------------------------------------------------------------------------

final _verified = DateTime.utc(2026, 8, 28);

// ---------------------------------------------------------------------------
// FTMO
// ---------------------------------------------------------------------------

final _ftmoPresets = [
  PropFirmPreset(
    id: 'ftmo_2phase',
    firmName: 'FTMO',
    modelName: '2-Phase Challenge',
    phases: 2,
    profitTargetPct: 10,
    profitTargetP2Pct: 5,
    maxDailyLossPct: 5,
    maxDrawdownPct: 10,
    drawdownType: 'static',
    minTradingDays: 4,
    hasConsistencyRule: false,
    newsRestriction: true,
    newsRestrictionNote:
        'No new trades 2 min before/after high-impact events (funded only)',
    overnightRestriction: false,
    notes:
        'Static drawdown: floor fixed at 90% of initial balance, never moves up. '
        'Fee refunded at first payout.',
    lastVerifiedAt: _verified,
  ),
  PropFirmPreset(
    id: 'ftmo_1phase',
    firmName: 'FTMO',
    modelName: '1-Phase Challenge',
    phases: 1,
    profitTargetPct: 10,
    maxDailyLossPct: 3,
    maxDrawdownPct: 10,
    drawdownType: 'trailing_eod',
    minTradingDays: 4,
    hasConsistencyRule: true,
    consistencyRulePct: null,
    consistencyRuleNote:
        'Best Day Rule: no single day should represent a disproportionate share '
        'of total profit (exact threshold not published)',
    newsRestriction: true,
    newsRestrictionNote:
        'No new trades 2 min before/after high-impact events (funded only)',
    overnightRestriction: false,
    notes:
        'Trailing EOD drawdown: floor rises as end-of-day balance grows. '
        'More restrictive than 2-phase. 90% profit split.',
    lastVerifiedAt: _verified,
  ),
];

// ---------------------------------------------------------------------------
// FundingPips
// ---------------------------------------------------------------------------

final _fundingpipsPresets = [
  PropFirmPreset(
    id: 'fundingpips_2step',
    firmName: 'FundingPips',
    modelName: '2-Step Standard',
    phases: 2,
    profitTargetPct: 8,
    profitTargetP2Pct: 5,
    maxDailyLossPct: 5,
    maxDrawdownPct: 10,
    drawdownType: 'static',
    minTradingDays: 0,
    hasConsistencyRule: false,
    newsRestriction: true,
    newsRestrictionNote:
        'No new positions 3 min before/after high-impact news (funded only). '
        'Managing existing positions allowed.',
    overnightRestriction: false,
    notes:
        'Fee refunded at first payout. '
        'Striking system on Master accounts >\$25K.',
    lastVerifiedAt: _verified,
  ),
  PropFirmPreset(
    id: 'fundingpips_1step',
    firmName: 'FundingPips',
    modelName: '1-Step Funded',
    phases: 1,
    profitTargetPct: 10,
    maxDailyLossPct: 3,
    maxDrawdownPct: 6,
    drawdownType: 'static',
    minTradingDays: 0,
    hasConsistencyRule: false,
    newsRestriction: true,
    newsRestrictionNote:
        'No new positions 3 min before/after high-impact news (funded only).',
    overnightRestriction: false,
    lastVerifiedAt: _verified,
  ),
  PropFirmPreset(
    id: 'fundingpips_zero',
    firmName: 'FundingPips',
    modelName: 'Zero (Instant Funding)',
    phases: 1,
    profitTargetPct: 0, // no profit target — instant funding
    maxDailyLossPct: 0, // no separate daily limit
    maxDrawdownPct: 5,
    drawdownType: 'trailing_eod',
    minTradingDays: 0,
    hasConsistencyRule: true,
    consistencyRulePct: 15,
    consistencyRuleNote:
        'Best day cannot exceed 15% of total profits at payout',
    newsRestriction: true,
    newsRestrictionNote: 'No trading during news events',
    overnightRestriction: true,
    notes:
        'Trailing drawdown based on highest equity reached. '
        'No overnight/weekend positions.',
    lastVerifiedAt: _verified,
  ),
];

// ---------------------------------------------------------------------------
// FundedNext
// ---------------------------------------------------------------------------

final _fundednextPresets = [
  PropFirmPreset(
    id: 'fundednext_2step',
    firmName: 'FundedNext',
    modelName: 'Stellar 2-Step',
    phases: 2,
    profitTargetPct: 10,
    profitTargetP2Pct: 5,
    maxDailyLossPct: 5,
    maxDrawdownPct: 10,
    drawdownType: 'static',
    minTradingDays: 0,
    hasConsistencyRule: true,
    consistencyRulePct: 40,
    consistencyRuleNote:
        'No single day can bring more than 40% of the profit target '
        '(challenge phase only; removed in funded)',
    newsRestriction: false,
    overnightRestriction: false,
    notes:
        'Static drawdown. Consistency rule applies only during challenge, '
        'removed in funded account (2026).',
    lastVerifiedAt: _verified,
  ),
  PropFirmPreset(
    id: 'fundednext_lite',
    firmName: 'FundedNext',
    modelName: 'Stellar Lite (2-Step)',
    phases: 2,
    profitTargetPct: 8,
    profitTargetP2Pct: 4,
    maxDailyLossPct: 5,
    maxDrawdownPct: 10,
    drawdownType: 'static',
    minTradingDays: 0,
    hasConsistencyRule: true,
    consistencyRulePct: 40,
    consistencyRuleNote:
        'Same 40% consistency rule as Stellar 2-Step',
    newsRestriction: false,
    overnightRestriction: false,
    lastVerifiedAt: _verified,
  ),
  PropFirmPreset(
    id: 'fundednext_1step',
    firmName: 'FundedNext',
    modelName: 'Stellar 1-Step',
    phases: 1,
    profitTargetPct: 10,
    maxDailyLossPct: 5,
    maxDrawdownPct: 6,
    drawdownType: 'static',
    minTradingDays: 0,
    hasConsistencyRule: false,
    newsRestriction: false,
    overnightRestriction: false,
    notes:
        'Tighter max drawdown (6%) vs 2-step (10%). No consistency rule.',
    lastVerifiedAt: _verified,
  ),
];

// ---------------------------------------------------------------------------
// The Funded Trader (TFT)
// ---------------------------------------------------------------------------

final _tftPresets = [
  PropFirmPreset(
    id: 'tft_classic2step',
    firmName: 'The Funded Trader',
    modelName: 'Classic 2-Step',
    phases: 2,
    profitTargetPct: 10,
    profitTargetP2Pct: 5,
    maxDailyLossPct: 3,
    maxDrawdownPct: 6,
    drawdownType: 'static',
    minTradingDays: 0,
    hasConsistencyRule: false,
    newsRestriction: false,
    overnightRestriction: false,
    notes:
        'Tighter daily loss (3%) and max drawdown (6%) than most firms. '
        'Verify current rules at thefundedtraderprogram.com — rules change frequently.',
    lastVerifiedAt: _verified,
  ),
  PropFirmPreset(
    id: 'tft_knight2step',
    firmName: 'The Funded Trader',
    modelName: 'Knight 2-Step',
    phases: 2,
    profitTargetPct: 8,
    profitTargetP2Pct: 5,
    maxDailyLossPct: 5,
    maxDrawdownPct: 10,
    drawdownType: 'static',
    minTradingDays: 0,
    hasConsistencyRule: false,
    newsRestriction: false,
    overnightRestriction: false,
    notes:
        'Up to 99% profit split. '
        'Verify current rules at thefundedtraderprogram.com.',
    lastVerifiedAt: _verified,
  ),
];

// ---------------------------------------------------------------------------
// E8 Markets
// ---------------------------------------------------------------------------

final _e8Presets = [
  PropFirmPreset(
    id: 'e8_signature',
    firmName: 'E8 Markets',
    modelName: 'Signature',
    phases: 1,
    profitTargetPct: 8,
    maxDailyLossPct: 4,
    maxDrawdownPct: 8,
    drawdownType: 'static',
    minTradingDays: 0,
    hasConsistencyRule: true,
    consistencyRulePct: 35,
    consistencyRuleNote:
        'No single day can exceed 35% of total profit accumulated since '
        'becoming funded (funded phase only)',
    newsRestriction: true,
    newsRestrictionNote:
        'No trading 5 min before/after high-impact news (funded only)',
    overnightRestriction: false,
    notes:
        'Consistency rule applies in funded account only, not during evaluation.',
    lastVerifiedAt: _verified,
  ),
  PropFirmPreset(
    id: 'e8_one',
    firmName: 'E8 Markets',
    modelName: 'ONE (Configurable)',
    phases: 1,
    // Mid-range defaults — fully configurable (6–21% target, 3–9.2% daily, 4–14% DD)
    profitTargetPct: 10,
    maxDailyLossPct: 5,
    maxDrawdownPct: 8,
    drawdownType: 'static',
    minTradingDays: 0,
    hasConsistencyRule: true,
    consistencyRulePct: 40,
    consistencyRuleNote:
        'No single day can exceed 40% of total profit (funded phase). '
        'Rule applies to all ONE configurations.',
    newsRestriction: true,
    newsRestrictionNote:
        'No trading 5 min before/after high-impact news (funded only)',
    overnightRestriction: false,
    notes:
        'Fully configurable: profit target (6–21%), daily loss (3–9.2%), '
        'max drawdown (4–14%), profit split (80–100%). '
        'Defaults shown are mid-range estimates.',
    lastVerifiedAt: _verified,
  ),
];

// ---------------------------------------------------------------------------
// Topstep — FUTURES ONLY
// ---------------------------------------------------------------------------

final _topstepPresets = [
  PropFirmPreset(
    id: 'topstep_combine',
    firmName: 'Topstep',
    modelName: 'Trading Combine (Futures)',
    assetClass: 'futures',
    phases: 1,
    // Percentages shown for $50K account (most common entry point).
    // $50K: target=$3000 (6%), DLL=$1000 (2%), DD=$2000 (4%)
    // $100K: target=$6000 (6%), DLL=$2000 (2%), DD=$3000 (3%)
    // $150K: target=$9000 (6%), DLL=$3000 (2%), DD=$3000 (3%)
    profitTargetPct: 6,
    maxDailyLossPct: 2,
    maxDrawdownPct: 4, // 4% on $50K; 3% on $100K/$150K — use lower as default
    drawdownType: 'trailing_eod',
    minTradingDays: 0,
    hasConsistencyRule: true,
    consistencyRulePct: 50,
    consistencyRuleNote:
        'Best Day Rule: best day must stay below 50% of profit target. '
        'If exceeded, target is increased proportionally '
        '(not a disqualifying breach)',
    newsRestriction: false,
    overnightRestriction: false,
    notes:
        '⚡ FUTURES ONLY (CME). '
        'Trailing EOD drawdown: floor rises with end-of-day balance. '
        'Monthly subscription model. '
        'First payout: min 5 winning days ≥\$150 each. '
        'Drawdown % varies by account size: 4% (\$50K), 3% (\$100K–\$150K).',
    lastVerifiedAt: _verified,
  ),
];

// ---------------------------------------------------------------------------
// Apex Trader Funding — FUTURES ONLY
// ---------------------------------------------------------------------------

final _apexPresets = [
  PropFirmPreset(
    id: 'apex_eod',
    firmName: 'Apex Trader Funding',
    modelName: 'EOD Trail (Futures)',
    assetClass: 'futures',
    phases: 1,
    profitTargetPct: 6,
    maxDailyLossPct: 2,
    maxDrawdownPct: 5, // e.g. $2500 buffer on $50K account
    drawdownType: 'trailing_eod',
    minTradingDays: 0,
    hasConsistencyRule: true,
    consistencyRulePct: 30,
    consistencyRuleNote:
        'No single day can exceed 30% of total accumulated profit at payout time',
    newsRestriction: false,
    overnightRestriction: false,
    notes:
        '⚡ FUTURES ONLY (CME). '
        '30-day evaluation time limit. '
        'Trailing drawdown updated once daily at 16:59:59 ET. '
        'Consistency rule applies only at payout, not during evaluation.',
    lastVerifiedAt: _verified,
  ),
  PropFirmPreset(
    id: 'apex_intraday',
    firmName: 'Apex Trader Funding',
    modelName: 'Intraday Trail (Futures)',
    assetClass: 'futures',
    phases: 1,
    profitTargetPct: 6,
    maxDailyLossPct: 0, // no separate DLL — absorbed by intraday trailing DD
    maxDrawdownPct: 5,
    // 'trailing_eod' used as closest proxy; real behaviour is intraday on peak equity
    drawdownType: 'trailing_eod',
    minTradingDays: 0,
    hasConsistencyRule: true,
    consistencyRulePct: 30,
    consistencyRuleNote:
        'Same 30% consistency rule as EOD Trail',
    newsRestriction: false,
    overnightRestriction: false,
    notes:
        '⚡ FUTURES ONLY. '
        'Trailing drawdown on real-time peak equity (including unrealized P&L). '
        'No separate daily loss limit. '
        'Floor locks when account reaches initial balance + \$100.',
    lastVerifiedAt: _verified,
  ),
];

// ---------------------------------------------------------------------------
// Custom / Other
// ---------------------------------------------------------------------------

final _customPresets = [
  PropFirmPreset(
    id: 'custom_default',
    firmName: 'Custom / Other',
    modelName: 'Custom Rules',
    phases: 2,
    profitTargetPct: 10,
    profitTargetP2Pct: 5,
    maxDailyLossPct: 5,
    maxDrawdownPct: 10,
    drawdownType: 'static',
    minTradingDays: 0,
    hasConsistencyRule: false,
    newsRestriction: false,
    overnightRestriction: false,
    notes: "Enter your firm's rules manually. All fields are editable.",
    lastVerifiedAt: _verified,
  ),
];

// ---------------------------------------------------------------------------
// Master list
// ---------------------------------------------------------------------------

final List<PropFirmConfig> kPropFirmConfigs = [
  PropFirmConfig(
    firmId: 'ftmo',
    firmName: 'FTMO',
    logoAsset: 'assets/images/Icona PipLock.png',
    accountSizes: [10000, 25000, 50000, 100000, 200000],
    presets: _ftmoPresets,
  ),
  PropFirmConfig(
    firmId: 'fundingpips',
    firmName: 'FundingPips',
    logoAsset: 'assets/images/Icona PipLock.png',
    accountSizes: [5000, 10000, 25000, 50000, 100000, 200000],
    presets: _fundingpipsPresets,
  ),
  PropFirmConfig(
    firmId: 'fundednext',
    firmName: 'FundedNext',
    logoAsset: 'assets/images/Icona PipLock.png',
    accountSizes: [6000, 10000, 25000, 50000, 100000, 200000],
    presets: _fundednextPresets,
  ),
  PropFirmConfig(
    firmId: 'tft',
    firmName: 'The Funded Trader',
    logoAsset: 'assets/images/Icona PipLock.png',
    accountSizes: [5000, 25000, 50000, 100000, 200000],
    presets: _tftPresets,
  ),
  PropFirmConfig(
    firmId: 'e8',
    firmName: 'E8 Markets',
    logoAsset: 'assets/images/Icona PipLock.png',
    accountSizes: [25000, 50000, 100000, 150000],
    presets: _e8Presets,
  ),
  PropFirmConfig(
    firmId: 'topstep',
    firmName: 'Topstep',
    logoAsset: 'assets/images/Icona PipLock.png',
    accountSizes: [50000, 100000, 150000],
    presets: _topstepPresets,
  ),
  PropFirmConfig(
    firmId: 'apex',
    firmName: 'Apex Trader Funding',
    logoAsset: 'assets/images/Icona PipLock.png',
    accountSizes: [25000, 50000, 100000, 150000],
    presets: _apexPresets,
  ),
  PropFirmConfig(
    firmId: 'custom',
    firmName: 'Custom / Other',
    logoAsset: 'assets/images/Icona PipLock.png',
    accountSizes: [10000, 25000, 50000, 100000, 200000],
    presets: _customPresets,
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns the [PropFirmConfig] matching [firmId], or null if not found.
PropFirmConfig? getPropFirmById(String firmId) {
  for (final config in kPropFirmConfigs) {
    if (config.firmId == firmId) return config;
  }
  return null;
}

/// Returns the [PropFirmPreset] matching [presetId] across all firms, or null.
PropFirmPreset? getPresetById(String presetId) {
  for (final config in kPropFirmConfigs) {
    for (final preset in config.presets) {
      if (preset.id == presetId) return preset;
    }
  }
  return null;
}
