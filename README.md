# PipLock AI

**Disciplina forzata per trader: regole, challenge, AI Planner e Killswitch Android.**

PipLock AI è un'applicazione Flutter orientata ad Android che aiuta i trader a rispettare le proprie regole operative. L'app combina monitoraggio del comportamento, limiti giornalieri, challenge prop firm, diario di trading, notifiche di mercato e overlay Android per introdurre una barriera concreta quando viene raggiunto un limite.

> **Importante:** PipLock AI è uno strumento di disciplina e gestione del rischio. Non fornisce consulenza finanziaria, segnali di trading, gestione del conto o garanzie sui risultati. Il trading comporta il rischio di perdita del capitale.

---

## Indice

- [Funzionalità](#funzionalità)
- [Architettura](#architettura)
- [Tecnologie](#tecnologie)
- [Struttura del progetto](#struttura-del-progetto)
- [Requisiti](#requisiti)
- [Configurazione locale](#configurazione-locale)
- [Configurazione Supabase](#configurazione-supabase)
- [Configurazione Firebase](#configurazione-firebase)
- [Configurazione Android](#configurazione-android)
- [Integrazioni broker](#integrazioni-broker)
- [AI Planner](#ai-planner)
- [Notifiche e calendario economico](#notifiche-e-calendario-economico)
- [Build e test](#build-e-test)
- [Sicurezza](#sicurezza)
- [Stato del progetto](#stato-del-progetto)
- [Documentazione aggiuntiva](#documentazione-aggiuntiva)

---

## Funzionalità

### Killswitch

Il Killswitch applica un blocco temporaneo quando vengono superati i limiti configurati dall'utente, tra cui:

- perdita massima giornaliera;
- numero massimo di trade;
- pattern di revenge trading;
- pattern FOMO;
- overleveraging;
- perdite consecutive;
- rientro troppo rapido dopo la chiusura di un trade;
- violazione del piano;
- fuoriuscita dagli orari di trading.

Su Android il blocco può essere mostrato come overlay sopra l'app broker. La durata può essere configurata, ad esempio, per 2 ore, 6 ore, fino a mezzanotte o 24 ore.

### FOMO Gatekeeper

Il Gatekeeper introduce una conferma prima o durante un comportamento considerato impulsivo. La rilevazione può essere attivata da eventi come l'apertura rapida di una posizione o un ingresso successivo a una notizia ad alto impatto.

### Challenge prop firm

È possibile creare e seguire challenge con:

- prop firm;
- capitale dell'account;
- profit target;
- perdita massima giornaliera;
- drawdown massimo totale;
- durata;
- stile operativo;
- regole di consistenza;
- restrizioni sulle news;
- restrizioni overnight;
- piano AI e simulazione Monte Carlo.

Le challenge possono essere classificate come attive, superate, fallite o abbandonate.

### Account personali

L'app supporta regole per account personali e, tramite il modello `personal_accounts`, più configurazioni/account con:

- nome account;
- numero account;
- metodo di connessione;
- limiti di perdita;
- limite trade;
- orari operativi;
- durata del Killswitch;
- timezone.

### AI Planner

L'AI Planner offre:

- generazione di piani personali;
- generazione di protocolli per challenge;
- briefing giornalieri;
- chat contestuale;
- analisi del diario;
- ricalcolo del piano sulla base dei risultati;
- fallback locale quando il servizio AI non è disponibile.

Le richieste passano dall'Edge Function `ai-proxy`, che inoltra le richieste al provider AI senza inserire la chiave API nell'app Flutter.

### Diario di trading

Il journal consente di registrare:

- risultato del trade;
- emozione prevalente;
- trade pianificato o non pianificato;
- note;
- contesto operativo.

Il diario viene usato anche per statistiche locali e analisi comportamentali AI.

### Broker e dati live

Sono previsti più metodi di collegamento:

- inserimento manuale;
- Android Accessibility Service;
- Expert Advisor MQL5 tramite webhook Supabase;
- MetaAPI tramite polling REST.

I dati normalizzati includono, quando disponibili:

- balance;
- equity;
- P&L;
- perdita giornaliera;
- drawdown;
- posizioni aperte;
- trade giornalieri;
- valuta;
- perdite consecutive;
- ultimo lot size.

### Notifiche

Il servizio notifiche integra:

- notifiche locali Android;
- Firebase Cloud Messaging;
- promemoria di sessione;
- notifiche di fine orario operativo;
- reminder di sblocco Killswitch;
- calendario economico;
- notizie RSS finanziarie;
- avvisi per eventi ad alto impatto.

Il calendario prova più sorgenti, con fallback tra TradingView, Finnhub e ForexFactory.

### Observer Mode

La modalità Observer permette di dichiarare una sessione senza operazioni e di uscire solo dopo una conferma prolungata, per ridurre il trading impulsivo.

### Profilo, localizzazione e accessibilità

L'app include:

- autenticazione email/password;
- OAuth Google tramite Supabase;
- reset password;
- gestione profilo;
- tema chiaro/scuro;
- localizzazione multilingua;
- impostazioni notifiche;
- gestione permessi Android;
- account deletion;
- integrazione Crashlytics in release.

---

## Architettura

Il progetto segue una struttura Flutter con separazione per responsabilità:

```text
Flutter UI
  └── Screens / Widgets
        └── Riverpod Providers
              ├── Domain state
              ├── Local persistence
              └── Service layer
                    ├── Supabase
                    ├── MetaAPI
                    ├── Firebase
                    ├── RevenueCat
                    ├── Android Method/Event Channels
                    └── AI Edge Function
```

### Client Flutter

- `lib/screens/`: schermate dell'app;
- `lib/widgets/`: componenti UI riutilizzabili;
- `lib/providers/`: stato applicativo e coordinamento dei flussi;
- `lib/services/`: accesso ai servizi esterni e logica di integrazione;
- `lib/models/`: modelli dati;
- `lib/config/`: tema, colori, stringhe, preset e configurazione ambiente.

### Backend Supabase

- autenticazione utenti;
- database Postgres con RLS;
- Realtime per dati broker e killswitch;
- Edge Functions;
- rate limiting AI;
- audit log;
- webhook EA;
- webhook RevenueCat;
- reset dei limiti giornalieri.

### Integrazione nativa Android

Il codice Kotlin implementa:

- `MainActivity` con MethodChannel ed EventChannel;
- Accessibility Service;
- Killswitch overlay;
- FOMO Gatekeeper overlay;
- Trade Limit overlay;
- persistenza SharedPreferences;
- sincronizzazione delle regole Flutter → Android;
- lettura dei dati visibili dalle app broker supportate.

---

## Tecnologie

### App

- Flutter / Dart;
- Riverpod;
- Supabase Flutter;
- Firebase Core, Analytics, Messaging e Crashlytics;
- RevenueCat;
- Flutter Local Notifications;
- Google Fonts;
- `fl_chart`;
- `shared_preferences`;
- `local_auth`;
- `app_links`;
- `url_launcher`;
- `share_plus`;
- `timezone`.

### Backend

- Supabase Auth;
- PostgreSQL;
- Row Level Security;
- Supabase Realtime;
- Supabase Edge Functions;
- Groq tramite proxy server-side;
- RevenueCat webhook.

### Android

- Kotlin;
- Android Accessibility Service;
- overlay permission;
- foreground services;
- Firebase Cloud Messaging;
- Android 17 compile configuration tramite Flutter SDK.

---

## Struttura del progetto

```text
.
├── android/
│   └── app/
│       ├── src/main/kotlin/com/piplock/piplock_ai/
│       │   ├── MainActivity.kt
│       │   ├── PipLockAccessibilityService.kt
│       │   └── ...OverlayService.kt
│       └── src/main/res/
├── assets/
│   └── images/
├── docs/
│   ├── privacy_policy.md
│   ├── terms_of_service.md
│   ├── play_store_listing.md
│   └── sql_migrations/
├── lib/
│   ├── config/
│   ├── models/
│   ├── providers/
│   ├── screens/
│   ├── services/
│   ├── widgets/
│   ├── app.dart
│   └── main.dart
├── supabase/
│   ├── functions/
│   │   ├── ai-proxy/
│   │   ├── ea-webhook/
│   │   ├── reset-daily-limits/
│   │   └── revenuecat-webhook/
│   └── migrations/
├── test/
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
```

---

## Requisiti

Per lo sviluppo locale sono necessari:

- Flutter stabile compatibile con Dart `3.11.5` o superiore;
- Android Studio con Android SDK;
- JDK compatibile con la configurazione Gradle del progetto;
- dispositivo Android o emulatore;
- account Supabase;
- progetto Firebase configurato per Android;
- account RevenueCat se si vogliono testare gli abbonamenti;
- account MetaAPI opzionale;
- chiave Finnhub opzionale.

L'applicazione è principalmente orientata ad Android. Le funzionalità Accessibility Service, overlay e broker monitoring non sono disponibili su iOS nello stesso modo.

---

## Configurazione locale

### 1. Installare le dipendenze

```bash
flutter pub get
```

### 2. Configurare le variabili Dart

Copiare il template:

```bash
cp secrets.json.example secrets.json
```

Compilare `secrets.json` localmente. Il file è ignorato da Git e non deve essere committato.

Esempio:

```json
{
  "SUPABASE_URL": "https://your-project.supabase.co",
  "SUPABASE_ANON_KEY": "your-supabase-anon-key",
  "FINNHUB_API_KEY": "your-finnhub-key",
  "METAAPI_TOKEN": "your-metaapi-token",
  "GOOGLE_WEB_CLIENT_ID": "your-client-id.apps.googleusercontent.com",
  "REVENUECAT_PUBLIC_KEY": "goog_your_revenuecat_public_key"
}
```

Le chiavi usate dal codice sono quelle definite in `lib/config/env_config.dart`. In particolare, la chiave pubblica RevenueCat attesa dal codice è `REVENUECAT_PUBLIC_KEY`; non inserire mai una secret key RevenueCat nell'app.

### 3. Avviare l'app

```bash
flutter run --dart-define-from-file=secrets.json
```

Oppure per un device specifico:

```bash
flutter devices
flutter run -d <device-id> --dart-define-from-file=secrets.json
```

### 4. Configurazione debug

La modalità di sviluppo è controllata da:

```text
lib/config/constants.dart
```

Prima di una build pubblica verificare che:

```dart
const bool kDevMode = false;
```

Non usare dati mock o bypass di autenticazione in produzione.

---

## Configurazione Supabase

### Schema

Le migrazioni principali sono in:

```text
supabase/migrations/
```

Devono essere applicate in ordine. La sequenza include:

1. schema iniziale e RLS;
2. split dei token;
3. rate limiting AI;
4. audit log;
5. restrizione privilegi anonimi;
6. limiti AI aggiornati;
7. correzione trigger;
8. dati live broker e nuovi motivi Killswitch;
9. protocollo challenge;
10. override token;
11. limiti AI Pro.

Per usare Supabase CLI:

```bash
supabase login
supabase link --project-ref <project-ref>
supabase db push
```

Prima di applicare le migrazioni in produzione è necessario verificare lo stato effettivo del database e fare un backup.

### Edge Functions

Deploy delle funzioni:

```bash
supabase functions deploy ai-proxy
supabase functions deploy ea-webhook
supabase functions deploy reset-daily-limits
supabase functions deploy revenuecat-webhook
```

Secret server-side richiesti, da configurare nel progetto Supabase:

```text
GROQ_API_KEY
REVENUECAT_WEBHOOK_SECRET
```

Le variabili `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` devono essere gestite secondo la configurazione Supabase. La service role key non deve mai essere inserita nell'app Flutter, nel repository o nell'APK.

### Funzioni principali

#### `ai-proxy`

- verifica il JWT Supabase;
- controlla il tipo di chiamata `chat` o `plan`;
- applica il limite giornaliero AI;
- inoltra la richiesta al provider AI;
- usa un modello fallback se il principale non risponde.

#### `ea-webhook`

- riceve heartbeat e dati dall'EA MQL5;
- valida l'identità dell'utente;
- aggiorna i dati live broker;
- registra eventi Killswitch e soft warning.

#### `revenuecat-webhook`

- riceve eventi di acquisto, rinnovo, cancellazione e scadenza;
- aggiorna il livello subscription nel profilo.

#### `reset-daily-limits`

- resetta i limiti e i token secondo la pianificazione configurata;
- aggiorna i giorni delle challenge attive.

---

## Configurazione Firebase

Per Firebase Android è necessario disporre di:

```text
android/app/google-services.json
```

Il file deve corrispondere a:

```text
com.piplock.piplock_ai
```

La configurazione Firebase abilita principalmente:

- Firebase Cloud Messaging;
- Analytics;
- Crashlytics.

Verificare anche che il progetto Firebase abbia configurato correttamente SHA-1/SHA-256 per le build utilizzate e il client OAuth Google.

---

## Configurazione Android

PipLock richiede, in base alle funzionalità utilizzate:

- accesso a Internet;
- notifiche Android 13+;
- notifiche schedulate;
- Accessibility Service;
- visualizzazione sopra altre app;
- foreground service;
- autenticazione biometrica opzionale.

Dopo l'installazione, l'utente deve eventualmente abilitare manualmente:

1. **Impostazioni → Accessibilità → PipLock AI**;
2. **Impostazioni → App → Accesso speciale → Mostra sopra altre app**;
3. notifiche;
4. esclusione dal risparmio energetico, se il produttore del dispositivo limita i servizi in background.

Il comportamento degli overlay e dell'Accessibility Service può variare tra produttori Android. È necessario testare almeno su Pixel, Samsung e Xiaomi prima della pubblicazione.

---

## Integrazioni broker

### Accessibility Service

Il servizio nativo rileva l'app broker in primo piano e prova a leggere i dati visibili nell'interfaccia, quando disponibili. Sono previsti parser per MetaTrader, cTrader e modalità generica.

Il servizio non esegue ordini e non modifica le posizioni. Tuttavia, poiché l'integrazione dipende dalla struttura UI dell'app broker, aggiornamenti dell'app broker o differenze di lingua/layout possono rendere l'estrazione incompleta o inaccurata.

### Expert Advisor MQL5

La documentazione dell'EA è in:

```text
docs/EA_PipLock_v2.mq5
```

Il flusso generale è:

```text
EA MQL5 → Supabase Edge Function ea-webhook → broker_connections → Realtime Flutter
```

L'EA deve essere configurato con:

- URL della Edge Function;
- `user_id` dell'utente;
- secret webhook;
- permesso `WebRequest` verso il dominio Supabase.

Prima dell'uso in produzione verificare l'autenticazione per-user del webhook e il comportamento in caso di retry/replay.

### MetaAPI

MetaAPI utilizza polling REST e richiede:

- `METAAPI_TOKEN` in fase di build/run;
- account ID MetaAPI inserito dall'utente;
- account MetaTrader collegato a MetaAPI.

Il polling standard dell'app è ogni 30 secondi. L'integrazione è opzionale.

---

## AI Planner

Il client non dovrebbe chiamare direttamente il provider AI. Il flusso previsto è:

```text
Flutter → Supabase ai-proxy → Provider AI → ai-proxy → Flutter
```

Il sistema supporta:

- piani personali;
- protocolli challenge;
- chat;
- analisi journal;
- risposte fallback locali.

I limiti attualmente previsti dalle migrazioni più recenti sono:

- utenti Trial/Free: 2 piani e 5 messaggi chat al giorno;
- utenti Pro: 3 piani e 20 messaggi chat al giorno.

Il valore effettivo dipende dalla migrazione SQL applicata nel progetto Supabase. Dopo modifiche ai limiti, aggiornare contemporaneamente:

- funzione SQL di rate limiting;
- UI dei contatori;
- documentazione legale e Play Store;
- eventuali test.

---

## Notifiche e calendario economico

La sorgente primaria del calendario è TradingView. Sono previsti fallback verso Finnhub e ForexFactory.

Le notifiche possono includere:

- eventi macroeconomici ad alto impatto;
- news finanziarie RSS;
- reminder di sessione;
- avviso chiusura orario di trading;
- reminder sblocco Killswitch;
- eventi di rischio.

Per notifiche affidabili in background è necessario verificare:

- permessi Android;
- exact alarm;
- timezone del dispositivo;
- ottimizzazione batteria;
- configurazione FCM;
- comportamento dopo reboot.

---

## Build e test

### Analisi statica

```bash
flutter analyze
```

### Test

```bash
flutter test
```

### Build debug

```bash
flutter build apk --debug \
  --dart-define-from-file=secrets.json
```

### Build release

```bash
flutter build apk --release \
  --dart-define-from-file=secrets.json
```

Per una release Android configurare anche le credenziali di firma in un file locale non tracciato:

```text
android/key.properties
```

Non inserire keystore, password o alias nel repository.

### Verifiche consigliate prima della release

- `flutter analyze` senza warning bloccanti;
- tutti i test verdi;
- test su dispositivo fisico;
- login/logout;
- conferma email e reset password;
- overlay sopra MT5/cTrader;
- Killswitch con app in foreground e background;
- reboot del dispositivo;
- notifiche locali e FCM;
- acquisto e restore RevenueCat;
- deep link con app chiusa;
- perdita di connessione e ripristino;
- cambio account broker;
- timezone e cambio giorno;
- cancellazione completa dell'account.

---

## Sicurezza

Regole obbligatorie:

- non committare `.env`, `secrets.json`, token, API key private o service role key;
- non inserire secret AI, RevenueCat o Supabase service role nell'APK;
- usare solo chiavi pubbliche lato client;
- ruotare immediatamente ogni credenziale esposta;
- mantenere RLS attivo su tutte le tabelle business;
- validare sempre l'identità lato Edge Function;
- non fidarsi dei dati inviati dal client;
- usare RPC atomiche per token, subscription e contatori sensibili;
- non loggare password, token o payload finanziari completi;
- verificare i secret del webhook prima del deploy.

I file di configurazione locale previsti sono ignorati da Git. Prima di ogni push controllare:

```bash
git status --short
git diff --check
git grep -n -i "service_role\|gsk_\|sbp_\|password\|secret" -- ':!*.lock'
```

La presenza di una chiave pubblica in `google-services.json` non sostituisce le regole di sicurezza Firebase e Supabase.

---

## Stato del progetto

Il progetto contiene una base funzionale ampia, ma prima di una release pubblica è necessario completare una fase di hardening.

Aree da verificare prioritariamente:

1. allineamento tra migrazioni Supabase e codice client;
2. autenticazione e hashing del webhook EA;
3. consumo atomico dei token;
4. rate limiting AI fail-closed;
5. gestione deep link a cold start;
6. test per Killswitch, P&L, token e parser broker;
7. lifecycle di timer e subscription;
8. coerenza delle timezone;
9. test su dispositivi Android reali;
10. controllo delle credenziali nelle pipeline di build.

Lo stato di compilazione e quello di produzione non sono equivalenti: una build APK riuscita non garantisce che Supabase, Firebase, RevenueCat, permessi Android e webhook siano configurati correttamente.

---

## Documentazione aggiuntiva

- [Privacy Policy](docs/privacy_policy.md)
- [Terms of Service](docs/terms_of_service.md)
- [Play Store Listing](docs/play_store_listing.md)
- [EA MQL5](docs/EA_PipLock_v2.mq5)
- [Migrazioni SQL aggiuntive](docs/sql_migrations/)
- [Configurazione esempio](secrets.json.example)

---

## Licenza e contatti

Il progetto è distribuito come applicazione proprietaria PipLock AI. Per supporto o richieste relative a privacy e dati:

```text
support.piplock@gmail.com
```

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


