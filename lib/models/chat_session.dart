import 'dart:convert';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        text: j['text'] as String? ?? '',
        isUser: j['isUser'] as bool? ?? false,
        timestamp: j['timestamp'] != null
            ? DateTime.parse(j['timestamp'] as String)
            : DateTime.now(),
      );
}

class ChatSession {
  final String id;
  final String title;
  final String type; // 'personal' | 'challenge'
  final String? contextName; // nome prop firm oppure 'Personale'
  final String? challengeId;
  final Map<String, dynamic>? plan;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatSession({
    required this.id,
    required this.title,
    required this.type,
    this.contextName,
    this.challengeId,
    this.plan,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  ChatSession copyWith({
    String? title,
    Map<String, dynamic>? plan,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
  }) =>
      ChatSession(
        id: id,
        title: title ?? this.title,
        type: type,
        contextName: contextName,
        challengeId: challengeId,
        plan: plan ?? this.plan,
        messages: messages ?? this.messages,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'contextName': contextName,
        'challengeId': challengeId,
        'plan': plan != null ? jsonEncode(plan) : null,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> j) {
    final rawPlan = j['plan'];
    Map<String, dynamic>? plan;
    if (rawPlan is String) {
      try { plan = jsonDecode(rawPlan) as Map<String, dynamic>; } catch (_) {}
    } else if (rawPlan is Map) {
      plan = rawPlan.cast<String, dynamic>();
    }
    return ChatSession(
      id: j['id'] as String,
      title: j['title'] as String? ?? 'Chat',
      type: j['type'] as String? ?? 'personal',
      contextName: j['contextName'] as String?,
      challengeId: j['challengeId'] as String?,
      plan: plan,
      messages: (j['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: j['createdAt'] != null
          ? DateTime.parse(j['createdAt'] as String)
          : DateTime.now(),
      updatedAt: j['updatedAt'] != null
          ? DateTime.parse(j['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}
