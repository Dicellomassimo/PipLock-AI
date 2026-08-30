class Profile {
  final String id;
  final String accountMode; // 'personal' | 'challenge'
  final int tokensWeekly;   // free tokens that reset every Sunday
  final int tokensPurchased; // purchased tokens that never reset
  final DateTime? tokensResetAt;
  final String subscriptionTier; // 'free' | 'pro'
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.accountMode,
    this.tokensWeekly = 2,
    this.tokensPurchased = 0,
    this.tokensResetAt,
    required this.subscriptionTier,
    required this.createdAt,
  });

  /// Total tokens available = weekly free + purchased
  int get tokensAvailable => tokensWeekly + tokensPurchased;

  factory Profile.fromJson(Map<String, dynamic> json) {
    // Support both old schema (tokens_available) and new split schema
    final rawWeekly = json['tokens_weekly'] as int?;
    final rawPurchased = json['tokens_purchased'] as int? ?? 0;
    final rawAvailable = json['tokens_available'] as int? ?? 2;
    final tokensWeekly = rawWeekly ?? (rawAvailable > rawPurchased ? rawAvailable - rawPurchased : rawAvailable).clamp(0, 2);
    return Profile(
      id: json['id'] as String,
      accountMode: json['account_mode'] as String? ?? 'personal',
      tokensWeekly: tokensWeekly,
      tokensPurchased: rawPurchased,
      tokensResetAt: json['tokens_reset_at'] != null
          ? DateTime.parse(json['tokens_reset_at'] as String)
          : null,
      subscriptionTier: json['subscription_tier'] as String? ?? 'free',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_mode': accountMode,
      'tokens_weekly': tokensWeekly,
      'tokens_purchased': tokensPurchased,
      'tokens_available': tokensAvailable,
      'tokens_reset_at': tokensResetAt?.toIso8601String(),
      'subscription_tier': subscriptionTier,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Profile copyWith({
    String? id,
    String? accountMode,
    int? tokensWeekly,
    int? tokensPurchased,
    DateTime? tokensResetAt,
    String? subscriptionTier,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      accountMode: accountMode ?? this.accountMode,
      tokensWeekly: tokensWeekly ?? this.tokensWeekly,
      tokensPurchased: tokensPurchased ?? this.tokensPurchased,
      tokensResetAt: tokensResetAt ?? this.tokensResetAt,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static Profile get mock => Profile(
        id: 'test-user-001',
        accountMode: 'personal',
        tokensWeekly: 2,
        tokensPurchased: 0,
        tokensResetAt: DateTime.now().add(const Duration(days: 3)),
        subscriptionTier: 'free',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
}
