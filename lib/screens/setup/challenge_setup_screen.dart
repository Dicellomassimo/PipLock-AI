import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../models/challenge.dart';
import '../../providers/auth_provider.dart';
import '../../providers/challenge_provider.dart';
import '../../providers/pending_challenge_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/glow_progress_bar.dart';

class ChallengeSetupScreen extends ConsumerStatefulWidget {
  const ChallengeSetupScreen({super.key});

  @override
  ConsumerState<ChallengeSetupScreen> createState() =>
      _ChallengeSetupScreenState();
}

class _ChallengeSetupScreenState extends ConsumerState<ChallengeSetupScreen> {
  final PageController _controller = PageController();
  int _step = 0;
  final int _totalSteps = 6;

  // Step 1
  String _propFirm = 'FTMO';
  final TextEditingController _customFirmController = TextEditingController();

  // Step 2
  double _accountSize = 50000;

  // Step 3
  double _profitTarget = 10;

  // Step 4
  double _maxDailyLoss = 5;
  double _maxDrawdown = 10;

  // Step 5
  final TextEditingController _durationController =
      TextEditingController(text: '30');

  // Step 6
  double _styleValue = 1; // 0=conservative, 1=moderate, 2=aggressive
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _investorPasswordController = TextEditingController();
  String _selectedPlatform = 'MT5';

  final List<String> _propFirms = [
    'FTMO',
    'MyForexFunds',
    'E8 Funding',
    'The Funded Trader',
    'Apex Trader Funding',
    'Other',
  ];

  final List<double> _accountSizes = [10000, 25000, 50000, 100000, 200000];

