import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PrivacyPolicyScreen extends ConsumerStatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  ConsumerState<PrivacyPolicyScreen> createState() =>
      _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends ConsumerState<PrivacyPolicyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: AppColors.textPrimary, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          s.privacyTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _buildTabBar(s),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrivacyContent(s),
          _buildTermsContent(s),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab bar
  // ---------------------------------------------------------------------------

  Widget _buildTabBar(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          labelColor: Colors.black,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: s.privacyTabPrivacy),
            Tab(text: s.privacyTabTerms),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared layout helpers
  // ---------------------------------------------------------------------------

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    );
  }

  Widget _sectionBody(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        color: AppColors.textSecondary,
        fontSize: 13,
        height: 1.65,
      ),
    );
  }

  Widget _divider() => const Divider(
        height: 32,
        thickness: 1,
        color: AppColors.divider,
      );

  Widget _metaLine(AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.privacyLastUpdated,
          style: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
        Text(
          s.t('Version 1.0', 'Versione 1.0'),
          style: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Privacy Policy content
  // ---------------------------------------------------------------------------

  Widget _buildPrivacyContent(AppStrings s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.logoGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_outline,
                    color: Colors.black, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                s.t('Privacy Policy', 'Privacy Policy'),
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _metaLine(s),
          _divider(),

          // Sezione 1 — Chi siamo
          _sectionTitle(s.t('1. Who we are', '1. Chi siamo')),
          const SizedBox(height: 10),
          _sectionBody(s.t(
            'PipLock AI is a trading discipline application that helps traders respect their own risk management rules. It is developed for prop firm challenge traders and personal account traders.\n\nContact: support.piplock@gmail.com',
            'PipLock AI è un\'applicazione per la disciplina nel trading che aiuta i trader a rispettare le proprie regole di risk management. È sviluppata per trader in challenge prop firm e per account personali.\n\nContatto: support.piplock@gmail.com',
          )),
          _divider(),

          // Sezione 2 — Dati che raccogliamo
          _sectionTitle(s.t('2. Data we collect', '2. Dati che raccogliamo')),
          const SizedBox(height: 10),
          _sectionBody(s.t(
            'We collect only the data strictly necessary for the service to function:',
            'Raccogliamo solo i dati strettamente necessari al funzionamento del servizio:',
          )),
          const SizedBox(height: 12),
          _dataPointRow(Icons.email_outlined, AppColors.accent,
              s.t('Email and password (authentication via Supabase Auth)', 'Email e password (autenticazione tramite Supabase Auth)')),
          _dataPointRow(Icons.tune_rounded, AppColors.accent,
              s.t('Trading rules set by the user (max loss, trade count, hours)', 'Regole di trading impostate dall\'utente (perdita massima, numero trade, orari)')),
          _dataPointRow(Icons.bar_chart_rounded, AppColors.accent,
              s.t('Broker account performance data (equity, P&L, number of open positions) — only if the user connects a broker', 'Dati di performance del conto broker (equity, P&L, numero posizioni) — solo se l\'utente connette un broker')),
          _dataPointRow(Icons.mood_rounded, AppColors.accent,
              s.t('Pre-session check-in scores (stored locally on device, not transmitted)', 'Punteggi check-in pre-sessione (salvati localmente sul dispositivo, non trasmessi)')),
          _dataPointRow(Icons.notifications_outlined, AppColors.accent,
              s.t('FCM token for push notifications', 'Token FCM per notifiche push')),
          _dataPointRow(Icons.payment_rounded, AppColors.accent,
              s.t('Purchase data (managed by Google Play, not stored by us)', 'Dati di acquisto (gestiti da Google Play, non archiviati da noi)')),
          _divider(),

          // Sezione 3 — Accessibility Service (CRITICAL)
          _accessibilitySection(s),
          _divider(),

          // Sezione 4 — Come usiamo i dati
          _sectionTitle(s.t('4. How we use your data', '4. Come usiamo i dati')),
          const SizedBox(height: 10),
          _bulletList([
            s.t('Provide the Killswitch and risk monitoring service', 'Fornire il servizio di Killswitch e monitoraggio rischio'),
            s.t('Generate the AI plan for prop firm challenges', 'Generare il piano AI per challenge prop firm'),
            s.t('Send notifications about relevant economic events', 'Inviare notifiche su eventi economici rilevanti'),
            s.t('Improve user experience (aggregated anonymous data)', 'Migliorare l\'esperienza utente (dati aggregati anonimi)'),
          ]),
          _divider(),

          // Sezione 5 — Conservazione
          _sectionTitle(s.t('5. Data retention', '5. Conservazione dei dati')),
          const SizedBox(height: 10),
          _bulletList([
            s.t('Account data: retained while the account is active', 'Dati account: conservati finché l\'account è attivo'),
            s.t('Broker data: not stored permanently, updated in real time', 'Dati broker: non conservati permanentemente, aggiornati in tempo reale'),
            s.t('Check-in data: stored locally on the device', 'Dati check-in: conservati localmente sul dispositivo'),
            s.t('Deletion: users can request complete cancellation at support.piplock@gmail.com', 'Eliminazione: l\'utente può richiedere la cancellazione completa via support.piplock@gmail.com'),
          ]),
          _divider(),

          // Sezione 6 — Terze parti
          _sectionTitle(s.t('6. Third-party services', '6. Servizi di terze parti')),
          const SizedBox(height: 12),
          _thirdPartyTable(s),
          _divider(),

          // Sezione 7 — Diritti GDPR
          _sectionTitle(s.t('7. Your rights (GDPR)', '7. Diritti dell\'utente (GDPR)')),
          const SizedBox(height: 10),
          _bulletList([
            s.t('Right of access to your data', 'Diritto di accesso ai propri dati'),
            s.t('Right of rectification', 'Diritto di rettifica'),
            s.t('Right to erasure ("right to be forgotten")', 'Diritto alla cancellazione ("diritto all\'oblio")'),
            s.t('Right to data portability', 'Diritto di portabilità'),
          ]),
          const SizedBox(height: 10),
          _sectionBody(s.t(
            'To exercise these rights, contact: support.piplock@gmail.com',
            'Per esercitare questi diritti, contatta: support.piplock@gmail.com',
          )),
          _divider(),

          // Sezione 8 — Sicurezza
          _sectionTitle(s.t('8. Security', '8. Sicurezza')),
          const SizedBox(height: 10),
          _sectionBody(s.t(
            'Data is protected with TLS encryption in transit and stored on Supabase servers with Row Level Security (RLS) enabled. Each user can only access their own data.',
            'I dati sono protetti con crittografia TLS in transito e archiviati su server Supabase con Row Level Security (RLS) attivato. Ogni utente può accedere solo ai propri dati.',
          )),
          _divider(),

          // Sezione 9 — Minori
          _sectionTitle(s.t('9. Minors', '9. Minori')),
          const SizedBox(height: 10),
          _sectionBody(s.t(
            'The app is not intended for users under 18 years of age. We do not knowingly collect data from minors.',
            'L\'app non è destinata a utenti di età inferiore ai 18 anni. Non raccogliamo consapevolmente dati di minori.',
          )),
          _divider(),

          // Sezione 10 — Modifiche
          _sectionTitle(s.t('10. Changes to this Privacy Policy', '10. Modifiche alla Privacy Policy')),
          const SizedBox(height: 10),
          _sectionBody(s.t(
            'We will notify users of significant changes via in-app notification or email.',
            'Notificheremo gli utenti di modifiche significative tramite notifica in-app o email.',
          )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Accessibility Service section (highlighted)
  // ---------------------------------------------------------------------------

  Widget _accessibilitySection(AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
            s.t('3. Use of Accessibility Service', '3. Uso dell\'Accessibility Service')),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    s.t('Accessibility Service — Purpose', 'Accessibility Service — Scopo'),
                    style: GoogleFonts.manrope(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                s.t(
                  'PipLock AI requests the activation of the Android Accessibility Service exclusively for the following functions:',
                  'PipLock AI richiede l\'attivazione del Servizio di Accessibilità Android esclusivamente per le seguenti funzioni:',
                ),
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 10),
              _accessBullet(Icons.app_shortcut_rounded,
                  s.t('Active broker app detection: the app identifies when the user opens a trading application (MetaTrader 5, cTrader or similar) to activate risk monitoring.',
                      'Rilevamento dell\'app broker attiva: l\'app identifica quando l\'utente apre un\'applicazione di trading (MetaTrader 5, cTrader o simili) per attivare il monitoraggio del rischio.')),
              _accessBullet(Icons.monitor_rounded,
                  s.t('Trading data reading: only numerical data visible on screen related to the trading account is read (equity, balance, P&L, number of open positions).',
                      'Lettura dei dati di trading: vengono letti esclusivamente i dati numerici visibili sullo schermo relativi al conto di trading (equity, bilancio, P&L, numero di posizioni aperte).')),
              _accessBullet(Icons.lock_rounded,
                  s.t('Killswitch activation: when the data read exceeds the limits set by the user, the app activates the temporary block.',
                      'Attivazione del Killswitch: quando i dati letti superano i limiti impostati dall\'utente, l\'app attiva il blocco temporaneo.')),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t('PipLock AI\'s Accessibility Service does NOT:',
                          'L\'Accessibility Service di PipLock AI NON:'),
                      style: GoogleFonts.manrope(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _noAccessBullet(s.t('Read passwords, authentication data or personal information',
                        'Legge password, dati di autenticazione o informazioni personali')),
                    _noAccessBullet(s.t('Access content from non-trading apps',
                        'Accede a contenuti di app non di trading')),
                    _noAccessBullet(s.t('Transmit screen data to external servers',
                        'Trasmette dati dello schermo a server esterni')),
                    _noAccessBullet(s.t('Record or store screenshots',
                        'Registra o memorizza screenshot')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s.t(
                  'Data read by the Accessibility Service is processed locally on the device and used exclusively to verify compliance with the risk management rules set by the user.',
                  'I dati letti dall\'Accessibility Service vengono elaborati localmente sul dispositivo e utilizzati esclusivamente per verificare il rispetto delle regole di risk management impostate dall\'utente.',
                ),
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _accessBullet(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.warning, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noAccessBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.close_rounded, color: AppColors.danger, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Third-party table
  // ---------------------------------------------------------------------------

  Widget _thirdPartyTable(AppStrings s) {
    final rows = [
      _ThirdParty('Supabase',
          s.t('Database and authentication', 'Database e autenticazione'),
          'https://supabase.com/privacy'),
      _ThirdParty('Firebase (Google)',
          s.t('Push notifications', 'Notifiche push'),
          'https://firebase.google.com/support/privacy'),
      _ThirdParty('Google Play Billing',
          s.t('Subscription management', 'Gestione abbonamenti'),
          'https://policies.google.com/privacy'),
      _ThirdParty('Groq',
          s.t('AI plan generation (anonymous data)', 'Generazione piano AI (dati anonimi)'),
          'https://groq.com/privacy'),
      _ThirdParty('Finnhub',
          s.t('Economic events calendar', 'Calendario eventi economici'),
          'https://finnhub.io/privacy-policy'),
    ];

    return Column(
      children: rows
          .map(
            (r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: GoogleFonts.manrope(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.purpose,
                          style: GoogleFonts.manrope(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openUrl(r.url),
                    child: Text(
                      s.t('Policy', 'Policy'),
                      style: GoogleFonts.manrope(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  Widget _dataPointRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletList(List<String> items) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: CircleAvatar(
                      radius: 3,
                      backgroundColor: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.65,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Terms of Service content
  // ---------------------------------------------------------------------------

  Widget _buildTermsContent(AppStrings s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.logoGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.gavel_rounded,
                    color: Colors.black, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                s.t('Terms of Service', 'Termini di Servizio'),
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _metaLine(s),
          _divider(),

          // Art. 1 — Accettazione
          _sectionTitle(s.t('Art. 1 — Acceptance', 'Art. 1 — Accettazione')),
          const SizedBox(height: 10),
          _sectionBody(s.t(
            'By using PipLock AI you accept these Terms of Service. If you do not agree, do not use the app.',
            'Usando PipLock AI accetti questi Termini di Servizio. Se non accetti, non usare l\'app.',
          )),
          _divider(),

          // Art. 2 — Descrizione del servizio
          _sectionTitle(s.t('Art. 2 — Service description', 'Art. 2 — Descrizione del servizio')),
          const SizedBox(height: 10),
          _sectionBody(s.t(
            'PipLock AI is a behavioral discipline tool for traders. It is NOT:',
            'PipLock AI è uno strumento di disciplina comportamentale per trader. NON è:',
          )),
          const SizedBox(height: 8),
          _bulletList([
            s.t('A financial advisory service', 'Un servizio di consulenza finanziaria'),
            s.t('An automated trading system', 'Un sistema di trading automatico'),
            s.t('A tool to increase profits', 'Uno strumento per aumentare i profitti'),
          ]),
          const SizedBox(height: 8),
          _sectionBody(s.t(
            'The app helps traders respect their own rules, but does not guarantee any financial results.',
            'L\'app aiuta il trader a rispettare le proprie regole, ma non garantisce risultati economici.',
          )),
          _divider(),

          // Art. 3 — Disclaimer rischio (highlighted)
          _financialDisclaimerSection(s),
          _divider(),

          // Art. 4 — Account
          _sectionTitle(s.t('Art. 4 — User account', 'Art. 4 — Account utente')),
          const SizedBox(height: 10),
          _sectionBody(s.t(
            'The user is responsible for the security of their account and for the rules they configure. Credentials must not be shared with third parties.',
            'L\'utente è responsabile della sicurezza del proprio account e delle regole impostate. Le credenziali non devono essere condivise con terze parti.',
          )),
          _divider(),

          // Art. 5 — Abbonamento
          _sectionTitle(s.t('Art. 5 — Subscription and payments', 'Art. 5 — Abbonamento e pagamenti')),
          const SizedBox(height: 12),
          _pricingTable(s),
          const SizedBox(height: 12),
          _bulletList([
            s.t('Payments are managed by Google Play Billing', 'I pagamenti sono gestiti da Google Play Billing'),
            s.t('Cancellation: via Google Play, effective at end of billing period', 'Cancellazione: tramite Google Play, effettiva a fine periodo di fatturazione'),
            s.t('Refunds: according to the Google Play policy', 'Rimborsi: secondo la policy Google Play'),
          ]),
          _divider(),

          // Art. 6 — Uso accettabile
          _sectionTitle(s.t('Art. 6 — Acceptable use', 'Art. 6 — Uso accettabile')),
          const SizedBox(height: 10),
          _sectionBody(s.t('The user may not:', 'L\'utente non può:')),
          const SizedBox(height: 8),
          _bulletList([
            s.t('Use the app for illegal purposes', 'Usare l\'app per scopi illegali'),
            s.t('Attempt to fraudulently bypass the Killswitch', 'Tentare di bypassare il Killswitch in modo fraudolento'),
            s.t('Share credentials with other users', 'Condividere credenziali con altri utenti'),
          ]),
          _divider(),

          // Art. 7 — Limitazione responsabilità
          _sectionTitle(s.t('Art. 7 — Limitation of liability', 'Art. 7 — Limitazione di responsabilità')),
          const SizedBox(height: 10),
          _sectionBody(s.t(
            'PipLock AI is not responsible for indirect damages, loss of profits, or service interruptions. The service is provided "as is" without guarantees of continuity or accuracy.',
            'PipLock AI non è responsabile per danni indiretti, perdita di profitti, o interruzioni del servizio. Il servizio è fornito "così com\'è" senza garanzie di continuità o accuratezza.',
          )),
          _divider(),

          // Art. 8 — Legge applicabile
          _sectionTitle(s.t('Art. 8 — Governing law', 'Art. 8 — Legge applicabile')),
          const SizedBox(height: 10),
          _sectionBody(s.t(
            'These Terms are governed by Italian law. Competent court: Italy.',
            'Questi Termini sono regolati dalla legge italiana. Foro competente: Italia.',
          )),
          _divider(),

          // Art. 9 — Contatti
          _sectionTitle(s.t('Art. 9 — Contacts', 'Art. 9 — Contatti')),
          const SizedBox(height: 10),
          _sectionBody('support.piplock@gmail.com'),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Financial disclaimer (highlighted in red)
  // ---------------------------------------------------------------------------

  Widget _financialDisclaimerSection(AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(s.t('Art. 3 — Financial risk disclaimer', 'Art. 3 — Disclaimer rischio finanziario')),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    s.t('Important', 'Importante'),
                    style: GoogleFonts.manrope(
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                s.t(
                  'TRADING ON FINANCIAL MARKETS INVOLVES SIGNIFICANT RISKS, INCLUDING TOTAL LOSS OF INVESTED CAPITAL. PIPLOCK AI IS NOT RESPONSIBLE FOR FINANCIAL LOSSES ARISING FROM THE USE OR NON-USE OF THE APPLICATION. THE KILLSWITCH AND MONITORING FUNCTIONS ARE TOOLS TO SUPPORT DISCIPLINE, NOT GUARANTEES OF PROTECTION FROM RISK.',
                  'IL TRADING SU MERCATI FINANZIARI COMPORTA RISCHI SIGNIFICATIVI, INCLUSA LA PERDITA TOTALE DEL CAPITALE INVESTITO. PIPLOCK AI NON È RESPONSABILE DI PERDITE FINANZIARIE DERIVANTI DALL\'USO O DAL MANCATO USO DELL\'APPLICAZIONE. LE FUNZIONI DI KILLSWITCH E MONITORAGGIO SONO STRUMENTI DI SUPPORTO ALLA DISCIPLINA, NON GARANZIE DI PROTEZIONE DAL RISCHIO.',
                ),
                style: GoogleFonts.manrope(
                  color: AppColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Pricing table
  // ---------------------------------------------------------------------------

  Widget _pricingTable(AppStrings s) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _priceRow(
            s.t('Free plan', 'Piano Free'),
            s.t('Basic Killswitch + 2 tokens/week', 'Killswitch base + 2 token/settimana'),
            s.t('Free', 'Gratuito'),
            AppColors.textSecondary,
            isFirst: true,
          ),
          Divider(height: 1, thickness: 1, color: AppColors.divider),
          _priceRow(
            s.t('Pro — monthly', 'Pro — mensile'),
            s.t('Full AI Planner + unlimited tokens + 7-day trial', 'AI Planner completo + token illimitati + 7 giorni di prova'),
            '€19.99',
            AppColors.accent,
          ),
          Divider(height: 1, thickness: 1, color: AppColors.divider),
          _priceRow(
            s.t('Pro — yearly', 'Pro — annuale'),
            s.t('€13.99/month — save 30% vs monthly', '€13,99/mese — risparmia il 30% rispetto al mensile'),
            '€167.88',
            AppColors.accent,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String plan, String description, String price, Color priceColor,
      {bool isFirst = false, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(12) : Radius.zero,
          bottom: isLast ? const Radius.circular(12) : Radius.zero,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan,
                    style: GoogleFonts.manrope(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(description,
                    style: GoogleFonts.manrope(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(price,
              style: GoogleFonts.manrope(
                  color: priceColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data helpers
// ---------------------------------------------------------------------------

class _ThirdParty {
  const _ThirdParty(this.name, this.purpose, this.url);
  final String name;
  final String purpose;
  final String url;
}
