import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/challenge.dart';

/// Holds a challenge that should be loaded by AiPlannerScreen immediately
/// after navigating to the main nav (e.g. right after challenge setup).
/// Consumed once by AiPlannerScreen and then cleared.
final pendingChallengeProvider = StateProvider<Challenge?>((ref) => null);
