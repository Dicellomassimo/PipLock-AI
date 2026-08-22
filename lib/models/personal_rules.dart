class PersonalRules {
  final String userId;
  final double? maxDailyLoss;
  final String? maxDailyLossType; // 'amount' | 'percent'
  final int? maxTradesPerDay;
  final double? maxWeeklyLoss;
  final bool tradingHoursEnabled;
  final String? tradingHoursStart; // 'HH:mm'
  final String? tradingHoursEnd;
  final String killswitchDuration; // '2h'|'6h'|'midnight'|'24h'
  final String? timezone;
  final DateTime? updatedAt;
  /// Numero account MT5/cTrader (6-9 cifre). Se impostato, il killswitch
  /// si attiva SOLO quando PipLock rileva questo account specifico su MT5.
  final String? accountNumber;

  const PersonalRules({
    required this.userId,
    this.maxDailyLoss,
    this.maxDailyLossType,
    this.maxTradesPerDay,
    this.maxWeeklyLoss,
    this.tradingHoursEnabled = false,
    this.tradingHoursStart,
    this.tradingHoursEnd,
    this.killswitchDuration = '6h',
    this.timezone,
    this.updatedAt,
    this.accountNumber,
  });

  factory PersonalRules.fromJson(Map<String, dynamic> json) {
    return PersonalRules(
      userId: json['user_id'] as String,
      maxDailyLoss: (json['max_daily_loss'] as num?)?.toDouble(),
      maxDailyLossType: json['max_daily_loss_type'] as String?,
      maxTradesPerDay: json['max_trades_per_day'] as int?,
      maxWeeklyLoss: (json['max_weekly_loss'] as num?)?.toDouble(),
      tradingHoursEnabled: json['trading_hours_enabled'] as bool? ?? false,
      tradingHoursStart: json['trading_hours_start'] as String?,
      tradingHoursEnd: json['trading_hours_end'] as String?,
      killswitchDuration: json['killswitch_duration'] as String? ?? '6h',
      timezone: json['timezone'] as String?,
      accountNumber: json['account_number'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'max_daily_loss': maxDailyLoss,
      'max_daily_loss_type': maxDailyLossType,
      'max_trades_per_day': maxTradesPerDay,
      'max_weekly_loss': maxWeeklyLoss,
      'trading_hours_enabled': tradingHoursEnabled,
      'trading_hours_start': tradingHoursStart,
      'trading_hours_end': tradingHoursEnd,
      'killswitch_duration': killswitchDuration,
      'timezone': timezone,
      'account_number': accountNumber,
      'updated_at': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  PersonalRules copyWith({
    String? userId,
    double? maxDailyLoss,
    String? maxDailyLossType,
    int? maxTradesPerDay,
    double? maxWeeklyLoss,
    bool? tradingHoursEnabled,
    String? tradingHoursStart,
    String? tradingHoursEnd,
    String? killswitchDuration,
    String? timezone,
    DateTime? updatedAt,
    Object? accountNumber = _sentinel,
  }) {
    return PersonalRules(
      userId: userId ?? this.userId,
      maxDailyLoss: maxDailyLoss ?? this.maxDailyLoss,
      maxDailyLossType: maxDailyLossType ?? this.maxDailyLossType,
      maxTradesPerDay: maxTradesPerDay ?? this.maxTradesPerDay,
      maxWeeklyLoss: maxWeeklyLoss ?? this.maxWeeklyLoss,
      tradingHoursEnabled: tradingHoursEnabled ?? this.tradingHoursEnabled,
      tradingHoursStart: tradingHoursStart ?? this.tradingHoursStart,
      tradingHoursEnd: tradingHoursEnd ?? this.tradingHoursEnd,
      killswitchDuration: killswitchDuration ?? this.killswitchDuration,
      timezone: timezone ?? this.timezone,
      accountNumber: accountNumber == _sentinel ? this.accountNumber : accountNumber as String?,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const Object _sentinel = Object();

  static PersonalRules get mock => const PersonalRules(
        userId: 'test-user-001',
        maxDailyLoss: 100.0,
        maxDailyLossType: 'amount',
        maxTradesPerDay: 3,
        maxWeeklyLoss: 300.0,
        tradingHoursEnabled: true,
        tradingHoursStart: '08:00',
        tradingHoursEnd: '18:00',
        killswitchDuration: '6h',
        timezone: 'Europe/Rome',
      );
}
