import 'package:flutter_riverpod/flutter_riverpod.dart';

// Tiene in memoria l'ultimo piano personale generato dall'AI Planner
final personalPlanProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
