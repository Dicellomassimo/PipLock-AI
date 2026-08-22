import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;
}

class _FaqSection {
  const _FaqSection({required this.title, required this.items});
  final String title;
  final List<_FaqItem> items;
}

// ---------------------------------------------------------------------------
// Locale-aware FAQ data
// ---------------------------------------------------------------------------

List<_FaqSection> _buildSections(AppStrings s) => [
  _FaqSection(
    title: s.t('GENERAL', 'GENERALE'),
    items: [
      _FaqItem(
        question: s.t("What is PipLock AI?", "Cos'e PipLock AI?"),
        answer: s.t(
          "PipLock AI is a discipline app for traders that forcibly enforces your risk management rules. It is not a technical analysis tool: it is a behavioral gatekeeper that blocks you when you are about to make classic mistakes like overtrading, revenge trading or FOMO.",
          "PipLock AI e un'app di disciplina per trader che impone forzatamente le tue regole di risk management. Non e un tool di analisi tecnica: e un gatekeeper comportamentale che ti blocca quando stai per fare errori classici come overtrading, revenge trading o FOMO.",
        ),
      ),
      _FaqItem(
        question: s.t('Does it work without internet?', 'Funziona senza connessione internet?'),
        answer: s.t(
          "For most features yes — rules and the Killswitch work offline. The AI Chat, news notifications and broker sync require a connection.",
          "Per la maggior parte delle funzioni si — le regole e il Killswitch funzionano offline. La Chat AI, le notifiche news e la sincronizzazione con il broker richiedono connessione.",
        ),
      ),
      _FaqItem(
        question: s.t('Is my trading data safe?', 'I miei dati di trading sono al sicuro?'),
        answer: s.t(
          "Yes. PipLock AI never accesses your broker account or can open/close positions. It reads only the data needed to apply your rules (equity, trade count) — via Screen Reading (Accessibility Service for mobile), EA MQL5 on MT5 desktop, MetaAPI, cTrader or OANDA API.",
          "Sì. PipLock AI non accede mai al tuo conto broker né può aprire/chiudere posizioni. Legge solo i dati necessari per applicare le tue regole (equity, numero trade) — tramite Lettura Schermo (Accessibility Service per mobile), EA MQL5 su MT5 desktop, MetaAPI, cTrader o OANDA API.",
        ),
      ),
    ],
  ),
  _FaqSection(
    title: 'KILLSWITCH',
    items: [
      _FaqItem(
        question: s.t('How does the Killswitch work?', 'Come funziona il Killswitch?'),
        answer: s.t(
          "You set your rules (max daily loss, number of trades, trading hours). When you reach a limit, PipLock activates in 2 phases:\n\n1. WARNING (60s): a banner appears over MT5 — you can still close positions. A button lets you immediately confirm you've closed the losing ones.\n\n2. LOCKDOWN: full-screen overlay blocks MT5 completely. Countdown visible. Use the 'Exit MT5' button to go to home screen, or hold the token button for 2 seconds to unlock early.\n\nPipLock itself stays accessible at all times — only the broker app is blocked.",
          "Imposti le tue regole (perdita massima, numero trade, orari). Quando raggiungi un limite, PipLock si attiva in 2 fasi:\n\n1. AVVISO (60s): un pannello appare sopra MT5 — puoi ancora chiudere le posizioni. Un bottone ti permette di confermare che hai chiuso quelle in perdita.\n\n2. BLOCCO: overlay a schermo intero blocca MT5 completamente. Countdown visibile. Usa 'Esci da MT5' per tornare alla home, oppure tieni premuto il bottone token per 2 secondi per sbloccarti anticipatamente.\n\nPipLock stesso rimane sempre accessibile — solo l'app broker viene bloccata.",
        ),
      ),
      _FaqItem(
        question: s.t('Can I unlock the Killswitch early?', 'Posso sbloccare il Killswitch prima che scada?'),
        answer: s.t(
          "Yes, using a token. You have 2 free tokens per week. You can purchase extra ones (1, 3 or 5 tokens) in the Tokens section. The operation requires holding the button for 2 seconds — an anti-impulsivity brake that prevents you from unlocking impulsively.",
          "Sì, usando un token. Hai 2 token gratuiti a settimana. Puoi acquistarne di extra (1, 3 o 5 token) nella sezione Token. L'operazione richiede tenere premuto il pulsante per 2 secondi — un freno anti-impulsività che ti impedisce di sbloccarti d'impulso.",
        ),
      ),
      _FaqItem(
        question: s.t('Does the Killswitch close my positions?', 'Il Killswitch chiude le mie posizioni?'),
        answer: s.t(
          "No. PipLock AI never has direct access to your broker account. The Killswitch only locks the app and sends you a push notification reminding you to close positions manually. This is a deliberate choice for prop firm compliance.",
          "No. PipLock AI non ha mai accesso diretto al tuo conto broker. Il Killswitch ti blocca solo l'app e ti invia una notifica push per ricordarti di chiudere le posizioni manualmente. Questa e una scelta deliberata per conformita con le prop firm.",
        ),
      ),
      _FaqItem(
        question: s.t('Does it work for prop firm challenge accounts?', 'Funziona per account challenge prop firm?'),
        answer: s.t(
          "Yes. You can use it for both personal accounts and challenges from FTMO, The5%ers, Funded Next, FunderPro and similar. The MQL5 EA is explicitly allowed by major prop firms as a personal risk management tool.",
          "Si. Puoi usarlo sia per account personali che per challenge FTMO, The5%ers, Funded Next, FunderPro e simili. L'EA MQL5 e esplicitamente consentito dalle principali prop firm come strumento di risk management personale.",
        ),
      ),
    ],
  ),
  _FaqSection(
    title: 'AI PLANNER',
    items: [
      _FaqItem(
        question: s.t('How does the AI generate the plan?', "Come genera il piano l'AI?"),
        answer: s.t(
          "You enter your challenge parameters (capital, profit target, max drawdown, duration) and desired style. PipLock's AI calculates recommended lot size, trades per day, weekly milestones and an estimate of success probability based on your parameters.",
          "Inserisci i parametri della tua challenge (capitale, profit target, max drawdown, durata) e lo stile desiderato. L'AI di PipLock calcola lot size consigliato, trade al giorno, milestone settimanali e una stima della probabilita di successo basata sui tuoi parametri.",
        ),
      ),
      _FaqItem(
        question: s.t('Does the plan update automatically?', 'Il piano si aggiorna automaticamente?'),
        answer: s.t(
          "Yes — with dynamic progression (Pro plan). If you are ahead of the plan, the AI may propose a slight risk increase using the accumulated buffer. If you are behind, it recalculates targets more conservatively.",
          "Si — con la progressione dinamica (piano Pro). Se sei in profitto rispetto al piano, l'AI puo proporre un lieve aumento del rischio usando il buffer accumulato. Se sei in perdita, ricalcola i target in modo piu conservativo.",
        ),
      ),
      _FaqItem(
        question: s.t('Can the AI trade for me?', "L'AI puo fare trading per me?"),
        answer: s.t(
          "No. PipLock AI never executes trades. It is a discipline and planning tool, not an algorithmic trading EA.",
          "No. PipLock AI non esegue mai operazioni. E un tool di disciplina e pianificazione, non un EA di trading algoritmico.",
        ),
      ),
      _FaqItem(
        question: s.t('How does the FOMO Gatekeeper work?', 'Come funziona il Gatekeeper anti-FOMO?'),
        answer: s.t(
          "The FOMO Gatekeeper (Pro plan) detects typical FOMO patterns: opening a position on an asset you were not already trading, moments after a sharp price movement. When detected, PipLock shows an intermediate alert — before a full Killswitch — with a message like \"This move already happened for 70% — are you entering late?\"\n\nTo avoid alert fatigue, a 5-minute cooldown applies between consecutive FOMO alerts on the same session.",
          "Il Gatekeeper anti-FOMO (piano Pro) rileva pattern tipici da FOMO: apertura di una posizione su un asset che non stavi già trattando, pochi istanti dopo un forte movimento di prezzo. Quando rilevato, PipLock mostra un alert intermedio — prima del Killswitch completo — con un messaggio come \"Questo movimento è già avvenuto per il 70% — stai entrando in ritardo?\"\n\nPer evitare l'overload di alert, tra un avviso FOMO e il successivo nella stessa sessione è previsto un cooldown di 5 minuti.",
        ),
      ),
    ],
  ),
  _FaqSection(
    title: s.t('NOTIFICATIONS', 'NOTIFICHE'),
    items: [
      _FaqItem(
        question: s.t(
          'Why am I not receiving economic news notifications?',
          'Perché non ricevo le notifiche sulle news economiche?',
        ),
        answer: s.t(
          "Check the following:\n\n1. Grant notification permission — Android Settings → Apps → PipLock → Notifications → All on.\n\n2. Disable battery optimization for PipLock — Android Settings → Battery → Battery optimization → PipLock → Don't optimize. This is the most common cause of missed notifications on Android.\n\n3. Notifications are scheduled automatically at app launch and every 6 hours. Open the app once to trigger the scheduling.\n\n4. Only HIGH and MEDIUM impact events generate notifications, 60 minutes and 15 minutes before the event. If no events are scheduled in the coming days, you will not receive alerts.",
          "Controlla questi punti:\n\n1. Permesso notifiche — Impostazioni Android → App → PipLock → Notifiche → Tutte attive.\n\n2. Disabilita l'ottimizzazione batteria per PipLock — Impostazioni → Batteria → Ottimizzazione batteria → PipLock → Non ottimizzare. È la causa più comune di notifiche mancate su Android.\n\n3. Le notifiche vengono schedulate automaticamente all'avvio dell'app e ogni 6 ore. Apri l'app almeno una volta per attivare la schedulazione.\n\n4. Solo gli eventi ad impatto ALTO e MEDIO generano notifiche, 60 minuti e 15 minuti prima dell'evento. Se non ci sono eventi programmati nei prossimi giorni, non riceverai alert.",
        ),
      ),
      _FaqItem(
        question: s.t(
          'Can I choose which events trigger notifications?',
          'Posso scegliere quali eventi attivano le notifiche?',
        ),
        answer: s.t(
          "Yes. In the Notifications screen you can filter by currency (USD, EUR, GBP, JPY…) and by asset. Only events relevant to your selected currencies will show in the calendar. Notifications for high-impact events (⚠️) are always sent. Medium-impact events (📊) generate only a 15-minute alert.",
          "Sì. Nella schermata Notifiche puoi filtrare per valuta (USD, EUR, GBP, JPY…) e per asset. Solo gli eventi rilevanti per le valute selezionate appariranno nel calendario. Le notifiche per eventi ad alto impatto (⚠️) vengono sempre inviate. Gli eventi a impatto medio (📊) generano solo un alert a 15 minuti.",
        ),
      ),
    ],
  ),
  _FaqSection(
    title: s.t('PERMISSIONS & PRIVACY', 'PERMESSI & PRIVACY'),
    items: [
      _FaqItem(
        question: s.t(
          'Why does the app require Accessibility and Overlay permissions?',
          "Perché l'app richiede i permessi di Accessibilità e Overlay?",
        ),
        answer: s.t(
          'Two permissions are required for the Screen Reading connection method:\n\n• Accessibility Service: reads numerical data (equity, P&L, open positions) directly from your MT5/cTrader screen on mobile. No passwords, no messages, no screenshots are ever read.\n\n• Display over other apps (Overlay): allows PipLock to show the WARNING and LOCKDOWN panels directly above the broker app when limits are exceeded, without having to open PipLock separately.\n\nBoth permissions persist until you manually disable them in Android Settings. They are not required if you connect via EA MQL5, MetaAPI, cTrader or OANDA instead.',
          "Sono richiesti due permessi per il metodo di connessione via Lettura Schermo:\n\n• Accessibility Service: legge i dati numerici (equity, P&L, posizioni aperte) direttamente dalla schermata di MT5/cTrader sul tuo telefono. Non vengono mai lette password, messaggi o screenshot.\n\n• Visualizza sopra altre app (Overlay): permette a PipLock di mostrare i pannelli AVVISO e BLOCCO direttamente sopra l'app broker quando si superano i limiti, senza dover aprire PipLock separatamente.\n\nEntrambi i permessi persistono finché non li disabiliti manualmente nelle Impostazioni Android. Non sono richiesti se ti connetti tramite EA MQL5, MetaAPI, cTrader o OANDA.",
        ),
      ),
      _FaqItem(
        question: s.t(
          'Are my trading data safe?',
          'I miei dati di trading sono al sicuro?',
        ),
        answer: s.t(
          'Yes. Data read by the Accessibility Service is processed locally on your device. Your account data (rules, killswitch history) is stored on Supabase with TLS encryption and Row Level Security — only you can access your data.',
          "Sì. I dati letti dall'Accessibility Service vengono elaborati localmente sul tuo dispositivo. I dati del tuo conto (regole, storico killswitch) sono salvati su Supabase con cifratura TLS e Row Level Security — solo tu puoi accedere ai tuoi dati.",
        ),
      ),
    ],
  ),
  _FaqSection(
    title: s.t('SUBSCRIPTION', 'ABBONAMENTO'),
    items: [
      _FaqItem(
        question: s.t('What does the Free plan include?', 'Cosa include il piano Free?'),
        answer: s.t(
          "Basic Killswitch, pre-session check-in, 2 free tokens per week for early unlock, 30-day history.",
          "Killswitch base, check-in pre-sessione, 2 token gratuiti a settimana per sblocco anticipato, storico degli ultimi 30 giorni.",
        ),
      ),
      _FaqItem(
        question: s.t('What does the Pro plan include?', 'Cosa include il piano Pro?'),
        answer: s.t(
          "Everything in Free plus: full AI Planner with dynamic progression, advanced anti-FOMO Gatekeeper, unlimited tokens, extended history (1 year), soft and hard killswitch with customizable thresholds, advanced notifications.\n\nPro is €19.99/month or €13.99/month billed annually (save 30%). A 7-day free trial is available. You are shown the Pro offer before completing registration.",
          "Tutto il Free piu: AI Planner completo con progressione dinamica, Gatekeeper anti-FOMO avanzato, token illimitati, storico esteso (1 anno), soft e hard killswitch con soglie personalizzabili, notifiche avanzate.\n\nPro costa €19,99/mese oppure €13,99/mese con fatturazione annuale (risparmio 30%). Sono disponibili 7 giorni di prova gratuita. L'offerta Pro ti viene mostrata prima di completare la registrazione.",
        ),
      ),
      _FaqItem(
        question: s.t('Can I cancel the Pro subscription?', "Posso cancellare l'abbonamento Pro?"),
        answer: s.t(
          "Yes, at any time from Google Play Store -> Subscriptions. You will continue to have Pro access until the end of the paid period.",
          "Si, in qualsiasi momento da Google Play Store -> Abbonamenti. Continuerai ad avere accesso Pro fino alla fine del periodo pagato.",
        ),
      ),
      _FaqItem(
        question: s.t('Is there a free trial?', 'Esiste una prova gratuita?'),
        answer: s.t(
          "Yes, 7 days free trial for the monthly Pro plan (€19.99/month). You can cancel at any time during the trial without being charged.",
          "Si, 7 giorni di prova gratuita per il piano Pro mensile (€19,99/mese). Puoi cancellare in qualsiasi momento durante il periodo di prova senza essere addebitato.",
        ),
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class HelpFaqScreen extends ConsumerStatefulWidget {
  const HelpFaqScreen({super.key});

  @override
  ConsumerState<HelpFaqScreen> createState() => _HelpFaqScreenState();
}

class _HelpFaqScreenState extends ConsumerState<HelpFaqScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Tracks which FAQ items are expanded: key = "sectionIndex_itemIndex"
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Returns only sections/items that match the search query.
  List<_FaqSection> _filteredSections(AppStrings s) {
    final sections = _buildSections(s);
    if (_searchQuery.isEmpty) return sections;
    final result = <_FaqSection>[];
    for (final section in sections) {
      final matchedItems = section.items.where((item) {
        return item.question.toLowerCase().contains(_searchQuery) ||
            item.answer.toLowerCase().contains(_searchQuery);
      }).toList();
      if (matchedItems.isNotEmpty) {
        result.add(_FaqSection(title: section.title, items: matchedItems));
      }
    }
    return result;
  }

  void _toggleItem(String key) {
    setState(() {
      if (_expanded.contains(key)) {
        _expanded.remove(key);
      } else {
        _expanded.add(key);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final filtered = _filteredSections(s);

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
          s.helpTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(s),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptySearch(s)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      for (int si = 0; si < filtered.length; si++) ...[
                        _buildSectionHeader(filtered[si].title),
                        const SizedBox(height: 8),
                        for (int ii = 0;
                            ii < filtered[si].items.length;
                            ii++) ...[
                          _buildFaqCard(
                            key: '${si}_$ii',
                            item: filtered[si].items[ii],
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 12),
                      ],
                      _buildContactCard(s),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.manrope(
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          hintText: s.helpSearchHint,
          hintStyle: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search,
              color: AppColors.textSecondary, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () => _searchController.clear(),
                  child: const Icon(Icons.close,
                      color: AppColors.textSecondary, size: 18),
                )
              : null,
          filled: true,
          fillColor: AppColors.cardBg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: GoogleFonts.manrope(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.3,
        ),
      ),
    );
  }

  Widget _buildFaqCard({required String key, required _FaqItem item}) {
    final isOpen = _expanded.contains(key);
    return GestureDetector(
      onTap: () => _toggleItem(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOpen ? AppColors.accent.withValues(alpha: 0.35) : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.question,
                      style: GoogleFonts.manrope(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            // Answer (animated height via ClipRect + AnimatedSize)
            if (isOpen) ...[
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.border,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Text(
                  item.answer,
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearch(AppStrings s) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              color: AppColors.textSecondary, size: 52),
          const SizedBox(height: 16),
          Text(
            s.helpNoResults,
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.helpTryKeywords,
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(AppStrings s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded,
                  color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              Text(
                s.helpMoreQuestions,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.t(
              "Couldn't find what you were looking for? Our team is ready to help.",
              "Non hai trovato quello che cercavi? Il nostro team e a disposizione per aiutarti.",
            ),
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    s.helpContactEmail,
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  backgroundColor: AppColors.cardBg,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  margin: const EdgeInsets.all(20),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.email_outlined,
                      color: Colors.black, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    s.helpContactSupport,
                    style: GoogleFonts.manrope(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
