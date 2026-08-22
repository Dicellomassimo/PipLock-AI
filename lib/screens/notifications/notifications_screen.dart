import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../services/notification_service.dart';

// ── Mapping asset → valute rilevanti su ForexFactory ──────────────────────────
const _assetCurrencies = <String, List<String>>{
  'XAUUSD': ['USD'],
  'XAGUSD': ['USD'],
  'XPTUSD': ['USD'],
  'EURUSD': ['EUR', 'USD'],
  'GBPUSD': ['GBP', 'USD'],
  'USDJPY': ['USD', 'JPY'],
  'USDCHF': ['USD', 'CHF'],
  'AUDUSD': ['AUD', 'USD'],
  'NZDUSD': ['NZD', 'USD'],
  'USDCAD': ['USD', 'CAD'],
  'GBPJPY': ['GBP', 'JPY'],
  'EURJPY': ['EUR', 'JPY'],
  'EURGBP': ['EUR', 'GBP'],
  'EURAUD': ['EUR', 'AUD'],
  'GBPAUD': ['GBP', 'AUD'],
  'EURCHF': ['EUR', 'CHF'],
  'US30':   ['USD'],
  'NAS100': ['USD'],
  'SP500':  ['USD'],
  'USOIL':  ['USD'],
  'BTC':    ['USD'],
};

