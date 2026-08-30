import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../models/personal_rules.dart';
import '../../providers/rules_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/accessibility_service.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/glow_progress_bar.dart';

class PersonalRulesScreen extends ConsumerStatefulWidget {
  const PersonalRulesScreen({super.key});

  @override
  ConsumerState<PersonalRulesScreen> createState() =>
      _PersonalRulesScreenState();
}

class _PersonalRulesScreenState extends ConsumerState<PersonalRulesScreen> {
  final PageController _controller = PageController();
  int _step = 0;
  final int _totalSteps = 6;

  // Step 1
  double _maxDailyLoss = 100;
  String _lossType = 'amount'; // 'amount' | 'percent'
  String _currency = 'EUR';

  // Step 2
  int _maxTradesPerDay = 3;

  // Step 3
  bool _weeklyLossEnabled = false;
  double _maxWeeklyLoss = 300;

  // Step 4
  bool _tradingHoursEnabled = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);

  // Step 5
  String _killswitchDuration = '6h';

  // Step 6
  final TextEditingController _brokerController = TextEditingController();

  // Lock state
  bool _isLocked = false;
  bool _isUnlocking = false;
  static const _lockKey = 'rules_locked_until_ms';
  int _lockedUntilMs = 0;
  Duration _lockRemaining = Duration.zero;
  Timer? _lockCountdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkLockState();
      _preloadRules();
    });
  }

  Future<void> _checkLockState() async {
    final prefs = await SharedPreferences.getInstance();

    // If user just used a killswitch token, bypass the lock for this session
    final tokenUsed = prefs.getBool('killswitch_token_used') ?? false;
    if (tokenUsed) return; // skip lock — flag cleared in _confirm()

    final lockedUntil = prefs.getInt(_lockKey) ?? 0;
    if (lockedUntil > DateTime.now().millisecondsSinceEpoch) {
      if (mounted) {
        setState(() {
          _isLocked = true;
          _lockedUntilMs = lockedUntil;
          _lockRemaining = Duration(milliseconds: lockedUntil - DateTime.now().millisecondsSinceEpoch);
        });
        _lockCountdownTimer?.cancel();
        _lockCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          final rem = _lockedUntilMs - DateTime.now().millisecondsSinceEpoch;
          if (rem <= 0) {
            _lockCountdownTimer?.cancel();
            setState(() { _isLocked = false; _lockRemaining = Duration.zero; });
          } else {
            setState(() => _lockRemaining = Duration(milliseconds: rem));
          }
        });
      }
    } else {
      // Lock expired → clear
      await prefs.remove(_lockKey);
    }
  }

  Future<void> _unlockWithToken() async {
    final userId = ref.read(currentUserIdProvider);
    final s = ref.read(appStringsProvider);
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.t('Login required to use tokens.', 'Accesso richiesto per usare i token.'), style: GoogleFonts.manrope()),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }
    setState(() => _isUnlocking = true);
    try {
      // Consuma direttamente da Supabase (fonte di verità) — non usare authProvider
      // che può essere stale rispetto al tokenRealtimeProvider mostrato sulla dashboard
      final success = await SupabaseService.consumeToken(userId);
      // Aggiorna anche lo stato locale per coerenza visiva
      if (success) ref.read(authProvider.notifier).consumeToken();
      if (!mounted) return;
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_lockKey);
        setState(() {
          _isLocked = false;
          _isUnlocking = false;
        });
      } else {
        setState(() => _isUnlocking = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            s.t('No tokens available. You get 2 free tokens every Sunday.', 'Token esauriti. Ricevi 2 token gratuiti ogni domenica.'),
            style: GoogleFonts.manrope(),
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUnlocking = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          s.t('Unable to use token. Please try again.', 'Impossibile usare il token. Riprova.'),
          style: GoogleFonts.manrope(),
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _writeLock() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    await prefs.setInt(_lockKey, midnight.millisecondsSinceEpoch);
  }

  Future<void> _preloadRules() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId.isEmpty) return;
    try {
      final rules = await SupabaseService.getPersonalRules(userId);
      if (rules == null || !mounted) return;
      setState(() {
        if (rules.maxDailyLoss != null) _maxDailyLoss = rules.maxDailyLoss!;
        if (rules.maxDailyLossType != null) _lossType = rules.maxDailyLossType!;
        if (rules.maxTradesPerDay != null) _maxTradesPerDay = rules.maxTradesPerDay!;
        if (rules.maxWeeklyLoss != null) {
          _weeklyLossEnabled = true;
          _maxWeeklyLoss = rules.maxWeeklyLoss!;
        }
        _tradingHoursEnabled = rules.tradingHoursEnabled;
        if (rules.tradingHoursStart != null) {
          final parts = rules.tradingHoursStart!.split(':');
          if (parts.length >= 2) {
            _startTime = TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 8,
              minute: int.tryParse(parts[1]) ?? 0,
            );
          }
        }
        if (rules.tradingHoursEnd != null) {
          final parts = rules.tradingHoursEnd!.split(':');
          if (parts.length >= 2) {
            _endTime = TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 18,
              minute: int.tryParse(parts[1]) ?? 0,
            );
          }
        }
        _killswitchDuration = rules.killswitchDuration;
        _currency = rules.currency;
        if (rules.accountNumber != null) _brokerController.text = rules.accountNumber!;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _lockCountdownTimer?.cancel();
    _controller.dispose();
    _brokerController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < _totalSteps - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _back() {
    if (_step > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _confirm() async {
    final userId = ref.read(currentUserIdProvider);
    final accountNum = _brokerController.text.trim();
    if (accountNum.isEmpty) {
      // L'account number è obbligatorio — mostra errore e torna allo step 6
      _controller.animateToPage(
        5, // index dello step 6 (0-based)
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(appStringsProvider).t('MT5 account number is required.', 'Il numero account MT5 è obbligatorio.'),
            style: GoogleFonts.manrope(),
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    final rules = PersonalRules(
      userId: userId.isNotEmpty ? userId : 'anonymous',
      maxDailyLoss: _maxDailyLoss,
      maxDailyLossType: _lossType,
      maxTradesPerDay: _maxTradesPerDay,
      maxWeeklyLoss: _weeklyLossEnabled ? _maxWeeklyLoss : null,
      tradingHoursEnabled: _tradingHoursEnabled,
      tradingHoursStart: _tradingHoursEnabled
          ? '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}'
          : null,
      tradingHoursEnd: _tradingHoursEnabled
          ? '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}'
          : null,
      killswitchDuration: _killswitchDuration,
      accountNumber: accountNum.isNotEmpty ? accountNum : null,
      currency: _currency,
    );
    ref.read(rulesProvider.notifier).setRules(rules);
    // Clear the killswitch token bypass flag now that rules have been saved
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('killswitch_token_used');
    await _writeLock(); // lock rules until midnight

    final durationMin = switch (_killswitchDuration) {
      '2h' => 120,
      '6h' => 360,
      '24h' => 1440,
      _ => () {
          final now = DateTime.now();
          return DateTime(now.year, now.month, now.day + 1)
              .difference(now)
              .inMinutes;
        }(),
    };
    AccessibilityService.syncRulesToNative(
      maxDailyLossAmount: _lossType == 'amount' ? _maxDailyLoss : null,
      maxDailyLossPct: _lossType == 'percent' ? _maxDailyLoss : null,
      maxTradesPerDay: _maxTradesPerDay,
      killswitchDurationMinutes: durationMin,
      accountNumber: accountNum.isNotEmpty ? accountNum : null,
    );

    if (userId.isNotEmpty) {
      try {
        await SupabaseService.savePersonalRules(rules);
      } catch (_) {}
    }
    if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    if (_isLocked) return _buildLockedScreen(s);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Inline header with progress
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.pagePadding, 20, AppTheme.pagePadding, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
                        onPressed: _back,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        s.personalRulesStep(_step + 1, _totalSteps),
                        style: GoogleFonts.manrope(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GlowProgressBar(
                    value: (_step + 1) / _totalSteps,
                    fillColor: AppColors.accent,
                    trackColor: AppColors.divider,
                    height: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _buildStep1(s),
                  _buildStep2(s),
                  _buildStep3(s),
                  _buildStep4(s),
                  _buildStep5(s),
                  _buildStep6(s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _currencySymbol(String code) {
    const map = {'EUR': '€', 'USD': '\$', 'GBP': '£', 'CHF': 'Fr', 'JPY': '¥', 'AUD': 'A\$', 'CAD': 'C\$'};
    return map[code] ?? code;
  }

  Widget _buildLockedScreen(AppStrings s) {
    final rules = ref.watch(rulesProvider).rules;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Inline header
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.pagePadding, 20, AppTheme.pagePadding, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                   child: Text(
                    s.t('Your rules for today', 'Le tue regole di oggi'),
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
                   ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppTheme.pagePadding, 0, AppTheme.pagePadding, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner blocco
                    AnimatedCard(
                      padding: const EdgeInsets.all(16),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.lock, color: AppColors.danger, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _lockRemaining > Duration.zero
                                      ? s.t(
                                          'Rules locked — ${_lockRemaining.inHours.toString().padLeft(2, '0')}:${(_lockRemaining.inMinutes % 60).toString().padLeft(2, '0')}:${(_lockRemaining.inSeconds % 60).toString().padLeft(2, '0')} remaining',
                                          'Regole bloccate — ${_lockRemaining.inHours.toString().padLeft(2, '0')}:${(_lockRemaining.inMinutes % 60).toString().padLeft(2, '0')}:${(_lockRemaining.inSeconds % 60).toString().padLeft(2, '0')} rimanenti',
                                        )
                                      : s.t('Rules locked', 'Regole bloccate'),
                                  style: GoogleFonts.manrope(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s.t('You already set your rules today. Changing them now requires 1 token.', 'Hai già impostato le regole per oggi. Modificarle ora richiede 1 token.'),
                                  style: GoogleFonts.manrope(
                                    color: AppColors.danger.withValues(alpha: 0.8),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Sommario regole attuali
                    if (rules != null) ...[
                      Text(
                        s.t('ACTIVE RULES', 'REGOLE ATTIVE'),
                        style: GoogleFonts.manrope(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _lockedRuleCard(
                        icon: Icons.trending_down,
                        label: s.t('Max daily loss', 'Perdita max giornaliera'),
                        value: rules.maxDailyLossType == 'percent'
                            ? '${rules.maxDailyLoss?.round()}%'
                            : '${_currencySymbol(rules.currency)}${rules.maxDailyLoss?.round() ?? 0}',
                      ),
                      _lockedRuleCard(
                        icon: Icons.swap_horiz,
                        label: s.t('Max trades/day', 'Trade max al giorno'),
                        value: '${rules.maxTradesPerDay ?? 0}',
                      ),
                      if (rules.maxWeeklyLoss != null)
                        _lockedRuleCard(
                          icon: Icons.date_range,
                          label: s.t('Max weekly loss', 'Perdita max settimanale'),
                          value: '€${rules.maxWeeklyLoss!.round()}',
                        ),
                      if (rules.tradingHoursEnabled &&
                          rules.tradingHoursStart != null &&
                          rules.tradingHoursEnd != null)
                        _lockedRuleCard(
                          icon: Icons.schedule,
                          label: s.t('Trading hours', 'Orari di trading'),
                          value: '${rules.tradingHoursStart} – ${rules.tradingHoursEnd}',
                        ),
                      _lockedRuleCard(
                        icon: Icons.lock_clock,
                        label: s.t('Killswitch duration', 'Durata Killswitch'),
                        value: rules.killswitchDuration,
                      ),
                      if (rules.accountNumber != null)
                        _lockedRuleCard(
                          icon: Icons.account_balance,
                          label: 'MT5 Account',
                          value: rules.accountNumber!,
                        ),
                    ],
                    const SizedBox(height: 32),
                    // Bottone sblocco con token
                    PremiumButton(
                      label: _isUnlocking ? s.t('Unlocking...', 'Sblocco in corso...') : s.t('Use 1 token to edit', 'Usa 1 token per modificare'),
                      icon: Icons.token,
                      loading: _isUnlocking,
                      onTap: _isUnlocking ? null : _unlockWithToken,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        s.t('Tokens reset every week (2 free).', 'I token si rigenerano ogni settimana (2 gratis).'),
                        style: GoogleFonts.manrope(
                            color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lockedRuleCard(
      {required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
            Text(value,
                style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ---------- STEP 1: Max daily loss ----------
  Widget _buildStep1(AppStrings s) {
    return _stepWrapper(
      s: s,
      title: s.personalRulesMaxDailyLoss,
      subtitle: s.t(
        'When you reach this limit, PipLock blocks you until the chosen time.',
        "Quando raggiungi questo limite, PipLock ti blocca fino all'ora scelta.",
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _lossType = 'amount';
                      _maxDailyLoss = _maxDailyLoss.clamp(10.0, 1000.0);
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _lossType == 'amount'
                            ? AppColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        s.personalRulesAmount,
                        style: GoogleFonts.manrope(
                          color: _lossType == 'amount'
                              ? Colors.black
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _lossType = 'percent';
                      _maxDailyLoss = _maxDailyLoss.clamp(0.5, 20.0);
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _lossType == 'percent'
                            ? AppColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        s.personalRulesPercent,
                        style: GoogleFonts.manrope(
                          color: _lossType == 'percent'
                              ? Colors.black
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _lossType == 'amount'
                ? '${_currencySymbol(_currency)}${_maxDailyLoss.round()}'
                : '${_maxDailyLoss.round()}%',
            style: GoogleFonts.manrope(
              color: AppColors.accent,
              fontSize: 52,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _maxDailyLoss,
            min: _lossType == 'amount' ? 10 : 0.5,
            max: _lossType == 'amount' ? 1000 : 20,
            divisions: _lossType == 'amount' ? 99 : 39,
            activeColor: AppColors.accent,
            inactiveColor: AppColors.divider,
            onChanged: (v) => setState(() => _maxDailyLoss = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _lossType == 'amount' ? '€10' : '0.5%',
                style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 12),
              ),
              Text(
                _lossType == 'amount' ? '€1000' : '20%',
                style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            s.t('Currency', 'Valuta'),
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['EUR', 'USD', 'GBP', 'CHF', 'JPY', 'AUD', 'CAD'].map((c) {
              final selected = _currency == c;
              return GestureDetector(
                onTap: () => setState(() => _currency = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.divider,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    c,
                    style: GoogleFonts.manrope(
                      color: selected ? AppColors.accent : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      onNext: _next,
    );
  }

  // ---------- STEP 2: Max trades per day ----------
  Widget _buildStep2(AppStrings s) {
    return _stepWrapper(
      s: s,
      title: s.personalRulesMaxTrades,
      subtitle: s.t(
        'When you exceed this number, the Killswitch activates automatically.',
        'Superato questo numero, il Killswitch si attiva automaticamente.',
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepperButton(
                icon: Icons.remove,
                onTap: () {
                  if (_maxTradesPerDay > 1) setState(() => _maxTradesPerDay--);
                },
              ),
              const SizedBox(width: 32),
              Text(
                '$_maxTradesPerDay',
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 32),
              _stepperButton(
                icon: Icons.add,
                onTap: () {
                  if (_maxTradesPerDay < 20) setState(() => _maxTradesPerDay++);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.personalRulesTradesPerDay(_maxTradesPerDay),
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
      onNext: _next,
    );
  }

  Widget _stepperButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 28),
      ),
    );
  }

  // ---------- STEP 3: Weekly limit ----------
  Widget _buildStep3(AppStrings s) {
    return _stepWrapper(
      s: s,
      title: s.personalRulesWeeklyLimit,
      subtitle: s.t(
        'A cap on losses for the entire week.',
        'Un tetto alle perdite per tutta la settimana.',
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.personalRulesEnableWeekly,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
              Switch(
                value: _weeklyLossEnabled,
                onChanged: (v) => setState(() => _weeklyLossEnabled = v),
                thumbColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? Colors.black : null),
                trackColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? AppColors.accent : null),
              ),
            ],
          ),
          if (_weeklyLossEnabled) ...[
            const SizedBox(height: 24),
            Text(
              '€${_maxWeeklyLoss.round()}',
              style: GoogleFonts.manrope(
                color: AppColors.accent,
                fontSize: 52,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _maxWeeklyLoss,
              min: 50,
              max: 5000,
              divisions: 99,
              activeColor: AppColors.accent,
              inactiveColor: AppColors.divider,
              onChanged: (v) => setState(() => _maxWeeklyLoss = v),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                s.personalRulesNoWeeklyLimit,
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      onNext: _next,
    );
  }

  // ---------- STEP 4: Trading hours ----------
  Widget _buildStep4(AppStrings s) {
    return _stepWrapper(
      s: s,
      title: s.personalRulesTradingHours,
      subtitle: s.t(
        'Outside these hours, the Killswitch activates if you try to open positions.',
        'Fuori da questi orari, il Killswitch si attiva se tenti di aprire posizioni.',
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.personalRulesEnableHours,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
              Switch(
                value: _tradingHoursEnabled,
                onChanged: (v) => setState(() => _tradingHoursEnabled = v),
                thumbColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? Colors.black : null),
                trackColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? AppColors.accent : null),
              ),
            ],
          ),
          if (_tradingHoursEnabled) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _timePickerField(
                    label: s.personalRulesStart,
                    time: _startTime,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                        builder: (ctx, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.accent,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setState(() => _startTime = picked);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _timePickerField(
                    label: s.personalRulesEnd,
                    time: _endTime,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                        builder: (ctx, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.accent,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setState(() => _endTime = picked);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      onNext: _next,
    );
  }

  Widget _timePickerField({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    final formatted =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              formatted,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- STEP 5: Lock duration ----------
  Widget _buildStep5(AppStrings s) {
    final options = [
      ('2h', s.personalRules2h, Icons.timer_outlined),
      ('6h', s.personalRules6h, Icons.av_timer),
      ('midnight', s.personalRulesMidnight, Icons.nights_stay_outlined),
      ('24h', s.personalRules24h, Icons.lock_clock),
    ];
    return _stepWrapper(
      s: s,
      title: s.personalRulesLockDuration,
      subtitle: s.t(
        'How long will the Killswitch last when it activates?',
        'Quanto tempo durerà il Killswitch quando si attiva?',
      ),
      child: Column(
        children: options
            .map((opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _durationCard(value: opt.$1, label: opt.$2, icon: opt.$3),
                ))
            .toList(),
      ),
      onNext: _next,
    );
  }

  Widget _durationCard(
      {required String value, required String label, required IconData icon}) {
    final isSelected = _killswitchDuration == value;
    return GestureDetector(
      onTap: () => setState(() => _killswitchDuration = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: isSelected ? AppColors.accent : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }

  // ---------- STEP 6: Connect broker (optional) ----------
  Widget _buildStep6(AppStrings s) {
    return _stepWrapper(
      s: s,
      title: s.personalRulesConnectBroker,
      subtitle: s.t(
        'Connect MT5 to automatically detect trades and P&L.',
        'Collega MT5 per rilevare automaticamente trade e P&L.',
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined,
                    color: AppColors.accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.personalRulesReadOnly,
                    style: GoogleFonts.manrope(
                      color: AppColors.accent,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Numero Account MT5 ',
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _brokerController,
            style: GoogleFonts.manrope(color: AppColors.textPrimary),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: s.personalRulesAccountHint,
              hintStyle: GoogleFonts.manrope(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ref.read(appStringsProvider).t(
                    'Find it in MT5 → top menu → number below your name',
                    'Trovalo in MT5 → menu in alto → numero sotto il tuo nome',
                  ),
                  style: GoogleFonts.manrope(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.personalRulesSummary,
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                _summaryRow(
                  s.personalRulesMaxDailyLossLabel,
                  _lossType == 'amount'
                      ? '${_currencySymbol(_currency)}${_maxDailyLoss.round()}'
                      : '${_maxDailyLoss.round()}%',
                ),
                _summaryRow(s.personalRulesMaxTradesLabel, '$_maxTradesPerDay'),
                if (_weeklyLossEnabled)
                  _summaryRow(
                      s.personalRulesWeeklyLossLabel, '€${_maxWeeklyLoss.round()}'),
                if (_tradingHoursEnabled)
                  _summaryRow(
                    s.personalRulesHoursLabel,
                    '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')} - ${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                  ),
                _summaryRow(s.personalRulesLockLabel, _killswitchDuration),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PremiumButton(
            label: s.personalRulesConfirm,
            icon: Icons.check_circle_outline,
            onTap: _confirm,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: GoogleFonts.manrope(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ---------- Common step wrapper ----------
  Widget _stepWrapper({
    required AppStrings s,
    required String title,
    required String subtitle,
    required Widget child,
    VoidCallback? onNext,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppTheme.pagePadding, 8, AppTheme.pagePadding, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          AnimatedCard(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
          if (onNext != null) ...[
            const SizedBox(height: 16),
            if (_step > 0)
              PremiumButton(
                label: s.t('Back', 'Indietro'),
                variant: PremiumButtonVariant.ghost,
                onTap: _back,
              ),
            const SizedBox(height: 10),
            PremiumButton(
              label: s.personalRulesNext,
              onTap: onNext,
            ),
          ],
        ],
      ),
    );
  }
}
