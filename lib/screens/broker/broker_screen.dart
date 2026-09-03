import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../providers/broker_provider.dart';
import '../../providers/killswitch_provider.dart';
import '../../providers/rules_provider.dart';
import '../../services/accessibility_service.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/premium_button.dart';

class BrokerScreen extends ConsumerStatefulWidget {
  const BrokerScreen({super.key});

  @override
  ConsumerState<BrokerScreen> createState() => _BrokerScreenState();
}

class _BrokerScreenState extends ConsumerState<BrokerScreen> {
  BrokerConnectionMethod? _selectedMethod;
  bool _addingAnother = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final state = ref.watch(brokerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Inline header
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.pagePadding, 20, AppTheme.pagePadding, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: AppColors.textPrimary, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (_selectedMethod != null) {
                            setState(() => _selectedMethod = null);
                          } else if (_addingAnother) {
                            setState(() => _addingAnother = false);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      Text(
                        s.brokerTitle,
                        style: GoogleFonts.manrope(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      'PipLock reads account data — never executes orders.',
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
                child: state.hasAccount && !_addingAnother
                    ? _buildConnectedView(state, s)
                    : _selectedMethod == null
                        ? _buildMethodSelection(state, s)
                        : _buildMethodForm(_selectedMethod!, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Method selection — 6 cards
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMethodSelection(BrokerState state, AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.link, color: AppColors.accent, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t('Choose how to connect your broker account', 'Scegli come collegare il tuo conto broker'),
                      style: GoogleFonts.manrope(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.t('PipLock reads account data — never executes orders.', 'PipLock legge i dati del conto — non esegue mai ordini.'),
                      style: GoogleFonts.manrope(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // EA MQL5
        _MethodCard(
          icon: Icons.computer_outlined,
          title: 'EA MQL5',
          subtitle: s.t('Desktop / VPS', 'Desktop / VPS'),
          accuracyBadge: s.t('100% Accurate', '100% Preciso'),
          accuracyColor: AppColors.accent,
          description: s.t(
            'An Expert Advisor runs inside MetaTrader 5 and sends real account data to PipLock via webhook. The most precise method — reads actual equity, drawdown and trade count.',
            'Un Expert Advisor gira dentro MetaTrader 5 e invia i dati reali del conto a PipLock via webhook. Il metodo più preciso — legge equity, drawdown e numero di trade.',
          ),
          setupGuide: [
            s.t('Download MetaTrader 5 for Windows from metatrader5.com (free)', 'Scarica MetaTrader 5 per Windows da metatrader5.com (gratis)'),
            s.t('Open MetaEditor (F4 inside MT5) and create a new Expert Advisor', 'Apri MetaEditor (F4 dentro MT5) e crea un nuovo Expert Advisor'),
            s.t('Copy the PipLock EA code (tap "Activate EA Connection" below)', 'Copia il codice EA di PipLock (premi "Attiva Connessione EA" sotto)'),
            s.t('Enable WebRequest in MT5: Tools → Options → Expert Advisors → check "Allow WebRequest for listed URL" → add your Supabase URL', 'Abilita WebRequest in MT5: Strumenti → Opzioni → Expert Advisor → spunta "Consenti WebRequest per URL" → aggiungi il tuo URL Supabase'),
            s.t('Compile the EA (F7) and attach it to any chart', 'Compila l\'EA (F7) e collegalo a qualsiasi grafico'),
            s.t('Enter your webhook secret in PipLock — your trades will be monitored in real time via Supabase Realtime.', 'Inserisci il webhook secret in PipLock — i tuoi trade saranno monitorati in tempo reale via Supabase Realtime.'),
          ],
          onTap: () => setState(() => _selectedMethod = BrokerConnectionMethod.ea),
        ),

        const SizedBox(height: 12),

        // MetaAPI Cloud
        _MethodCard(
          icon: Icons.cloud_sync_outlined,
          title: 'MetaAPI Cloud',
          subtitle: s.t('Most MT4/MT5 brokers', 'La maggior parte dei broker MT4/MT5'),
          accuracyBadge: s.t('98% Accurate', '98% Preciso'),
          accuracyColor: AppColors.accent,
          description: s.t(
            'Connect your MT4/MT5 account via MetaAPI Cloud. Enter your MetaAPI Account ID to read equity, P&L and positions in real time. Free tier available.',
            'Collega il tuo conto MT4/MT5 via MetaAPI Cloud. Inserisci il tuo MetaAPI Account ID per leggere equity, P&L e posizioni in tempo reale. Piano gratuito disponibile.',
          ),
          setupGuide: [
            s.t('Go to app.metaapi.cloud and create a free account', 'Vai su app.metaapi.cloud e crea un account gratuito'),
            s.t('Click "Add Account" and enter your MT5 broker credentials', 'Clicca "Aggiungi Account" e inserisci le credenziali del tuo broker MT5'),
            s.t('Copy your MetaAPI Account ID from the dashboard', 'Copia il tuo MetaAPI Account ID dalla dashboard'),
            s.t('Paste it into PipLock below', 'Incollalo in PipLock qui sotto'),
            s.t('Note: MetaAPI free tier has limited requests. Upgrade for continuous monitoring.', 'Nota: il piano gratuito MetaAPI ha richieste limitate. Passa al piano a pagamento per monitoraggio continuo.'),
          ],
          onTap: () =>
              setState(() => _selectedMethod = BrokerConnectionMethod.metaApi),
        ),

        const SizedBox(height: 12),

        // Screen Reading (MT5 Mobile)
        _MethodCard(
          icon: Icons.phone_android_outlined,
          title: s.t('Screen Reading (MT5 Mobile)', 'Lettura Schermo (MT5 Mobile)'),
          subtitle: s.t('MetaTrader 5 Android, MetaTrader 4 Android', 'MetaTrader 5 Android, MetaTrader 4 Android'),
          accuracyBadge: s.t('~85% · Improving', '~85% · In miglioramento'),
          accuracyColor: const Color(0xFF4A90E2),
          description: s.t(
            'PipLock uses the Android Accessibility Service to read equity and P&L directly from the broker app screen. Back and Recents keys are blocked during lockdown. No credentials required.',
            'PipLock usa il Servizio di Accessibilità Android per leggere equity e P&L direttamente dallo schermo dell\'app broker. I tasti Indietro e Recenti sono bloccati durante il lockdown. Nessuna credenziale richiesta.',
          ),
          setupGuide: [
            s.t('Tap "Enable Accessibility Service" below', 'Premi "Abilita Servizio Accessibilità" qui sotto'),
            s.t('Find PipLock in the list and enable it', 'Trova PipLock nell\'elenco e abilitalo'),
            s.t('Open MetaTrader 5 and navigate to your Trade tab', 'Apri MetaTrader 5 e vai alla scheda Trade'),
            s.t('PipLock will read your account data automatically', 'PipLock leggerà i dati del tuo conto automaticamente'),
            s.t('Note: Keep PipLock active in background for continuous monitoring.', 'Nota: mantieni PipLock attivo in background per un monitoraggio continuo.'),
          ],
          onTap: () => setState(
              () => _selectedMethod = BrokerConnectionMethod.accessibility),
        ),

        const SizedBox(height: 12),

        // Manual Entry
        _MethodCard(
          icon: Icons.edit_outlined,
          title: s.t('Manual Entry', 'Inserimento Manuale'),
          subtitle: s.t('Any broker', 'Qualsiasi broker'),
          accuracyBadge: s.t('You decide', 'Decidi tu'),
          accuracyColor: AppColors.textSecondary,
          description: s.t(
            'Enter your account data manually after each trading session. PipLock applies your rules to the data you enter. Works with any broker or platform.',
            'Inserisci i dati del tuo conto manualmente dopo ogni sessione di trading. PipLock applica le tue regole ai dati che inserisci. Funziona con qualsiasi broker o piattaforma.',
          ),
          setupGuide: [
            s.t('Tap "Update Data" below to enter your latest account figures', 'Premi "Aggiorna Dati" qui sotto per inserire i tuoi dati più recenti'),
            s.t('You manually enter equity, balance, P&L and open positions', 'Inserisci manualmente equity, saldo, P&L e posizioni aperte'),
            s.t('PipLock checks your limits every time you press Update', 'PipLock controlla i tuoi limiti ogni volta che premi Aggiorna'),
            s.t('Accuracy depends entirely on your honesty with yourself', 'La precisione dipende interamente dalla tua onestà con te stesso'),
          ],
          onTap: () =>
              setState(() => _selectedMethod = BrokerConnectionMethod.manual),
        ),

        if (state.error != null) ...[
          const SizedBox(height: 20),
          _ErrorBanner(message: state.error!),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Method-specific form
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMethodForm(BrokerConnectionMethod method, BrokerState state) {
    switch (method) {
      case BrokerConnectionMethod.ea:
        return _EaForm(state: state);
      case BrokerConnectionMethod.metaApi:
        return _MetaApiForm(state: state);
      case BrokerConnectionMethod.accessibility:
        return _AccessibilityForm(state: state);
      case BrokerConnectionMethod.manual:
        return _ManualForm(state: state);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Connected view
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildConnectedView(BrokerState state, AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MethodBadge(method: state.method),
        const SizedBox(height: 16),

        AnimatedCard(
          padding: const EdgeInsets.all(18),
          border: Border.all(
            color: state.isConnected
                ? AppColors.accent.withValues(alpha: 0.3)
                : AppColors.divider,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (state.isConnected
                              ? AppColors.accent
                              : AppColors.textSecondary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      state.isConnected
                          ? Icons.wifi
                          : Icons.wifi_off_rounded,
                      color: state.isConnected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.method == BrokerConnectionMethod.accessibility &&
                                  state.detectedAppName != null
                              ? state.detectedAppName!
                              : _methodLabel(state.method, s),
                          style: GoogleFonts.manrope(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        Text(
                          state.statusMessage ??
                              _methodDescription(state.method, s),
                          style: GoogleFonts.manrope(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                        if (state.isConnected && state.equity != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Equity: ${state.currency ?? ''} ${state.equity!.toStringAsFixed(2)}'
                            '  P&L: ${state.dailyPnl != null ? (state.dailyPnl! >= 0 ? '+' : '') + state.dailyPnl!.toStringAsFixed(2) : '—'}',
                            style: GoogleFonts.manrope(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _StatusBadge(connected: state.isConnected),
                ],
              ),
              if (state.isConnecting && !state.isConnected) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: AppColors.accent, strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.statusMessage ??
                            s.t('Waiting for data…', 'In attesa di dati...'),
                        style: GoogleFonts.manrope(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
              if (state.lastUpdate != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (state.method == BrokerConnectionMethod.accessibility)
                      Text(
                        s.brokerAutoUpdate,
                        style: GoogleFonts.manrope(
                            color: AppColors.textSecondary, fontSize: 11),
                      )
                    else
                      const SizedBox.shrink(),
                    Text(
                      s.brokerReadAgo(_formatTime(state.lastUpdate!, s)),
                      style: GoogleFonts.manrope(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        if (state.isConnected && state.equity != null) ...[
          const SizedBox(height: 16),
          _MetricsGrid(state: state),
        ],

        if (state.error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: state.error!),
        ],

        const SizedBox(height: 20),

        // Add another account — no need to disconnect first
        GestureDetector(
          onTap: () => setState(() {
            _addingAnother = true;
            _selectedMethod = null;
          }),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline_rounded,
                    color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Add another account',
                  style: GoogleFonts.manrope(
                    color: AppColors.success,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        PremiumButton(
          label: s.brokerDisconnect,
          icon: Icons.link_off,
          variant: PremiumButtonVariant.danger,
          onTap: _disconnect,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns true if any personal-account lock or challenge lock is currently active.
  Future<bool> _anyLockActive() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final key in prefs.getKeys()) {
      if (key.startsWith('rules_locked_until_ms') ||
          key.startsWith('challenge_locked_until_')) {
        final expiry = prefs.getInt(key) ?? 0;
        if (expiry > now) return true;
      }
    }
    return false;
  }

  Future<void> _disconnect() async {
    final s = ref.read(appStringsProvider);
    final ksActive = ref.read(killswitchProvider).isActive;
    final hasRules = ref.read(rulesProvider).rules != null;

    // BLOCCO TOTALE: killswitch attivo — non si può disconnettere
    if (ksActive) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_rounded, color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Text(
                s.t('Killswitch Active', 'Killswitch Attivo'),
                style: GoogleFonts.manrope(
                    color: AppColors.danger, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            s.t(
              'You cannot disconnect the broker while the Killswitch is active. Wait for the lock to expire or use a token to unlock early.',
              'Non puoi disconnettere il broker mentre il Killswitch è attivo. Attendi la scadenza del blocco oppure usa un token per sbloccarti anticipatamente.',
            ),
            style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.t('Got it', 'Ok'),
                  style: GoogleFonts.manrope(color: AppColors.accent)),
            ),
          ],
        ),
      );
      return;
    }

    // BLOCCO TOTALE: regole bloccate (lock attivo su qualsiasi account)
    if (await _anyLockActive()) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_clock_rounded, color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Text(
                s.t('Rules Locked', 'Regole Bloccate'),
                style: GoogleFonts.manrope(
                    color: AppColors.danger, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            s.t(
              'Your trading rules are locked. You cannot disconnect the broker until the lock expires. This protects you from bypassing your own rules.',
              'Le tue regole di trading sono bloccate. Non puoi disconnettere il broker fino alla scadenza del blocco. Questo ti protegge dal bypassare le tue stesse regole.',
            ),
            style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.t('Got it', 'Ok'),
                  style: GoogleFonts.manrope(color: AppColors.accent)),
            ),
          ],
        ),
      );
      return;
    }

    // AVVISO RINFORZATO: regole attive ma KS non scattato
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.brokerDisconnect,
            style: GoogleFonts.manrope(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasRules) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.t(
                          'Your rules are active. Disconnecting will stop all monitoring — the Killswitch will no longer trigger automatically.',
                          'Le tue regole sono attive. Disconnettendoti il monitoraggio si fermerà — il Killswitch non scatterà più automaticamente.',
                        ),
                        style: GoogleFonts.manrope(
                            color: AppColors.danger, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              s.t(
                'Do you want to remove the broker connection?',
                'Vuoi rimuovere la connessione al broker?',
              ),
              style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.brokerCancel,
                style: GoogleFonts.manrope(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.brokerDisconnectConfirm,
                style: GoogleFonts.manrope(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(brokerProvider.notifier).disconnect();
      if (mounted) setState(() => _selectedMethod = null);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _methodLabel(BrokerConnectionMethod method, AppStrings s) {
    switch (method) {
      case BrokerConnectionMethod.ea:
        return s.t('EA MQL5 — Desktop/VPS', 'EA MQL5 — Desktop/VPS');
      case BrokerConnectionMethod.metaApi:
        return s.t('MetaAPI Live', 'MetaAPI Live');
      case BrokerConnectionMethod.accessibility:
        return s.t('Screen Reading (MT5 Mobile)', 'Lettura Schermo (MT5 Mobile)');
      case BrokerConnectionMethod.manual:
        return s.t('Manual Entry', 'Inserimento Manuale');
      default:
        return 'Broker';
    }
  }

  String _methodDescription(BrokerConnectionMethod method, AppStrings s) {
    switch (method) {
      case BrokerConnectionMethod.ea:
        return s.t('Data incoming from EA on MT5', 'Dati in arrivo dall\'EA su MT5');
      case BrokerConnectionMethod.metaApi:
        return s.t('Live data via MetaAPI Cloud', 'Dati live via MetaAPI Cloud');
      case BrokerConnectionMethod.accessibility:
        return s.t('Screen reading MT5 mobile', 'Lettura schermo MT5 mobile');
      case BrokerConnectionMethod.manual:
        return s.t('Manually entered data', 'Dati inseriti manualmente');
      default:
        return '';
    }
  }

  String _formatTime(DateTime dt, AppStrings s) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    return '${diff.inMinutes}min';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form: EA MQL5
// ─────────────────────────────────────────────────────────────────────────────

class _EaForm extends ConsumerStatefulWidget {
  final BrokerState state;
  const _EaForm({required this.state});

  @override
  ConsumerState<_EaForm> createState() => _EaFormState();
}

class _EaFormState extends ConsumerState<_EaForm> {
  String? _generatedSecret;
  bool _activating = false;

  static const _webhookUrl =
      'https://<project-ref>.supabase.co/functions/v1/ea-webhook';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final secret = _generatedSecret ?? widget.state.webhookSecret;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GuideBox(
          icon: Icons.computer_outlined,
          title: 'EA MQL5 Setup Guide',
          steps: const [
            'Download MetaTrader 5 for Windows from metatrader5.com (free)',
            'Open MetaEditor (F4 inside MT5) and create a new Expert Advisor',
            'Activate the connection below — copy the Webhook Secret into the EA',
            'In MT5 go to Tools → Options → Expert Advisors → add the webhook URL to the whitelist',
            'Compile the EA (F7) and attach it to any chart — account data arrives automatically',
          ],
        ),

        const SizedBox(height: 20),

        if (secret != null) ...[
          AnimatedCard(
            padding: const EdgeInsets.all(16),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Webhook Secret',
                  style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          secret,
                          style: GoogleFonts.manrope(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [const FontFeature.tabularFigures()]),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_outlined,
                            color: AppColors.accent, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: secret));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(s.brokerSecretCopied,
                                style: GoogleFonts.manrope(
                                    color: AppColors.textPrimary)),
                            backgroundColor: AppColors.cardBg,
                          ));
                        },
                        tooltip: 'Copy',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Webhook URL (for the MT5 whitelist)',
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _webhookUrl,
                          style: GoogleFonts.manrope(
                              color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_outlined,
                            color: AppColors.textSecondary, size: 16),
                        onPressed: () {
                          Clipboard.setData(
                              const ClipboardData(text: _webhookUrl));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(s.brokerUrlCopied,
                                style: GoogleFonts.manrope(
                                    color: AppColors.textPrimary)),
                            backgroundColor: AppColors.cardBg,
                          ));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Step-by-step setup guide
          _EaSetupGuide(webhookSecret: secret),
          const SizedBox(height: 24),
        ],

        if (widget.state.error != null) ...[
          _ErrorBanner(message: widget.state.error!),
          const SizedBox(height: 16),
        ],

        PremiumButton(
          label: s.brokerActivateEA,
          icon: Icons.link_rounded,
          loading: _activating,
          onTap: (_activating || widget.state.hasAccount) ? null : _activate,
        ),

        const SizedBox(height: 16),
        _SecurityNote(
            text:
                'The Webhook Secret authenticates the EA to PipLock. Keep it private — anyone who knows it can send data to your account.'),
      ],
    );
  }

  Future<void> _activate() async {
    setState(() => _activating = true);
    try {
      final secret = await ref.read(brokerProvider.notifier).connectEA();
      setState(() => _generatedSecret = secret);
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form: MetaAPI
// ─────────────────────────────────────────────────────────────────────────────

class _MetaApiForm extends ConsumerStatefulWidget {
  final BrokerState state;
  const _MetaApiForm({required this.state});

  @override
  ConsumerState<_MetaApiForm> createState() => _MetaApiFormState();
}

class _MetaApiFormState extends ConsumerState<_MetaApiForm> {
  final _accountIdCtrl = TextEditingController();

  @override
  void dispose() {
    _accountIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final brokerState = ref.watch(brokerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GuideBox(
          icon: Icons.cloud_sync_outlined,
          title: 'MetaAPI Cloud Setup',
          steps: const [
            'Go to app.metaapi.cloud and create a free account',
            'Click "Add Account" and enter your MT5 broker credentials',
            'Copy your MetaAPI Account ID from the dashboard',
            'Paste it into PipLock below',
            'Note: MetaAPI free tier has limited requests. Upgrade for continuous monitoring.',
          ],
        ),

        const SizedBox(height: 20),

        Text(
          'MetaAPI Account ID',
          style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: TextField(
            controller: _accountIdCtrl,
            style: GoogleFonts.manrope(
                color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
              hintStyle: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.cloud_outlined,
                  color: AppColors.textSecondary, size: 20),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Find the ID on app.metaapi.cloud → Accounts → click your MT5 account',
          style: GoogleFonts.manrope(
              color: const Color(0xFF4A90E2), fontSize: 12, height: 1.4),
        ),

        const SizedBox(height: 20),

        if (brokerState.error != null) ...[
          _ErrorBanner(message: brokerState.error!),
          const SizedBox(height: 16),
        ],

        PremiumButton(
          label: s.brokerConnect,
          icon: Icons.link_rounded,
          loading: brokerState.isConnecting,
          onTap: brokerState.isConnecting ? null : _connect,
        ),

        const SizedBox(height: 16),
        _SecurityNote(
            text:
                'PipLock reads only equity, balance and open positions via MetaAPI. It never executes orders.'),
      ],
    );
  }

  Future<void> _connect() async {
    final accountId = _accountIdCtrl.text.trim();
    if (accountId.isEmpty) return;
    await ref.read(brokerProvider.notifier).connectMetaApi(accountId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form: Accessibility (Screen Reading)
// ─────────────────────────────────────────────────────────────────────────────

class _AccessibilityForm extends ConsumerStatefulWidget {
  final BrokerState state;
  const _AccessibilityForm({required this.state});

  @override
  ConsumerState<_AccessibilityForm> createState() => _AccessibilityFormState();
}

class _AccessibilityFormState extends ConsumerState<_AccessibilityForm> {
  bool? _isEnabled;
  bool? _hasOverlayPermission;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final enabled = await AccessibilityService.isEnabled();
    final overlay = await AccessibilityService.canDrawOverlays();
    if (mounted) {
      setState(() {
        _isEnabled = enabled;
        _hasOverlayPermission = overlay;
      });
    }
  }

  Widget _accessStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.manrope(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final brokerState = ref.watch(brokerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GuideBox(
          icon: Icons.phone_android_outlined,
          title: 'Screen Reading Setup',
          steps: const [
            'Tap "Enable Accessibility Service" below',
            'Find PipLock in the list and enable it',
            'Open MetaTrader 5 and navigate to your Trade tab',
            'PipLock will read your account data automatically',
            'Note: Keep PipLock active in background for continuous monitoring.',
          ],
          accentColor: const Color(0xFF4A90E2),
          note: 'Continuously improving — accuracy depends on MT5 layout',
        ),

        const SizedBox(height: 20),

        if (_isEnabled == null)
          const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
        else if (!_isEnabled!) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Accessibility Service not enabled. Press the button to open settings.',
                    style: GoogleFonts.manrope(
                        color: AppColors.warning, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Guida step-by-step per abilitare l'Accessibility Service ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to enable — 3 steps',
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _accessStep('1', 'Tap "Open Settings" below. Your phone\'s Accessibility menu will open.'),
                _accessStep('2', 'Scroll down and find "Installed apps" or "Downloaded apps" — look for PipLock AI.'),
                _accessStep('3', 'Tap PipLock AI → toggle ON "Use PipLock AI" → press Allow in the confirmation dialog.'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'PipLock only reads financial data (equity, balance, P&L). It never stores passwords or personal info.',
                        style: GoogleFonts.manrope(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumButton(
            label: s.brokerEnableInSettings,
            icon: Icons.settings_outlined,
            onTap: () async {
              await AccessibilityService.openSettings();
              await Future.delayed(const Duration(seconds: 2));
              _checkStatus();
            },
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: AppColors.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accessibility Service active',
                        style: GoogleFonts.manrope(
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      if (brokerState.isConnected &&
                          brokerState.method ==
                              BrokerConnectionMethod.accessibility) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Equity: ${brokerState.currency ?? ''} ${brokerState.equity?.toStringAsFixed(2) ?? '—'}  '
                          'P&L: ${brokerState.dailyPnl != null ? (brokerState.dailyPnl! >= 0 ? '+' : '') + brokerState.dailyPnl!.toStringAsFixed(2) : '—'}',
                          style: GoogleFonts.manrope(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        Text(
                          'Open MT5 to start reading data.',
                          style: GoogleFonts.manrope(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumButton(
            label: s.brokerStartMonitoring,
            icon: Icons.phone_android_outlined,
            onTap: () {
              ref.read(brokerProvider.notifier).connectAccessibility();
            },
          ),

          if (_hasOverlayPermission == false) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.layers_outlined,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"Display over other apps" permission required',
                          style: GoogleFonts.manrope(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To show the Killswitch and FOMO Gatekeeper over MT5, PipLock needs the "Display over other apps" permission. Without this, the overlay will not appear while trading.',
                    style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  PremiumButton(
                    label: 'Grant overlay permission',
                    icon: Icons.open_in_new,
                    variant: PremiumButtonVariant.ghost,
                    onTap: () async {
                      await AccessibilityService.requestOverlayPermission();
                      await Future.delayed(const Duration(seconds: 2));
                      _checkStatus();
                    },
                  ),
                ],
              ),
            ),
          ] else if (_hasOverlayPermission == true) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.layers, color: AppColors.accent, size: 15),
                const SizedBox(width: 6),
                Text(
                  'Killswitch and FOMO overlay enabled',
                  style: GoogleFonts.manrope(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],

        const SizedBox(height: 16),
        _SecurityNote(
            text:
                'PipLock reads only the numeric values shown on the broker app screen (equity, balance, P&L). It never accesses login credentials or passwords.'),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form: Manual Entry
// ─────────────────────────────────────────────────────────────────────────────

class _ManualForm extends ConsumerStatefulWidget {
  final BrokerState state;
  const _ManualForm({required this.state});

  @override
  ConsumerState<_ManualForm> createState() => _ManualFormState();
}

class _ManualFormState extends ConsumerState<_ManualForm> {
  final _equityCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _pnlCtrl = TextEditingController();
  final _tradesCtrl = TextEditingController();
  final _positionsCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'USD');

  @override
  void dispose() {
    _equityCtrl.dispose();
    _balanceCtrl.dispose();
    _pnlCtrl.dispose();
    _tradesCtrl.dispose();
    _positionsCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final state = ref.watch(brokerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Data is updated only when you enter it manually. PipLock will check limits every time you press Update.',
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          s.brokerAccountData,
          style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
        const SizedBox(height: 14),

        _NumField(
            ctrl: _equityCtrl,
            label: 'Equity',
            hint: 'e.g. 10500.00',
            icon: Icons.account_balance_wallet_outlined),
        const SizedBox(height: 10),
        _NumField(
            ctrl: _balanceCtrl,
            label: 'Balance',
            hint: 'e.g. 10000.00',
            icon: Icons.savings_outlined),
        const SizedBox(height: 10),
        _NumField(
            ctrl: _pnlCtrl,
            label: "Today's P&L",
            hint: 'e.g. +150.00 or -80.00',
            icon: Icons.trending_up,
            signed: true),
        const SizedBox(height: 10),
        _NumField(
            ctrl: _tradesCtrl,
            label: s.brokerTradesToday,
            hint: 'e.g. 2',
            icon: Icons.bar_chart,
            isInt: true),
        const SizedBox(height: 10),
        _NumField(
            ctrl: _positionsCtrl,
            label: s.brokerOpenPositions,
            hint: 'e.g. 1',
            icon: Icons.open_in_new,
            isInt: true),
        const SizedBox(height: 10),
        _TextField(
            ctrl: _currencyCtrl,
            label: 'Currency',
            hint: 'e.g. USD, EUR',
            icon: Icons.currency_exchange),

        const SizedBox(height: 24),

        if (state.error != null) ...[
          _ErrorBanner(message: state.error!),
          const SizedBox(height: 16),
        ],

        PremiumButton(
          label: s.brokerUpdate,
          icon: Icons.save_outlined,
          onTap: _update,
        ),
      ],
    );
  }

  void _update() {
    final s = ref.read(appStringsProvider);
    ref.read(brokerProvider.notifier).updateManual(
          equity: double.tryParse(_equityCtrl.text.replaceAll(',', '.')),
          balance: double.tryParse(_balanceCtrl.text.replaceAll(',', '.')),
          dailyPnl: double.tryParse(_pnlCtrl.text.replaceAll(',', '.')),
          tradesToday: int.tryParse(_tradesCtrl.text),
          openPositions: int.tryParse(_positionsCtrl.text),
          currency: _currencyCtrl.text.trim().isNotEmpty
              ? _currencyCtrl.text.trim()
              : null,
        );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(s.brokerUpdated,
          style: GoogleFonts.manrope(color: AppColors.textPrimary)),
      backgroundColor: AppColors.cardBg,
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Card for selecting a connection method with expandable setup guide.
class _MethodCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String accuracyBadge;
  final Color accuracyColor;
  final String description;
  final List<String> setupGuide;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accuracyBadge,
    required this.accuracyColor,
    required this.description,
    required this.setupGuide,
    required this.onTap,
  });

  @override
  State<_MethodCard> createState() => _MethodCardState();
}

class _MethodCardState extends State<_MethodCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Main tappable area (selects method)
          InkWell(
            onTap: widget.onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: widget.accuracyColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(widget.icon,
                            color: widget.accuracyColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: GoogleFonts.manrope(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            Text(
                              widget.subtitle,
                              style: GoogleFonts.manrope(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // Accuracy badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: widget.accuracyColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color:
                                  widget.accuracyColor.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          widget.accuracyBadge,
                          style: GoogleFonts.manrope(
                              color: widget.accuracyColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary, size: 18),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.description,
                    style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.5),
                  ),
                ],
              ),
            ),
          ),

          // Setup Guide toggle
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(_expanded ? 0 : 16),
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _expanded ? 'Hide Setup Guide' : 'Setup Guide',
                    style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              decoration: const BoxDecoration(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < widget.setupGuide.length; i++)
                    _Step(
                        n: '${i + 1}', text: widget.setupGuide[i]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MethodBadge extends ConsumerWidget {
  final BrokerConnectionMethod method;
  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = switch (method) {
      BrokerConnectionMethod.ea => 'EA MQL5',
      BrokerConnectionMethod.metaApi => 'MetaAPI Live',
      BrokerConnectionMethod.accessibility => 'Screen Reading',
      BrokerConnectionMethod.manual => 'Manual',
      _ => 'Broker',
    };
    final icon = switch (method) {
      BrokerConnectionMethod.ea => Icons.computer_outlined,
      BrokerConnectionMethod.metaApi => Icons.cloud_sync_outlined,
      BrokerConnectionMethod.accessibility => Icons.phone_android_outlined,
      BrokerConnectionMethod.manual => Icons.edit_outlined,
      _ => Icons.link,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accent, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends ConsumerWidget {
  final BrokerState state;
  const _MetricsGrid({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Equity',
                value:
                    '${state.currency ?? ''} ${state.equity?.toStringAsFixed(2) ?? '—'}',
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Balance',
                value:
                    '${state.currency ?? ''} ${state.balance?.toStringAsFixed(2) ?? '—'}',
                icon: Icons.savings_outlined,
                color: const Color(0xFF4A90E2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: s.brokerDailyLoss,
                value: state.dailyLossUsd != null
                    ? '-\$${state.dailyLossUsd!.toStringAsFixed(2)} (${state.dailyLossPct!.toStringAsFixed(1)}%)'
                    : '—',
                icon: Icons.trending_down,
                color: (state.dailyLossUsd ?? 0) > 0
                    ? AppColors.danger
                    : AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: s.brokerDrawdown,
                value: state.drawdownPct != null
                    ? '${state.drawdownPct!.toStringAsFixed(2)}%'
                    : '—',
                icon: Icons.waterfall_chart,
                color: (state.drawdownPct ?? 0) > 5
                    ? AppColors.warning
                    : AppColors.accent,
              ),
            ),
          ],
        ),
        // Trades Today e Open Positions solo per metodi con dati precisi (EA, MetaAPI, cTrader, OANDA)
        // Lo screen reading non legge questi dati in modo affidabile → nascosti
        if (state.method != BrokerConnectionMethod.accessibility) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: s.brokerTradesToday,
                  value: state.tradesToday?.toString() ?? '—',
                  icon: Icons.bar_chart,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: s.brokerOpenPositions,
                  value: state.openPositions?.toString() ?? '—',
                  icon: Icons.open_in_new,
                  color: (state.openPositions ?? 0) > 0
                      ? AppColors.warning
                      : AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.manrope(
                color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends ConsumerWidget {
  final bool connected;
  const _StatusBadge({required this.connected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final color = connected ? AppColors.accent : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          connected
              ? _BrokerPulsingDot(color: color)
              : Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
          const SizedBox(width: 5),
          Text(
            connected ? s.brokerLive : s.brokerWaiting,
            style: GoogleFonts.manrope(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// Pulsing dot for the connected status badge
class _BrokerPulsingDot extends StatefulWidget {
  final Color color;
  const _BrokerPulsingDot({required this.color});

  @override
  State<_BrokerPulsingDot> createState() => _BrokerPulsingDotState();
}

class _BrokerPulsingDotState extends State<_BrokerPulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _anim.value * 0.5),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style:
                  GoogleFonts.manrope(color: AppColors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  final String text;
  const _SecurityNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Setup guide box shown at the top of each form.
class _GuideBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> steps;
  final Color accentColor;
  final String? note;

  const _GuideBox({
    required this.icon,
    required this.title,
    required this.steps,
    this.accentColor = AppColors.accent,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF4A90E2), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note!,
                      style: GoogleFonts.manrope(
                          color: const Color(0xFF4A90E2),
                          fontSize: 11,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            _Step(n: '${i + 1}', text: steps[i]),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(n,
                  style: GoogleFonts.manrope(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final bool signed;
  final bool isInt;

  const _NumField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.signed = false,
    this.isInt = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType:
            TextInputType.numberWithOptions(decimal: !isInt, signed: signed),
        style:
            GoogleFonts.manrope(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.manrope(
              color: AppColors.textSecondary, fontSize: 13),
          hintText: hint,
          hintStyle: GoogleFonts.manrope(
              color: AppColors.textSecondary, fontSize: 13),
          prefixIcon:
              Icon(icon, color: AppColors.textSecondary, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;

  const _TextField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: TextField(
        controller: ctrl,
        style:
            GoogleFonts.manrope(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.manrope(
              color: AppColors.textSecondary, fontSize: 13),
          hintText: hint,
          hintStyle: GoogleFonts.manrope(
              color: AppColors.textSecondary, fontSize: 13),
          prefixIcon:
              Icon(icon, color: AppColors.textSecondary, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EA Step-by-step Setup Guide (collapsible)
// ─────────────────────────────────────────────────────────────────────────────

class _EaSetupGuide extends ConsumerStatefulWidget {
  /// The user's webhook secret, may be null if not yet generated.
  final String? webhookSecret;

  const _EaSetupGuide({this.webhookSecret});

  @override
  ConsumerState<_EaSetupGuide> createState() => _EaSetupGuideState();
}

class _EaSetupGuideState extends ConsumerState<_EaSetupGuide> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Collapsible header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: Radius.circular(_expanded ? 0 : 16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        color: AppColors.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.brokerEaGuideTitle,
                      style: GoogleFonts.manrope(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              decoration: const BoxDecoration(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppColors.divider, height: 16),

                  // Step 1
                  _EaStep(
                    number: 1,
                    icon: Icons.download_rounded,
                    title: s.brokerEaStep1Title,
                    body: s.brokerEaStep1Body,
                  ),

                  // Step 2
                  _EaStep(
                    number: 2,
                    icon: Icons.code_rounded,
                    title: s.brokerEaStep2Title,
                    body: s.brokerEaStep2Body,
                  ),

                  // Step 3
                  _EaStep(
                    number: 3,
                    icon: Icons.add_box_outlined,
                    title: s.brokerEaStep3Title,
                    body: s.brokerEaStep3Body,
                    extra: _InfoBox(text: s.brokerEaStep3Extra),
                  ),

                  // Step 4 — shows the actual secret if available
                  _EaStep(
                    number: 4,
                    icon: Icons.vpn_key_rounded,
                    title: s.brokerEaStep4Title,
                    body: s.brokerEaStep4Body,
                    extra: widget.webhookSecret != null
                        ? _SecretBox(secret: widget.webhookSecret!)
                        : _InfoBox(text: s.brokerEaStep4Extra),
                  ),

                  // Step 5
                  _EaStep(
                    number: 5,
                    icon: Icons.play_circle_outline_rounded,
                    title: s.brokerEaStep5Title,
                    body: s.brokerEaStep5Body,
                  ),

                  // Step 6
                  _EaStep(
                    number: 6,
                    icon: Icons.check_circle_outline_rounded,
                    title: s.brokerEaStep6Title,
                    body: s.brokerEaStep6Body,
                    isLast: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A single step row inside the EA guide.
class _EaStep extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String body;
  final Widget? extra;
  final bool isLast;

  const _EaStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
    this.extra,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number circle
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.35)),
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: GoogleFonts.manrope(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 12,
                  color: AppColors.divider,
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.accent, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.manrope(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.5),
                ),
                if (extra != null) ...[
                  const SizedBox(height: 8),
                  extra!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grey info box with monospace-style text (for file names / email).
class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        text,
        style: GoogleFonts.robotoMono(
            color: AppColors.textSecondary, fontSize: 11, height: 1.4),
      ),
    );
  }
}

/// Dark box displaying the webhook secret with a copy button.
class _SecretBox extends ConsumerWidget {
  final String secret;
  const _SecretBox({required this.secret});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              secret,
              style: GoogleFonts.robotoMono(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: secret));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(s.brokerSecretCopied,
                      style: GoogleFonts.manrope(
                          color: AppColors.textPrimary)),
                  backgroundColor: AppColors.cardBg,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.copy_outlined,
                  color: AppColors.accent, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}
