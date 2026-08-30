import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../config/prop_firm_presets.dart';
import '../../models/challenge.dart';
import '../../providers/auth_provider.dart';
import '../../providers/challenge_provider.dart';
import '../../providers/pending_challenge_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../services/ai_service.dart';
import '../../services/monte_carlo_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/glow_progress_bar.dart';
import '../../widgets/premium_button.dart';

class ChallengeSetupScreen extends ConsumerStatefulWidget {
  const ChallengeSetupScreen({super.key});

  @override
  ConsumerState<ChallengeSetupScreen> createState() =>
      _ChallengeSetupScreenState();
}

class _ChallengeSetupScreenState extends ConsumerState<ChallengeSetupScreen> {
  final PageController _controller = PageController();
  int _step = 0;
  static const int _totalSteps = 4;

  // ── Step 1 — Account & Prop Firm ──────────────────────────────────────────
  PropFirmConfig? _selectedFirm;
  PropFirmPreset? _selectedPreset;
  double _accountSize = 50000;
  int _durationDays = 30;
  bool _overrideRules = false;
  double _profitTarget = 10;
  double _maxDailyLoss = 5;
  double _maxDrawdown = 10;
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _customFirmController = TextEditingController();
  // Override controllers
  final TextEditingController _profitTargetController =
      TextEditingController(text: '10');
  final TextEditingController _maxDailyLossController =
      TextEditingController(text: '5');
  final TextEditingController _maxDrawdownController =
      TextEditingController(text: '10');
  final TextEditingController _durationController =
      TextEditingController(text: '30');

  // ── Step 2 — Strategy ─────────────────────────────────────────────────────
  double _winRate = 45; // percentage e.g. 45 = 45%
  double _avgRR = 2.0;
  int _tradesPerDay = 2;

  // ── Step 3 — Risk Profile ─────────────────────────────────────────────────
  int _riskProfileIndex = 1; // 0=conservative, 1=balanced, 2=aggressive
  double _customRiskPct = 0; // 0 = use profile
  final TextEditingController _customRiskController = TextEditingController();

  // ── Step 4 — Protocol result ──────────────────────────────────────────────
  MonteCarloResult? _mcResult;
  bool _isGenerating = false;
  bool _protocolReady = false;
  String? _errorMessage;
  Map<String, dynamic>? _generatedPlan;
  Challenge? _finalChallenge;

  // ── Computed ──────────────────────────────────────────────────────────────
  double get _riskPerTradePct {
    if (_customRiskPct > 0) return _customRiskPct;
    switch (_riskProfileIndex) {
      case 0:
        return 0.5;
      case 2:
        return 2.0;
      default:
        return 1.0;
    }
  }

  String get _riskProfileString {
    switch (_riskProfileIndex) {
      case 0:
        return 'conservative';
      case 2:
        return 'aggressive';
      default:
        return 'balanced';
    }
  }

  bool get _isCustomFirm =>
      _selectedFirm == null || _selectedFirm!.firmId == 'custom';

  @override
  void dispose() {
    _controller.dispose();
    _accountNumberController.dispose();
    _customFirmController.dispose();
    _profitTargetController.dispose();
    _maxDailyLossController.dispose();
    _maxDrawdownController.dispose();
    _durationController.dispose();
    _customRiskController.dispose();
    super.dispose();
  }

  void _onFirmSelected(PropFirmConfig firm) {
    setState(() {
      _selectedFirm = firm;
      _selectedPreset = firm.presets.isNotEmpty ? firm.presets.first : null;
      if (_selectedPreset != null) {
        _onPresetSelected(_selectedPreset!);
      }
      if (firm.accountSizes.isNotEmpty) {
        _accountSize = firm.accountSizes
            .map((s) => s.toDouble())
            .firstWhere((_) => true, orElse: () => firm.accountSizes.first.toDouble());
        // pick closest to 50000 or first
        final sizes = firm.accountSizes;
        double closest = sizes.first.toDouble();
        for (final s in sizes) {
          if ((s - 50000).abs() < (closest - 50000).abs()) closest = s.toDouble();
        }
        _accountSize = closest;
      }
    });
  }

