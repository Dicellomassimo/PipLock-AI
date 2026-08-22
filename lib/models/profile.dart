class Profile {
  final String id;
  final String accountMode; // 'personal' | 'challenge'
  final int tokensAvailable;
  final DateTime? tokensResetAt;
  final String subscriptionTier; // 'free' | 'pro'
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.accountMode,
    required this.tokensAvailable,
    this.tokensResetAt,
    required this.subscriptionTier,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      accountMode: json['account_mode'] as String? ?? 'personal',
      tokensAvailable: json['tokens_available'] as int? ?? 2,
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
      'tokens_available': tokensAvailable,
      'tokens_reset_at': tokensResetAt?.toIso8601String(),
      'subscription_tier': subscriptionTier,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Profile copyWith({
    String? id,
    String? accountMode,
    int? tokensAvailable,
    DateTime? tokensResetAt,
    String? subscriptionTier,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      accountMode: accountMode ?? this.accountMode,
      tokensAvailable: tokensAvailable ?? this.tokensAvailable,
      tokensResetAt: tokensResetAt ?? this.tokensResetAt,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static Profile get mock => Profile(
        id: 'test-user-001',
        accountMode: 'personal',
        tokensAvailable: 2,
        tokensResetAt: DateTime.now().add(const Duration(days: 3)),
        subscriptionTier: 'free',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
}
