import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../widgets/premium_button.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  // Rate limiting: one reset request per 60 seconds
  static DateTime? _lastResetAttempt;
  static const _resetCooldown = Duration(seconds: 60);

  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic),
    );
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset(AppStrings s) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage(s.forgotPasswordErrEmail, isError: true);
      return;
    }
    // Rate limit: max one request per 60 seconds
    final now = DateTime.now();
    if (_lastResetAttempt != null &&
        now.difference(_lastResetAttempt!) < _resetCooldown) {
      final remaining =
          _resetCooldown.inSeconds - now.difference(_lastResetAttempt!).inSeconds;
      _showMessage(
        s.t('Please wait $remaining seconds before requesting another reset.',
            'Attendi $remaining secondi prima di richiedere un altro reset.'),
        isError: true,
      );
      return;
    }
    _lastResetAttempt = now;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'piplock://auth-callback',
      );
      if (mounted) {
        _showMessage(s.forgotPasswordSuccess);
        _emailController.clear();
      }
    } catch (e) {
      if (mounted) {
        _showMessage(s.forgotPasswordError, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope()),
        backgroundColor: isError ? AppColors.danger : AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background blob top-right
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Background blob bottom-left
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Inline back button
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: AppColors.textPrimary, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.pagePadding, 16, AppTheme.pagePadding, 32),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            // Icon
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.accent.withValues(alpha: 0.28),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent.withValues(alpha: 0.18),
                                    blurRadius: 28,
                                    spreadRadius: -4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.lock_reset_outlined,
                                color: AppColors.accent,
                                size: 38,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              s.forgotPasswordHeading,
                              style: GoogleFonts.manrope(
                                color: AppColors.textPrimary,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.5,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              s.forgotPasswordBody,
                              style: GoogleFonts.manrope(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 32),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.manrope(
                                  color: AppColors.textPrimary, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Email',
                                hintStyle: GoogleFonts.manrope(
                                    color: AppColors.textTertiary, fontSize: 15),
                                prefixIcon: const Icon(Icons.mail_outline,
                                    color: AppColors.textSecondary, size: 20),
                                filled: true,
                                fillColor: AppColors.cardBg,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: AppColors.accent, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            PremiumButton(
                              label: s.forgotPasswordSend,
                              icon: Icons.send_rounded,
                              loading: _isLoading,
                              onTap: _isLoading ? null : () => _sendReset(s),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
