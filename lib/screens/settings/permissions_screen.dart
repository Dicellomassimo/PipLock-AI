import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../services/accessibility_service.dart';
import '../../services/notification_service.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
    with WidgetsBindingObserver {
  int _refreshKey = 0;

  static const _kPermAccessibility = 'perm_accessibility_granted';
  static const _kPermOverlay       = 'perm_overlay_granted';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsOnResume();
      setState(() => _refreshKey++);
    }
  }

  Future<bool> _canChangePermissions() async {
    final prefs = await SharedPreferences.getInstance();

    // Check 1: se killswitch è attivo, blocca
    final ksActive = prefs.getBool('killswitch_active') ?? false;
    if (ksActive) return false;

    // Check 2: se già revocato oggi, blocca
    final lastRevokeStr = prefs.getString('perm_last_revoke_date');
    if (lastRevokeStr != null) {
      final lastRevoke = DateTime.tryParse(lastRevokeStr);
      if (lastRevoke != null) {
        final today = DateTime.now();
        if (lastRevoke.year == today.year &&
            lastRevoke.month == today.month &&
            lastRevoke.day == today.day) {
          return false;
        }
      }
    }
    return true;
  }

  void _showPermissionLockedDialog() {
    final s = ref.read(appStringsProvider);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: AppColors.warning, size: 22),
            const SizedBox(width: 10),
            Text(
              s.t('Permission Locked', 'Permesso Bloccato'),
              style: GoogleFonts.manrope(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          s.t(
            'You cannot change permissions while a Killswitch is active, or more than once per day. This protects your trading rules.',
            'Non puoi modificare i permessi durante un Killswitch attivo, o più di una volta al giorno. Questo protegge le tue regole di trading.',
          ),
          style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(s.t('OK', 'OK'), style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPermissionsOnResume() async {
    final prefs = await SharedPreferences.getInstance();
    final wasAccessibilityGranted = prefs.getBool(_kPermAccessibility) ?? false;
    final wasOverlayGranted = prefs.getBool(_kPermOverlay) ?? false;

    final isAccessibilityNowEnabled = await AccessibilityService.isEnabled();
    final isOverlayNowEnabled = await AccessibilityService.canDrawOverlays();

    if (wasAccessibilityGranted && !isAccessibilityNowEnabled) {
      await prefs.setBool(_kPermAccessibility, false);
      await prefs.setString('perm_last_revoke_date', DateTime.now().toIso8601String());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'Accessibility permission was revoked. Killswitch protection is disabled.'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 5),
        ));
      }
    }
    if (wasOverlayGranted && !isOverlayNowEnabled) {
      await prefs.setBool(_kPermOverlay, false);
      await prefs.setString('perm_last_revoke_date', DateTime.now().toIso8601String());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'Overlay permission was revoked. Killswitch block screen is disabled.'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  void _showAccessibilityExplanation(BuildContext context, AppStrings s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.accessibility_new, color: AppColors.fomo, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.t('Accessibility Permission', 'Permesso Accessibilità'),
                style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.t('Why PipLock needs this permission:',
                  'Perché PipLock ha bisogno di questo permesso:'),
              style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
            const SizedBox(height: 10),
            _bulletPoint(s.t(
              '✓  Detects when you open your broker app (MT5, MT4, etc.)',
              '✓  Rileva quando apri l\'app del tuo broker (MT5, MT4, ecc.)',
            )),
            _bulletPoint(s.t(
              '✓  Enforces the Killswitch block if your trading limits are reached',
              '✓  Applica il blocco Killswitch se raggiungi i tuoi limiti di trading',
            )),
            _bulletPoint(s.t(
              '✗  Does NOT read passwords, messages or any content from other apps',
              '✗  NON legge password, messaggi o contenuti di altre app',
            )),
            _bulletPoint(s.t(
              '✗  Does NOT take screenshots or record your screen',
              '✗  NON acquisisce screenshot né registra lo schermo',
            )),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.fomo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.fomo.withValues(alpha: 0.2)),
              ),
              child: Text(
                s.t(
                  'In the next screen, find "PipLock AI" in the list and enable the toggle.',
                  'Nella schermata successiva, cerca "PipLock AI" nell\'elenco e abilita l\'interruttore.',
                ),
                style: GoogleFonts.manrope(
                    color: AppColors.fomo, fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.t('Cancel', 'Annulla'),
                style:
                    GoogleFonts.manrope(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final canChange = await _canChangePermissions();
              if (!canChange) {
                if (mounted) _showPermissionLockedDialog();
                return;
              }
              AccessibilityService.openSettings();
              SharedPreferences.getInstance().then(
                  (p) => p.setBool(_kPermAccessibility, true));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(s.t('Open Settings', 'Apri Impostazioni'),
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.manrope(
            color: AppColors.textSecondary, fontSize: 12, height: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          s.permissionsTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PermissionCard(
            refreshKey: _refreshKey,
            title: s.permissionsAccessibilityTitle,
            description: s.t(
              'Allows PipLock to detect when you open your broker app on this device. It never reads passwords or content from other apps.',
              'Permette a PipLock di rilevare quando apri l\'app del tuo broker su questo dispositivo. Non legge password o contenuti delle altre app.',
            ),
            statusFuture: AccessibilityService.isEnabled(),
            activeLabel: s.permissionsAccessibilityActive,
            inactiveLabel: s.permissionsAccessibilityInactive,
            actionButton: ElevatedButton.icon(
              onPressed: () => _showAccessibilityExplanation(context, s),
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: Text(
                s.permissionsGoToSettings,
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            checkingLabel: s.permissionsChecking,
          ),
          const SizedBox(height: 16),
          _OverlayPermissionCard(refreshKey: _refreshKey, s: s, onOpenSettings: () async {
            final canChange = await _canChangePermissions();
            if (!canChange) {
              if (mounted) _showPermissionLockedDialog();
              return;
            }
            AccessibilityService.requestOverlayPermission();
            SharedPreferences.getInstance().then(
                (p) => p.setBool('perm_overlay_granted', true));
          }),
          const SizedBox(height: 16),
          _FcmPermissionCard(refreshKey: _refreshKey, s: s),
          const SizedBox(height: 16),
          _StaticPermissionCard(
            title: s.permissionsInternet,
            icon: Icons.wifi,
            iconColor: AppColors.accent,
            statusWidget: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  s.permissionsActive,
                  style: GoogleFonts.manrope(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            description: s.permissionsInternetSubtitle,
            actionButton: null,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _refreshKey++),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(
                s.permissionsRefreshStatus,
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final int refreshKey;
  final String title;
  final String description;
  final Future<bool> statusFuture;
  final String activeLabel;
  final String inactiveLabel;
  final String checkingLabel;
  final Widget actionButton;

  const _PermissionCard({
    required this.refreshKey,
    required this.title,
    required this.description,
    required this.statusFuture,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.checkingLabel,
    required this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.fomo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.accessibility_new,
                    color: AppColors.fomo, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<bool>(
            key: ValueKey(refreshKey),
            future: statusFuture,
            builder: (context, snapshot) {
              final isEnabled = snapshot.data ?? false;
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;
              if (isLoading) {
                return Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent),
                    ),
                    const SizedBox(width: 8),
                    Text(checkingLabel,
                        style: GoogleFonts.manrope(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                );
              }
              return Row(
                children: [
                  Icon(
                    isEnabled ? Icons.check_circle : Icons.cancel,
                    color: isEnabled ? AppColors.accent : AppColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEnabled ? activeLabel : inactiveLabel,
                      style: GoogleFonts.manrope(
                        color: isEnabled ? AppColors.accent : AppColors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(description,
              style: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 14),
          actionButton,
        ],
      ),
    );
  }
}

class _OverlayPermissionCard extends StatelessWidget {
  final int refreshKey;
  final AppStrings s;
  final VoidCallback onOpenSettings;
  const _OverlayPermissionCard({required this.refreshKey, required this.s, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.layers_outlined,
                    color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.t('Display over other apps', 'Visualizza sopra altre app'),
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<bool>(
            key: ValueKey(refreshKey),
            future: AccessibilityService.canDrawOverlays(),
            builder: (context, snapshot) {
              final isEnabled = snapshot.data ?? false;
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;
              if (isLoading) {
                return Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent),
                    ),
                    const SizedBox(width: 8),
                    Text(s.permissionsChecking,
                        style: GoogleFonts.manrope(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                );
              }
              return Row(
                children: [
                  Icon(
                    isEnabled ? Icons.check_circle : Icons.cancel,
                    color: isEnabled ? AppColors.accent : AppColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEnabled
                          ? s.t('Active — overlay enabled', 'Attivo — overlay abilitato')
                          : s.t('Required for Killswitch overlay', 'Richiesto per l\'overlay Killswitch'),
                      style: GoogleFonts.manrope(
                        color: isEnabled ? AppColors.accent : AppColors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            s.t(
              'Allows PipLock to show the WARNING and LOCKDOWN panels directly above your broker app when limits are exceeded. Required for Screen Reading connection.',
              'Permette a PipLock di mostrare i pannelli AVVISO e BLOCCO direttamente sopra l\'app broker quando si superano i limiti. Richiesto per la connessione via Lettura Schermo.',
            ),
            style: GoogleFonts.manrope(
                color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(
              s.permissionsGoToSettings,
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FcmPermissionCard extends StatelessWidget {
  final int refreshKey;
  final AppStrings s;
  const _FcmPermissionCard({required this.refreshKey, required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_outlined,
                    color: Color(0xFF4A90E2), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                s.permissionsPushTitle,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<String?>(
            key: ValueKey(refreshKey),
            future: NotificationService.getToken(),
            builder: (context, snapshot) {
              final isActive = snapshot.data != null;
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;
              if (isLoading) {
                return Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent),
                    ),
                    const SizedBox(width: 8),
                    Text(s.permissionsChecking,
                        style: GoogleFonts.manrope(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isActive ? Icons.check_circle : Icons.cancel,
                        color: isActive ? AppColors.accent : AppColors.danger,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isActive
                              ? s.permissionsPushActive
                              : s.permissionsPushInactive,
                          style: GoogleFonts.manrope(
                            color: isActive ? AppColors.accent : AppColors.danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(s.permissionsPushSubtitle,
                      style: GoogleFonts.manrope(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 14),
                  if (isActive)
                    ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppColors.accent.withValues(alpha: 0.15),
                        foregroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(s.permissionsWorking,
                          style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600)),
                    )
                  else
                    ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.divider,
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(s.permissionsCheckFirebase,
                          style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StaticPermissionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget statusWidget;
  final String description;
  final Widget? actionButton;

  const _StaticPermissionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.statusWidget,
    required this.description,
    this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          statusWidget,
          const SizedBox(height: 10),
          Text(description,
              style: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 12)),
          if (actionButton != null) ...[
            const SizedBox(height: 14),
            actionButton!,
          ],
        ],
      ),
    );
  }
}
