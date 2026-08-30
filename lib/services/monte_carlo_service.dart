import 'dart:isolate';
import 'dart:math';

class MonteCarloInput {
  final double balance;
  final double profitTargetPct;
  final double maxDrawdownPct;
  final double dailyDrawdownPct;
  final String drawdownType;
  final double winRate;
  final double avgRR;
  final double riskPerTradePct;
  final int tradesPerDay;
  final int totalDays;
  final bool hasConsistencyRule;
  final double? consistencyRulePct;
  final int simulationCount;

  const MonteCarloInput({
    required this.balance,
    required this.profitTargetPct,
    required this.maxDrawdownPct,
    required this.dailyDrawdownPct,
    required this.drawdownType,
    required this.winRate,
    required this.avgRR,
    required this.riskPerTradePct,
    required this.tradesPerDay,
    required this.totalDays,
    required this.hasConsistencyRule,
    this.consistencyRulePct,
    this.simulationCount = 10000,
  });

  MonteCarloInput copyWith({double? riskPerTradePct, int? simulationCount}) {
    return MonteCarloInput(
      balance: balance,
      profitTargetPct: profitTargetPct,
      maxDrawdownPct: maxDrawdownPct,
      dailyDrawdownPct: dailyDrawdownPct,
      drawdownType: drawdownType,
      winRate: winRate,
      avgRR: avgRR,
      riskPerTradePct: riskPerTradePct ?? this.riskPerTradePct,
      tradesPerDay: tradesPerDay,
      totalDays: totalDays,
      hasConsistencyRule: hasConsistencyRule,
      consistencyRulePct: consistencyRulePct,
      simulationCount: simulationCount ?? this.simulationCount,
    );
  }
}

class MonteCarloResult {
  final double passProbability;
  final double drawdownHitProbability;
  final double timeoutProbability;
  final int? medianDaysToPass;
  final int? p25DaysToPass;
  final int? p75DaysToPass;
  final double recommendedRiskMin;
  final double recommendedRiskMax;
  final int simulationCount;

  const MonteCarloResult({
    required this.passProbability,
    required this.drawdownHitProbability,
    required this.timeoutProbability,
    this.medianDaysToPass,
    this.p25DaysToPass,
    this.p75DaysToPass,
    required this.recommendedRiskMin,
    required this.recommendedRiskMax,
    required this.simulationCount,
  });

  String get probabilityRangeString {
    final pct = (passProbability * 100).round();
    final low = (pct - 4).clamp(0, 100);
    final high = (pct + 4).clamp(0, 100);
    return '$low–$high%';
  }

  String get summaryPhrase {
    final pct = (passProbability * 100).round();
    final low = (pct - 4).clamp(0, 100);
    final high = (pct + 4).clamp(0, 100);
    return 'Based on the inputs and model assumptions, the simulated probability of reaching the target without hitting the drawdown is estimated at $low–$high%.';
  }
}

void _validateInput(MonteCarloInput input) {
  if (input.winRate < 0.01 || input.winRate > 0.99) {
    throw ArgumentError('winRate must be between 0.01 and 0.99, got ${input.winRate}');
  }
  if (input.avgRR < 0.1 || input.avgRR > 20.0) {
    throw ArgumentError('avgRR must be between 0.1 and 20.0, got ${input.avgRR}');
  }
  if (input.riskPerTradePct < 0.01 || input.riskPerTradePct > 10.0) {
    throw ArgumentError('riskPerTradePct must be between 0.01 and 10.0, got ${input.riskPerTradePct}');
  }
  if (input.tradesPerDay < 1 || input.tradesPerDay > 20) {
    throw ArgumentError('tradesPerDay must be between 1 and 20, got ${input.tradesPerDay}');
  }
  if (input.totalDays < 1 || input.totalDays > 365) {
    throw ArgumentError('totalDays must be between 1 and 365, got ${input.totalDays}');
  }
  if (input.profitTargetPct < 0.1 || input.profitTargetPct > 50.0) {
    throw ArgumentError('profitTargetPct must be between 0.1 and 50.0, got ${input.profitTargetPct}');
  }
  if (input.maxDrawdownPct < 0.1 || input.maxDrawdownPct > 50.0) {
    throw ArgumentError('maxDrawdownPct must be between 0.1 and 50.0, got ${input.maxDrawdownPct}');
  }
}

