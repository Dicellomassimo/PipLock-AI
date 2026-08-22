// Modello unificato per i dati broker, indipendente dalla fonte di connessione.

enum BrokerConnectionMethod { ea, ctrader, oanda, manual, metaApi, accessibility, none }

enum BrokerConnectionStatus { disconnected, connecting, connected, error }

class BrokerData {
  final double? equity;
  final double? balance;

  /// P&L del giorno: positivo = profitto, negativo = perdita
  final double? dailyPnl;

  /// Perdita giornaliera in USD (sempre >= 0)
  final double? dailyLossUsd;

  /// Perdita giornaliera in percentuale (sempre >= 0)
  final double? dailyLossPct;

  final double? drawdownPct;
  final int? openPositions;
  final int? tradesToday;
  final String? currency;
  final DateTime? lastUpdate;

  const BrokerData({
    this.equity,
    this.balance,
    this.dailyPnl,
    this.dailyLossUsd,
    this.dailyLossPct,
    this.drawdownPct,
    this.openPositions,
    this.tradesToday,
    this.currency,
    this.lastUpdate,
  });

  BrokerData copyWith({
    Object? equity = _sentinel,
    Object? balance = _sentinel,
    Object? dailyPnl = _sentinel,
    Object? dailyLossUsd = _sentinel,
    Object? dailyLossPct = _sentinel,
    Object? drawdownPct = _sentinel,
    Object? openPositions = _sentinel,
    Object? tradesToday = _sentinel,
    Object? currency = _sentinel,
    Object? lastUpdate = _sentinel,
  }) {
    return BrokerData(
      equity: equity == _sentinel ? this.equity : equity as double?,
      balance: balance == _sentinel ? this.balance : balance as double?,
      dailyPnl: dailyPnl == _sentinel ? this.dailyPnl : dailyPnl as double?,
      dailyLossUsd: dailyLossUsd == _sentinel ? this.dailyLossUsd : dailyLossUsd as double?,
      dailyLossPct: dailyLossPct == _sentinel ? this.dailyLossPct : dailyLossPct as double?,
      drawdownPct: drawdownPct == _sentinel ? this.drawdownPct : drawdownPct as double?,
      openPositions: openPositions == _sentinel ? this.openPositions : openPositions as int?,
      tradesToday: tradesToday == _sentinel ? this.tradesToday : tradesToday as int?,
      currency: currency == _sentinel ? this.currency : currency as String?,
      lastUpdate: lastUpdate == _sentinel ? this.lastUpdate : lastUpdate as DateTime?,
    );
  }

  static const Object _sentinel = Object();
}
