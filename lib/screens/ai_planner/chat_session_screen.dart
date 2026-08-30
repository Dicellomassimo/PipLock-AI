import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../models/challenge.dart';
import '../../models/chat_session.dart';
import '../../providers/ai_plan_provider.dart';
import '../../providers/broker_provider.dart';
import '../../providers/challenge_provider.dart';
import '../../providers/chat_history_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/rules_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/donut_chart.dart';

class ChatSessionScreen extends ConsumerStatefulWidget {
  final ChatSession session;
  final Challenge? initialChallenge;

  const ChatSessionScreen({
    super.key,
    required this.session,
    this.initialChallenge,
  });

  @override
  ConsumerState<ChatSessionScreen> createState() => _ChatSessionScreenState();
}

class _ChatSessionScreenState extends ConsumerState<ChatSessionScreen> {
  late ChatSession _session;
  Map<String, dynamic>? _plan;
  bool _isLoadingPlan = false;
  bool _isChatLoading = false;
  Challenge? _challenge;
  bool _isPersonalMode = false;

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> get _messages => _session.messages;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _challenge = widget.initialChallenge;
    _plan = widget.session.plan;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_plan != null) {
        // Sessione già con piano: mostra messaggio di ripresa
        if (_messages.isEmpty) {
          final s = ref.read(appStringsProvider);
          _addBotMessage(
            _session.type == 'personal'
                ? s.chatPersonalPlanLoaded
                : s.chatPlanLoaded(_session.contextName ?? s.t('the challenge', 'la challenge')),
          );
        }
        return;
      }
      // Nuova sessione — genera il piano
      if (widget.session.type == 'challenge') {
        _isPersonalMode = false;
        if (_challenge != null) {
          _generateChallengePlan(_challenge!);
        } else {
          _loadAndGenerateChallenge();
        }
      } else {
        _isPersonalMode = true;
        _generatePersonalPlan();
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Salvataggio sessione ────────────────────────────────────────────────

  Future<void> _saveSession() async {
    final updated = _session.copyWith(
      plan: _plan,
      messages: _messages,
      updatedAt: DateTime.now(),
    );
    _session = updated;
    await ref.read(chatHistoryProvider.notifier).updateSession(updated);
  }

  // ── Generazione piani ────────────────────────────────────────────────────

  Future<void> _loadAndGenerateChallenge() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId.isNotEmpty) {
      try {
        final challenges = await SupabaseService.getActiveChallenges(userId);
        if (!mounted) return;
        if (challenges.isNotEmpty) {
          setState(() => _challenge = challenges.first);
          _generateChallengePlan(challenges.first);
          return;
        }
      } catch (_) {}
    }
    final allChallenges = ref.read(challengeListProvider);
    if (allChallenges.isNotEmpty) {
      setState(() => _challenge = allChallenges.first);
      _generateChallengePlan(allChallenges.first);
    } else {
      _addBotMessage(ref.read(appStringsProvider).chatNoChallengeFound);
    }
  }

  Future<void> _generateChallengePlan(Challenge challenge) async {
    // Se il piano è già stato generato nel challenge setup, usalo direttamente
    if (challenge.aiPlan != null) {
      setState(() {
        _plan = challenge.aiPlan;
        _isLoadingPlan = false;
      });
      final plan = challenge.aiPlan!;
      final capitalAtRisk = (challenge.accountSize * (plan['riskPerTrade'] as num? ?? 0.5) / 100).toStringAsFixed(0);
      final maxLosses = ((challenge.maxTotalDrawdown) / (plan['riskPerTrade'] as num? ?? 0.5)).round();
      final s = ref.read(appStringsProvider);
      _addBotMessage(
        s.t(
          'Challenge plan for ${challenge.propFirmName ?? "the challenge"} loaded!\n\n'
          '• Success probability: ${plan['successPercentage']}%\n'
          '• Lot size: ${plan['recommendedLotSize']}\n'
          '• Trades/day: ${plan['recommendedTradesPerDay']}\n'
          '• Risk/trade: ${plan['riskPerTrade']}% (\$$capitalAtRisk)\n'
          '• Max consecutive losses before drawdown: $maxLosses\n\n'
          '⚠️ These are your active rules. The killswitch will trigger if you exceed them.\n\n'
          'Ask me anything about the plan or about discipline.',
          'Piano challenge per ${challenge.propFirmName ?? "la challenge"} caricato!\n\n'
          '• Probabilità di successo: ${plan['successPercentage']}%\n'
          '• Lot size: ${plan['recommendedLotSize']}\n'
          '• Trade/giorno: ${plan['recommendedTradesPerDay']}\n'
          '• Rischio/trade: ${plan['riskPerTrade']}% (\$$capitalAtRisk)\n'
          '• Max perdite di fila prima del drawdown: $maxLosses\n\n'
          '⚠️ Queste sono le tue regole attive. Il Killswitch scatterà se le superi.\n\n'
          'Chiedimi qualsiasi cosa sul piano o sulla disciplina.',
        ),
      );
      await _saveSession();
      return;
    }

    setState(() { _isLoadingPlan = true; _isPersonalMode = false; });
    try {
      final plan = await AiService.generatePlan(challenge);
      if (!mounted) return;
      setState(() => _plan = plan);

      final userId = ref.read(currentUserIdProvider);
      if (userId.isNotEmpty) {
        try { await SupabaseService.updateAiPlan(challenge.id, plan); } catch (_) {}
      }

      final capitalAtRisk =
          (challenge.accountSize * (plan['riskPerTrade'] as num? ?? 0.5) / 100)
              .toStringAsFixed(0);
      final maxLosses =
          ((challenge.maxTotalDrawdown) / (plan['riskPerTrade'] as num? ?? 0.5))
              .round();
      final s = ref.read(appStringsProvider);
      _addBotMessage(
        s.t(
          'Plan generated for ${challenge.propFirmName ?? "the challenge"}!\n\n'
          '• Success probability: ${plan['successPercentage']}%\n'
          '• Lot size: ${plan['recommendedLotSize']}\n'
          '• Trades/day: ${plan['recommendedTradesPerDay']}\n'
          '• Risk/trade: ${plan['riskPerTrade']}% (\$$capitalAtRisk)\n'
          '• Max consecutive losses before drawdown: $maxLosses\n\n'
          'Ask me anything about the plan or about discipline.',
          'Piano generato per ${challenge.propFirmName ?? "la challenge"}!\n\n'
          '• Probabilità di successo: ${plan['successPercentage']}%\n'
          '• Lot size: ${plan['recommendedLotSize']}\n'
          '• Trade/giorno: ${plan['recommendedTradesPerDay']}\n'
          '• Rischio/trade: ${plan['riskPerTrade']}% (\$$capitalAtRisk)\n'
          '• Max perdite di fila prima del drawdown: $maxLosses\n\n'
          'Chiedimi qualsiasi cosa sul piano o sulla disciplina.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingPlan = false);
      await _saveSession();
    }
  }

  Future<void> _generatePersonalPlan() async {
    setState(() { _isLoadingPlan = true; _isPersonalMode = true; _challenge = null; });
    final rulesState = ref.read(rulesProvider);
    final brokerState = ref.read(brokerProvider);
    final brokerData = brokerState.isConnected
        ? {
            'equity': brokerState.equity,
            'balance': brokerState.balance,
            'dailyPnl': brokerState.dailyPnl,
            'openPositions': brokerState.data.openPositions,
          }
        : <String, dynamic>{};
    try {
      final plan = await AiService.generatePersonalPlan(
        rules: rulesState.rules?.toJson() ?? {},
        brokerData: brokerData,
      );
      if (!mounted) return;
      setState(() => _plan = plan);
      ref.read(personalPlanProvider.notifier).state = plan;
      final s = ref.read(appStringsProvider);
      _addBotMessage(
        s.t(
          'Personal account plan generated!\n\n'
          '• Max daily loss: ${plan['maxDailyLossUsd'] ?? '—'}\n'
          '• Max trades/day: ${plan['maxTradesPerDay'] ?? '—'}\n'
          '• Daily target: ${plan['dailyTarget'] ?? '—'}\n'
          '• Advice: ${plan['sessionAdvice'] ?? '—'}\n\n'
          'Ask me anything about today\'s session.',
          'Piano conto personale generato!\n\n'
          '• Max perdita giornaliera: ${plan['maxDailyLossUsd'] ?? '—'}\n'
          '• Max trade/giorno: ${plan['maxTradesPerDay'] ?? '—'}\n'
          '• Obiettivo giornaliero: ${plan['dailyTarget'] ?? '—'}\n'
          '• Consiglio: ${plan['sessionAdvice'] ?? '—'}\n\n'
          'Chiedimi qualsiasi cosa sulla tua sessione di oggi.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingPlan = false);
      await _saveSession();
    }
  }

  // ── Messaggi ──────────────────────────────────────────────────────────────

  void _addBotMessage(String text) {
    final msg = ChatMessage(text: text, isUser: false, timestamp: DateTime.now());
    setState(() {
      _session = _session.copyWith(
        messages: [..._messages, msg],
        updatedAt: DateTime.now(),
      );
    });
    _scrollToBottom();
    _saveSession();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final distanceFromBottom = pos.maxScrollExtent - pos.pixels;
      if (_messages.length <= 2 || distanceFromBottom < 300) {
        _scrollController.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isChatLoading) return;
    _inputController.clear();

    final userMsg = ChatMessage(text: text, isUser: true, timestamp: DateTime.now());
    setState(() {
      _session = _session.copyWith(
        messages: [..._messages, userMsg],
        updatedAt: DateTime.now(),
      );
      _isChatLoading = true;
    });
    _scrollToBottom();

    try {
      final allChallenges = ref.read(challengeListProvider);
      final brokerState = ref.read(brokerProvider);
      final brokerContext = brokerState.equity != null
          ? {
              'equity': brokerState.equity,
              'balance': brokerState.balance,
              'dailyPnl': brokerState.dailyPnl,
              'positions': brokerState.data.openPositions,
            }
          : null;
      final challengeIsLocked = _challenge != null &&
          _challenge!.status == 'active' &&
          _challenge!.aiPlan != null;
      final response = await AiService.chat(
        text,
        _plan,
        allChallenges: allChallenges,
        brokerData: brokerContext,
        isPersonalMode: _isPersonalMode,
        locale: ref.read(localeProvider).languageCode,
        challengeIsLocked: challengeIsLocked,
      );
      if (mounted) {
        final botMsg = ChatMessage(text: response, isUser: false, timestamp: DateTime.now());
        setState(() {
          _session = _session.copyWith(
            messages: [..._messages, botMsg],
            updatedAt: DateTime.now(),
          );
        });
        _scrollToBottom();
        await _saveSession();
      }
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _session.title,
              style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
            if (_session.contextName != null)
              Text(
                _session.contextName!,
                style: GoogleFonts.manrope(
                    color: AppColors.accent, fontSize: 11),
              ),
          ],
        ),
        actions: [
          if (!_isPersonalMode && _challenge != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.textSecondary, size: 20),
              tooltip: ref.watch(appStringsProvider).chatRegeneratePlan,
              onPressed: () => _generateChallengePlan(_challenge!),
            ),
          if (_isPersonalMode)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.textSecondary, size: 20),
              tooltip: ref.watch(appStringsProvider).chatRegeneratePlan,
              onPressed: _generatePersonalPlan,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Broker status (solo personal)
                if (_isPersonalMode)
                  SliverToBoxAdapter(child: _buildBrokerStatusCard()),
                // Piano card
                if (_plan != null || _isLoadingPlan)
                  SliverToBoxAdapter(child: _buildPlanCard()),
                // Disclaimer
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.warning, size: 13),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ref.watch(appStringsProvider).chatDisclaimer,
                            style: GoogleFonts.manrope(
                                color: AppColors.warning, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Messaggi o stato vuoto
                if (_messages.isEmpty && !_isChatLoading)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyChat(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          if (i == _messages.length) return _buildTypingIndicator();
                          return _buildChatBubble(_messages[i]);
                        },
                        childCount: _messages.length + (_isChatLoading ? 1 : 0),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildBrokerStatusCard() {
    final brokerState = ref.watch(brokerProvider);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: brokerState.isConnected
              ? AppColors.accent.withValues(alpha: 0.25)
              : AppColors.divider,
        ),
      ),
      child: brokerState.isConnected && brokerState.equity != null
          ? Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ref.watch(appStringsProvider).chatBrokerLive,
                          style: GoogleFonts.manrope(
                              color: AppColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      Text(
                        'Equity: ${brokerState.currency ?? ''} ${brokerState.equity!.toStringAsFixed(2)}'
                        '  P&L: ${brokerState.dailyPnl != null ? (brokerState.dailyPnl! >= 0 ? '+' : '') + brokerState.dailyPnl!.toStringAsFixed(2) : '—'}'
                        '  Pos: ${brokerState.openPositions ?? 0}',
                        style: GoogleFonts.manrope(
                            color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.link_off,
                    color: AppColors.textSecondary, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(ref.watch(appStringsProvider).chatBrokerConnect,
                      style: GoogleFonts.manrope(
                          color: AppColors.textSecondary, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/broker'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(ref.watch(appStringsProvider).chatConnect,
                      style: GoogleFonts.manrope(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
    );
  }

  Widget _buildPlanCard() {
    if (_isLoadingPlan) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
            const SizedBox(width: 12),
            Text(ref.watch(appStringsProvider).chatGeneratingPlan,
                style: GoogleFonts.manrope(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    final plan = _plan!;
    final pct = (plan['successPercentage'] as num?)?.toDouble() ?? 0;
    final lotSize = plan['recommendedLotSize'];
    final tradesPerDay = plan['recommendedTradesPerDay'];
    final riskPct = (plan['riskPerTrade'] as num?)?.toDouble() ?? 0.5;
    final softKs = plan['softKillswitchThreshold'];
    final hardKs = plan['hardKillswitchThreshold'];
    final milestones =
        (plan['milestones'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    final capitalAtRisk = _challenge != null
        ? '\$${(_challenge!.accountSize * riskPct / 100).toStringAsFixed(0)}'
        : null;
    final maxConsecLosses = _challenge != null
        ? (_challenge!.maxTotalDrawdown / riskPct).round()
        : null;
    final daysProgress = _challenge != null && _challenge!.durationDays > 0
        ? _challenge!.currentDay / _challenge!.durationDays
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                child: DonutChart(
                  key: ValueKey(pct),
                  value: pct,
                  size: 90,
                  strokeWidth: 11,
                  centerChild: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${pct.round()}%',
                        style: GoogleFonts.manrope(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        ref.watch(appStringsProvider).t('win', 'successo'),
                        style: GoogleFonts.manrope(
                          color: AppColors.textTertiary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _planStatRow(ref.watch(appStringsProvider).chatLotSize, '$lotSize'),
                    const SizedBox(height: 6),
                    _planStatRow(ref.watch(appStringsProvider).chatTradesPerDay, '$tradesPerDay'),
                    const SizedBox(height: 6),
                    _planStatRow(ref.watch(appStringsProvider).chatRiskPerTrade, '$riskPct%'),
                    if (capitalAtRisk != null) ...[
                      const SizedBox(height: 6),
                      _planStatRow(ref.watch(appStringsProvider).chatUsdPerTrade, capitalAtRisk,
                          color: AppColors.warning),
                    ],
                    // Dati personali extra
                    if (_isPersonalMode && plan['dailyTarget'] != null) ...[
                      const SizedBox(height: 6),
                      _planStatRow(ref.watch(appStringsProvider).chatDailyTarget, plan['dailyTarget'].toString(),
                          color: AppColors.accent),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _thresholdBadge(ref.watch(appStringsProvider).chatSoftKS, '$softKs%', AppColors.warning)),
              const SizedBox(width: 8),
              Expanded(child: _thresholdBadge(ref.watch(appStringsProvider).chatHardKS, '$hardKs%', AppColors.danger)),
              if (maxConsecLosses != null) ...[
                const SizedBox(width: 8),
                Expanded(child: _thresholdBadge(
                    ref.watch(appStringsProvider).chatMaxStreak, '$maxConsecLosses', AppColors.textSecondary)),
              ],
            ],
          ),
          if (daysProgress != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(ref.watch(appStringsProvider).chatChallengeProgress,
                    style: GoogleFonts.manrope(
                        color: AppColors.textSecondary, fontSize: 11)),
                Text(
                    ref.watch(appStringsProvider).chatDayProgress(_challenge!.currentDay, _challenge!.durationDays),
                    style: GoogleFonts.manrope(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: daysProgress.clamp(0.0, 1.0),
                backgroundColor: AppColors.divider,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
                minHeight: 6,
              ),
            ),
          ],
          if (milestones.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 12),
            Text(ref.watch(appStringsProvider).chatMilestone,
                style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1.2)),
            const SizedBox(height: 8),
            ...milestones.take(3).map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '${ref.watch(appStringsProvider).chatMilestoneWeek(m['week'] as int, m['profitTarget'].toString())} — ${m['description']}',
                          style: GoogleFonts.manrope(
                              color: AppColors.textSecondary,
                              fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          // Consigli sessione (piano personale)
          if (_isPersonalMode && plan['sessionAdvice'] != null) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: AppColors.accent, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan['sessionAdvice'].toString(),
                    style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _planStatRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.manrope(
                color: AppColors.textSecondary, fontSize: 11)),
        Text(value,
            style: GoogleFonts.manrope(
                color: color ?? AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ],
    );
  }

  Widget _thresholdBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.manrope(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.manrope(color: color, fontSize: 9),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.accent, size: 44),
          const SizedBox(height: 14),
          Text(ref.watch(appStringsProvider).chatHintPlanner,
              style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            ref.watch(appStringsProvider).chatHintPlan,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
                color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: msg.isUser
            ? BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              )
            : BoxDecoration(
                color: AppColors.cardBg2,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: AppColors.border),
              ),
        child: Text(
          msg.text,
          style: GoogleFonts.manrope(
            color: msg.isUser ? Colors.black : AppColors.textPrimary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: const _TypingIndicator(),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              style:
                  GoogleFonts.manrope(color: AppColors.textPrimary),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: ref.watch(appStringsProvider).chatHint,
                hintStyle: GoogleFonts.manrope(
                    color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.cardBg,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: AppColors.accent, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded,
                  color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing Indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _anims = _ctrls
        .map((c) => Tween<double>(begin: 0, end: -6)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();

    Future.delayed(Duration.zero, () => _ctrls[0].repeat(reverse: true));
    Future.delayed(const Duration(milliseconds: 150),
        () => _ctrls[1].repeat(reverse: true));
    Future.delayed(const Duration(milliseconds: 300),
        () => _ctrls[2].repeat(reverse: true));
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg2,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => AnimatedBuilder(
            animation: _anims[i],
            builder: (_, _) => Transform.translate(
              offset: Offset(0, _anims[i].value),
              child: Container(
                width: 6,
                height: 6,
                margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
