class JournalEntry {
  final String id;
  final String userId;
  final DateTime date;
  final String symbol;
  final String direction; // 'long' | 'short'
  final double? pnl;
  final String emotion; // 'calm'|'confident'|'anxious'|'frustrated'|'fomo'|'revenge'
  final int emotionScore; // 1-5
  final String? setupDescription;
  final String? mistakes;
  final String? lessons;
  final bool wasPlanned;
  final DateTime createdAt;

  const JournalEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.symbol,
    required this.direction,
    this.pnl,
    required this.emotion,
    required this.emotionScore,
    this.setupDescription,
    this.mistakes,
    this.lessons,
    required this.wasPlanned,
    required this.createdAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      symbol: json['symbol'] as String,
      direction: json['direction'] as String,
      pnl: json['pnl'] != null ? (json['pnl'] as num).toDouble() : null,
      emotion: json['emotion'] as String,
      emotionScore: json['emotion_score'] as int,
      setupDescription: json['setup_description'] as String?,
      mistakes: json['mistakes'] as String?,
      lessons: json['lessons'] as String?,
      wasPlanned: json['was_planned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String(),
      'symbol': symbol,
      'direction': direction,
      'pnl': pnl,
      'emotion': emotion,
      'emotion_score': emotionScore,
      'setup_description': setupDescription,
      'mistakes': mistakes,
      'lessons': lessons,
      'was_planned': wasPlanned,
      'created_at': createdAt.toIso8601String(),
    };
  }

  JournalEntry copyWith({
    String? id,
    String? userId,
    DateTime? date,
    String? symbol,
    String? direction,
    double? pnl,
    String? emotion,
    int? emotionScore,
    String? setupDescription,
    String? mistakes,
    String? lessons,
    bool? wasPlanned,
    DateTime? createdAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      symbol: symbol ?? this.symbol,
      direction: direction ?? this.direction,
      pnl: pnl ?? this.pnl,
      emotion: emotion ?? this.emotion,
      emotionScore: emotionScore ?? this.emotionScore,
      setupDescription: setupDescription ?? this.setupDescription,
      mistakes: mistakes ?? this.mistakes,
      lessons: lessons ?? this.lessons,
      wasPlanned: wasPlanned ?? this.wasPlanned,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ─── Helper getters ───────────────────────────────────────────────────────────

  String get emotionEmoji {
    switch (emotion) {
      case 'calm':
        return '😌';
      case 'confident':
        return '🦁';
      case 'anxious':
        return '😰';
      case 'frustrated':
        return '😤';
      case 'fomo':
        return '😱';
      case 'revenge':
        return '🔥';
      default:
        return '😶';
    }
  }

  String get emotionLabel {
    switch (emotion) {
      case 'calm':
        return 'Calmo';
      case 'confident':
        return 'Fiducioso';
      case 'anxious':
        return 'Ansioso';
      case 'frustrated':
        return 'Frustrato';
      case 'fomo':
        return 'FOMO';
      case 'revenge':
        return 'Revenge';
      default:
        return emotion;
    }
  }

  bool get isProfitable => pnl != null && pnl! > 0;

  // ─── Mock data ────────────────────────────────────────────────────────────────

  static List<JournalEntry> get mockList => [
        JournalEntry(
          id: 'mock-1',
          userId: 'dev-user-000',
          date: DateTime.now().subtract(const Duration(days: 0)),
          symbol: 'XAUUSD',
          direction: 'long',
          pnl: 142.50,
          emotion: 'confident',
          emotionScore: 4,
          setupDescription: 'Breakout confermato su H1 con volume crescente. Entry al retest della zona 2310.',
          mistakes: null,
          lessons: 'Aspettare il retest ha pagato. Non anticipare.',
          wasPlanned: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        JournalEntry(
          id: 'mock-2',
          userId: 'dev-user-000',
          date: DateTime.now().subtract(const Duration(days: 1)),
          symbol: 'EURUSD',
          direction: 'short',
          pnl: -87.00,
          emotion: 'anxious',
          emotionScore: 2,
          setupDescription: 'Short su resistenza weekly. SL troppo stretto.',
          mistakes: 'Stop loss sotto-dimensionato rispetto alla volatilità ATR.',
          lessons: 'Calcola SL basandoti sull\'ATR, non su valori fissi.',
          wasPlanned: true,
          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
        ),
        JournalEntry(
          id: 'mock-3',
          userId: 'dev-user-000',
          date: DateTime.now().subtract(const Duration(days: 2)),
          symbol: 'NAS100',
          direction: 'long',
          pnl: 315.00,
          emotion: 'calm',
          emotionScore: 5,
          setupDescription: 'Rimbalzo su supporto giornaliero. Risk/reward 1:3.',
          mistakes: null,
          lessons: 'La pazienza ha premiato. Setup 10/10.',
          wasPlanned: true,
          createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 2)),
        ),
        JournalEntry(
          id: 'mock-4',
          userId: 'dev-user-000',
          date: DateTime.now().subtract(const Duration(days: 3)),
          symbol: 'GBPJPY',
          direction: 'long',
          pnl: -210.00,
          emotion: 'revenge',
          emotionScore: 1,
          setupDescription: 'Entrata dopo la terza perdita della giornata.',
          mistakes: 'FOMO + revenge trading. Nessun setup valido, entrata impulsiva.',
          lessons: 'Il killswitch esiste per un motivo. Usarlo.',
          wasPlanned: false,
          createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 1)),
        ),
        JournalEntry(
          id: 'mock-5',
          userId: 'dev-user-000',
          date: DateTime.now().subtract(const Duration(days: 4)),
          symbol: 'US30',
          direction: 'short',
          pnl: 78.50,
          emotion: 'calm',
          emotionScore: 4,
          setupDescription: 'Short su open NY con divergenza RSI su M15.',
          mistakes: null,
          lessons: 'Gestione posizione eccellente, trailing stop ottimale.',
          wasPlanned: true,
          createdAt: DateTime.now().subtract(const Duration(days: 4, hours: 4)),
        ),
      ];
}
