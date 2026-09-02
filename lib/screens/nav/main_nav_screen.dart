import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/broker_provider.dart';
import '../../providers/challenge_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../providers/token_provider.dart';
import '../../services/accessibility_service.dart';
import '../../services/ai_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../ai_planner/ai_planner_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rules_provider.dart';

class MainNavScreen extends ConsumerStatefulWidget {
  const MainNavScreen({super.key});

  @override
  ConsumerState<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends ConsumerState<MainNavScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  DateTime? _lastResumeRefresh;
  static const List<Widget> _pages = [
    DashboardScreen(),
    AiPlannerScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  static const _navItems = [
    _NavItemData(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
    _NavItemData(icon: Icons.auto_awesome_outlined, selectedIcon: Icons.auto_awesome, label: 'AI'),
    _NavItemData(icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart_rounded, label: 'History'),
    _NavItemData(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int && args >= 0 && args < _pages.length) {
        setState(() {
          _currentIndex = args;
        });
      }
      try {
        ref.read(accessibilityWatcherProvider);
        ref.read(realtimeProvider);
        ref.read(brokerProvider);
      } catch (_) {}
      // Load challenges on startup (provider auto-loads via auth listener,
      // but trigger here too in case auth was already ready before provider init)
      final userId = ref.read(currentUserIdProvider);
      if (userId.isNotEmpty) {
        unawaited(ref.read(challengeListProvider.notifier).load(userId));
      }

      // Schedule economic calendar notifications after 4s — by this point
      // the user is on the main screen and the network stack is fully ready.
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) unawaited(NotificationService.scheduleUpcomingNotifications());
      });

      // Pre-populate native SharedPreferences with rules for ALL registered accounts
      // (personal + challenge) so the Kotlin Accessibility Service can apply the
      // correct limits immediately on account switch, even with Flutter in background.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          unawaited(ref.read(brokerProvider.notifier).syncAllAccountsToNative());
        }
      });
      // Recalculate dynamic plan on first load (also fires on resume via lifecycle observer)
      unawaited(_checkDynamicPlan());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ricalcola dinamicamente il piano challenge se non già fatto oggi.
  Future<void> _checkDynamicPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRecalc = prefs.getString('plan_last_recalc');
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (lastRecalc == today) return; // già ricalcolato oggi

      final challenges = ref.read(challengeListProvider);
      final active = challenges.where((c) => c.status == 'active').toList();
      if (active.isEmpty || active.first.aiPlan == null) return;
      final activeChallenge = active.first;

      // Leggi P&L attuale da broker
      final brokerState = ref.read(brokerProvider);
      final currentPnl = brokerState.dailyPnl ?? 0.0;
      final accountSize = activeChallenge.accountSize;
      if (accountSize <= 0) return;

      final daysElapsed = DateTime.now().difference(activeChallenge.startedAt).inDays;
      final newPlan = await AiService.recalculatePlan(
        originalPlan: activeChallenge.aiPlan!,
        currentProfitPct: (currentPnl / accountSize) * 100,
        targetProfitPct: activeChallenge.profitTarget,
        daysElapsed: daysElapsed,
        totalDays: activeChallenge.durationDays,
        maxDailyLossPct: activeChallenge.maxDailyLoss,
        style: activeChallenge.style,
      );

      if (newPlan != null && mounted) {
        await SupabaseService.updateChallengePlan(activeChallenge.id, newPlan);
        await prefs.setString('plan_last_recalc', today);
        debugPrint('[DynamicPlan] Plan recalculated for challenge ${activeChallenge.id}');
      }
    } catch (e) {
      debugPrint('[DynamicPlan] _checkDynamicPlan error: $e');
    }
  }

  /// Called automatically when the app comes back to foreground.
  /// Refreshes data providers and notifications, throttled to once per 5 minutes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_checkDynamicPlan());

    final now = DateTime.now();
    if (_lastResumeRefresh != null &&
        now.difference(_lastResumeRefresh!) < const Duration(minutes: 5)) {
      return; // skip — refreshed recently
    }
    _lastResumeRefresh = now;

    // Reload rules and challenges from Supabase (both use file cache so won't spam API)
    try { ref.read(rulesProvider.notifier).reload(); } catch (_) {}
    final userId = ref.read(currentUserIdProvider);
    if (userId.isNotEmpty) {
      try { ref.read(challengeListProvider.notifier).load(userId); } catch (_) {}
    }

    unawaited(NotificationService.refresh());
  }

  void _onTap(int i) {
    if (i == _currentIndex) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentIndex = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);

    ref.listen<String?>(pendingNavigationProvider, (_, route) {
      if (route != null && mounted) {
        Navigator.of(context).pushNamed(route);
        ref.read(pendingNavigationProvider.notifier).state = null;
      }
    });

    ref.listen<int?>(pendingTabIndexProvider, (_, idx) {
      if (idx != null && mounted) {
        setState(() => _currentIndex = idx.clamp(0, _pages.length - 1));
        ref.read(pendingTabIndexProvider.notifier).state = null;
      }
    });

    ref.listen<AsyncValue<int>>(tokenRealtimeProvider, (_, next) {
      next.whenData((count) => AccessibilityService.syncTokenCount(count));
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true, // il body va sotto la nav bar floating
        body: _FadedIndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: _FloatingNavBar(
          currentIndex: _currentIndex,
          items: _navItems,
          strings: s,
          onTap: _onTap,
        ),
      ),
    );
  }
}

