import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/accessibility_service.dart';
import 'broker_provider.dart';
import 'killswitch_provider.dart';
import 'rules_provider.dart';
import 'auth_provider.dart';

/// Ascolta gli eventi dell'Accessibility Service e:
/// 1. Aggiorna brokerProvider con i dati finanziari estratti (MT5/cTrader mobile)
/// 2. Aggiorna il nome dell'app broker rilevata
/// 3. Triggera il Killswitch quando vengono rilevati pattern di overtrading
class AccessibilityWatcher {
  final Ref _ref;
  StreamSubscription? _eventSub;
  StreamSubscription? _dataSub;
  bool _disposed = false;

  AccessibilityWatcher(this._ref) {
    _startListening();
  }

  void _startListening() {
    if (_disposed) return;
    _eventSub?.cancel();
    _dataSub?.cancel();

    // Ascolta eventi: apertura app broker, killswitch nativo, ecc.
    _eventSub = AccessibilityService.brokerEvents.listen((event) {
      final eventType = event['event_type'] as String? ?? '';

      if (eventType == 'broker_opened') {
        final appName = event['app_name'] as String? ?? 'App Broker';
        _ref.read(brokerProvider.notifier).setDetectedApp(appName);
      }

      // Killswitch attivato nativamente (da PipLockAccessibilityService Kotlin)
      // → sincronizza lo stato Flutter così il bottone token funziona
      if (eventType == 'killswitch_native_active') {
        final reason = event['reason'] as String? ?? 'daily_loss';
        final remainingMin = event['remaining_minutes'] as int? ?? 360;
        final ksState = _ref.read(killswitchProvider);
        if (!ksState.isActive) {
          // activateNative: non chiama showKillswitchOverlay (già attivo nativo)
          _ref.read(killswitchProvider.notifier).activateNative(reason, remainingMin);
        }
      }
    }, onError: (_) {
      // Stream error → reconnect after 5s
      if (!_disposed) {
        Future.delayed(const Duration(seconds: 5), _startListening);
      }
    });

    // Ascolta i dati finanziari estratti dall'albero di accessibilità
    _dataSub = AccessibilityService.brokerDataStream.listen((data) {
      final equity    = data['equity']    as double?;
      final balance   = data['balance']   as double?;
      final profit    = data['profit']    as double?;
      final positions = data['positions'] as int?;

      // Aggiorna brokerProvider con i dati estratti
      _ref.read(brokerProvider.notifier).updateFromAccessibility(
        equity: equity,
        balance: balance,
        profit: profit,
        positions: positions,
      );

      // Controlla limite trade (accessibility conta ogni apertura come evento)
      _checkTradeLimit();
    }, onError: (_) {
      // Stream error → reconnect (già gestito da _eventSub, ma riavvia entrambi)
      if (!_disposed) {
        Future.delayed(const Duration(seconds: 5), _startListening);
      }
    });
  }

  void _checkTradeLimit() {
    final ksState = _ref.read(killswitchProvider);
    if (ksState.isActive) return;

    final rulesState = _ref.read(rulesProvider);
    final maxTrades = rulesState.rules?.maxTradesPerDay;
    if (maxTrades == null || maxTrades <= 0) return;

    final tradesToday = _ref.read(brokerProvider).tradesToday ?? 0;
    if (tradesToday >= maxTrades) {
      final userId = _ref.read(currentUserIdProvider);
      final duration = rulesState.rules?.killswitchDuration ?? '6h';
      _ref.read(killswitchProvider.notifier).activateAndSave(
        'max_trades',
        _durationMinutes(duration),
        userId,
        'personal',
      );
    }
  }

  int _durationMinutes(String d) {
    switch (d) {
      case '2h':   return 120;
      case '6h':   return 360;
      case '24h':  return 1440;
      default:
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day + 1);
        return midnight.difference(now).inMinutes;
    }
  }

  void dispose() {
    _disposed = true;
    _eventSub?.cancel();
    _dataSub?.cancel();
  }
}

final accessibilityWatcherProvider = Provider<AccessibilityWatcher>((ref) {
  final watcher = AccessibilityWatcher(ref);
  ref.onDispose(() => watcher.dispose());
  return watcher;
});
