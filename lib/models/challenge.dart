class Challenge {
  final String id;
  final String userId;
  final String? propFirmName;
  final double accountSize;
  final double profitTarget;
  final double maxDailyLoss;
  final double maxTotalDrawdown;
  final int durationDays;
  final String style; // 'conservative'|'moderate'|'aggressive'
  final String status; // 'active'|'passed'|'failed'|'abandoned'
  final int currentDay;
  final Map<String, dynamic>? aiPlan;
  final DateTime startedAt;
  final String? accountNumber;

  // ── Challenge Protocol fields (migration 009) ──────────────────────
  final String? propFirmPreset;       // es. 'ftmo_2phase'
  final int phases;                   // 1 o 2
  final String drawdownType;          // 'static' | 'trailing_eod'
  final bool consistencyRule;
  final double? consistencyRulePct;   // % max winning day su totale
  final bool newsRestriction;
  final bool overnightRestriction;
  final double? winRate;              // 0.0–1.0
  final double? avgRr;                // es. 2.0 per 1:2
  final int? tradesPerDayStrategy;
  final String riskProfile;           // 'conservative'|'balanced'|'aggressive'
  final double? monteCarloPassPct;
  final String? monteCarloRange;      // es. '68–76'
  final DateTime? monteCarloUpdatedAt;

  const Challenge({
    required this.id,
    required this.userId,
    this.propFirmName,
    required this.accountSize,
    required this.profitTarget,
    required this.maxDailyLoss,
    required this.maxTotalDrawdown,
    required this.durationDays,
    required this.style,
    this.status = 'active',
    this.currentDay = 0,
    this.aiPlan,
    required this.startedAt,
    this.accountNumber,
    // Challenge Protocol fields
    this.propFirmPreset,
    this.phases = 2,
    this.drawdownType = 'static',
    this.consistencyRule = false,
    this.consistencyRulePct,
    this.newsRestriction = false,
    this.overnightRestriction = false,
    this.winRate,
    this.avgRr,
    this.tradesPerDayStrategy,
    this.riskProfile = 'balanced',
    this.monteCarloPassPct,
    this.monteCarloRange,
    this.monteCarloUpdatedAt,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      propFirmName: json['prop_firm_name'] as String?,
      accountSize: (json['account_size'] as num).toDouble(),
      profitTarget: (json['profit_target'] as num).toDouble(),
      maxDailyLoss: (json['max_daily_loss'] as num).toDouble(),
      maxTotalDrawdown: (json['max_total_drawdown'] as num).toDouble(),
      durationDays: json['duration_days'] as int,
      style: json['style'] as String? ?? 'moderate',
      status: json['status'] as String? ?? 'active',
      currentDay: json['current_day'] as int? ?? 0,
      aiPlan: json['ai_plan'] as Map<String, dynamic>?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : DateTime.now(),
      accountNumber: json['account_number'] as String?,
      // Challenge Protocol fields
      propFirmPreset: json['prop_firm_preset'] as String?,
      phases: json['phases'] as int? ?? 2,
      drawdownType: json['drawdown_type'] as String? ?? 'static',
      consistencyRule: json['consistency_rule'] as bool? ?? false,
      consistencyRulePct: (json['consistency_rule_pct'] as num?)?.toDouble(),
      newsRestriction: json['news_restriction'] as bool? ?? false,
      overnightRestriction: json['overnight_restriction'] as bool? ?? false,
      winRate: (json['win_rate'] as num?)?.toDouble(),
      avgRr: (json['avg_rr'] as num?)?.toDouble(),
      tradesPerDayStrategy: json['trades_per_day_strategy'] as int?,
      riskProfile: json['risk_profile'] as String? ?? 'balanced',
      monteCarloPassPct: (json['monte_carlo_pass_pct'] as num?)?.toDouble(),
      monteCarloRange: json['monte_carlo_range'] as String?,
      monteCarloUpdatedAt: json['monte_carlo_updated_at'] != null
          ? DateTime.parse(json['monte_carlo_updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'prop_firm_name': propFirmName,
      'account_size': accountSize,
      'profit_target': profitTarget,
      'max_daily_loss': maxDailyLoss,
      'max_total_drawdown': maxTotalDrawdown,
      'duration_days': durationDays,
      'style': style,
      'status': status,
      'current_day': currentDay,
      'ai_plan': aiPlan,
      'started_at': startedAt.toIso8601String(),
      'account_number': accountNumber,
      // Challenge Protocol fields
      'prop_firm_preset': propFirmPreset,
      'phases': phases,
      'drawdown_type': drawdownType,
      'consistency_rule': consistencyRule,
      'consistency_rule_pct': consistencyRulePct,
      'news_restriction': newsRestriction,
      'overnight_restriction': overnightRestriction,
      'win_rate': winRate,
      'avg_rr': avgRr,
      'trades_per_day_strategy': tradesPerDayStrategy,
      'risk_profile': riskProfile,
      'monte_carlo_pass_pct': monteCarloPassPct,
      'monte_carlo_range': monteCarloRange,
      'monte_carlo_updated_at': monteCarloUpdatedAt?.toIso8601String(),
    };
  }

  Challenge copyWith({
    String? id,
    String? userId,
    String? propFirmName,
    double? accountSize,
    double? profitTarget,
    double? maxDailyLoss,
    double? maxTotalDrawdown,
    int? durationDays,
    String? style,
    String? status,
    int? currentDay,
    Map<String, dynamic>? aiPlan,
    DateTime? startedAt,
    String? accountNumber,
    // Challenge Protocol fields
    String? propFirmPreset,
    int? phases,
    String? drawdownType,
    bool? consistencyRule,
    double? consistencyRulePct,
    bool? newsRestriction,
    bool? overnightRestriction,
    double? winRate,
    double? avgRr,
    int? tradesPerDayStrategy,
    String? riskProfile,
    double? monteCarloPassPct,
    String? monteCarloRange,
    DateTime? monteCarloUpdatedAt,
  }) {
    return Challenge(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      propFirmName: propFirmName ?? this.propFirmName,
      accountSize: accountSize ?? this.accountSize,
      profitTarget: profitTarget ?? this.profitTarget,
      maxDailyLoss: maxDailyLoss ?? this.maxDailyLoss,
      maxTotalDrawdown: maxTotalDrawdown ?? this.maxTotalDrawdown,
      durationDays: durationDays ?? this.durationDays,
      style: style ?? this.style,
      status: status ?? this.status,
      currentDay: currentDay ?? this.currentDay,
      aiPlan: aiPlan ?? this.aiPlan,
      startedAt: startedAt ?? this.startedAt,
      accountNumber: accountNumber ?? this.accountNumber,
      propFirmPreset: propFirmPreset ?? this.propFirmPreset,
      phases: phases ?? this.phases,
      drawdownType: drawdownType ?? this.drawdownType,
      consistencyRule: consistencyRule ?? this.consistencyRule,
      consistencyRulePct: consistencyRulePct ?? this.consistencyRulePct,
      newsRestriction: newsRestriction ?? this.newsRestriction,
      overnightRestriction: overnightRestriction ?? this.overnightRestriction,
      winRate: winRate ?? this.winRate,
      avgRr: avgRr ?? this.avgRr,
      tradesPerDayStrategy: tradesPerDayStrategy ?? this.tradesPerDayStrategy,
      riskProfile: riskProfile ?? this.riskProfile,
      monteCarloPassPct: monteCarloPassPct ?? this.monteCarloPassPct,
      monteCarloRange: monteCarloRange ?? this.monteCarloRange,
      monteCarloUpdatedAt: monteCarloUpdatedAt ?? this.monteCarloUpdatedAt,
    );
  }

  static Challenge get mock => Challenge(
        id: 'challenge-001',
        userId: 'test-user-001',
        propFirmName: 'FTMO',
        accountSize: 50000,
        profitTarget: 10,
        maxDailyLoss: 5,
        maxTotalDrawdown: 10,
        durationDays: 30,
        style: 'moderate',
        status: 'active',
        currentDay: 8,
        aiPlan: {
          'successPercentage': 78,
          'recommendedLotSize': 0.5,
          'recommendedTradesPerDay': 2,
          'riskPerTrade': 0.5,
          'softKillswitchThreshold': 1.5,
          'hardKillswitchThreshold': 2.5,
          'milestones': [
            {
              'week': 1,
              'profitTarget': 2,
              'description': 'Fase di base, rischio conservativo'
            },
            {'week': 2, 'profitTarget': 4, 'description': 'Consolidamento'},
            {'week': 3, 'profitTarget': 7, 'description': 'Accelerazione'},
            {'week': 4, 'profitTarget': 10, 'description': 'Obiettivo finale'},
          ],
          'generatedAt': DateTime.now().toIso8601String(),
          'lastAdjustedAt': null,
        },
        startedAt: DateTime.now().subtract(const Duration(days: 7)),
      );
}