  void _onPresetSelected(PropFirmPreset preset) {
    setState(() {
      _selectedPreset = preset;
      if (!_overrideRules) {
        _profitTarget = preset.profitTargetPct;
        _maxDailyLoss = preset.maxDailyLossPct;
        _maxDrawdown = preset.maxDrawdownPct;
        _profitTargetController.text = preset.profitTargetPct.toStringAsFixed(1);
        _maxDailyLossController.text = preset.maxDailyLossPct.toStringAsFixed(1);
        _maxDrawdownController.text = preset.maxDrawdownPct.toStringAsFixed(1);
      }
    });
  }

  void _next() {
    if (_step < _totalSteps - 1) {
      if (_step == 2) {
        // Going to step 4 — trigger generation
        _controller.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _generateProtocol();
      } else {
        _controller.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
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

  bool _validateStep1() {
    if (_isCustomFirm && _customFirmController.text.trim().isEmpty) {
      _showError('Enter your firm name / Inserisci il nome della firm');
      return false;
    }
    if (_profitTarget <= 0) {
      _showError('Profit target must be > 0');
      return false;
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.manrope()),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _generateProtocol() async {
    setState(() {
      _isGenerating = true;
      _protocolReady = false;
      _errorMessage = null;
    });

    try {
      // Effective values
      final effectiveProfitTarget = _profitTarget;
      final effectiveMaxDailyLoss = _maxDailyLoss;
      final effectiveMaxDrawdown = _maxDrawdown;
      final effectiveDrawdownType =
          _selectedPreset?.drawdownType ?? 'static';

      // 1. Monte Carlo
      final mcInput = MonteCarloInput(
        balance: _accountSize,
        profitTargetPct: effectiveProfitTarget,
        maxDrawdownPct: effectiveMaxDrawdown,
        dailyDrawdownPct: effectiveMaxDailyLoss,
        drawdownType: effectiveDrawdownType,
        winRate: _winRate / 100,
        avgRR: _avgRR,
        riskPerTradePct: _riskPerTradePct,
        tradesPerDay: _tradesPerDay,
        totalDays: _durationDays,
        hasConsistencyRule: _selectedPreset?.hasConsistencyRule ?? false,
        consistencyRulePct: _selectedPreset?.consistencyRulePct,
      );
      final mcResult = await MonteCarloService.simulate(mcInput);

      // 2. Build challenge object
      final userId = ref.read(currentUserIdProvider);
      final firmName = _isCustomFirm
          ? (_customFirmController.text.trim().isNotEmpty
              ? _customFirmController.text.trim()
              : 'Custom')
          : (_selectedFirm?.firmName ?? 'Unknown');

      final tempChallenge = Challenge(
        id: 'tmp',
        userId: userId.isNotEmpty ? userId : 'anonymous',
        propFirmName: firmName,
        accountSize: _accountSize,
        profitTarget: effectiveProfitTarget,
        maxDailyLoss: effectiveMaxDailyLoss,
        maxTotalDrawdown: effectiveMaxDrawdown,
        durationDays: _durationDays,
        style: _riskProfileString,
        startedAt: DateTime.now(),
        accountNumber: _accountNumberController.text.trim().isNotEmpty
            ? _accountNumberController.text.trim()
            : null,
        propFirmPreset: _selectedPreset?.id,
        phases: _selectedPreset?.phases ?? 2,
        drawdownType: effectiveDrawdownType,
        consistencyRule: _selectedPreset?.hasConsistencyRule ?? false,
        consistencyRulePct: _selectedPreset?.consistencyRulePct,
        newsRestriction: _selectedPreset?.newsRestriction ?? false,
        overnightRestriction: _selectedPreset?.overnightRestriction ?? false,
        winRate: _winRate / 100,
        avgRr: _avgRR,
        tradesPerDayStrategy: _tradesPerDay,
        riskProfile: _riskProfileString,
        monteCarloPassPct: mcResult.passProbability * 100,
        monteCarloRange:
            mcResult.probabilityRangeString.replaceAll('%', ''),
        monteCarloUpdatedAt: DateTime.now(),
      );

      // 3. Generate AI plan
      Map<String, dynamic>? plan;
      try {
        plan = await AiService.generateChallengePlan(tempChallenge, mcResult);
      } catch (_) {
        // plan stays null — we continue without it
      }

      final challengeWithPlan =
          plan != null ? tempChallenge.copyWith(aiPlan: plan) : tempChallenge;

      // 4. Save to Supabase
      Challenge finalChallenge = challengeWithPlan;
      if (userId.isNotEmpty) {
        try {
          finalChallenge =
              await SupabaseService.insertChallenge(challengeWithPlan);
        } catch (_) {}
      }

      ref.read(pendingChallengeProvider.notifier).state = finalChallenge;
      ref.read(challengeListProvider.notifier).addChallenge(finalChallenge);

      if (mounted) {
        setState(() {
          _mcResult = mcResult;
          _generatedPlan = finalChallenge.aiPlan;
          _finalChallenge = finalChallenge;
          _isGenerating = false;
          _protocolReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with progress
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding, 20, AppTheme.pagePadding, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: AppColors.textPrimary, size: 20),
                        onPressed: _back,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        s.challengeSetupStep(_step + 1, _totalSteps),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1 — Account & Prop Firm ──────────────────────────────────────────
  Widget _buildStep1(AppStrings s) {
    final isCustom = _isCustomFirm;
    final isFutures = _selectedPreset?.assetClass == 'futures';

    return _stepWrapper(
      s: s,
      title: s.t('Account & Prop Firm', 'Account e Prop Firm'),
      subtitle: s.t(
        'Select your firm and account size.',
        'Seleziona la tua firm e la dimensione dell\'account.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prop Firm dropdown
          _sectionLabel('Prop Firm'),
          const SizedBox(height: 8),
          _dropdownContainer(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<PropFirmConfig>(
                value: _selectedFirm,
                hint: Text(
                  s.t('Select firm', 'Seleziona firm'),
                  style: GoogleFonts.manrope(color: AppColors.textSecondary),
                ),
                dropdownColor: AppColors.cardBg,
                style: GoogleFonts.manrope(
                    color: AppColors.textPrimary, fontSize: 15),
                isExpanded: true,
                onChanged: (v) {
                  if (v != null) _onFirmSelected(v);
                },
                items: kPropFirmConfigs.map((firm) {
                  return DropdownMenuItem(
                    value: firm,
                    child: Text(firm.firmName,
                        style: GoogleFonts.manrope(
                            color: AppColors.textPrimary)),
                  );
                }).toList(),
              ),
            ),
          ),

          // Custom firm name
          if (isCustom) ...[
            const SizedBox(height: 12),
            _sectionLabel(s.t('Firm Name', 'Nome Firm')),
            const SizedBox(height: 8),
            TextField(
              controller: _customFirmController,
              style: GoogleFonts.manrope(color: AppColors.textPrimary),
              decoration: _inputDecoration(
                  hint: s.t('e.g. My Prop Firm', 'es. La Mia Firm')),
              onChanged: (_) {},
            ),
          ],

          // Preset dropdown (if firm selected and has >1 preset)
          if (_selectedFirm != null &&
              _selectedFirm!.presets.length > 1) ...[
            const SizedBox(height: 12),
            _sectionLabel(s.t('Challenge Model', 'Modello Challenge')),
            const SizedBox(height: 8),
            _dropdownContainer(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<PropFirmPreset>(
                  value: _selectedPreset,
                  dropdownColor: AppColors.cardBg,
                  style: GoogleFonts.manrope(
                      color: AppColors.textPrimary, fontSize: 15),
                  isExpanded: true,
                  onChanged: (v) {
                    if (v != null) _onPresetSelected(v);
                  },
                  items: _selectedFirm!.presets.map((preset) {
                    return DropdownMenuItem(
                      value: preset,
                      child: Text(preset.modelName,
                          style: GoogleFonts.manrope(
                              color: AppColors.textPrimary)),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          // Futures banner
          if (isFutures) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.t(
                        'Futures account — ensure your broker data matches',
                        'Account futures — verifica che i dati del broker corrispondano',
                      ),
                      style: GoogleFonts.manrope(
                        color: const Color(0xFFF59E0B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Preset info chips (if preset selected and not override)
          if (_selectedPreset != null && !isCustom) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _infoChip(
                  _selectedPreset!.drawdownType == 'trailing_eod'
                      ? '📈 Trailing EOD'
                      : '🔒 Static',
                ),
                _infoChip(
                    '${_selectedPreset!.profitTargetPct.toStringAsFixed(0)}% target'),
                _infoChip(
                    '${_selectedPreset!.maxDailyLossPct.toStringAsFixed(0)}% daily loss'),
                _infoChip(
                    '${_selectedPreset!.maxDrawdownPct.toStringAsFixed(0)}% drawdown'),
                if (_selectedPreset!.phases > 0)
                  _infoChip('${_selectedPreset!.phases}-phase'),
                if (_selectedPreset!.hasConsistencyRule)
                  _infoChip(_selectedPreset!.consistencyRulePct != null
                      ? '⚠️ Consistency ${_selectedPreset!.consistencyRulePct!.toStringAsFixed(0)}%'
                      : '⚠️ Consistency rule'),
                if (_selectedPreset!.newsRestriction)
                  _infoChip('⚠️ News restriction'),
                if (_selectedPreset!.overnightRestriction)
                  _infoChip('⚠️ No overnight'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Switch(
                  value: _overrideRules,
                  onChanged: (v) => setState(() => _overrideRules = v),
                  activeThumbColor: AppColors.accent,
                  activeTrackColor: AppColors.accent.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 8),
                Text(
                  s.t('Override rules', 'Modifica regole'),
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ],

          // Manual / override rule fields
          if (isCustom || _overrideRules) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _numericField(
                    label: s.t('Profit target %', 'Profit target %'),
                    controller: _profitTargetController,
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null) setState(() => _profitTarget = parsed);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _numericField(
                    label: s.t('Max daily loss %', 'Max daily loss %'),
                    controller: _maxDailyLossController,
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null) {
                        setState(() => _maxDailyLoss = parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _numericField(
                    label: s.t('Max drawdown %', 'Max drawdown %'),
                    controller: _maxDrawdownController,
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null) {
                        setState(() => _maxDrawdown = parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _numericField(
                    label: s.t('Duration (days)', 'Durata (giorni)'),
                    controller: _durationController,
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null) {
                        setState(() => _durationDays = parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],

          // Account size
          const SizedBox(height: 16),
          _sectionLabel(s.challengeSetupAccountSize),
          const SizedBox(height: 8),
          _dropdownContainer(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<double>(
                value: _accountSize,
                dropdownColor: AppColors.cardBg,
                style: GoogleFonts.manrope(
                    color: AppColors.textPrimary, fontSize: 15),
                isExpanded: true,
                onChanged: (v) {
                  if (v != null) setState(() => _accountSize = v);
                },
                items: (_selectedFirm != null
                        ? _selectedFirm!.accountSizes
                            .map((s) => s.toDouble())
                            .toList()
                        : <double>[
                            10000,
                            25000,
                            50000,
                            100000,
                            200000
                          ])
                    .map((size) {
                  return DropdownMenuItem<double>(
                    value: size,
                    child: Text(
                      '\$${size >= 1000 ? '${(size / 1000).round()}k' : size.round()}',
                      style: GoogleFonts.manrope(
                          color: AppColors.textPrimary),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Duration (if preset, show as chip — otherwise already in override)
          if (!isCustom && !_overrideRules) ...[
            const SizedBox(height: 16),
            _sectionLabel(s.challengeSetupDuration),
            const SizedBox(height: 8),
            _numericField(
              label: s.t('Duration (days)', 'Durata (giorni)'),
              controller: _durationController,
              onChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null) setState(() => _durationDays = parsed);
              },
            ),
          ],

          // Account number (optional)
          const SizedBox(height: 16),
          _sectionLabel(
              s.t('Account Number (optional)', 'Numero Account (opzionale)')),
          const SizedBox(height: 8),
          TextField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.manrope(color: AppColors.textPrimary),
            decoration: _inputDecoration(
                hint: s.t('Your MT5/cTrader account number',
                    'Il tuo numero account MT5/cTrader')),
            onChanged: (_) {},
          ),
        ],
      ),
      onNext: () {
        if (_validateStep1()) _next();
      },
    );
  }

  // ── Step 2 — Your Strategy ────────────────────────────────────────────────
  Widget _buildStep2(AppStrings s) {
    return _stepWrapper(
      s: s,
      title: s.t('How do you trade?', 'Come operi?'),
      subtitle: s.t(
        'Use your actual history, not expectations.',
        'Usa la tua storia reale, non le aspettative.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Win rate
          _sectionLabel(
              '${s.t('Win Rate', 'Win Rate')} — ${_winRate.round()}%'),
          const SizedBox(height: 4),
          Slider(
            value: _winRate,
            min: 30,
            max: 70,
            divisions: 40,
            activeColor: AppColors.accent,
            inactiveColor: AppColors.divider,
            label: '${_winRate.round()}%',
            onChanged: (v) => setState(() => _winRate = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('30%',
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 11)),
              Text('70%',
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),

          const SizedBox(height: 20),

          // Avg RR
          _sectionLabel(
              '${s.t('Avg Risk:Reward', 'Risk:Reward Medio')} — 1:${_avgRR.toStringAsFixed(1)}'),
          const SizedBox(height: 4),
          Slider(
            value: _avgRR,
            min: 1.0,
            max: 4.0,
            divisions: 30,
            activeColor: AppColors.accent,
            inactiveColor: AppColors.divider,
            label: '1:${_avgRR.toStringAsFixed(1)}',
            onChanged: (v) => setState(() =>
                _avgRR = double.parse(v.toStringAsFixed(1))),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1:1.0',
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 11)),
              Text('1:4.0',
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),

          const SizedBox(height: 20),

          // Trades per day stepper
          _sectionLabel(s.t('Avg Trades/Day', 'Trade Medi al Giorno')),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppColors.accent),
                  onPressed: _tradesPerDay > 1
                      ? () => setState(() => _tradesPerDay--)
                      : null,
                ),
                Text(
                  '$_tradesPerDay',
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppColors.accent),
                  onPressed: _tradesPerDay < 10
                      ? () => setState(() => _tradesPerDay++)
                      : null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.t(
                      'These inputs directly affect your Monte Carlo simulation accuracy.',
                      'Questi valori influenzano direttamente la precisione della simulazione Monte Carlo.',
                    ),
                    style: GoogleFonts.manrope(
                      color: AppColors.accent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      onNext: _next,
    );
  }

  // ── Step 3 — Risk Profile ─────────────────────────────────────────────────
  Widget _buildStep3(AppStrings s) {
    final riskOptions = [
      {
        'emoji': '🐢',
        'label': s.challengeSetupConservative,
        'sublabel': '0.5% risk/trade',
        'desc': s.t(
            'Lower probability of drawdown. Slower progress.',
            'Minore probabilità di drawdown. Progresso più lento.'),
        'pct': 0.5,
        'index': 0,
      },
      {
        'emoji': '⚖️',
        'label': s.t('Balanced', 'Bilanciato'),
        'sublabel': '1.0% risk/trade',
        'desc': s.t(
            'Optimal balance for most challenge structures.',
            'Bilanciamento ottimale per la maggior parte delle challenge.'),
        'pct': 1.0,
        'index': 1,
      },
      {
        'emoji': '🚀',
        'label': s.challengeSetupAggressive,
        'sublabel': '2.0% risk/trade',
        'desc': s.t(
            'Higher upside, significantly higher drawdown risk.',
            'Potenziale maggiore, rischio drawdown significativamente più alto.'),
        'pct': 2.0,
        'index': 2,
      },
    ];

    return _stepWrapper(
      s: s,
      title: s.t('Risk Profile', 'Profilo di Rischio'),
      subtitle: s.t(
        'Choose how much you risk per trade.',
        'Scegli quanto rischiare per trade.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...riskOptions.map((opt) {
            final idx = opt['index'] as int;
            final pct = opt['pct'] as double;
            final amountUsd = _accountSize * pct / 100;
            final isSelected = _riskProfileIndex == idx && _customRiskPct == 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() {
                  _riskProfileIndex = idx;
                  _customRiskPct = 0;
                  _customRiskController.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.08)
                        : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : AppColors.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(opt['emoji'] as String,
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  opt['label'] as String,
                                  style: GoogleFonts.manrope(
                                    color: isSelected
                                        ? AppColors.accent
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    opt['sublabel'] as String,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              opt['desc'] as String,
                              style: GoogleFonts.manrope(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${amountUsd.round()}/trade',
                        style: GoogleFonts.manrope(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Custom risk
          const SizedBox(height: 4),
          _sectionLabel(s.t('Custom risk % (optional)', 'Rischio custom % (opzionale)')),
          const SizedBox(height: 6),
          TextField(
            controller: _customRiskController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.manrope(color: AppColors.textPrimary),
            decoration: _inputDecoration(hint: s.t('e.g. 1.5', 'es. 1.5')),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              setState(() =>
                  _customRiskPct = (parsed != null && parsed > 0) ? parsed : 0);
            },
          ),
        ],
      ),
      onNext: _next,
    );
  }

  // ── Step 4 — Challenge Protocol ───────────────────────────────────────────
  Widget _buildStep4(AppStrings s) {
    if (_isGenerating) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 24),
            Text(
              s.t(
                'Running 10,000 simulations...',
                'Eseguendo 10.000 simulazioni...',
              ),
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              Text(
                s.t('Something went wrong.', 'Qualcosa è andato storto.'),
                style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: GoogleFonts.manrope(
                    color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PremiumButton(
                label: s.t('Retry', 'Riprova'),
                onTap: _generateProtocol,
              ),
            ],
          ),
        ),
      );
    }

    if (!_protocolReady || _mcResult == null) {
      return const SizedBox.shrink();
    }

    final mc = _mcResult!;
    final plan = _generatedPlan;
    final processFocus = plan?['processFocus'] as Map<String, dynamic>?;

    final passPct = (mc.passProbability * 100).round();
    final rangeStr =
        '${mc.probabilityRangeString.replaceAll('%', '')}%';
    final ddHitPct = (mc.drawdownHitProbability * 100).round();
    final medianDays = mc.medianDaysToPass;

    final challenge = _finalChallenge;
    final hasConsistency = challenge?.consistencyRule ?? false;
    final consistencyPct = challenge?.consistencyRulePct;
    final hasNews = challenge?.newsRestriction ?? false;

    final dailyRiskUsd =
        processFocus?['dailyRiskBudgetUsd'] as int? ??
            (_accountSize * _riskPerTradePct / 100 * _tradesPerDay).round();
    final maxTrades =
        processFocus?['maxTradesPerDay'] as int? ?? _tradesPerDay;
    final riskPerTradeUsd =
        processFocus?['riskPerTradeUsd'] as int? ??
            (_accountSize * _riskPerTradePct / 100).round();
    final maxConsecLosses =
        processFocus?['maxConsecutiveLossesBeforeStop'] as int? ?? 2;
    final cooldown =
        processFocus?['cooldownMinutes'] as int? ?? 30;
    final objectives =
        (processFocus?['processObjectives'] as List<dynamic>?)
            ?.cast<String>() ??
            <String>[
              s.t('Wait for A+ setup only', 'Aspetta solo setup A+'),
              s.t('Fixed risk per trade', 'Rischio fisso per trade'),
              s.t('Stop after N consecutive losses',
                  'Stop dopo N perdite consecutive'),
            ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding, 8, AppTheme.pagePadding, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            s.t('Challenge Protocol', 'Challenge Protocol'),
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.t('Your personalised plan is ready.',
                'Il tuo piano personalizzato è pronto.'),
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Card 1 — Probability
          _protocolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🎯', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      s.t('Challenge Protocol', 'Challenge Protocol'),
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  s.t('Simulated pass probability',
                      'Probabilità di passaggio simulata'),
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  rangeStr,
                  style: GoogleFonts.manrope(
                    color: AppColors.accent,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 10),
                GlowProgressBar(
                  value: mc.passProbability.clamp(0.0, 1.0),
                  fillColor: AppColors.accent,
                  trackColor: AppColors.divider,
                  height: 6,
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$passPct%',
                    style: GoogleFonts.manrope(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 12),
                if (medianDays != null)
                  _protocolRow(
                    s.t('Median days to pass', 'Giorni mediani per passare'),
                    '$medianDays',
                  ),
                _protocolRow(
                  s.t('Drawdown hit risk', 'Rischio hit drawdown'),
                  '$ddHitPct%',
                  valueColor: ddHitPct > 40 ? AppColors.danger : null,
                ),
                _protocolRow(
                  s.t('Optimal risk range', 'Range rischio ottimale'),
                  '${mc.recommendedRiskMin.toStringAsFixed(1)}–${mc.recommendedRiskMax.toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    mc.summaryPhrase,
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Card 2 — Daily Protocol
          _protocolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('📋', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      s.t('Your Daily Protocol', 'Il Tuo Protocollo Giornaliero'),
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _protocolRow(
                    s.t('Daily risk budget', 'Budget rischio giornaliero'),
                    '\$$dailyRiskUsd'),
                _protocolRow(
                    s.t('Max trades/day', 'Max trade/giorno'),
                    '$maxTrades'),
                _protocolRow(
                    s.t('Risk per trade', 'Rischio per trade'),
                    '\$$riskPerTradeUsd'),
                _protocolRow(
                    s.t('Stop after', 'Stop dopo'),
                    '$maxConsecLosses ${s.t('consecutive losses', 'perdite consecutive')}'),
                _protocolRow(
                    s.t('Cooldown', 'Cooldown'),
                    '$cooldown ${s.t('min', 'min')}'),
                const SizedBox(height: 12),
                Text(
                  s.t('Process objectives:', 'Obiettivi di processo:'),
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ...objectives.map((obj) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('✅  ',
                              style: const TextStyle(fontSize: 12)),
                          Expanded(
                            child: Text(
                              obj,
                              style: GoogleFonts.manrope(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('❌  ', style: TextStyle(fontSize: 12)),
                      Expanded(child: Text('No daily profit obligation')),
                    ],
                  ),
                ),
                if (hasConsistency) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️  ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Text(
                          consistencyPct != null
                              ? s.t(
                                  'No single day > ${consistencyPct.toStringAsFixed(0)}% of total profit',
                                  'Nessun giorno > ${consistencyPct.toStringAsFixed(0)}% del profitto totale')
                              : s.t(
                                  'Consistency rule active — check firm details',
                                  'Regola di consistenza attiva — verifica i dettagli della firm'),
                          style: GoogleFonts.manrope(
                            color: AppColors.warning,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (hasNews) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️  ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Text(
                          s.t(
                            'No new trades 2 min before/after high-impact news',
                            'Nessun trade 2 min prima/dopo news ad alto impatto',
                          ),
                          style: GoogleFonts.manrope(
                            color: AppColors.warning,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          PremiumButton(
            label: s.t('Start Challenge', 'Inizia Challenge'),
            icon: Icons.flag_rounded,
            onTap: () {
              // Signal tab switch to AI Planner (index 1) before popping back.
              // Using pendingTabIndexProvider avoids creating a second /main instance.
              ref.read(pendingTabIndexProvider.notifier).state = 1;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _protocolCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: child,
    );
  }

  Widget _protocolRow(String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.manrope(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _dropdownContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
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
    );
  }

  Widget _numericField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.manrope(color: AppColors.textPrimary),
          decoration: _inputDecoration(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _stepWrapper({
    required AppStrings s,
    required String title,
    required String subtitle,
    required Widget child,
    VoidCallback? onNext,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding, 8, AppTheme.pagePadding, 20),
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
              label: _step == 2
                  ? s.t('Generate Protocol', 'Genera Protocollo')
                  : s.challengeSetupNext,
              icon: _step == 2 ? Icons.auto_awesome : null,
              onTap: onNext,
            ),
          ],
        ],
      ),
    );
  }
}
