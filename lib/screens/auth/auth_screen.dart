import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/ambient_blobs.dart';
import '../../widgets/google_sign_in_button.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<Offset> _slidAnim;
  late final Animation<double> _fadeAnim;

  // Login controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscure = true;
  bool _loginLoading = false;
  bool _loginHasError = false;
  bool _googleLoading = false;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slidAnim = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await SupabaseService.signInWithGoogle();
      // authProvider listener handles navigation
    } catch (e) {
      if (mounted && !e.toString().contains('cancelled')) {
        _showError('Google Sign In failed. Try again.');
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _login(AppStrings s) async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;
    if (email.isEmpty || password.isEmpty) {
      _triggerLoginShake();
      _showError(s.authErrEmailPassword);
      return;
    }
    setState(() => _loginLoading = true);
    try {
      await SupabaseService.signIn(email, password);
      // Auth state change handled by authProvider listener — no manual nav needed
    } catch (e) {
      if (mounted) {
        _triggerLoginShake();
        _showError(_friendlyError(e.toString(), s));
      }
    } finally {
      if (mounted) setState(() => _loginLoading = false);
    }
  }

  void _triggerLoginShake() {
    setState(() => _loginHasError = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _loginHasError = false);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope()),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _friendlyError(String raw, AppStrings s) {
    if (raw.contains('Invalid login credentials') ||
        raw.contains('invalid_credentials')) {
      return s.t('Wrong email or password.', 'Email o password errati.');
    }
    if (raw.contains('User already registered') ||
        raw.contains('already been registered')) {
      return s.t('This email is already registered. Try signing in.', 'Questa email è già registrata. Prova ad accedere.');
    }
    if (raw.contains('Email not confirmed') || raw.contains('email_not_confirmed')) {
      return s.t('Check your inbox and click the confirmation link before signing in.', 'Controlla la tua email e clicca il link di conferma prima di accedere.');
    }
    if (raw.contains('network') || raw.contains('SocketException')) {
      return s.t('Connection error. Check your network.', 'Errore di connessione. Controlla la tua rete.');
    }
    if (raw.contains('email') && raw.contains('rate')) {
      return s.t('Too many requests. Wait a moment and try again.', 'Troppe richieste. Attendi qualche minuto e riprova.');
    }
    if (raw.contains('Please wait before trying again') ||
        raw.contains('Too many failed attempts')) {
      return raw; // already user-friendly from rate limiter
    }
    // Generic fallback — never expose raw server errors or internal details
    return s.t('Something went wrong. Please try again.', 'Qualcosa è andato storto. Riprova.');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);

    // Navigate to /main as soon as the user is authenticated
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.isLoggedIn && mounted) {
        Navigator.of(context).pushReplacementNamed('/main');
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Animated ambient blobs
          const Positioned.fill(child: IgnorePointer(child: AmbientBlobs())),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 52),
                  // Animated logo/title
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slidAnim,
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.22),
                                  blurRadius: 40,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/Icona PipLock.png',
                              width: 76,
                              height: 76,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'PipLock AI',
                            style: GoogleFonts.manrope(
                              color: AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.authTagline,
                            style: GoogleFonts.manrope(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Login form
                  _ShakeWidget(
                    shake: _loginHasError,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _loginEmailController,
                          hint: 'Email',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _loginPasswordController,
                          hint: 'Password',
                          icon: Icons.lock_outline,
                          obscureText: _loginObscure,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _loginObscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _loginObscure = !_loginObscure),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _loginLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                            strokeWidth: 2.5,
                          ),
                        )
                      : PremiumButton(
                          label: s.authSignIn,
                          onTap: () => _login(s),
                        ),
                  const OrDivider(),
                  GoogleSignInButton(
                    label: 'Continue with Google',
                    loading: _googleLoading,
                    onTap: _loginWithGoogle,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/forgot_password'),
                      child: Text(
                        s.authForgotPassword,
                        style: GoogleFonts.manrope(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Sign up link
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/paywall'),
                      child: Text.rich(
                        TextSpan(
                          text: s.t(
                            "Don't have an account? ",
                            "Non hai un account? ",
                          ),
                          style: GoogleFonts.manrope(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          children: [
                            TextSpan(
                              text: s.t(
                                'Start free trial',
                                'Inizia la prova gratuita',
                              ),
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
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.manrope(
        color: AppColors.textPrimary,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(
          color: AppColors.textTertiary,
          fontSize: 15,
        ),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ── ShakeWidget ───────────────────────────────────────────────────────────────

class _ShakeWidget extends StatefulWidget {
  final Widget child;
  final bool shake;
  const _ShakeWidget({required this.child, required this.shake});

  @override
  State<_ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<_ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _anim = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: const Offset(0.02, 0)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(
              begin: const Offset(0.02, 0), end: const Offset(-0.02, 0)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(
              begin: const Offset(-0.02, 0), end: const Offset(0.02, 0)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(0.02, 0), end: Offset.zero),
          weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_ShakeWidget old) {
    super.didUpdateWidget(old);
    if (widget.shake && !old.shake) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SlideTransition(position: _anim, child: widget.child);
}
