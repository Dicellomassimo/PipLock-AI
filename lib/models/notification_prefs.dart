class NotificationPrefs {
  final String userId;
  final bool newsAlerts;
  final bool sessionChanges;
  final bool riskWarnings;
  final bool challengeReminders;
  final bool fomoAlerts;
  final String? fcmToken;

  const NotificationPrefs({
    required this.userId,
    this.newsAlerts = true,
    this.sessionChanges = true,
    this.riskWarnings = true,
    this.challengeReminders = true,
    this.fomoAlerts = true,
    this.fcmToken,
  });

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    return NotificationPrefs(
      userId: json['user_id'] as String,
      newsAlerts: json['news_alerts'] as bool? ?? true,
      sessionChanges: json['session_changes'] as bool? ?? true,
      riskWarnings: json['risk_warnings'] as bool? ?? true,
      challengeReminders: json['challenge_reminders'] as bool? ?? true,
      fomoAlerts: json['fomo_alerts'] as bool? ?? true,
      fcmToken: json['fcm_token'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'news_alerts': newsAlerts,
      'session_changes': sessionChanges,
      'risk_warnings': riskWarnings,
      'challenge_reminders': challengeReminders,
      'fomo_alerts': fomoAlerts,
      'fcm_token': fcmToken,
    };
  }

  NotificationPrefs copyWith({
    String? userId,
    bool? newsAlerts,
    bool? sessionChanges,
    bool? riskWarnings,
    bool? challengeReminders,
    bool? fomoAlerts,
    String? fcmToken,
  }) {
    return NotificationPrefs(
      userId: userId ?? this.userId,
      newsAlerts: newsAlerts ?? this.newsAlerts,
      sessionChanges: sessionChanges ?? this.sessionChanges,
      riskWarnings: riskWarnings ?? this.riskWarnings,
      challengeReminders: challengeReminders ?? this.challengeReminders,
      fomoAlerts: fomoAlerts ?? this.fomoAlerts,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  static NotificationPrefs get mock => const NotificationPrefs(
        userId: 'test-user-001',
        newsAlerts: true,
        sessionChanges: true,
        riskWarnings: true,
        challengeReminders: true,
        fomoAlerts: true,
      );
}
