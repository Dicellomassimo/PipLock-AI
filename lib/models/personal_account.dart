import 'personal_rules.dart';

class PersonalAccount {
  static const Object _sentinel = Object();

  final String id;
  final String userId;
  final String name;
  final String? accountNumber;
  final String connectionMethod; // 'manual'|'accessibility'|'ea'|'metaapi'|'ctrader'|'oanda'

  // Rule fields (mirrors PersonalRules)
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

  const PersonalAccount({
    required this.id,
    required this.userId,
    required this.name,
    this.accountNumber,
    this.connectionMethod = 'manual',
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
  });

  factory PersonalAccount.fromJson(Map<String, dynamic> json) {
    return PersonalAccount(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? 'Account',
      accountNumber: json['account_number'] as String?,
      connectionMethod: json['connection_method'] as String? ?? 'manual',
      maxDailyLoss: (json['max_daily_loss'] as num?)?.toDouble(),
      maxDailyLossType: json['max_daily_loss_type'] as String?,
      maxTradesPerDay: json['max_trades_per_day'] as int?,
      maxWeeklyLoss: (json['max_weekly_loss'] as num?)?.toDouble(),
      tradingHoursEnabled: json['trading_hours_enabled'] as bool? ?? false,
      tradingHoursStart: json['trading_hours_start'] as String?,
      tradingHoursEnd: json['trading_hours_end'] as String?,
      killswitchDuration: json['killswitch_duration'] as String? ?? '6h',
      timezone: json['timezone'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'user_id': userId,
      'name': name,
      'account_number': accountNumber,
      'connection_method': connectionMethod,
      'max_daily_loss': maxDailyLoss,
      'max_daily_loss_type': maxDailyLossType,
      'max_trades_per_day': maxTradesPerDay,
      'max_weekly_loss': maxWeeklyLoss,
      'trading_hours_enabled': tradingHoursEnabled,
      'trading_hours_start': tradingHoursStart,
      'trading_hours_end': tradingHoursEnd,
      'killswitch_duration': killswitchDuration,
      'timezone': timezone,
      'updated_at': DateTime.now().toIso8601String(),
    };
    // Only include id if non-empty — let Supabase generate it otherwise
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  PersonalAccount copyWith({
    String? id,
    String? userId,
    String? name,
    Object? accountNumber = _sentinel,
    String? connectionMethod,
    Object? maxDailyLoss = _sentinel,
    Object? maxDailyLossType = _sentinel,
    Object? maxTradesPerDay = _sentinel,
    Object? maxWeeklyLoss = _sentinel,
    bool? tradingHoursEnabled,
    Object? tradingHoursStart = _sentinel,
    Object? tradingHoursEnd = _sentinel,
    String? killswitchDuration,
    Object? timezone = _sentinel,
    Object? updatedAt = _sentinel,
  }) {
    return PersonalAccount(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      accountNumber: accountNumber == _sentinel ? this.accountNumber : accountNumber as String?,
      connectionMethod: connectionMethod ?? this.connectionMethod,
      maxDailyLoss: maxDailyLoss == _sentinel ? this.maxDailyLoss : maxDailyLoss as double?,
      maxDailyLossType: maxDailyLossType == _sentinel ? this.maxDailyLossType : maxDailyLossType as String?,
      maxTradesPerDay: maxTradesPerDay == _sentinel ? this.maxTradesPerDay : maxTradesPerDay as int?,
      maxWeeklyLoss: maxWeeklyLoss == _sentinel ? this.maxWeeklyLoss : maxWeeklyLoss as double?,
      tradingHoursEnabled: tradingHoursEnabled ?? this.tradingHoursEnabled,
      tradingHoursStart: tradingHoursStart == _sentinel ? this.tradingHoursStart : tradingHoursStart as String?,
      tradingHoursEnd: tradingHoursEnd == _sentinel ? this.tradingHoursEnd : tradingHoursEnd as String?,
      killswitchDuration: killswitchDuration ?? this.killswitchDuration,
      timezone: timezone == _sentinel ? this.timezone : timezone as String?,
      updatedAt: updatedAt == _sentinel ? this.updatedAt : updatedAt as DateTime?,
    );
  }

  /// Converts this account into a PersonalRules object (for use by RulesNotifier).
  PersonalRules toPersonalRules() {
    return PersonalRules(
      userId: userId,
      maxDailyLoss: maxDailyLoss,
      maxDailyLossType: maxDailyLossType,
      maxTradesPerDay: maxTradesPerDay,
      maxWeeklyLoss: maxWeeklyLoss,
      tradingHoursEnabled: tradingHoursEnabled,
      tradingHoursStart: tradingHoursStart,
      tradingHoursEnd: tradingHoursEnd,
      killswitchDuration: killswitchDuration,
      timezone: timezone,
      accountNumber: accountNumber,
      updatedAt: updatedAt,
    );
  }
}
