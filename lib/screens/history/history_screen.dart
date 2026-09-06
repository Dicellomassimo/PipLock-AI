import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../models/challenge.dart';
import '../../models/killswitch_event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/challenge_provider.dart';
import '../../providers/killswitch_provider.dart';
import '../../services/cache_service.dart';
import '../../services/discipline_service.dart';
import '../../services/supabase_service.dart';
import '../../services/share_service.dart';
import '../../widgets/ambient_blobs.dart';
import '../../widgets/candle_background.dart';
import '../../widgets/skeleton_loader.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _tab = 0; // 0=Grafico, 1=Lista, 2=Calendario, 3=Avanzate
  List<KillswitchEvent> _events = [];
  DisciplineReport? _disciplineReport;
  bool _isLoading = true;
  bool _hasError = false;
  DateTime _calendarMonth = DateTime.now();
  DateTime? _selectedDay;

  // Dati check-in reali (caricati da SharedPreferences)
  List<FlSpot> _readinessSpots = [];
  double _avgReadiness = 0;
  bool _readinessLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadCheckinData();
    // Ricarica la history quando il killswitch viene attivato/disattivato
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(killswitchProvider, (prev, next) {
        if (prev?.isActive != next.isActive) {
          _loadHistory(forceRefresh: true);
        }
      });
    });
  }

  /// Carica i punteggi check-in reali degli ultimi 7 giorni da SharedPreferences.
  Future<void> _loadCheckinData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('checkin_scores_history');
      if (!mounted) return;

      if (raw == null) {
        setState(() => _readinessLoaded = true);
        return;
      }

      final scores = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final now = DateTime.now();
      final spots = <FlSpot>[];
      double total = 0;
      int count = 0;

      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final key =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        if (scores.containsKey(key)) {
          final score = (scores[key] as num).toDouble();
          // X = posizione nel grafico (0 = 6 giorni fa, 6 = oggi)
          spots.add(FlSpot((6 - i).toDouble(), score));
          total += score;
          count++;
        }
      }

      if (mounted) {
        setState(() {
          _readinessSpots = spots;
          _avgReadiness = count > 0 ? total / count : 0;
          _readinessLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _readinessLoaded = true);
    }
  }

  Future<void> _loadHistory({bool forceRefresh = false}) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (forceRefresh) {
      // Bust cache so we always get fresh data on manual refresh
      await CacheService.delete('ks_$userId');
    }
    try {
      final events = await SupabaseService.getKillswitchHistory(userId);
      if (mounted) {
        setState(() {
          _events = events;
          _disciplineReport = DisciplineService.computeWeekly(events);
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Color _colorForReason(String reason) {
    switch (reason) {
      case 'daily_loss': return AppColors.danger;
      case 'max_trades': return AppColors.warning;
      case 'revenge_pattern': return AppColors.danger;
      case 'overleveraging': return AppColors.warning;
      case 'fomo_pattern': return AppColors.fomo;
      default: return AppColors.textSecondary;
    }
  }

  IconData _iconForReason(String reason) {
    switch (reason) {
      case 'daily_loss': return Icons.trending_down;
      case 'max_trades': return Icons.block;
      case 'revenge_pattern': return Icons.repeat;
      case 'overleveraging': return Icons.warning_amber_rounded;
      case 'fomo_pattern': return Icons.remove_red_eye_outlined;
      default: return Icons.lock;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: AppColors.textPrimary, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(ref.watch(appStringsProvider).historyTitle, style: GoogleFonts.manrope(
          color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.textPrimary, size: 22),
            tooltip: ref.read(appStringsProvider).t('Share stats', 'Condividi statistiche'),
            onPressed: _shareStats,
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CandleBackground(
                accentColor: Color(0xFF00C896),
                opacity: 0.05,
              ),
            ),
          ),
          const Positioned.fill(child: IgnorePointer(child: AmbientBlobs())),
          Column(
            children: [
              if (_disciplineReport != null && _events.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _WeeklyReportCard(report: _disciplineReport!),
                ),
              _buildToggle(),
              Expanded(
                child: _isLoading
                    ? ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: 5,
                        itemBuilder: (_, __) => const SkeletonEventCard(),
                      )
                    : _hasError
                        ? _buildErrorState()
                        : RefreshIndicator(
                            color: AppColors.accent,
                            backgroundColor: AppColors.cardBg,
                            onRefresh: () => _loadHistory(forceRefresh: true),
                            child: _tab == 0 ? _buildChartView()
                              : _tab == 1 ? _buildListView()
                              : _tab == 2 ? _buildCalendarView()
                              : _buildAdvancedView(),
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    final s = ref.watch(appStringsProvider);
    final labels = [s.historyTabChart, s.historyTabList, s.historyTabCalendar, s.t('Advanced', 'Avanzate')];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: List.generate(labels.length, (i) {
            final active = _tab == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(labels[i], style: GoogleFonts.manrope(
                    color: active ? Colors.black : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  )),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── ERROR STATE ────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    final s = ref.watch(appStringsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.textTertiary, size: 48),
            const SizedBox(height: 16),
            Text(
              s.t('Could not load history', 'Impossibile caricare la cronologia'),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.t('Check your connection and try again.', 'Controlla la connessione e riprova.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                setState(() { _isLoading = true; _hasError = false; });
                _loadHistory(forceRefresh: true);
              },
              icon: const Icon(Icons.refresh_rounded, color: AppColors.accent),
              label: Text(
                s.t('Retry', 'Riprova'),
                style: GoogleFonts.manrope(color: AppColors.accent, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SHARE ──────────────────────────────────────────────────────────────

  Future<void> _shareStats() async {
    final s = ref.read(appStringsProvider);
    final cleanDays = _consecutiveCleanDays();
    final text = ShareService.generateStatsText(
      ksEvents: _events.length,
      cleanDays: cleanDays,
      totalTrades: _events.length,
      title: s.historyShareTitle,
      ksLabel: s.historyShareKsEvents(_events.length),
      cleanDaysLabel: s.historyShareCleanDays(cleanDays),
      tradesLabel: s.historyShareTrades(_events.length),
      tagline: s.historyShareTagline,
    );
    await ShareService.shareText(text);
  }

  int _consecutiveCleanDays() {
    if (_events.isEmpty) return 0;
    final now = DateTime.now();
    int days = 0;
    DateTime cursor = DateTime(now.year, now.month, now.day);
    while (true) {
      final hasEvent = _events.any((e) => _isSameDay(e.triggeredAt, cursor));
      if (hasEvent) break;
      days++;
      cursor = cursor.subtract(const Duration(days: 1));
      if (days > 365) break;
    }
    return days;
  }

  // ── GRAFICO ──────────────────────────────────────────────────────

  Widget _buildEmptyPlaceholder() {
    final s = ref.read(appStringsProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.accent,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            s.t('No killswitch events', 'Nessun evento killswitch'),
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.t('You\'re respecting your rules. Keep it up.', 'Stai rispettando le tue regole. Continua così.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartView() {
    if (_events.isEmpty) return _buildEmptyPlaceholder();
    final now = DateTime.now();
    const _bottomPad = 88.0; // nav bar height
    final countsByDay = List<int>.filled(7, 0);
    final colorsByDay = List<Color>.filled(7, AppColors.accent);
    for (final e in _events) {
      final diff = now.difference(e.triggeredAt).inDays;
      if (diff < 7) {
        final idx = 6 - diff;
        countsByDay[idx] += 1;
        colorsByDay[idx] = _colorForReason(e.reason);
      }
    }
    final barGroups = List.generate(7, (i) =>
        _barGroup(i, countsByDay[i].toDouble(), colorsByDay[i]));

    final maxCount = countsByDay.reduce((a, b) => a > b ? a : b);
    final chartMaxY = (maxCount + 1).toDouble().clamp(3.0, double.infinity);

    final s = ref.watch(appStringsProvider);
    final dayLabels = [s.historyDayMon, s.historyDayTue, s.historyDayWed, s.historyDayThu, s.historyDayFri, s.historyDaySat, s.historyDaySun];
    final todayLabel = s.t('Today', 'Oggi');
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, _bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsSummary(),
          const SizedBox(height: 20),
          Text(s.historyKsHeader, style: GoogleFonts.manrope(
            color: AppColors.textSecondary, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: chartMaxY,
              barGroups: barGroups,
              gridData: FlGridData(show: true, drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                  getTitlesWidget: (v, _) => Text('${v.round()}',
                    style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 11)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                  getTitlesWidget: (v, _) {
                    final barDate = now.subtract(Duration(days: 6 - v.round()));
                    final isToday = v.round() == 6;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        isToday ? todayLabel : dayLabels[barDate.weekday - 1],
                        style: GoogleFonts.manrope(
                          color: isToday ? AppColors.accent : AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    );
                  })),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
            )),
          ),
          const SizedBox(height: 28),
          Text(s.historyReadinessHeader, style: GoogleFonts.manrope(
            color: AppColors.textSecondary, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          // Grafico readiness con dati reali da check-in
          if (!_readinessLoaded)
            const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent))),
            )
          else if (_readinessSpots.length < 2)
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  s.t(
                    'Complete daily check-ins to see your readiness trend',
                    'Completa i check-in giornalieri per vedere il tuo andamento',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: LineChart(LineChartData(
                minY: 0, maxY: 10,
                gridData: FlGridData(show: true, drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      if (v % 2 != 0) return const SizedBox.shrink();
                      return Text('${v.round()}',
                        style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 11));
                    })),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                    interval: 1, // evita label duplicate (es. "Today" due volte)
                    getTitlesWidget: (v, _) {
                      final idx = v.round();
                      // Salta valori non interi che il chart può passare
                      if ((v - idx).abs() > 0.01) return const SizedBox.shrink();
                      final barDate = now.subtract(Duration(days: 6 - idx));
                      final isToday = idx == 6;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          isToday ? todayLabel : dayLabels[barDate.weekday - 1],
                          style: GoogleFonts.manrope(
                            color: isToday ? AppColors.accent : AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      );
                    })),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [LineChartBarData(
                  spots: _readinessSpots,
                  isCurved: true,
                  color: AppColors.accent,
                  barWidth: 2.5,
                  dotData: FlDotData(getDotPainter: (spot, xIndex, barData, idx) => FlDotCirclePainter(
                    radius: 4, color: AppColors.accent,
                    strokeColor: AppColors.background, strokeWidth: 2)),
                  belowBarData: BarAreaData(show: true,
                    color: AppColors.accent.withValues(alpha: 0.08)),
                )],
              )),
            ),
        ],
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double y, Color color) {
    return BarChartGroupData(x: x, barRods: [BarChartRodData(
      toY: y == 0 ? 0.1 : y,
      color: y == 0 ? AppColors.accent.withValues(alpha: 0.3) : color,
      width: 20,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
    )]);
  }

  Widget _statsSummary() {
    final s = ref.watch(appStringsProvider);
    final tokenUsed = _events.where((e) => e.unlockedWithToken).length;
    final readinessLabel = _avgReadiness > 0
        ? _avgReadiness.toStringAsFixed(1)
        : '—';
    return Row(
      children: [
        Expanded(child: _statCard(s.historyStatTotal, '${_events.length}', AppColors.danger)),
        const SizedBox(width: 12),
        Expanded(child: _statCard(s.historyStatTokens, '$tokenUsed', AppColors.warning)),
        const SizedBox(width: 12),
        Expanded(child: _statCard(s.historyStatReadiness, readinessLabel, AppColors.accent)),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: GoogleFonts.manrope(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 11)),
      ]),
    );
  }

  // ── LISTA ────────────────────────────────────────────────────────

  Widget _buildListView() {
    if (_events.isEmpty) return _buildEmptyPlaceholder();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
      itemCount: _events.length,
      itemBuilder: (_, i) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 300 + i * 50),
        curve: Curves.easeOut,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 20),
            child: child,
          ),
        ),
        child: _buildEventCard(_events[i]),
      ),
    );
  }

  Widget _buildEventCard(KillswitchEvent event) {
    final color = _colorForReason(event.reason);
    final icon = _iconForReason(event.reason);
    final fmt = DateFormat('dd MMM, HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left colored border
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref.read(appStringsProvider).t(event.reasonLabelEn, event.reasonLabelIt),
                              style: GoogleFonts.manrope(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fmt.format(event.triggeredAt),
                              style: GoogleFonts.manrope(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${event.lockDurationMinutes ~/ 60}h',
                            style: GoogleFonts.manrope(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (event.unlockedWithToken)
                            Text(
                              'Token',
                              style: GoogleFonts.manrope(
                                color: AppColors.warning,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CALENDARIO ───────────────────────────────────────────────────

  Widget _buildCalendarView() {
    final challenges = ref.watch(challengeListProvider);

    // Raccogli tutti gli eventi del giorno selezionato
    final List<_DayItem> selectedItems = [];
    final s = ref.read(appStringsProvider);
    if (_selectedDay != null) {
      for (final e in _events) {
        if (_isSameDay(e.triggeredAt, _selectedDay!)) {
          final blockedHours = (e.lockDurationMinutes / 60.0).roundToDouble();
          final estTrades = (blockedHours / 2).ceil();
          final saving = '~€${(estTrades * 50).round()} ${s.t('saved', 'salvati')}';
          selectedItems.add(_DayItem(
            type: 'killswitch',
            title: s.t(e.reasonLabelEn, e.reasonLabelIt),
            subtitle: DateFormat('HH:mm').format(e.triggeredAt),
            color: _colorForReason(e.reason),
            icon: _iconForReason(e.reason),
            savingEstimate: saving,
          ));
        }
      }
      for (final c in challenges) {
        final milestones = (c.aiPlan?['milestones'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        for (final m in milestones) {
          final week = (m['week'] as num?)?.toInt() ?? 0;
          final milestoneDate = c.startedAt.add(Duration(days: (week - 1) * 7));
          if (_isSameDay(milestoneDate, _selectedDay!)) {
            selectedItems.add(_DayItem(
              type: 'milestone',
              title: s.historyMilestone(week, c.propFirmName ?? "Challenge"),
              subtitle: '+${m['profitTarget']}% — ${m['description'] ?? ""}',
              color: AppColors.accent,
              icon: Icons.flag_outlined,
            ));
          }
        }
      }
    }

    return Column(
      children: [
        _buildMonthHeader(),
        _buildWeekDayHeaders(),
        _buildMonthSummary(),
        _buildMonthGrid(challenges),
        if (_selectedDay != null) ...[
          const Divider(color: AppColors.divider, height: 1),
          Expanded(
            child: selectedItems.isEmpty
                ? Center(
                    child: Text(
                      ref.watch(appStringsProvider).historyNoEventsForDay(_selectedDay!.day, _selectedDay!.month, _selectedDay!.year),
                      style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: selectedItems.length,
                    itemBuilder: (_, i) => _buildDayItemCard(selectedItems[i]),
                  ),
          ),
        ] else
          Expanded(
            child: Center(
              child: Text(ref.watch(appStringsProvider).historySelectDay,
                style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 13)),
            ),
          ),
      ],
    );
  }

  Widget _buildMonthSummary() {
    final ksThisMonth = _events.where((e) =>
      e.triggeredAt.year == _calendarMonth.year &&
      e.triggeredAt.month == _calendarMonth.month).toList();

    if (ksThisMonth.isEmpty) return const SizedBox.shrink();

    int totalMinutes = 0;
    for (final e in ksThisMonth) totalMinutes += e.lockDurationMinutes;
    final blockedHours = (totalMinutes / 60.0).roundToDouble();
    final estTrades = (blockedHours / 2).ceil();
    final saving = estTrades * 50;

    final s = ref.read(appStringsProvider);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Text(
        s.t(
          '${ksThisMonth.length} killswitch this month · ~€$saving estimated saved',
          '${ksThisMonth.length} killswitch questo mese · ~€$saving stimati salvati',
        ),
        style: GoogleFonts.manrope(color: AppColors.success, fontSize: 12),
      ),
    );
  }

  Widget _buildMonthHeader() {
    final months = ref.watch(appStringsProvider).historyMonths;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: () => setState(() {
              _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
              _selectedDay = null;
            }),
          ),
          Expanded(
            child: Text(
              '${months[_calendarMonth.month - 1]} ${_calendarMonth.year}',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(color: AppColors.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
            onPressed: () => setState(() {
              _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
              _selectedDay = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDayHeaders() {
    final days = ref.watch(appStringsProvider).historyDaysShort;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: days.map((d) => Expanded(
          child: Center(
            child: Text(d, style: GoogleFonts.manrope(
              color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildMonthGrid(List<Challenge> challenges) {
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    // Lunedì = 1, Domenica = 7
    final int startOffset = firstDay.weekday - 1; // 0-6
    final daysInMonth = DateUtils.getDaysInMonth(_calendarMonth.year, _calendarMonth.month);
    final today = DateTime.now();

    // Calcola giorni con eventi killswitch
    final killswitchDays = <int>{};
    for (final e in _events) {
      if (e.triggeredAt.year == _calendarMonth.year &&
          e.triggeredAt.month == _calendarMonth.month) {
        killswitchDays.add(e.triggeredAt.day);
      }
    }

    // Calcola giorni con milestone
    final milestoneDays = <int>{};
    for (final c in challenges) {
      final milestones = (c.aiPlan?['milestones'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      for (final m in milestones) {
        final week = (m['week'] as num?)?.toInt() ?? 0;
        final mDate = c.startedAt.add(Duration(days: (week - 1) * 7));
        if (mDate.year == _calendarMonth.year && mDate.month == _calendarMonth.month) {
          milestoneDays.add(mDate.day);
        }
      }
    }

    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final cellIdx = row * 7 + col;
              final day = cellIdx - startOffset + 1;
              if (day < 1 || day > daysInMonth) {
                return const Expanded(child: SizedBox(height: 44));
              }
              final date = DateTime(_calendarMonth.year, _calendarMonth.month, day);
              final isToday = _isSameDay(date, today);
              final isSelected = _selectedDay != null && _isSameDay(date, _selectedDay!);
              final hasKs = killswitchDays.contains(day);
              final hasMilestone = milestoneDays.contains(day);

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = date),
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent
                          : isToday
                              ? AppColors.accent.withValues(alpha: 0.15)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isSelected
                          ? Border.all(color: AppColors.accent.withValues(alpha: 0.4))
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$day', style: GoogleFonts.manrope(
                          color: isSelected ? Colors.black : AppColors.textPrimary,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        )),
                        if (hasKs || hasMilestone)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (hasKs) Container(
                                width: 5, height: 5, margin: const EdgeInsets.only(right: 2),
                                decoration: const BoxDecoration(
                                  color: AppColors.danger, shape: BoxShape.circle),
                              ),
                              if (hasMilestone) Container(
                                width: 5, height: 5,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.black : AppColors.accent,
                                  shape: BoxShape.circle),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildDayItemCard(_DayItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: GoogleFonts.manrope(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              if (item.subtitle.isNotEmpty)
                Text(item.subtitle, style: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 11)),
              if (item.savingEstimate != null)
                Text(item.savingEstimate!, style: GoogleFonts.manrope(
                  color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.type == 'killswitch' ? 'KS' : 'Target',
              style: GoogleFonts.manrope(color: item.color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── AVANZATE ─────────────────────────────────────────────────────────

  Widget _buildAdvancedView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCleanDaysBadge(),
          const SizedBox(height: 24),
          _buildWeeklyTrendLabel(),
          const SizedBox(height: 12),
          _buildWeeklyLineChart(),
          const SizedBox(height: 28),
          _buildHourHeatmapLabel(),
          const SizedBox(height: 12),
          _buildHourHeatmap(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // A) Clean days badge
  Widget _buildCleanDaysBadge() {
    final days = _consecutiveCleanDays();
    final isStreak = days >= 7;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStreak ? AppColors.accent.withValues(alpha: 0.3) : AppColors.border,
        ),
        gradient: isStreak
            ? LinearGradient(
                colors: [AppColors.accent.withValues(alpha: 0.06), AppColors.cardBg],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Column(
        children: [
          Text(
            '$days',
            style: GoogleFonts.manrope(
              color: isStreak ? AppColors.accent : AppColors.textPrimary,
              fontSize: 64,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isStreak) ...[
                const Icon(Icons.local_fire_department_rounded,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: 5),
              ],
              Text(
                ref.read(appStringsProvider).t('days without Killswitch', 'giorni senza Killswitch'),
                style: GoogleFonts.manrope(
                    color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // B) Weekly trend line chart label
  Widget _buildWeeklyTrendLabel() {
    return Text(
      ref.read(appStringsProvider).t('KILLSWITCH LAST 8 WEEKS', 'KILLSWITCH ULTIME 8 SETTIMANE'),
      style: GoogleFonts.manrope(
        color: AppColors.textSecondary,
        fontSize: 11,
        letterSpacing: 0.5,
      ),
    );
  }

  // B) Weekly trend line chart
  Widget _buildWeeklyLineChart() {
    final now = DateTime.now();
    final weekCounts = List<double>.filled(8, 0);
    for (final e in _events) {
      final weekIndex = now.difference(e.triggeredAt).inDays ~/ 7;
      if (weekIndex < 8) {
        weekCounts[7 - weekIndex] += 1;
      }
    }
    final spots = List.generate(8, (i) => FlSpot(i.toDouble(), weekCounts[i]));
    final maxY = weekCounts.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY < 1 ? 2 : maxY + 1,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppColors.divider, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text(
                    '${v.round()}',
                    style: GoogleFonts.manrope(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) => Text(
                    'W${(v.round() + 1)}',
                    style: GoogleFonts.manrope(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
              ),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.danger,
                barWidth: 2.5,
                dotData: FlDotData(
                  getDotPainter: (spot, xIndex, barData, idx) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.danger,
                    strokeColor: AppColors.background,
                    strokeWidth: 2,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.danger.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // C) Hour heatmap label
  Widget _buildHourHeatmapLabel() {
    return Text(
      ref.read(appStringsProvider).t('HIGHEST RISK HOURS (0–23)', 'ORE PIÙ A RISCHIO (0–23)'),
      style: GoogleFonts.manrope(
        color: AppColors.textSecondary,
        fontSize: 11,
        letterSpacing: 0.5,
      ),
    );
  }

  // C) Hour heatmap
  Widget _buildHourHeatmap() {
    final hourCounts = List<int>.filled(24, 0);
    for (final e in _events) {
      hourCounts[e.triggeredAt.hour] += 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(24, (hour) {
              final count = hourCounts[hour];
              final Color boxColor;
              if (count == 0) {
                boxColor = AppColors.cardBg2;
              } else if (count == 1) {
                boxColor = AppColors.warning.withValues(alpha: 0.55);
              } else {
                boxColor = AppColors.danger;
              }
              return Tooltip(
                message: ref.read(appStringsProvider).t('${hour}h: $count events', '${hour}h: $count eventi'),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: boxColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _heatmapLegendItem(AppColors.cardBg2, ref.read(appStringsProvider).t('None', 'Nessuno')),
              const SizedBox(width: 12),
              _heatmapLegendItem(
                  AppColors.warning.withValues(alpha: 0.55), ref.read(appStringsProvider).t('1 event', '1 evento')),
              const SizedBox(width: 12),
              _heatmapLegendItem(AppColors.danger, ref.read(appStringsProvider).t('2+ events', '2+ eventi')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heatmapLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ── Weekly Discipline Report Card ─────────────────────────────────────────

class _WeeklyReportCard extends ConsumerWidget {
  final DisciplineReport report;
  const _WeeklyReportCard({required this.report});

  void _showScoreInfo(BuildContext context, AppStrings s) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          s.t('Weekly Discipline Score', 'Punteggio di Disciplina Settimanale'),
          style: GoogleFonts.manrope(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          s.t(
            'Score from 0 to 100 based on this week\'s activity:\n\n'
            '• Each Killswitch activation: −8 pts\n'
            '• Each early unlock (token): −15 pts\n'
            '• No unlocks despite activations: +5 pts\n'
            '• Zero activations: 100 pts (Perfect week)\n\n'
            'Higher = fewer impulsive trades this week.',
            'Punteggio da 0 a 100 basato sull\'attività della settimana:\n\n'
            '• Ogni attivazione Killswitch: −8 pt\n'
            '• Ogni sblocco anticipato (token): −15 pt\n'
            '• Nessuno sblocco nonostante attivazioni: +5 pt\n'
            '• Zero attivazioni: 100 pt (Settimana perfetta)\n\n'
            'Più alto = meno trade impulsivi questa settimana.',
          ),
          style: GoogleFonts.manrope(
              color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.t('Got it', 'Ok'),
                style: GoogleFonts.manrope(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);

    // Perfect week — full gold banner
    if (report.isPerfectWeek) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppTheme.bLg,
          border: Border.all(color: const Color(0xFFFFC947), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔒', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(
              s.t('Perfect week — no activations', 'Settimana perfetta — nessuna attivazione'),
              style: GoogleFonts.manrope(
                color: const Color(0xFFFFC947),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    final scoreColor = report.score >= 80
        ? const Color(0xFF4CAF50)
        : report.score >= 55
            ? const Color(0xFFFFC947)
            : AppColors.danger;

    final hasDangerousPattern =
        report.mostDangerousPatternLabel != '—' &&
        report.mostDangerousPattern != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppTheme.bLg,
        border: Border.all(color: AppColors.glassBorderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: label + score badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                s.t('THIS WEEK', 'QUESTA SETTIMANA'),
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showScoreInfo(context, s),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.textTertiary),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: scoreColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${report.score}',
                      style: GoogleFonts.manrope(
                        color: scoreColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      report.scoreLabel,
                      style: GoogleFonts.manrope(
                        color: scoreColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stats chips row
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: Icons.shield_outlined,
                  iconColor: const Color(0xFF4CAF50),
                  label: s.t('Avoided: ${report.tradesAvoided}', 'Evitati: ${report.tradesAvoided}'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatChip(
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFF5A623),
                  label: s.t('Activations: ${report.activations}', 'Attivazioni: ${report.activations}'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatChip(
                  icon: Icons.key_rounded,
                  iconColor: AppColors.danger,
                  label: s.t('Overrides: ${report.overridesUsed}', 'Sblocchi: ${report.overridesUsed}'),
                ),
              ),
            ],
          ),

          // Most dangerous pattern (only if present)
          if (hasDangerousPattern) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.t('Most frequent: ${report.mostDangerousPatternLabel}',
                        'Più frequente: ${report.mostDangerousPatternLabel}'),
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),
          // Monthly overrides note
          Text(
            'This month: ${report.monthlyOverrides} override${report.monthlyOverrides == 1 ? '' : 's'} used',
            style: GoogleFonts.manrope(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DayItem {
  final String type;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final String? savingEstimate;
  const _DayItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.savingEstimate,
  });
}
