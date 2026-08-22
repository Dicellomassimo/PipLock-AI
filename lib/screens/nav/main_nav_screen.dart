import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/broker_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../providers/token_provider.dart';
import '../../services/accessibility_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../ai_planner/ai_planner_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';

class MainNavScreen extends ConsumerStatefulWidget {
  const MainNavScreen({super.key});

  @override
  ConsumerState<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends ConsumerState<MainNavScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

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
    });
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

    // Il killswitch NON blocca PipLock — mostra solo un banner nella dashboard.
    // L'overlay di blocco viene applicato sull'app broker via AccessibilityService.

    ref.listen<String?>(pendingNavigationProvider, (_, route) {
      if (route != null && mounted) {
        Navigator.of(context).pushNamed(route);
        ref.read(pendingNavigationProvider.notifier).state = null;
      }
    });

    // Sync token count to native SharedPreferences every time it changes,
    // so the Kotlin killswitch overlay can check it without calling Flutter.
    ref.listen<AsyncValue<int>>(tokenRealtimeProvider, (_, next) {
      next.whenData((count) => AccessibilityService.syncTokenCount(count));
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _FadedIndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: _PremiumNavBar(
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

// ── Premium Navigation Bar ───────────────────────────────────────────────────

class _PremiumNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItemData> items;
  final AppStrings strings;
  final ValueChanged<int> onTap;

  const _PremiumNavBar({
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.4), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(left: 8, right: 8, top: 10, bottom: 10 + bottom),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) => _NavItem(
            item: items[i],
            label: _label(i, strings),
            selected: currentIndex == i,
            onTap: () => onTap(i),
          )),
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
            horizontal: selected ? 16 : 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: AppTheme.bMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: AppTheme.dFast,
                child: Icon(
                  selected ? widget.item.selectedIcon : widget.item.icon,
                  key: ValueKey(selected),
                  color: selected ? AppColors.accent : AppColors.textTertiary,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              // Dot indicator — solo quando selected
              AnimatedContainer(
                duration: AppTheme.dMedium,
                curve: AppTheme.cSpring,
                width: selected ? 16 : 4,
                height: 3,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: selected
                      ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.6), blurRadius: 6)]
                      : null,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: AppTheme.dFast,
                style: GoogleFonts.manrope(
                  color: selected ? AppColors.accent : AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: selected ? -0.1 : 0,
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
