import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/notification_service.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _newsAlerts = true;
  bool _sessionChanges = true;
  bool _riskWarnings = true;
  bool _fomoAlerts = true;
  bool _challengeReminders = true;
  bool _allEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final userId = SupabaseService.currentUserId ?? '';
    if (userId.isNotEmpty) {
      try {
        final data = await SupabaseService.getNotificationPrefs(userId);
        if (data != null && mounted) {
          setState(() {
            _newsAlerts = data['news_alerts'] as bool? ?? true;
            _sessionChanges = data['session_changes'] as bool? ?? true;
            _riskWarnings = data['risk_warnings'] as bool? ?? true;
            _fomoAlerts = data['fomo_alerts'] as bool? ?? true;
            _challengeReminders =
                data['challenge_reminders'] as bool? ?? true;
            _allEnabled = _newsAlerts &&
                _sessionChanges &&
                _riskWarnings &&
                _fomoAlerts &&
                _challengeReminders;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _savePrefs() async {
    final userId = SupabaseService.currentUserId ?? '';
    if (userId.isNotEmpty) {
      try {
        await SupabaseService.saveNotificationPrefs(userId, {
          'news_alerts': _newsAlerts,
          'session_changes': _sessionChanges,
          'risk_warnings': _riskWarnings,
          'fomo_alerts': _fomoAlerts,
          'challenge_reminders': _challengeReminders,
        });
        // Refresh the in-memory cache so new prefs take effect immediately,
        // then re-schedule (or cancel) calendar notifications accordingly.
        await NotificationService.refreshPrefsCache();
        NotificationService.scheduleUpcomingNotifications();
      } catch (_) {}
    }
  }

  void _toggleAll(bool value) {
    setState(() {
      _allEnabled = value;
      _newsAlerts = value;
      _sessionChanges = value;
      _riskWarnings = value;
      _fomoAlerts = value;
      _challengeReminders = value;
    });
    _savePrefs();
  }

  void _updateAll() {
    final all = _newsAlerts &&
        _sessionChanges &&
        _riskWarnings &&
        _fomoAlerts &&
        _challengeReminders;
    setState(() => _allEnabled = all);
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
          s.notifSettingsTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AnimatedContainer(
            duration: AppTheme.dMedium,
            curve: AppTheme.cSpring,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: _allEnabled
                  ? LinearGradient(colors: [
                      AppColors.accent.withValues(alpha: 0.12),
                      AppColors.accent.withValues(alpha: 0.04),
                    ])
                  : null,
              color: _allEnabled ? null : AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _allEnabled ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border,
                width: _allEnabled ? 1.5 : 1,
              ),
              boxShadow: _allEnabled ? [BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.12),
                blurRadius: 16, offset: const Offset(0, 4),
              )] : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: _allEnabled ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_active_rounded,
                    color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.notifSettingsEnableAll, style: GoogleFonts.manrope(
                        color: AppColors.textPrimary, fontSize: 15,
                        fontWeight: FontWeight.w700)),
                      Text(s.notifSettingsManageAll, style: GoogleFonts.manrope(
                        color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: _allEnabled,
                  onChanged: _toggleAll,
                  thumbColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected) ? Colors.black : null),
                  trackColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected) ? AppColors.accent : null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 8),
          Text(
            s.notifSettingsCategories,
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _notifTile(
            icon: Icons.newspaper_outlined,
            color: const Color(0xFF4A90E2),
            title: s.notifSettingsNewsTitle,
            subtitle: s.t(
              'NFP, CPI, central bank decisions and other macro data',
              'NFP, CPI, decisioni banche centrali e altri dati macro',
            ),
            value: _newsAlerts,
            onChanged: (v) {
              setState(() => _newsAlerts = v);
              _updateAll();
              _savePrefs();
            },
          ),
          _notifTile(
            icon: Icons.schedule_outlined,
            color: AppColors.accent,
            title: s.notifSettingsSessionTitle,
            subtitle: s.t(
              'Opening and closing of London, NY and Asia sessions',
              'Apertura e chiusura sessioni di Londra, NY e Asia',
            ),
            value: _sessionChanges,
            onChanged: (v) {
              setState(() => _sessionChanges = v);
              _updateAll();
              _savePrefs();
            },
          ),
          _notifTile(
            icon: Icons.warning_amber_rounded,
            color: AppColors.warning,
            title: s.notifSettingsRiskTitle,
            subtitle: s.t(
              "Alert when you're at 80% of the daily limit — before the Killswitch",
              "Alert quando sei all'80% del limite giornaliero — prima del Killswitch",
            ),
            value: _riskWarnings,
            onChanged: (v) {
              setState(() => _riskWarnings = v);
              _updateAll();
              _savePrefs();
            },
          ),
          _notifTile(
            icon: Icons.remove_red_eye_outlined,
            color: AppColors.fomo,
            title: s.notifSettingsFomoTitle,
            subtitle: s.t(
              'Detection of late entry patterns on moves that already happened',
              'Rilevamento pattern di entrata tardiva su movimenti già avvenuti',
            ),
            value: _fomoAlerts,
            onChanged: (v) {
              setState(() => _fomoAlerts = v);
              _updateAll();
              _savePrefs();
            },
          ),
          _notifTile(
            icon: Icons.emoji_events_outlined,
            color: AppColors.textPrimary,
            title: s.notifSettingsChallengeTitle,
            subtitle: s.t(
              'Day countdown, milestone updates and progress',
              'Countdown giorni, aggiornamento milestone e progressi',
            ),
            value: _challengeReminders,
            onChanged: (v) {
              setState(() => _challengeReminders = v);
              _updateAll();
              _savePrefs();
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.notifSettingsSilentHours,
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.notifSettingsSilentSubtitle,
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.bedtime_outlined,
                        color: AppColors.accent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '22:00 — 07:00',
                      style: GoogleFonts.manrope(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          FutureBuilder<List<EconomicEvent>>(
            future: NotificationService.fetchEconomicEvents(),
            builder: (context, snapshot) {
              final events = snapshot.data ?? [];
              if (!snapshot.hasData || events.isEmpty) {
                return const SizedBox.shrink();
              }
              final toShow = events.take(3).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 8),
                  Text(
                    s.notifSettingsUpcoming,
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...toShow.map((e) => _EconomicEventTile(event: e, s: s)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _notifTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: GoogleFonts.manrope(
          color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: GoogleFonts.manrope(
          color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
        value: value,
        onChanged: onChanged,
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.black : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.accent : AppColors.divider),
      ),
    );
  }
}

class _EconomicEventTile extends StatelessWidget {
  final EconomicEvent event;
  final AppStrings s;
  const _EconomicEventTile({required this.event, required this.s});

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return s.notifSettingsToday(_formatTime(dt));
    }
    return s.notifSettingsTomorrow(_formatTime(dt));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.event_outlined,
                color: AppColors.warning, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.event,
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.country.toUpperCase()} · ${_formatDate(event.time)}',
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'HIGH',
              style: GoogleFonts.manrope(
                color: AppColors.warning,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
