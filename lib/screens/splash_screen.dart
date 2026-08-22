import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../config/constants.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late final Future<void> _minDelay;
  bool _navigated = false;
  bool _delayDone = false;

  @override
  void initState() {
    super.initState();
    _minDelay = Future.delayed(const Duration(milliseconds: 2600));

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.80, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();

    if (kDevMode) {
      _minDelay.then((_) => _navigate());
      return;
    }

    _minDelay.then((_) {
      if (!mounted) return;
      _delayDone = true;
      // Se auth è già risolto (es. dopo logout), naviga subito.
      // Altrimenti il ref.listen nel build() chiamerà _navigate quando arriva.
      final auth = ref.read(authProvider);
      if (!auth.isLoading) _navigate();
    });
  }

  void _navigate() async {
    if (!mounted || _navigated) return;
    _navigated = true;
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_completed') ?? false;
    final auth = ref.read(authProvider);
    if (!mounted) return;
    if (!onboardingDone) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    } else if (auth.isLoggedIn) {
      Navigator.of(context).pushReplacementNamed('/main');
    } else {
      Navigator.of(context).pushReplacementNamed('/paywall');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDevMode) {
      // Ascolta cambiamenti auth: se il delay è già passato, naviga subito.
      // Copre il caso normale (app avviata da zero, auth risolve dopo il delay).
      ref.listen<AuthState>(authProvider, (_, AuthState next) {
        if (!next.isLoading && _delayDone) {
          _navigate();
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow diffuso attorno all'icona
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.25),
                        blurRadius: 80,
                        spreadRadius: 30,
                      ),
                    ],
                  ),
                ),
                Image.asset(
                  'assets/images/Icona PipLock.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