  @override
  void dispose() {
    _controller.dispose();
    _customFirmController.dispose();
    _durationController.dispose();
    _accountController.dispose();
    _investorPasswordController.dispose();
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

  String get _styleString {
    switch (_styleValue.round()) {
      case 0:
        return 'conservative';
      case 2:
        return 'aggressive';
      default:
        return 'moderate';
    }
  }

  String _styleLabel(AppStrings s) {
    switch (_styleValue.round()) {
      case 0:
        return s.challengeSetupConservative;
      case 2:
        return s.challengeSetupAggressive;
      default:
        return s.challengeSetupModerate;
    }
  }

  Future<void> _generate() async {
    final userId = ref.read(currentUserIdProvider);
    final accountNum = _accountController.text.trim();

    if (accountNum.isEmpty) {
      // Account number is required — show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account number is required.',
            style: GoogleFonts.manrope(),
          ),
          backgroundColor: const Color(0xFFEF5350),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // ID placeholder: 'tmp' verrà ignorato da insertChallenge (Supabase genera UUID)
    final tempChallenge = Challenge(
      id: 'tmp',
      userId: userId.isNotEmpty ? userId : 'anonymous',
      propFirmName:
          _propFirm == 'Other' ? _customFirmController.text : _propFirm,
      accountSize: _accountSize,
      profitTarget: _profitTarget,
      maxDailyLoss: _maxDailyLoss,
      maxTotalDrawdown: _maxDrawdown,
      durationDays: int.tryParse(_durationController.text) ?? 30,
      style: _styleString,
      startedAt: DateTime.now(),
      accountNumber: accountNum.isNotEmpty ? accountNum : null,
    );

    Challenge finalChallenge = tempChallenge;
    if (userId.isNotEmpty) {
      try {
        // Inserisce senza ID → Supabase genera UUID valido → ritorna challenge con ID reale
        finalChallenge = await SupabaseService.insertChallenge(tempChallenge);
      } catch (_) {
        // salvataggio fallito (es. devMode): usa challenge temporaneo in memoria
      }
    }

    if (mounted) {
      ref.read(pendingChallengeProvider.notifier).state = finalChallenge;
      ref.read(challengeListProvider.notifier).addChallenge(finalChallenge);
      Navigator.pushReplacementNamed(context, '/main', arguments: 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
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
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                  _buildStep5(),
                  _buildStep6(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 1: Prop firm
  Widget _buildStep1() {
    final s = ref.watch(appStringsProvider);
    return _stepWrapper(
      s: s,
      title: s.challengeSetupWhichFirm,
      subtitle: s.challengeSetupFirmSubtitle,
      child: Column(
        children: [
          ..._propFirms.map((firm) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _propFirm = firm),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _propFirm == firm
                          ? AppColors.accent.withValues(alpha: 0.1)
                          : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _propFirm == firm
                            ? AppColors.accent
                            : AppColors.divider,
                        width: _propFirm == firm ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          firm,
                          style: GoogleFonts.manrope(
                            color: _propFirm == firm
                                ? AppColors.accent
                                : AppColors.textPrimary,
                            fontWeight: _propFirm == firm
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        const Spacer(),
                        if (_propFirm == firm)
                          const Icon(Icons.check_circle,
                              color: AppColors.accent, size: 18),
                      ],
                    ),
                  ),
                ),
              )),
          if (_propFirm == 'Other')
            TextField(
              controller: _customFirmController,
              style: GoogleFonts.manrope(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: s.challengeSetupFirmNameHint,
                hintStyle: GoogleFonts.manrope(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent)),
              ),
            ),
        ],
      ),
      onNext: _next,
    );
  }

  // STEP 2: Capitale
  Widget _buildStep2() {
    final s = ref.watch(appStringsProvider);
    return _stepWrapper(
      s: s,
      title: s.challengeSetupAccountSize,
      subtitle: s.challengeSetupAccountSizeSubtitle,
      child: Column(
        children: [
          ..._accountSizes.map((size) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _accountSize = size),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _accountSize == size
                          ? AppColors.accent.withValues(alpha: 0.1)
                          : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _accountSize == size
                            ? AppColors.accent
                            : AppColors.divider,
                        width: _accountSize == size ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '\$${(size / 1000).round()}k',
                          style: GoogleFonts.manrope(
                            color: _accountSize == size
                                ? AppColors.accent
                                : AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_accountSize == size)
                          const Icon(Icons.check_circle,
                              color: AppColors.accent, size: 18),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
      onNext: _next,
    );
  }

  // STEP 3: Profit target
  Widget _buildStep3() {
    final s = ref.watch(appStringsProvider);
    return _stepWrapper(
      s: s,
      title: s.challengeSetupProfitTarget,
      subtitle: s.challengeSetupProfitTargetSubtitle,
      child: Column(
        children: [
          Text(
            '${_profitTarget.toStringAsFixed(1)}%',
            style: GoogleFonts.manrope(
              color: AppColors.accent,
              fontSize: 52,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _profitTarget,
            min: 5,
            max: 20,
            divisions: 30,
            activeColor: AppColors.accent,
            inactiveColor: AppColors.divider,
            onChanged: (v) =>
                setState(() => _profitTarget = double.parse(v.toStringAsFixed(1))),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('5%',
                  style:
                      GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 12)),
              Text('20%',
                  style:
                      GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              s.challengeSetupProfitHint(
                (_accountSize / 1000).round().toString(),
                (_accountSize * _profitTarget / 100).round().toString(),
              ),
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      onNext: _next,
    );
  }

  // STEP 4: Max daily loss + drawdown
  Widget _buildStep4() {
    final s = ref.watch(appStringsProvider);
    return _stepWrapper(
      s: s,
      title: s.challengeSetupLossLimits,
      subtitle: s.challengeSetupLossLimitsSubtitle,
      child: Column(
        children: [
          _sliderCard(
            label: 'Max daily loss',
            value: _maxDailyLoss,
            min: 1,
            max: 10,
            divisions: 18,
            color: AppColors.warning,
            onChanged: (v) => setState(() =>
                _maxDailyLoss = double.parse(v.toStringAsFixed(1))),
            format: (v) => '${v.toStringAsFixed(1)}%',
          ),
          const SizedBox(height: 24),
          _sliderCard(
            label: 'Max total drawdown',
            value: _maxDrawdown,
            min: 5,
            max: 20,
            divisions: 30,
            color: AppColors.danger,
            onChanged: (v) => setState(
                () => _maxDrawdown = double.parse(v.toStringAsFixed(1))),
            format: (v) => '${v.toStringAsFixed(1)}%',
          ),
        ],
      ),
      onNext: _next,
    );
  }

  Widget _sliderCard({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Color color,
    required ValueChanged<double> onChanged,
    required String Function(double) format,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 13)),
              Text(
                format(value),
                style: GoogleFonts.manrope(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: color,
            inactiveColor: AppColors.divider,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // STEP 5: Durata
  Widget _buildStep5() {
    final s = ref.watch(appStringsProvider);
    return _stepWrapper(
      s: s,
      title: s.challengeSetupDuration,
      subtitle: s.challengeSetupDurationSubtitle,
      child: Column(
        children: [
          TextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontSize: 52,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.cardBg,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent)),
              suffixText: s.challengeSetupDays,
              suffixStyle:
                  GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [30, 60, 90].map((d) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _durationController.text = '$d'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      '$d days',
                      style: GoogleFonts.manrope(
                          color: AppColors.textSecondary, fontSize: 13),
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

  // STEP 6: Stile
  Widget _buildStep6() {
    final s = ref.watch(appStringsProvider);
    final styleColor = _styleValue.round() == 0
        ? AppColors.accent
        : _styleValue.round() == 2
            ? AppColors.danger
            : AppColors.warning;

    return _stepWrapper(
      s: s,
      title: s.challengeSetupStyle,
      subtitle: s.challengeSetupStyleSubtitle,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            _styleLabel(s),
            style: GoogleFonts.manrope(
              color: styleColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Slider(
            value: _styleValue,
            min: 0,
            max: 2,
            divisions: 2,
            activeColor: styleColor,
            inactiveColor: AppColors.divider,
            onChanged: (v) => setState(() => _styleValue = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.challengeSetupConservative,
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 11)),
              Text(s.challengeSetupModerate,
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 11)),
              Text(s.challengeSetupAggressive,
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 24),
          _styleDescriptionCard(),
          const SizedBox(height: 24),
          Text(
            'Platform',
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPlatform,
                dropdownColor: AppColors.cardBg,
                style: GoogleFonts.manrope(color: AppColors.textPrimary, fontSize: 15),
                isExpanded: true,
                onChanged: (v) => setState(() => _selectedPlatform = v ?? 'MT5'),
                items: ['MT5', 'MT4', 'cTrader', 'OANDA', 'Other']
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p, style: GoogleFonts.manrope(color: AppColors.textPrimary)),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Account Number ',
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: Color(0xFFEF5350),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _accountController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.manrope(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. 9544480',
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
                  'Find it in your platform → account details → number below your name',
                  style: GoogleFonts.manrope(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Investor Password',
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _investorPasswordController,
            obscureText: true,
            style: GoogleFonts.manrope(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Investor (read-only) password',
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
              const Icon(Icons.lock_outline, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Used only to read data. Never grants trading access.',
                  style: GoogleFonts.manrope(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          PremiumButton(
            label: s.challengeSetupGenerate,
            icon: Icons.auto_awesome,
            onTap: _generate,
          ),
        ],
      ),
    );
  }

  Widget _styleDescriptionCard() {
    final s = ref.watch(appStringsProvider);
    final descriptions = [
      {
        'title': s.challengeSetupConservative,
        'desc': s.t(
          '0.25% risk per trade. Slower but much safer. Ideal for beginners or traders who have already failed a challenge.',
          'Rischio 0.25% per trade. Più lento ma molto più sicuro. Ideale per chi inizia o ha già fallito una challenge.',
        ),
        'color': AppColors.accent,
      },
      {
        'title': s.challengeSetupModerate,
        'desc': s.t(
          '0.5% risk per trade. The optimal balance between speed and safety. Recommended for most traders.',
          'Rischio 0.5% per trade. Il bilanciamento ottimale tra velocità e sicurezza. Consigliato per la maggior parte dei trader.',
        ),
        'color': AppColors.warning,
      },
      {
        'title': s.challengeSetupAggressive,
        'desc': s.t(
          '1-2% risk per trade. Complete the challenge faster, but with a reduced margin for error. For experienced traders only.',
          'Rischio 1-2% per trade. Completi la challenge più velocemente, ma il margine di errore è ridotto. Solo per trader esperti.',
        ),
        'color': AppColors.danger,
      },
    ];
    final d = descriptions[_styleValue.round()];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (d['color'] as Color).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (d['color'] as Color).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            d['title'] as String,
            style: GoogleFonts.manrope(
              color: d['color'] as Color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            d['desc'] as String,
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
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
              label: s.challengeSetupNext,
              onTap: onNext,
            ),
          ],
        ],
      ),
    );
  }
}
