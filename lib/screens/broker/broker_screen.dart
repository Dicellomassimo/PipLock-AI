import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../providers/broker_provider.dart';
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
                          if (_selectedMethod != null && !state.hasAccount) {
                            setState(() => _selectedMethod = null);
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
                child: state.hasAccount
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
                      'Choose how to connect your broker account',
                      style: GoogleFonts.manrope(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PipLock reads account data — never executes orders.',
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
          subtitle: 'Desktop / VPS',
          accuracyBadge: '100% Accurate',
          accuracyColor: AppColors.accent,
          description:
              'An Expert Advisor runs inside MetaTrader 5 and sends real account data to PipLock via webhook. The most precise method — reads actual equity, drawdown and trade count.',
          setupGuide: const [
            'Download MetaTrader 5 for Windows from metatrader5.com (free)',
            'Open MetaEditor (F4 inside MT5) and create a new Expert Advisor',
            'Copy the PipLock EA code (tap "Activate EA Connection" below)',
            'Enable WebRequest in MT5: Tools → Options → Expert Advisors → check "Allow WebRequest for listed URL" → add your Supabase URL',
            'Compile the EA (F7) and attach it to any chart',
            'Enter your webhook secret in PipLock — your trades will be monitored in real time via Supabase Realtime.',
          ],
          onTap: () => setState(() => _selectedMethod = BrokerConnectionMethod.ea),
        ),

        const SizedBox(height: 12),

        // cTrader Open API
        _MethodCard(
          icon: Icons.account_balance_outlined,
          title: 'cTrader Open API',
          subtitle: 'Pepperstone, IC Markets, FxPro & more',
          accuracyBadge: '99% Accurate',
          accuracyColor: AppColors.accent,
          description:
              'Connect directly using your cTrader access token and account ID. No PC required — works from your phone with full equity and position data.',
          setupGuide: const [
            'Log into your cTrader platform (desktop or web)',
            'Go to Settings → API → Generate Access Token',
            'Copy your Account ID (visible in your account overview)',
            'Paste both into PipLock below',
            'No PC required — works directly from your phone.',
          ],
          onTap: () =>
              setState(() => _selectedMethod = BrokerConnectionMethod.ctrader),
        ),

        const SizedBox(height: 12),

        // OANDA REST API
        _MethodCard(
          icon: Icons.api_outlined,
          title: 'OANDA REST API',
          subtitle: 'OANDA Live & Practice accounts',
          accuracyBadge: '99% Accurate',
          accuracyColor: AppColors.accent,
          description:
              'Connect your OANDA account using a Personal Access Token. Supports both live and practice accounts. No extra software needed.',
          setupGuide: const [
            'Go to my.oanda.com → My Account → Manage API Access',
            'Generate a Personal Access Token',
            'Find your Account ID in Account Details',
            'Select Live or Practice and paste both into PipLock',
            'No extra software needed.',
          ],
          onTap: () =>
              setState(() => _selectedMethod = BrokerConnectionMethod.oanda),
        ),

        const SizedBox(height: 12),

        // MetaAPI Cloud
        _MethodCard(
          icon: Icons.cloud_sync_outlined,
          title: 'MetaAPI Cloud',
          subtitle: 'Most MT4/MT5 brokers',
          accuracyBadge: '98% Accurate',
          accuracyColor: AppColors.accent,
          description:
              'Connect your MT4/MT5 account via MetaAPI Cloud. Enter your MetaAPI Account ID to read equity, P&L and positions in real time. Free tier available.',
          setupGuide: const [
            'Go to app.metaapi.cloud and create a free account',
            'Click "Add Account" and enter your MT5 broker credentials',
            'Copy your MetaAPI Account ID from the dashboard',
            'Paste it into PipLock below',
            'Note: MetaAPI free tier has limited requests. Upgrade for continuous monitoring.',
          ],
          onTap: () =>
              setState(() => _selectedMethod = BrokerConnectionMethod.metaApi),
        ),

        const SizedBox(height: 12),

        // Screen Reading (MT5 Mobile)
        _MethodCard(
          icon: Icons.phone_android_outlined,
          title: 'Screen Reading (MT5 Mobile)',
          subtitle: 'MetaTrader 5 Android, MetaTrader 4 Android',
          accuracyBadge: '~70% · Improving',
          accuracyColor: const Color(0xFF4A90E2),
          description:
              'PipLock uses the Android Accessibility Service to read equity and P&L directly from the broker app screen. No credentials required. Continuously improving.',
          setupGuide: const [
            'Tap "Enable Accessibility Service" below',
            'Find PipLock in the list and enable it',
            'Open MetaTrader 5 and navigate to your Trade tab',
            'PipLock will read your account data automatically',
            'Note: Keep PipLock active in background for continuous monitoring.',
          ],
          onTap: () => setState(
              () => _selectedMethod = BrokerConnectionMethod.accessibility),
        ),

        const SizedBox(height: 12),

        // Manual Entry
        _MethodCard(
          icon: Icons.edit_outlined,
          title: 'Manual Entry',
          subtitle: 'Any broker',
          accuracyBadge: 'You decide',
          accuracyColor: AppColors.textSecondary,
          description:
              'Enter your account data manually after each trading session. PipLock applies your rules to the data you enter. Works with any broker or platform.',
          setupGuide: const [
            'Tap "Update Data" below to enter your latest account figures',
            'You manually enter equity, balance, P&L and open positions',
            'PipLock checks your limits every time you press Update',
            'Accuracy depends entirely on your honesty with yourself',
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
      case BrokerConnectionMethod.ctrader:
        return _CTraderForm(state: state);
      case BrokerConnectionMethod.oanda:
        return _OandaForm(state: state);
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

  Future<void> _disconnect() async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.brokerDisconnect,
            style: GoogleFonts.manrope(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
            s.t(
              'Do you want to remove the broker connection? Monitoring will stop.',
              'Vuoi rimuovere la connessione al broker? Il monitoraggio si fermerà.',
            ),
            style: GoogleFonts.manrope(
                color: AppColors.textSecondary, fontSize: 14)),
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
        return 'EA MQL5 — Desktop/VPS';
      case BrokerConnectionMethod.ctrader:
        return 'cTrader Open API';
      case BrokerConnectionMethod.oanda:
        return 'OANDA REST API';
      case BrokerConnectionMethod.metaApi:
        return 'MetaAPI Live';
      case BrokerConnectionMethod.accessibility:
        return 'Screen Reading (MT5 Mobile)';
      case BrokerConnectionMethod.manual:
        return 'Manual Entry';
      default:
        return 'Broker';
    }
  }

  String _methodDescription(BrokerConnectionMethod method, AppStrings s) {
    switch (method) {
      case BrokerConnectionMethod.ea:
        return 'Data incoming from EA on MT5';
      case BrokerConnectionMethod.ctrader:
        return 'Live data via cTrader REST API';
      case BrokerConnectionMethod.oanda:
        return 'Live data via OANDA REST API';
      case BrokerConnectionMethod.metaApi:
        return 'Live data via MetaAPI Cloud';
      case BrokerConnectionMethod.accessibility:
        return 'Screen reading MT5 mobile';
      case BrokerConnectionMethod.manual:
        return 'Manually entered data';
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
// Form: cTrader Open API
// ─────────────────────────────────────────────────────────────────────────────

class _CTraderForm extends ConsumerStatefulWidget {
  final BrokerState state;
  const _CTraderForm({required this.state});

  @override
  ConsumerState<_CTraderForm> createState() => _CTraderFormState();
}

class _CTraderFormState extends ConsumerState<_CTraderForm> {
  final _tokenCtrl = TextEditingController();
  final _accountIdCtrl = TextEditingController();
  bool _obscureToken = true;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _accountIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brokerState = ref.watch(brokerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GuideBox(
          icon: Icons.account_balance_outlined,
          title: 'cTrader Open API Setup',
          steps: const [
            'Log into your cTrader platform (desktop or web)',
            'Go to Settings → API → Generate Access Token',
            'Copy your Account ID (visible in your account overview)',
            'Paste both into PipLock below',
            'No PC required — works directly from your phone.',
          ],
        ),

        const SizedBox(height: 20),

        Text(
          'Access Token',
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
            controller: _tokenCtrl,
            obscureText: _obscureToken,
            style: GoogleFonts.manrope(
                color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Paste your cTrader access token',
              hintStyle: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.vpn_key_outlined,
                  color: AppColors.textSecondary, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureToken ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureToken = !_obscureToken),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Account ID',
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
              hintText: 'e.g. 12345678',
              hintStyle: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.numbers_outlined,
                  color: AppColors.textSecondary, size: 20),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 20),

        if (brokerState.error != null) ...[
          _ErrorBanner(message: brokerState.error!),
          const SizedBox(height: 16),
        ],

        PremiumButton(
          label: 'Connect cTrader',
          icon: Icons.link_rounded,
          loading: brokerState.isConnecting,
          onTap: brokerState.isConnecting ? null : _connect,
        ),

        const SizedBox(height: 16),
        _SecurityNote(
            text:
                'Your access token is stored securely on this device and never sent anywhere except to the cTrader API. PipLock never executes orders.'),
      ],
    );
  }

  Future<void> _connect() async {
    final token = _tokenCtrl.text.trim();
    final accountId = _accountIdCtrl.text.trim();
    if (token.isEmpty || accountId.isEmpty) return;
    await ref.read(brokerProvider.notifier).connectCTrader(token, accountId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form: OANDA REST API
// ─────────────────────────────────────────────────────────────────────────────

class _OandaForm extends ConsumerStatefulWidget {
  final BrokerState state;
  const _OandaForm({required this.state});

  @override
  ConsumerState<_OandaForm> createState() => _OandaFormState();
}

class _OandaFormState extends ConsumerState<_OandaForm> {
  final _apiKeyCtrl = TextEditingController();
  final _accountIdCtrl = TextEditingController();
  bool _obscureKey = true;
  bool _isDemo = false;

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _accountIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brokerState = ref.watch(brokerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GuideBox(
          icon: Icons.api_outlined,
          title: 'OANDA REST API Setup',
          steps: const [
            'Go to my.oanda.com → My Account → Manage API Access',
            'Generate a Personal Access Token',
            'Find your Account ID in Account Details',
            'Select Live or Practice and paste both into PipLock',
            'No extra software needed.',
          ],
        ),

        const SizedBox(height: 20),

        Text(
          'Personal Access Token',
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
            controller: _apiKeyCtrl,
            obscureText: _obscureKey,
            style: GoogleFonts.manrope(
                color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Paste your OANDA API key',
              hintStyle: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.vpn_key_outlined,
                  color: AppColors.textSecondary, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Account ID',
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
              hintText: 'e.g. 001-001-1234567-001',
              hintStyle: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.numbers_outlined,
                  color: AppColors.textSecondary, size: 20),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Live / Practice toggle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isDemo ? 'Practice Account' : 'Live Account',
                      style: GoogleFonts.manrope(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    Text(
                      _isDemo
                          ? 'Using api-fxpractice.oanda.com'
                          : 'Using api-fxtrade.oanda.com',
                      style: GoogleFonts.manrope(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isDemo,
                onChanged: (v) => setState(() => _isDemo = v),
                activeThumbColor: AppColors.accent,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        if (brokerState.error != null) ...[
          _ErrorBanner(message: brokerState.error!),
          const SizedBox(height: 16),
        ],

        PremiumButton(
          label: 'Connect OANDA',
          icon: Icons.link_rounded,
          loading: brokerState.isConnecting,
          onTap: brokerState.isConnecting ? null : _connect,
        ),

        const SizedBox(height: 16),
        _SecurityNote(
            text:
                'Your API key is stored securely on this device and only used to call the official OANDA API. PipLock never executes orders.'),
      ],
    );
  }

  Future<void> _connect() async {
    final apiKey = _apiKeyCtrl.text.trim();
    final accountId = _accountIdCtrl.text.trim();
    if (apiKey.isEmpty || accountId.isEmpty) return;
    await ref
        .read(brokerProvider.notifier)
        .connectOanda(apiKey, accountId, isDemo: _isDemo);
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
                          'Open MT5 or cTrader to start reading data.',
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
                    'To show the Killswitch and FOMO Gatekeeper over MT5 or cTrader, PipLock needs the "Display over other apps" permission. Without this, the overlay will not appear while trading.',
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
      BrokerConnectionMethod.ctrader => 'cTrader API',
      BrokerConnectionMethod.oanda => 'OANDA API',
      BrokerConnectionMethod.metaApi => 'MetaAPI Live',
      BrokerConnectionMethod.accessibility => 'Screen Reading',
      BrokerConnectionMethod.manual => 'Manual',
      _ => 'Broker',
    };
    final icon = switch (method) {
      BrokerConnectionMethod.ea => Icons.computer_outlined,
      BrokerConnectionMethod.ctrader => Icons.account_balance_outlined,
      BrokerConnectionMethod.oanda => Icons.api_outlined,
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

class _EaSetupGuide extends StatefulWidget {
  /// The user's webhook secret, may be null if not yet generated.
  final String? webhookSecret;

  const _EaSetupGuide({this.webhookSecret});

  @override
  State<_EaSetupGuide> createState() => _EaSetupGuideState();
}

class _EaSetupGuideState extends State<_EaSetupGuide> {
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
                      'Come configurare l\'EA su MT5',
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
                    title: 'Scarica MetaTrader 5',
                    body:
                        'Scarica MT5 gratis da metatrader.com/en/trading-platform/metatrader5/ e installalo sul tuo PC o VPS.',
                  ),

                  // Step 2
                  _EaStep(
                    number: 2,
                    icon: Icons.code_rounded,
                    title: 'Apri MetaEditor',
                    body:
                        'In MT5, premi F4 (oppure Strumenti → MetaEditor) per aprire l\'editor MQL5.',
                  ),

                  // Step 3
                  _EaStep(
                    number: 3,
                    icon: Icons.add_box_outlined,
                    title: 'Crea il file EA',
                    body:
                        'In MetaEditor: File → Nuovo → Expert Advisor. Copia il codice EA da questo link (o chiedi a PipLock Support il file .mq5).',
                    extra: _InfoBox(text: 'PipLockEA.mq5 — disponibile su support@piplock.app'),
                  ),

                  // Step 4 — shows the actual secret if available
                  _EaStep(
                    number: 4,
                    icon: Icons.vpn_key_rounded,
                    title: 'Inserisci il tuo Webhook Secret',
                    body:
                        'Nel codice EA, alla riga InpWebhookSecret, incolla il tuo secret:',
                    extra: widget.webhookSecret != null
                        ? _SecretBox(secret: widget.webhookSecret!)
                        : _InfoBox(
                            text:
                                'Genera prima il secret premendo "Attiva connessione EA" qui sopra.'),
                  ),

                  // Step 5
                  _EaStep(
                    number: 5,
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Compila e avvia l\'EA',
                    body:
                        'Premi F7 per compilare. Poi in MT5 trascina l\'EA sul grafico del tuo account. Assicurati che "Allow WebRequests" sia abilitato in Opzioni → Expert Advisors, e aggiungi l\'URL: https://[il tuo progetto].supabase.co',
                  ),

                  // Step 6
                  _EaStep(
                    number: 6,
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Verifica connessione',
                    body:
                        'Se la connessione funziona, in questa schermata vedrai lo stato cambiare in "Connesso ✓". L\'EA invierà i dati ogni pochi secondi.',
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
