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
    _minDelay = Future.delayed(Duration.zero);

    _ctrl = AnimationController(vsync: this, duration: Duration.zero);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.linear);
    _scale = Tween<double>(begin: 1.0, end: 1.0).animate(_ctrl);

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

    // Timeout di sicurezza: se auth non si risolve entro 8s, naviga comunque.
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && !_navigated) _navigate();
    });
  }

  void _navigate() async {
    if (!mounted || _navigated) return;
    _navigated = true;
    // DEV: mostra sempre l'onboarding per poterlo testare
    if (kDevMode) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
      return;
    }
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

    return const Scaffold(
      backgroundColor: AppColors.background,
      body: SizedBox.shrink(),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

