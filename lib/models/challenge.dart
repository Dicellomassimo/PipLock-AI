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