// Tutte le valute note (per i chip valuta anche se non ci sono eventi questa settimana)
const _allCurrencies = ['USD', 'EUR', 'GBP', 'JPY', 'CHF', 'AUD', 'NZD', 'CAD', 'CNY'];

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<EconomicEvent> _events = [];
  List<Map<String, dynamic>> _killswitchEvents = [];
  bool _loading = true;
  String? _error;

  // ── Filtri ────────────────────────────────────────────────────────────────
  bool _filtersExpanded = false;
  Set<String> _selectedImpacts = {'high', 'medium', 'low'};
  Set<String> _selectedCurrencies = {};   // vuoto = tutte
  String? _selectedAsset;                 // null = nessun quick-filter

  static const _prefImpacts    = 'notif_filter_impacts';
  static const _prefCurrencies = 'notif_filter_currencies';
  static const _prefAsset      = 'notif_filter_asset';

  @override
  void initState() {
    super.initState();
    _loadPrefs().then((_) => _load());
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final impacts = prefs.getStringList(_prefImpacts);
    final currencies = prefs.getStringList(_prefCurrencies);
    final asset = prefs.getString(_prefAsset);
    setState(() {
      if (impacts != null) _selectedImpacts = impacts.toSet();
      if (currencies != null) _selectedCurrencies = currencies.toSet();
      _selectedAsset = asset;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefImpacts, _selectedImpacts.toList());
    await prefs.setStringList(_prefCurrencies, _selectedCurrencies.toList());
    if (_selectedAsset != null) {
      await prefs.setString(_prefAsset, _selectedAsset!);
    } else {
      await prefs.remove(_prefAsset);
    }
  }

  // ── Filtraggio ────────────────────────────────────────────────────────────

  List<EconomicEvent> get _filteredEvents {
    return _events.where((e) {
      // 1. Impatto
      if (!_selectedImpacts.contains(e.impact)) return false;

      // 2. Asset rapido → filtra per valute dell'asset
      final assetCurrencies = _selectedAsset != null
          ? (_assetCurrencies[_selectedAsset!] ?? [])
          : <String>[];

      if (assetCurrencies.isNotEmpty) {
        final country = e.country.toUpperCase();
        if (!assetCurrencies.any((c) => country.contains(c))) return false;
        return true; // asset filter sovrascrive currency filter
      }

      // 3. Valute manuali
      if (_selectedCurrencies.isNotEmpty) {
        final country = e.country.toUpperCase();
        if (!_selectedCurrencies.any((c) => country.contains(c))) return false;
      }

      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _selectedImpacts.length < 3 ||
      _selectedCurrencies.isNotEmpty ||
      _selectedAsset != null;

  // ── Dati ─────────────────────────────────────────────────────────────────

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() { _loading = true; _error = null; });
    if (forceRefresh) await NotificationService.refresh();
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final eventsFuture = NotificationService.fetchEconomicCalendar();
      final killswitchFuture = userId != null
          ? Supabase.instance.client
              .from('killswitch_events')
              .select('id, triggered_at, reason, lock_duration_minutes')
              .eq('user_id', userId)
              .order('triggered_at', ascending: false)
              .limit(10)
              .then((res) => (res as List<dynamic>).cast<Map<String, dynamic>>())
          : Future.value(<Map<String, dynamic>>[]);

      final results = await Future.wait([eventsFuture, killswitchFuture]);
      if (!mounted) return;
      setState(() {
        _events = results[0] as List<EconomicEvent>;
        _killswitchEvents = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Map<String, String> _reasonMap(AppStrings s) => {
    'daily_loss': s.brokerDailyLoss,
    'max_trades': s.t('Max trades reached', 'Max trade raggiunti'),
    'overleveraging': s.t('Overleveraging', 'Overleveraging'),
    'revenge_pattern': s.t('Revenge trading', 'Revenge trading'),
  };

  // ── Build ─────────────────────────────────────────────────────────────────

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
          s.notificationsTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Icona filtri con badge rosso se attivi
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: Icon(
                  _filtersExpanded ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: _hasActiveFilters ? AppColors.accent : AppColors.textSecondary,
                  size: 22,
                ),
                onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
                tooltip: s.notificationsFilters,
              ),
              if (_hasActiveFilters)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accent, size: 22),
            onPressed: () => _load(forceRefresh: true),
            tooltip: s.notificationsRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Pannello filtri ──────────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildFilterPanel(),
            crossFadeState: _filtersExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
          // ── Contenuto ────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : _error != null
                    ? _buildError()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  // ── Pannello filtri ────────────────────────────────────────────────────────

  Widget _buildFilterPanel() {
    final s = ref.watch(appStringsProvider);
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(s.notificationsFilters.toUpperCase(),
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  )),
              const Spacer(),
              if (_hasActiveFilters)
                GestureDetector(
                  onTap: _resetFilters,
                  child: Text(s.notificationsClearAll,
                      style: GoogleFonts.manrope(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── 1. Impatto ─────────────────────────────────────────────────
          Text(s.notificationsImpact,
              style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              _ImpactChip(
                label: 'HIGH',
                color: AppColors.danger,
                selected: _selectedImpacts.contains('high'),
                onTap: () => _toggleImpact('high'),
              ),
              const SizedBox(width: 8),
              _ImpactChip(
                label: 'MEDIUM',
                color: AppColors.warning,
                selected: _selectedImpacts.contains('medium'),
                onTap: () => _toggleImpact('medium'),
              ),
              const SizedBox(width: 8),
              _ImpactChip(
                label: 'LOW',
                color: AppColors.textSecondary,
                selected: _selectedImpacts.contains('low'),
                onTap: () => _toggleImpact('low'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 2. Asset rapido ────────────────────────────────────────────
          Text(s.notificationsAssets,
              style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(s.notificationsAssetsHint,
              style: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 10)),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _assetCurrencies.keys.map((asset) {
                final selected = _selectedAsset == asset;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => _selectAsset(asset),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.accent
                            : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.accent
                              : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        asset,
                        style: GoogleFonts.manrope(
                          color: selected
                              ? Colors.black
                              : AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // ── 3. Valuta manuale ──────────────────────────────────────────
          Row(
            children: [
              Text(s.notificationsCurrency,
                  style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              if (_selectedAsset != null)
                Text(s.notificationsCurrencyDisabled,
                    style: GoogleFonts.manrope(
                        color: AppColors.textSecondary, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _buildCurrencyChips(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCurrencyChips() {
    // Prendi le valute presenti negli eventi questa settimana + tutte quelle note
    final available = {
      ..._events.map((e) => e.country.toUpperCase()),
      ..._allCurrencies,
    }.toList()..sort();

    return available.map((currency) {
      final selected = _selectedCurrencies.contains(currency);
      final disabled = _selectedAsset != null;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onTap: disabled ? null : () => _toggleCurrency(currency),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected && !disabled
                  ? AppColors.accent.withValues(alpha: 0.2)
                  : AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected && !disabled
                    ? AppColors.accent
                    : AppColors.divider.withValues(
                        alpha: disabled ? 0.3 : 1.0),
              ),
            ),
            child: Text(
              currency,
              style: GoogleFonts.manrope(
                color: disabled
                    ? AppColors.textSecondary.withValues(alpha: 0.4)
                    : selected
                        ? AppColors.accent
                        : AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ── Azioni filtri ─────────────────────────────────────────────────────────

  void _toggleImpact(String impact) {
    setState(() {
      if (_selectedImpacts.contains(impact) && _selectedImpacts.length > 1) {
        _selectedImpacts = Set.from(_selectedImpacts)..remove(impact);
      } else {
        _selectedImpacts = Set.from(_selectedImpacts)..add(impact);
      }
    });
    _savePrefs();
  }

  void _selectAsset(String asset) {
    setState(() {
      _selectedAsset = _selectedAsset == asset ? null : asset;
      // Deseleziona valute manuali quando si usa il filtro asset
      if (_selectedAsset != null) _selectedCurrencies = {};
    });
    _savePrefs();
  }

  void _toggleCurrency(String currency) {
    setState(() {
      final next = Set<String>.from(_selectedCurrencies);
      if (next.contains(currency)) {
        next.remove(currency);
      } else {
        next.add(currency);
      }
      _selectedCurrencies = next;
    });
    _savePrefs();
  }

  void _resetFilters() {
    setState(() {
      _selectedImpacts = {'high', 'medium', 'low'};
      _selectedCurrencies = {};
      _selectedAsset = null;
    });
    _savePrefs();
  }

  // ── Contenuto ─────────────────────────────────────────────────────────────

  Widget _buildError() {
    final s = ref.watch(appStringsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(s.notificationsLoadError,
                style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 8),
            Text(_error ?? '',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
              ),
              child: Text(s.notificationsRetry,
                  style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final s = ref.watch(appStringsProvider);
    final filtered = _filteredEvents;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final past = filtered.where((e) => e.time.isBefore(now)).toList();
    final upcoming = filtered.where((e) => !e.time.isBefore(now)).toList();
    final todayUpcoming = upcoming.where((e) => e.time.isBefore(tomorrow)).toList();
    final futureEvents = upcoming.where((e) => !e.time.isBefore(tomorrow)).toList();

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Riepilogo filtri attivi ────────────────────────────────────
          if (_hasActiveFilters) ...[
            _buildActiveFiltersSummary(),
            const SizedBox(height: 16),
          ],

          // ── Sezione calendario ─────────────────────────────────────────
          if (_events.isNotEmpty) ...[
            _sectionTitle(s.notificationsCalendarHeader),
            const SizedBox(height: 4),
            Text(
              '${s.notificationsSource(filtered.length)} — ${s.t('next 30 days', 'prossimi 30 giorni')}',
              style: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 10),
            ),
            const SizedBox(height: 16),

            if (filtered.isEmpty) ...[
              _buildNoResults(),
              const SizedBox(height: 16),
            ] else ...[
              if (past.isNotEmpty) ...[
                _SectionHeader(label: s.notificationsSectionPast(past.length)),
                const SizedBox(height: 8),
                ...past.reversed.map((e) => _EventCard(event: e, isPast: true)),
                const SizedBox(height: 16),
              ],
              if (todayUpcoming.isNotEmpty) ...[
                _SectionHeader(
                    label: s.notificationsSectionToday(todayUpcoming.length),
                    highlight: true),
                const SizedBox(height: 8),
                ...todayUpcoming.map((e) => _EventCard(event: e, isToday: true)),
                const SizedBox(height: 16),
              ],
              if (futureEvents.isNotEmpty) ...[
                _SectionHeader(
                    label: s.notificationsSectionUpcoming(futureEvents.length)),
                const SizedBox(height: 8),
                ...futureEvents.map((e) => _EventCard(event: e, isFuture: true)),
                const SizedBox(height: 16),
              ],
            ],

            const Divider(color: AppColors.divider),
            const SizedBox(height: 20),
          ],

          if (_events.isEmpty) ...[
            _sectionTitle(s.t('MACROECONOMIC CALENDAR', 'CALENDARIO MACROECONOMICO')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_busy,
                      color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Text(s.notificationsNoEvents,
                      style: GoogleFonts.manrope(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 20),
          ],

          // ── Killswitch recenti ─────────────────────────────────────────
          if (_killswitchEvents.isNotEmpty) ...[
            _sectionTitle(s.notificationsRecentKs),
            const SizedBox(height: 12),
            ..._killswitchEvents.map(_buildKillswitchCard),
            const SizedBox(height: 20),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 20),
          ],

          // ── Impostazioni ───────────────────────────────────────────────
          GestureDetector(
            onTap: () =>
                Navigator.pushNamed(context, '/notification_settings'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.notificationsSettings,
                      style: GoogleFonts.manrope(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      color: AppColors.accent, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersSummary() {
    final s = ref.read(appStringsProvider);
    final parts = <String>[];
    if (_selectedImpacts.length < 3) {
      final labels = {
        'high': 'HIGH',
        'medium': 'MED',
        'low': 'LOW',
      };
      parts.add(_selectedImpacts.map((i) => labels[i] ?? i).join(' · '));
    }
    if (_selectedAsset != null) {
      parts.add('Asset: $_selectedAsset');
    } else if (_selectedCurrencies.isNotEmpty) {
      parts.add('Valute: ${_selectedCurrencies.join(', ')}');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, color: AppColors.accent, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${s.t('Active filters', 'Filtri attivi')}: ${parts.join('  •  ')}',
              style: GoogleFonts.manrope(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: _resetFilters,
            child: const Icon(Icons.close, color: AppColors.accent, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    final s = ref.watch(appStringsProvider);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off, color: AppColors.textSecondary, size: 36),
          const SizedBox(height: 10),
          Text(s.notificationsNoEventsFiltered,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              )),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _resetFilters,
            child: Text(s.notificationsClearFilters,
                style: GoogleFonts.manrope(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String label) {
    return Text(
      label,
      style: GoogleFonts.manrope(
        color: AppColors.textSecondary,
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildKillswitchCard(Map<String, dynamic> e) {
    final s = ref.watch(appStringsProvider);
    final rm = _reasonMap(s);
    final reason = rm[e['reason'] as String? ?? ''] ??
        (e['reason'] as String? ?? 'Killswitch');
    final triggeredAt = e['triggered_at'] as String? ?? '';
    final duration = e['lock_duration_minutes'] as int?;
    String dateLabel = '—';
    if (triggeredAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(triggeredAt).toLocal();
        final now = DateTime.now();
        final isToday = dt.year == now.year &&
            dt.month == now.month &&
            dt.day == now.day;
        final time =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        dateLabel = isToday
            ? s.notificationsToday(time)
            : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} $time';
      } catch (_) {}
    }

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
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.lock_outline,
                color: AppColors.danger, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reason,
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    )),
                const SizedBox(height: 2),
                Text(dateLabel,
                    style: GoogleFonts.manrope(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          if (duration != null)
            Text('${duration}min',
                style: GoogleFonts.manrope(
                  color: AppColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
        ],
      ),
    );
  }
}

// ── Chip impatto ───────────────────────────────────────────────────────────────

class _ImpactChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ImpactChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.divider),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: selected ? color : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Intestazione sezione ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool highlight;
  const _SectionHeader({required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.accent.withValues(alpha: 0.10)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: highlight ? AppColors.accent : AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ── Card singolo evento ────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final EconomicEvent event;
  final bool isPast;
  final bool isToday;
  final bool isFuture;

  const _EventCard({
    required this.event,
    this.isPast = false,
    this.isToday = false,
    this.isFuture = false,
  });

  Color get _impactColor {
    switch (event.impact) {
      case 'high':
        return AppColors.danger;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  String get _impactLabel {
    switch (event.impact) {
      case 'high':
        return 'HIGH';
      case 'medium':
        return 'MED';
      default:
        return 'LOW';
    }
  }

  String _formatDate(DateTime dt, BuildContext context) {
    final now = DateTime.now();
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      // Use a simple in-widget t() approach
      final locale = Localizations.localeOf(context);
      return locale.languageCode == 'it' ? 'Oggi $time' : 'Today $time';
    }
    final locale = Localizations.localeOf(context);
    final weekdays = locale.languageCode == 'it'
        ? ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final wd = weekdays[dt.weekday - 1];
    return '$wd ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} $time';
  }

  @override
  Widget build(BuildContext context) {
    final impactColor = _impactColor;
    final borderColor = isToday
        ? impactColor.withValues(alpha: 0.4)
        : isFuture
            ? AppColors.accent.withValues(alpha: 0.15)
            : AppColors.divider;

    return Opacity(
      opacity: isPast ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Country badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: impactColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  event.country.toUpperCase().isEmpty
                      ? '??'
                      : event.country.toUpperCase(),
                  style: GoogleFonts.manrope(
                    color: impactColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Titolo + data + valori
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDate(event.time, context),
                    style: GoogleFonts.manrope(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                  if (event.estimate != null ||
                      event.previous != null ||
                      event.actual != null) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      children: [
                        if (event.actual != null)
                          _ValueChip(
                              label: Localizations.localeOf(context).languageCode == 'it' ? 'Reale' : 'Actual',
                              value: event.actual!,
                              color: AppColors.accent),
                        if (event.estimate != null)
                          _ValueChip(
                              label: Localizations.localeOf(context).languageCode == 'it' ? 'Stima' : 'Estimate',
                              value: event.estimate!,
                              color: AppColors.textSecondary),
                        if (event.previous != null)
                          _ValueChip(
                              label: Localizations.localeOf(context).languageCode == 'it' ? 'Prec.' : 'Prev.',
                              value: event.previous!,
                              color: AppColors.textSecondary),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Impact badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: impactColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _impactLabel,
                style: GoogleFonts.manrope(
                  color: impactColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ValueChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: GoogleFonts.manrope(
                color: AppColors.textSecondary, fontSize: 10),
          ),
          TextSpan(
            text: value,
            style: GoogleFonts.manrope(
                color: color, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