/// IndexedStack con cross-fade tra tab
class _FadedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const _FadedIndexedStack({required this.index, required this.children});

  @override
  State<_FadedIndexedStack> createState() => _FadedIndexedStackState();
}

class _FadedIndexedStackState extends State<_FadedIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  int _visibleIndex = 0;

  @override
  void initState() {
    super.initState();
    _visibleIndex = widget.index;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 140));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_FadedIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _ctrl.reverse().then((_) {
        if (mounted) {
          setState(() => _visibleIndex = widget.index);
          _ctrl.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: IndexedStack(index: _visibleIndex, children: widget.children),
    );
  }
}

// ── Data ────────────────────────────────────────────────────────────────────

class _NavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItemData({required this.icon, required this.selectedIcon, required this.label});
}

// ── Floating Pill Navigation Bar ─────────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItemData> items;
  final AppStrings strings;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.items,
    required this.strings,
    required this.onTap,
  });

  String _label(int i, AppStrings s) {
    switch (i) {
      case 0: return s.navHome;
      case 1: return s.navAiPlanner;
      case 2: return s.navHistory;
      case 3: return s.navProfile;
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      // Trasparente — il contenuto visivo è nella pill interna
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(AppTheme.radius2xl),
              border: Border.all(
                color: AppColors.glassBorderStrong,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                items.length,
                (i) => _NavItem(
                  item: items[i],
                  label: _label(i, strings),
                  selected: currentIndex == i,
                  onTap: () => onTap(i),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final _NavItemData item;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    // Colori silver: attivo = silver chrome, inattivo = dim
    final activeColor = AppColors.accent;      // silver chrome
    final inactiveColor = AppColors.textTertiary;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: AnimatedContainer(
          duration: AppTheme.dMedium,
          curve: AppTheme.cSpring,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 18 : 14,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            // Pill highlight per item attivo — silver con bassa opacità
            color: selected
                ? AppColors.accent.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            // Micro-border silver sull'item attivo
            border: selected
                ? Border.all(
                    color: AppColors.accent.withValues(alpha: 0.18),
                    width: 0.5,
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icona con glow silver quando attiva
              AnimatedSwitcher(
                duration: AppTheme.dFast,
                child: selected
                    ? ShaderMask(
                        key: const ValueKey('selected'),
                        shaderCallback: (bounds) => AppColors.silverGradient.createShader(bounds),
                        blendMode: BlendMode.srcIn,
                        child: Icon(widget.item.selectedIcon, size: 22, color: Colors.white),
                      )
                    : Icon(
                        key: const ValueKey('unselected'),
                        widget.item.icon,
                        color: inactiveColor,
                        size: 22,
                      ),
              ),
              const SizedBox(height: 4),
              // Label
              AnimatedDefaultTextStyle(
                duration: AppTheme.dFast,
                style: GoogleFonts.manrope(
                  color: selected ? activeColor : inactiveColor,
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: selected ? 0.2 : 0,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle navLabelStyle({required bool selected}) {
  return GoogleFonts.manrope(
    color: selected ? AppColors.accent : AppColors.textSecondary,
    fontSize: 10,
    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
  );
}
