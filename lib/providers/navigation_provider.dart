import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Route da navigare in risposta a eventi nativi (overlay MT5).
/// Impostato da broker_provider, consumato da main_nav_screen.
/// Dopo la navigazione va resettato a null.
final pendingNavigationProvider = StateProvider<String?>((ref) => null);

/// Tab index da attivare in MainNavScreen senza push di nuove route.
/// Usato da challenge_setup → torna a /main e cambia tab a AI Planner.
final pendingTabIndexProvider = StateProvider<int?>((ref) => null);
