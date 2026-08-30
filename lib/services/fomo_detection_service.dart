import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

/// Detects potential FOMO entries by checking for recent price spikes on Finnhub.
///
/// Logic: when a new position is detected, call [checkSpike] with the instrument
/// symbol and the time the position was opened. If the price moved more than
/// [defaultThresholdPct]% in the preceding 15 minutes, a [FomoSignal] is returned.
///
/// Uses Finnhub forex/candle API (free tier supports FX and crypto).
/// MT5 symbol names are mapped to Finnhub format via [_symbolMap].
/// Unsupported symbols return null (detection silently skipped).
class FomoDetectionService {
  static const _baseUrl = 'https://finnhub.io/api/v1';
  static const double defaultThresholdPct = 0.5; // 0.5% move in 15 min = FOMO risk

  /// Maps common MT5 symbols to Finnhub forex/crypto identifiers.
  static const _symbolMap = <String, String>{
    'EURUSD':  'OANDA:EUR_USD',
    'GBPUSD':  'OANDA:GBP_USD',
    'USDJPY':  'OANDA:USD_JPY',
    'USDCHF':  'OANDA:USD_CHF',
    'AUDUSD':  'OANDA:AUD_USD',
    'USDCAD':  'OANDA:USD_CAD',
    'NZDUSD':  'OANDA:NZD_USD',
    'EURGBP':  'OANDA:EUR_GBP',
    'EURJPY':  'OANDA:EUR_JPY',
    'GBPJPY':  'OANDA:GBP_JPY',
    'XAUUSD':  'OANDA:XAU_USD',
    'US30':    'OANDA:US30_USD',
    'NAS100':  'OANDA:NAS100_USD',
    'BTCUSD':  'BINANCE:BTCUSDT',
    'ETHUSD':  'BINANCE:ETHUSDT',
  };

  /// Checks for a price spike on [mt5Symbol] in the 15 minutes before [positionOpenedAt].
  ///
  /// Returns a [FomoSignal] if the move exceeds [thresholdPct], otherwise null.
  /// Returns null immediately if Finnhub API key is not configured or symbol is unknown.
  static Future<FomoSignal?> checkSpike(
    String mt5Symbol, {
    DateTime? positionOpenedAt,
    double thresholdPct = defaultThresholdPct,
  }) async {
    final apiKey = EnvConfig.finnhubApiKey;
    if (apiKey.isEmpty) return null;

    final finnhubSymbol = _symbolMap[mt5Symbol.toUpperCase()];
    if (finnhubSymbol == null) return null;

    final to = positionOpenedAt ?? DateTime.now();
    final from = to.subtract(const Duration(minutes: 15));
    final fromTs = from.millisecondsSinceEpoch ~/ 1000;
    final toTs = to.millisecondsSinceEpoch ~/ 1000;

    try {
      final uri = Uri.parse(
        '$_baseUrl/forex/candle?symbol=$finnhubSymbol&resolution=1&from=$fromTs&to=$toTs&token=$apiKey',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['s'] != 'ok') return null;

      final closes = List<double>.from(
        (data['c'] as List).map((v) => (v as num).toDouble()),
      );
      if (closes.length < 2) return null;

      final first = closes.first;
      final last = closes.last;
      if (first == 0) return null;

      final movePct = ((last - first) / first * 100).abs();
      if (movePct < thresholdPct) return null;

      return FomoSignal(
        symbol: mt5Symbol,
        movePct: movePct,
        direction: last > first ? 'up' : 'down',
        windowMinutes: 15,
        detectedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}

class FomoSignal {
  final String symbol;
  final double movePct;
  final String direction; // 'up' or 'down'
  final int windowMinutes;
  final DateTime detectedAt;

  const FomoSignal({
    required this.symbol,
    required this.movePct,
    required this.direction,
    required this.windowMinutes,
    required this.detectedAt,
  });

  String get formattedMove => '${movePct.toStringAsFixed(2)}%';

  String get alertMessage =>
      '$symbol moved $formattedMove $direction in the last $windowMinutes min — '
      'you may be entering after the move. Is this your setup?';
}