/// Returns (passCount, passConsistencyCount, drawdownCount, timeoutCount, daysToPassList)
_SimStats _runSimulationsCore(MonteCarloInput input, Random rng) {
  final int simCount = input.simulationCount;
  final double balance = input.balance;
  final double targetEquity = balance * (1.0 + input.profitTargetPct / 100.0);
  final double winAmount = balance * input.riskPerTradePct / 100.0 * input.avgRR;
  final double lossAmount = balance * input.riskPerTradePct / 100.0;
  final bool hasDailyLimit = input.dailyDrawdownPct > 0;
  final bool isTrailing = input.drawdownType == 'trailing_eod';

  int passCount = 0;
  int passConsistencyCount = 0;
  int drawdownCount = 0;
  int timeoutCount = 0;
  final List<int> daysToPassList = [];

  for (int sim = 0; sim < simCount; sim++) {
    double equity = balance;
    double peakEquity = balance;
    double floorEquity = balance * (1.0 - input.maxDrawdownPct / 100.0);
    int? daysToPass;
    String result = 'timeout';
    double bestDayPnl = 0.0;
    bool consistencyViolated = false;
    bool outerBreak = false;

    for (int day = 1; day <= input.totalDays; day++) {
      final double dayStartEquity = equity;
      double dayPnl = 0.0;
      final double dailyFloor = hasDailyLimit
          ? dayStartEquity * (1.0 - input.dailyDrawdownPct / 100.0)
          : double.negativeInfinity;
      bool dailyLimitHit = false;

      for (int t = 0; t < input.tradesPerDay; t++) {
        final double rand = rng.nextDouble();
        final double tradeResult = rand < input.winRate ? winAmount : -lossAmount;
        equity += tradeResult;
        dayPnl += tradeResult;

        // Check daily drawdown
        if (hasDailyLimit && equity < dailyFloor) {
          equity = dailyFloor;
          dayPnl = equity - dayStartEquity;
          dailyLimitHit = true;
          break;
        }

        // Check max drawdown intraday (static only)
        if (!isTrailing && equity < floorEquity) {
          result = 'drawdown';
          outerBreak = true;
          break;
        }

        // Check target reached intraday
        if (equity >= targetEquity) {
          result = 'pass';
          daysToPass = day;
          outerBreak = true;
          break;
        }
      }

      if (outerBreak) break;
      if (dailyLimitHit && !isTrailing && equity < floorEquity) {
        result = 'drawdown';
        break;
      }

      // EOD updates
      if (isTrailing) {
        peakEquity = max(peakEquity, equity);
        floorEquity = peakEquity * (1.0 - input.maxDrawdownPct / 100.0);
      }

      if (equity < floorEquity) {
        result = 'drawdown';
        break;
      }

      // Consistency check EOD
      if (input.hasConsistencyRule && input.consistencyRulePct != null) {
        if (dayPnl > 0 && dayPnl > bestDayPnl) {
          bestDayPnl = dayPnl;
        }
        final double totalPnl = equity - balance;
        if (totalPnl > 0 &&
            bestDayPnl > 0 &&
            (bestDayPnl / totalPnl * 100.0) > input.consistencyRulePct!) {
          consistencyViolated = true;
        }
      }
    }

    // Accumulate results
    switch (result) {
      case 'pass':
        if (consistencyViolated) {
          passConsistencyCount++;
        } else {
          passCount++;
          if (daysToPass != null) daysToPassList.add(daysToPass);
        }
        break;
      case 'drawdown':
        drawdownCount++;
        break;
      default:
        timeoutCount++;
        break;
    }
  }

  return _SimStats(
    passCount: passCount,
    passConsistencyCount: passConsistencyCount,
    drawdownCount: drawdownCount,
    timeoutCount: timeoutCount,
    daysToPassList: daysToPassList,
  );
}

class _SimStats {
  final int passCount;
  final int passConsistencyCount;
  final int drawdownCount;
  final int timeoutCount;
  final List<int> daysToPassList;

  const _SimStats({
    required this.passCount,
    required this.passConsistencyCount,
    required this.drawdownCount,
    required this.timeoutCount,
    required this.daysToPassList,
  });
}

/// Top-level function required for Isolate.run
MonteCarloResult _runSimulations(MonteCarloInput input) {
  _validateInput(input);

  final rng = Random();
  final int simCount = input.simulationCount;

  final stats = _runSimulationsCore(input, rng);

  final double passProbability =
      (stats.passCount + stats.passConsistencyCount * 0.7) / simCount;
  final double drawdownHitProbability = stats.drawdownCount / simCount;
  final double timeoutProbability = stats.timeoutCount / simCount;

  // Compute percentile days to pass
  int? medianDaysToPass;
  int? p25DaysToPass;
  int? p75DaysToPass;

  final List<int> sortedDays = List<int>.from(stats.daysToPassList)..sort();
  if (sortedDays.isNotEmpty) {
    medianDaysToPass = sortedDays[(sortedDays.length * 0.5).floor().clamp(0, sortedDays.length - 1)];
    p25DaysToPass = sortedDays[(sortedDays.length * 0.25).floor().clamp(0, sortedDays.length - 1)];
    p75DaysToPass = sortedDays[(sortedDays.length * 0.75).floor().clamp(0, sortedDays.length - 1)];
  }

  // Find optimal risk range with mini-simulations (1000 iterations each)
  const List<double> riskLevels = [0.25, 0.5, 1.0, 1.5, 2.0];
  final List<double> riskProbabilities = [];

  for (final risk in riskLevels) {
    final miniInput = input.copyWith(riskPerTradePct: risk, simulationCount: 1000);
    final miniStats = _runSimulationsCore(miniInput, rng);
    final prob = (miniStats.passCount + miniStats.passConsistencyCount * 0.7) / 1000.0;
    riskProbabilities.add(prob);
  }

  final double maxRiskProb = riskProbabilities.reduce(max);
  final double threshold = maxRiskProb * 0.9;

  final List<double> optimalRisks = [];
  for (int i = 0; i < riskLevels.length; i++) {
    if (riskProbabilities[i] >= threshold) {
      optimalRisks.add(riskLevels[i]);
    }
  }

  final double recommendedRiskMin = optimalRisks.isNotEmpty ? optimalRisks.first : input.riskPerTradePct;
  final double recommendedRiskMax = optimalRisks.isNotEmpty ? optimalRisks.last : input.riskPerTradePct;

  return MonteCarloResult(
    passProbability: passProbability,
    drawdownHitProbability: drawdownHitProbability,
    timeoutProbability: timeoutProbability,
    medianDaysToPass: medianDaysToPass,
    p25DaysToPass: p25DaysToPass,
    p75DaysToPass: p75DaysToPass,
    recommendedRiskMin: recommendedRiskMin,
    recommendedRiskMax: recommendedRiskMax,
    simulationCount: simCount,
  );
}

class MonteCarloService {
  /// Runs Monte Carlo simulation in a separate Isolate to avoid blocking the UI.
  static Future<MonteCarloResult> simulate(MonteCarloInput input) async {
    return await Isolate.run(() => _runSimulations(input));
  }
}
