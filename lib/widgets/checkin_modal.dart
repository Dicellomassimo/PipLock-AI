import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../config/app_strings.dart';
import '../services/checkin_service.dart';

/// Risultato del check-in giornaliero
class CheckinResult {
  final int score; // 1-10
  final Map<String, dynamic> answers;

  const CheckinResult({required this.score, required this.answers});
}

class CheckinModal extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;

  const CheckinModal({super.key, this.onComplete});

  /// Mostra il check-in solo se non è già stato completato oggi.
  static Future<CheckinResult?> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final lastDate = prefs.getString('checkin_last_date');
    if (lastDate == today) return null;

    if (!context.mounted) return null;
    final result = await showModalBottomSheet<CheckinResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const CheckinModal(),
    );
    if (result != null) {
      await prefs.setString('checkin_last_date', today);
      await prefs.setInt('checkin_last_score', result.score);
    }
    return result;
  }

  static Future<CheckinResult?> show(BuildContext context) async {
    return showModalBottomSheet<CheckinResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const CheckinModal(),
    );
  }

  static Future<int> lastScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('checkin_last_score') ?? 5;
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  ConsumerState<CheckinModal> createState() => _CheckinModalState();
}

// ─── Dati domande ──────────────────────────────────────────────────────────────

class _Question {
  final String title;
  final String subtitle;
  final String icon;
  final List<_Option> options;

  const _Question({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.options,
  });
}

class _Option {
  final String label;
  final String emoji;
  final int scoreContrib;

  const _Option(this.label, this.emoji, this.scoreContrib);
}

List<_Question> _buildQuestions(AppStrings s) => [
  _Question(
    title: s.t('How are you physically?', 'Come stai fisicamente?'),
    subtitle: s.t('Energy and physical state this morning', 'Energia e stato corporeo di questa mattina'),
    icon: '⚡',
    options: [
      _Option(s.t('Tired, drained', 'Stanco/a, scarico/a'), '😴', -2),
      _Option(s.t('Somewhat fatigued', 'Abbastanza affaticato/a'), '😐', -1),
      _Option(s.t('Normal', 'Nella norma'), '🙂', 0),
      _Option(s.t('Energetic', 'Energico/a'), '💪', 1),
      _Option(s.t('Peak, well-rested', 'Al massimo, riposato/a'), '🔥', 2),
    ],
  ),
  _Question(
    title: s.t('Emotional state', 'Stato emotivo'),
    subtitle: s.t('How are you feeling mentally right now?', 'Come ti senti mentalmente in questo momento?'),
    icon: '🧠',
    options: [
      _Option(s.t('Anxious or agitated', 'Ansioso/a o agitato/a'), '😰', -2),
      _Option(s.t('A bit tense', 'Un po\' teso/a'), '😬', -1),
      _Option(s.t('Neutral / calm', 'Neutro/calmo/a'), '😌', 0),
      _Option(s.t('Focused and clear-headed', 'Concentrato/a e lucido/a'), '🎯', 1),
      _Option(s.t('Motivated and confident', 'Motivato/a e sicuro/a'), '💡', 2),
    ],
  ),
  _Question(
    title: s.t('Last night', 'Notte scorsa'),
    subtitle: s.t('Sleep quality', 'Qualità del sonno'),
    icon: '🌙',
    options: [
      _Option(s.t('Less than 4 hours', 'Meno di 4 ore'), '💤', -2),
      _Option(s.t('4–5 hours, fragmented', '4–5 ore, frammentato'), '😵', -1),
      _Option(s.t('6–7 hours, acceptable', '6–7 ore, accettabile'), '🙂', 0),
      _Option(s.t('7–8 hours, good', '7–8 ore, buono'), '😴', 1),
      _Option(s.t('8+ hours, great', '8+ ore, ottimo'), '✨', 2),
    ],
  ),
  _Question(
    title: s.t('Operational setup', 'Setup operativo'),
    subtitle: s.t('Do you have a precise idea of what to do today?', 'Hai un\'idea precisa di cosa fare oggi?'),
    icon: '📋',
    options: [
      _Option(s.t('No plan, opening to see', 'Nessun piano, apro per vedere'), '🎲', -2),
      _Option(s.t('Vague idea, deciding in the moment', 'Idea vaga, decido al momento'), '🤷', -1),
      _Option(s.t('Observing without trading', 'Osservo senza operare'), '👁', 0),
      _Option(s.t('Defined setup on 1–2 assets', 'Setup definito su 1–2 asset'), '📌', 1),
      _Option(s.t('Precise plan with levels and SL/TP', 'Piano preciso con livelli e SL/TP'), '✅', 2),
    ],
  ),
  _Question(
    title: s.t('Last 24 hours of trading', 'Ultime 24 ore di trading'),
    subtitle: s.t('How did the previous session go?', 'Com\'è andata la sessione precedente?'),
    icon: '📊',
    options: [
      _Option(s.t('Significant losses, frustrated', 'Perdite significative, frustrato/a'), '📉', -2),
      _Option(s.t('Some losses, not convinced', 'Qualche perdita, non convinto/a'), '😕', -1),
      _Option(s.t('I did not trade yesterday', 'Non ho operato ieri'), '⏸', 0),
      _Option(s.t('Neutral results, regular', 'Risultati neutri, regolare'), '📊', 1),
      _Option(s.t('Positive session, calm', 'Sessione positiva, sereno/a'), '📈', 2),
    ],
  ),
  _Question(
    title: s.t('Today\'s expectations', 'Aspettative di oggi'),
    subtitle: s.t('How are you approaching the market this morning?', 'Come ti approcci al mercato stamattina?'),
    icon: '🔭',
    options: [
      _Option(s.t('I need to recover losses', 'Devo recuperare le perdite'), '🚨', -2),
      _Option(s.t('I want to do at least something', 'Voglio fare almeno qualcosa'), '😅', -1),
      _Option(s.t('Evaluating opportunities without rush', 'Valuto le opportunità senza fretta'), '⚖️', 1),
      _Option(s.t('One quality trade is enough', 'Un trade di qualità è sufficiente'), '💎', 2),
    ],
  ),
];

