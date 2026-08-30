import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/ambient_blobs.dart';
import '../../widgets/google_sign_in_button.dart';
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  int _selectedPlan = 1; // 0=monthly, 1=annual (annual pre-selected)

  void _startTrial() {
    final s = ref.read(appStringsProvider);
    final isAnnual = _selectedPlan == 1;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RegistrationSheet(s: s, isAnnual: isAnnual),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: AmbientBlobs())),
          SafeArea(child: _buildContent(s)),
        ],
      ),
    );
  }

  Widget _buildContent(AppStrings s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Header gradient banner ────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.lock_rounded, color: Colors.black, size: 28),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      s.t('Go Pro', 'Diventa Pro'),
                      style: GoogleFonts.manrope(
                        color: Colors.black,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.t(
                        'The trading discipline system used by serious traders.',
                        'Il sistema di disciplina di trading usato dai trader seri.',
                      ),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: Colors.black.withValues(alpha: 0.7),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Social proof
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_rounded,
                            color: Colors.black, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          s.t('Built for disciplined traders', 'Costruito per trader disciplinati'),
                          style: GoogleFonts.manrope(
                            color: Colors.black.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Plan selector (animated border) ───────────────────────────
              _AnimatedBorderCard(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _PlanTab(
                        label: s.t('Monthly', 'Mensile'),
                        price: '€19.99',
                        period: s.t('/mo', '/mese'),
                        selected: _selectedPlan == 0,
                        onTap: () => setState(() => _selectedPlan = 0),
                        badge: null,
                      ),
                      _PlanTab(
                        label: s.t('Annual', 'Annuale'),
                        price: '€13.99',
                        period: s.t('/mo', '/mese'),
                        selected: _selectedPlan == 1,
                        onTap: () => setState(() => _selectedPlan = 1),
                        badge: s.t('Save 30%', 'Risparmia 30%'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              if (_selectedPlan == 1)
                Center(
                  child: Text(
                    s.t('Billed annually at €167.88 · Cancel anytime',
                        'Fatturato annualmente a €167,88 · Cancella quando vuoi'),
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                )
              else
                Center(
                  child: Text(
                    s.t('Billed monthly · Cancel anytime',
                        'Fatturato mensilmente · Cancella quando vuoi'),
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // ── Pro vs Free table ─────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    // Table header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              s.t('Feature', 'Funzione'),
                              style: GoogleFonts.manrope(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 52,
                            child: Text(
                              'Free',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 52,
                            child: Text(
                              'Pro',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    ..._buildFeatureRows(s),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Trial CTA ─────────────────────────────────────────────────
              PremiumButton(
                label: s.t('Start 7-day free trial', 'Inizia 7 giorni gratis'),
                icon: Icons.card_giftcard_rounded,
                onTap: _startTrial,
                height: 58,
                fontSize: 17,
              ),

              const SizedBox(height: 10),

              // ── Trial info ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      color: AppColors.textSecondary, size: 13),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      s.t(
                        'No charge for 7 days. Cancel before trial ends and you pay nothing.',
                        'Nessun addebito per 7 giorni. Cancella prima della scadenza e non paghi nulla.',
                      ),
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── What happens step by step ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t('HOW THE TRIAL WORKS', 'COME FUNZIONA LA PROVA'),
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _TrialStep(
                      step: '1',
                      title: s.t('Today — trial starts', 'Oggi — la prova inizia'),
                      subtitle: s.t(
                        'Enter your card. No charge made yet.',
                        'Inserisci la tua carta. Nessun addebito ora.',
                      ),
                      color: AppColors.accent,
                    ),
                    _TrialStep(
                      step: '2',
                      title: s.t('Days 1–7 — full Pro access', 'Giorni 1–7 — accesso Pro completo'),
                      subtitle: s.t(
                        'Use every Pro feature. Cancel at any time.',
                        'Usa tutte le funzioni Pro. Cancella in qualsiasi momento.',
                      ),
                      color: AppColors.accent,
                    ),
                    _TrialStep(
                      step: '3',
                      title: s.t(
                        'Day 8 — billing starts',
                        'Giorno 8 — inizia la fatturazione',
                      ),
                      subtitle: s.t(
                        'Only if you keep the subscription.',
                        'Solo se mantieni l\'abbonamento.',
                      ),
                      color: AppColors.textSecondary,
                      isLast: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Already have an account link ──────────────────────────────
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/auth'),
                  child: Text.rich(
                    TextSpan(
                      text: s.t('Already have an account? ', 'Hai già un account? '),
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: s.t('Sign in', 'Accedi'),
                          style: GoogleFonts.manrope(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
  }

  List<Widget> _buildFeatureRows(AppStrings s) {
    final rows = [
      (s.t('Killswitch', 'Killswitch'), true, true),
      (s.t('Manual rule setup', 'Regole manuali'), true, true),
      (s.t('2 unlock tokens/week', '2 token sblocco/settimana'), true, true),
      (s.t('2 unlock tokens/week (fixed)', '2 token sblocco/sett. (fissi)'), true, true),
      (s.t('AI Planner for challenges', 'AI Planner per challenge'), false, true),
      (s.t('MT5 EA integration', 'Integrazione EA MT5'), false, true),
      (s.t('Pre-session check-in', 'Check-in pre-sessione'), false, true),
      (s.t('FOMO Gatekeeper alerts', 'Alert Gatekeeper FOMO'), false, true),
      (s.t('Advanced statistics', 'Statistiche avanzate'), false, true),
      (s.t('Trade Journal + AI insights', 'Diario + AI insights'), false, true),
      (s.t('1-year history', 'Storico 1 anno'), false, true),
    ];

    return rows.asMap().entries.map((entry) {
      final i = entry.key;
      final r = entry.value;
      final isLast = i == rows.length - 1;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    r.$1,
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Center(
                    child: Icon(
                      r.$2 ? Icons.check_rounded : Icons.remove_rounded,
                      color: r.$2 ? AppColors.accent : AppColors.textSecondary.withValues(alpha: 0.4),
                      size: 18,
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Center(
                    child: Icon(
                      r.$3 ? Icons.check_rounded : Icons.remove_rounded,
                      color: r.$3 ? AppColors.accent : AppColors.textSecondary.withValues(alpha: 0.4),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isLast) const Divider(height: 1, color: AppColors.border, indent: 16, endIndent: 16),
        ],
      );
    }).toList();
  }
}

// ── Animated Border Card ──────────────────────────────────────────────────────
class _AnimatedBorderCard extends StatefulWidget {
  final Widget child;
  const _AnimatedBorderCard({required this.child});
  @override
  State<_AnimatedBorderCard> createState() => _AnimatedBorderCardState();
}

class _AnimatedBorderCardState extends State<_AnimatedBorderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: AppTheme.bXl,
          gradient: SweepGradient(
            center: Alignment.center,
            startAngle: _ctrl.value * 2 * math.pi,
            endAngle: _ctrl.value * 2 * math.pi + math.pi * 2,
            colors: const [
              AppColors.accent,
              AppColors.accentDark,
              AppColors.warning,
              AppColors.accent,
            ],
          ),
        ),
        padding: const EdgeInsets.all(1.5),
        child: child,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: AppTheme.bXl,
        ),
        child: widget.child,
      ),
    );
  }
}

// ── Plan tab ──────────────────────────────────────────────────────────────────
class _PlanTab extends StatelessWidget {
  final String label;
  final String price;
  final String period;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  const _PlanTab({
    required this.label,
    required this.price,
    required this.period,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: AppColors.accent.withValues(alpha: 0.6), width: 1.5)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      color: selected ? AppColors.accent : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: AppColors.silverGradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge!,
                        style: GoogleFonts.manrope(
                          color: const Color(0xFF07080D),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: GoogleFonts.manrope(
                      color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      period,
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Registration bottom sheet ─────────────────────────────────────────────────
class _RegistrationSheet extends StatefulWidget {
  final AppStrings s;
  final bool isAnnual;
  const _RegistrationSheet({required this.s, this.isAnnual = true});

  @override
  State<_RegistrationSheet> createState() => _RegistrationSheetState();
}

class _RegistrationSheetState extends State<_RegistrationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscure = true;
  bool _tosAccepted = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await SupabaseService.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushReplacementNamed('/main');
    } catch (e) {
      if (mounted && !e.toString().contains('cancelled')) {
        _showError(widget.s.t(
          'Google Sign In failed. Try again.',
          'Accesso Google fallito. Riprova.',
        ));
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_tosAccepted) return;
    setState(() => _loading = true);
    try {
      final res = await SupabaseService.signUp(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (!mounted) return;
      if (res.user != null) {
        Navigator.of(context).pop();
        Navigator.of(context).pushReplacementNamed('/main');
      } else {
        _showError(widget.s.t(
          'Registration failed. Please try again.',
          'Registrazione fallita. Riprova.',
        ));
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        _showError(widget.s.t(
          'This email is already registered.',
          'Questa email è già registrata.',
        ));
      } else if (msg.contains('password') || msg.contains('weak')) {
        _showError(widget.s.t(
          'Password too short. Use at least 6 characters.',
          'Password troppo corta. Usa almeno 6 caratteri.',
        ));
      } else {
        _showError(widget.s.t(
          'An error occurred. Please try again.',
          'Si è verificato un errore. Riprova.',
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.manrope()),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.s.t('Create your account', 'Crea il tuo account'),
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isAnnual
                  ? widget.s.t(
                      '7 days free, then €13.99/mo (billed annually)',
                      '7 giorni gratis, poi €13.99/mese (annuale)',
                    )
                  : widget.s.t(
                      '7 days free, then €19.99/month',
                      '7 giorni gratis, poi €19.99/mese',
                    ),
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            // Email
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: GoogleFonts.manrope(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: GoogleFonts.manrope(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return widget.s.t('Enter your email', 'Inserisci la tua email');
                }
                if (!v.contains('@')) {
                  return widget.s.t('Invalid email', 'Email non valida');
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            // Password
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              style: GoogleFonts.manrope(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: widget.s.t('Password', 'Password'),
                labelStyle: GoogleFonts.manrope(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return widget.s.t('Enter a password', 'Inserisci una password');
                }
                if (v.length < 6) {
                  return widget.s.t(
                    'Minimum 6 characters',
                    'Minimo 6 caratteri',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // ToS checkbox
            GestureDetector(
              onTap: () => setState(() => _tosAccepted = !_tosAccepted),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _tosAccepted,
                      onChanged: (v) =>
                          setState(() => _tosAccepted = v ?? false),
                      activeColor: AppColors.accent,
                      checkColor: Colors.black,
                      side: BorderSide(
                        color: _tosAccepted
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: GoogleFonts.manrope(
                            color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                        children: [
                          TextSpan(
                            text: widget.s.t(
                              'I have read and accept the ',
                              'Ho letto e accetto i ',
                            ),
                          ),
                          TextSpan(
                            text: widget.s.t('Terms of Service', 'Termini di Servizio'),
                            style: GoogleFonts.manrope(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.accent,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => Navigator.of(context)
                                  .pushNamed('/privacy_policy'),
                          ),
                          TextSpan(
                            text: widget.s.t(' and ', ' e la '),
                          ),
                          TextSpan(
                            text: widget.s.t('Privacy Policy', 'Privacy Policy'),
                            style: GoogleFonts.manrope(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.accent,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => Navigator.of(context)
                                  .pushNamed('/privacy_policy'),
                          ),
                          TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_loading || !_tosAccepted) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        widget.s.t(
                          'Create account and start trial',
                          'Crea account e inizia la prova',
                        ),
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            const OrDivider(),
            // Google Sign Up
            GoogleSignInButton(
              label: widget.s.t('Sign up with Google', 'Registrati con Google'),
              loading: _googleLoading,
              onTap: _signInWithGoogle,
            ),
            const SizedBox(height: 16),
            // Already have account
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed('/auth');
                },
                child: Text.rich(
                  TextSpan(
                    text: widget.s.t(
                      'Already have an account? ',
                      'Hai già un account? ',
                    ),
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: widget.s.t('Sign in', 'Accedi'),
                        style: GoogleFonts.manrope(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trial step ────────────────────────────────────────────────────────────────
class _TrialStep extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final Color color;
  final bool isLast;

  const _TrialStep({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: Text(
                  step,
                  style: GoogleFonts.manrope(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 1,
                height: 32,
                color: AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