// ─── State ────────────────────────────────────────────────────────────────────

class _CheckinModalState extends ConsumerState<CheckinModal>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  late List<int?> _selected;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late List<_Question> _questions;
  Set<int> _skippedIndices = {};

  bool get _isResult => _step >= _questions.length;
  bool get _canAdvance => _isResult || _skippedIndices.contains(_step) || _selected[_step] != null;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _loadSkippedQuestions();
  }

  Future<void> _loadSkippedQuestions() async {
    // Check if sleep question (index 2) can be skipped — consistently high score
    final sleepHistory = await CheckinService.getQuestionHistory('sleep', days: 7);
    if (sleepHistory.length >= 5) {
      final avg = sleepHistory.reduce((a, b) => a + b) / sleepHistory.length;
      if (avg >= 4.0) {
        if (mounted) setState(() => _skippedIndices = {2});
      }
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_isResult) return;
    _animCtrl.reverse().then((_) {
      int nextStep = _step + 1;
      // Skip questions that are marked as skippable
      while (nextStep < _questions.length && _skippedIndices.contains(nextStep)) {
        nextStep++;
      }
      setState(() => _step = nextStep);
      _animCtrl.forward();
    });
  }

  int get _totalScore {
    int base = 5;
    for (int i = 0; i < _questions.length; i++) {
      final sel = _selected[i];
      if (sel != null) base += _questions[i].options[sel].scoreContrib;
    }
    return base.clamp(1, 10);
  }

  Color _scoreColor(int score) {
    if (score <= 3) return AppColors.danger;
    if (score <= 5) return AppColors.warning;
    if (score <= 7) return const Color(0xFF4CAF50);
    return AppColors.accent;
  }

  String _scoreLabel(int score, AppStrings s) {
    if (score <= 3) return s.checkinReadinessCritical;
    if (score <= 5) return s.checkinReadinessLow;
    if (score <= 7) return s.checkinReadinessGood;
    return s.checkinReadinessOptimal;
  }

  List<String> _recommendations(int score, AppStrings s) {
    if (score <= 3) {
      return [
        s.t('Avoid trading today — the risk of impulsive decisions is high.', 'Evita di operare oggi — il rischio di decisioni impulsive è elevato.'),
        s.t('Take a walk or a relaxing activity before looking at the market.', 'Fai una passeggiata o un\'attività rilassante prima di guardare il mercato.'),
        s.t('If you absolutely must trade, reduce your size to 25% of normal.', 'Se devi assolutamente operare, riduci la size al 25% del normale.'),
      ];
    }
    if (score <= 5) {
      return [
        s.t('Consider reducing today\'s trades by 1–2 vs your plan.', 'Considera di ridurre i trade di oggi di 1–2 rispetto al piano.'),
        s.t('Set the killswitch at a more conservative level for today.', 'Imposta il killswitch a un livello più conservativo per oggi.'),
        s.t('Wait for confirmation on at least 2 timeframes before entering.', 'Aspetta conferma su almeno 2 timeframe prima di entrare.'),
      ];
    }
    if (score <= 7) {
      return [
        s.t('Good session ahead — keep to the plan and respect your SL.', 'Buona sessione in prospettiva — mantieni il piano e rispetta gli SL.'),
        s.t('Watch the first trade: don\'t risk more than 2% per position.', 'Attenzione al primo trade: non rischiare più del 2% per posizione.'),
      ];
    }
    return [
      s.t('Ideal conditions: keep discipline even when things go well.', 'Condizioni ideali: mantieni la disciplina anche quando le cose vanno bene.'),
      s.t('Don\'t increase size from euphoria — stick to the plan.', 'Non aumentare la size per euforia — stai al piano.'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    _questions = _buildQuestions(s);
    // Ensure _selected is sized correctly
    if (!_initialized) {
      _selected = List.filled(_questions.length, null);
      _initialized = true;
    }

    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(top: 60),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                _buildHeader(s),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _fadeAnim,
                  child: _isResult
                      ? _buildResult(s)
                      : _skippedIndices.contains(_step)
                          ? _buildSkippedNotice(s)
                          : _buildQuestion(s),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _initialized = false;

  Widget _buildHeader(AppStrings s) {
    final total = _questions.length;
    final progress = _isResult ? 1.0 : (_step / total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _isResult ? '✅' : _questions[_step].icon,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isResult ? s.checkinComplete : s.checkinTitle,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!_isResult)
              Text(
                s.checkinStep(_step + 1, total),
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.divider,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion(AppStrings s) {
    final q = _questions[_step];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          q.title,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          q.subtitle,
          style: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(q.options.length, (i) {
          final opt = q.options[i];
          final selected = _selected[_step] == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selected[_step] = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accent.withValues(alpha: 0.12)
                      : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.divider,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(opt.emoji,
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        opt.label,
                        style: GoogleFonts.manrope(
                          color: selected
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle,
                          color: AppColors.accent, size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _canAdvance ? _nextStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              disabledBackgroundColor: AppColors.divider,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _step < _questions.length - 1
                  ? s.checkinNext
                  : s.checkinSeeResult,
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkippedNotice(AppStrings s) {
    final q = _questions[_step];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Text('✅', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.t('${q.title} — consistently optimal, question skipped.', '${q.title} — risposta ottimale costante, domanda saltata.'),
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(s.checkinNext,
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(AppStrings s) {
    final score = _totalScore;
    final color = _scoreColor(score);
    final label = _scoreLabel(score, s);
    final recs = _recommendations(score, s);
    final isLow = score <= 5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$score',
                    style: GoogleFonts.manrope(
                      color: color,
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '/10',
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                height: 70,
                child: CustomPaint(
                  painter: _GaugePainter(score: score, color: color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.checkinRecommendations,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...recs.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.arrow_right, color: color, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            r,
                            style: GoogleFonts.manrope(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (isLow) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _close(reduceLimits: true),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(
                s.checkinReduceLimits,
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _close(reduceLimits: false),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              s.checkinStartSession,
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  void _close({required bool reduceLimits}) {
    widget.onComplete?.call();
    final answers = <String, dynamic>{};
    final questionScores = <String, int>{};
    for (int i = 0; i < _questions.length; i++) {
      final sel = _selected[i];
      if (sel != null) {
        answers['q$i'] = sel;
        // Map question index to semantic key for CheckinService
        final key = _questionKey(i);
        questionScores[key] = _questions[i].options[sel].scoreContrib + 2; // normalize to 0-4
      }
    }
    final score = _totalScore;

    // Save to CheckinService
    CheckinService.saveCheckIn(score, questionScores);

    // Show low score advisory snackbar
    final s = ref.read(appStringsProvider);
    if (score < 5 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 5),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1A10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.t(
                      'Low readiness — we recommend reducing your trades today.',
                      'Prontezza bassa — ti consigliamo di ridurre i trade oggi.',
                    ),
                    style: GoogleFonts.manrope(
                      color: AppColors.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      CheckinService.setTodayTradeOverride(1);
    }

    // Check poor sleep streak
    CheckinService.hasPoorSleepStreak().then((hasStreak) {
      if (hasStreak && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
            duration: const Duration(seconds: 6),
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A0A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text('😴', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.t(
                        'Poor sleep for 3 days in a row — we recommend reducing your risk today.',
                        'Sonno scarso per 3 giorni di fila — ti consigliamo di ridurre il rischio oggi.',
                      ),
                      style: GoogleFonts.manrope(
                        color: AppColors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        CheckinService.setTodayTradeOverride(1);
      }
    });

    Navigator.pop(
      context,
      CheckinResult(
          score: score,
          answers: {...answers, 'reduceLimits': reduceLimits}),
    );
  }

  String _questionKey(int index) {
    const keys = ['physical', 'emotion', 'sleep', 'setup', 'previous', 'expectations'];
    if (index < keys.length) return keys[index];
    return 'q$index';
  }
}

// ─── Gauge painter ─────────────────────────────────────────────────────────────

class _GaugePainter extends CustomPainter {
  final int score;
  final Color color;

  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 10;
    const strokeWidth = 12.0;

    final trackPaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi,
      math.pi,
      false,
      trackPaint,
    );

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi,
      math.pi * (score / 10),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.score != score;
}
