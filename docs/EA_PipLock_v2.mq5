//+------------------------------------------------------------------+
//|                                              EA_PipLock_v2.mq5   |
//|                              PipLock AI — Risk Management EA      |
//|                                                                    |
//| IMPORTANTE: Aggiungi l'URL del webhook alla lista degli URL       |
//| consentiti in MT5: Strumenti → Opzioni → Consulenti Esperti      |
//| → Consenti richieste Web, aggiungi il dominio Supabase.           |
//|                                                                    |
//| Questo EA è SOLA LETTURA: non esegue, modifica o chiude          |
//| posizioni. Legge solo equity/P&L/trade e notifica il backend.    |
//+------------------------------------------------------------------+
#property copyright "PipLock AI"
#property link      "https://piplock.ai"
#property version   "2.00"
#property strict

// ─── Input parameters ────────────────────────────────────────────────────────

input double MaxDailyLossUSD   = 100.0;   // Perdita massima giornaliera in USD
input double MaxDailyLossPct   = 5.0;     // Perdita massima giornaliera in % del balance
input int    MaxTradesPerDay   = 3;       // Numero massimo di trade al giorno
input string WebhookURL        = "";      // URL Supabase Edge Function (es. https://xxx.supabase.co/functions/v1/ks-trigger)
input string WebhookSecret     = "";      // Token segreto X-PipLock-Secret
input int    CheckInterval     = 5;       // Intervallo controllo in secondi

// ─── State ────────────────────────────────────────────────────────────────────

datetime _lastAlertTime     = 0;
double   _dayStartBalance   = 0.0;
datetime _dayStartTime      = 0;

// ─── Initialization ───────────────────────────────────────────────────────────

int OnInit()
{
   if(WebhookURL == "")
   {
      Print("[PipLock] ATTENZIONE: WebhookURL non configurato. L'EA non invierà notifiche.");
   }

   _dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   _dayStartTime    = _StartOfDay(TimeCurrent());

   EventSetTimer(CheckInterval);
   Print("[PipLock] EA avviato. Balance iniziale giornata: ", _dayStartBalance,
         " | Max perdita: ", MaxDailyLossUSD, " USD / ", MaxDailyLossPct, "%",
         " | Max trade: ", MaxTradesPerDay);
   return INIT_SUCCEEDED;
}

// ─── Deinitialization ─────────────────────────────────────────────────────────

void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("[PipLock] EA rimosso. Motivo: ", reason);
}

// ─── Timer tick ───────────────────────────────────────────────────────────────

void OnTimer()
{
   // Reset giornaliero a mezzanotte
   datetime todayStart = _StartOfDay(TimeCurrent());
   if(todayStart != _dayStartTime)
   {
      _dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      _dayStartTime    = todayStart;
      Print("[PipLock] Reset giornaliero. Nuovo balance di riferimento: ", _dayStartBalance);
   }

   // ── Calcola metriche ─────────────────────────────────────────────────────
   double equity        = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance       = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyPnl      = equity - _dayStartBalance;
   int    openPositions = PositionsTotal();
   int    todayTrades   = _CountTodayTrades();

   // ── Check condizioni ─────────────────────────────────────────────────────
   bool dailyLossExceeded = false;
   bool tradesExceeded    = false;
   bool revengeDetected   = false;
   string reason          = "";

   // Perdita giornaliera USD
   if(MaxDailyLossUSD > 0 && dailyPnl <= -MaxDailyLossUSD)
   {
      dailyLossExceeded = true;
      reason = "daily_loss";
   }

   // Perdita giornaliera %
   if(MaxDailyLossPct > 0 && _dayStartBalance > 0)
   {
      double lossPct = (-dailyPnl / _dayStartBalance) * 100.0;
      if(lossPct >= MaxDailyLossPct)
      {
         dailyLossExceeded = true;
         reason = "daily_loss";
      }
   }

   // Numero trade superato
   if(MaxTradesPerDay > 0 && todayTrades >= MaxTradesPerDay)
   {
      tradesExceeded = true;
      if(reason == "") reason = "max_trades";
   }

   // Revenge trading detection
   revengeDetected = _DetectRevengeTradingPattern();
   if(revengeDetected && reason == "") reason = "revenge_pattern";

   // ── Invia webhook se necessario ──────────────────────────────────────────
   if((dailyLossExceeded || tradesExceeded || revengeDetected) && reason != "")
   {
      // Anti-spam: non inviare più di una volta per minuto
      if(TimeCurrent() - _lastAlertTime >= 60)
      {
         _SendWebhook(equity, balance, dailyPnl, openPositions, todayTrades, reason);
         _lastAlertTime = TimeCurrent();
      }
   }
}

// ─── Webhook ──────────────────────────────────────────────────────────────────

void _SendWebhook(double equity, double balance, double dailyPnl,
                  int openPositions, int tradesCount, string reason)
{
   if(WebhookURL == "")
   {
      Print("[PipLock] Webhook non configurato — condizione rilevata: ", reason);
      return;
   }

   // Build JSON payload
   string payload = StringFormat(
      "{\"equity\":%.2f,\"balance\":%.2f,\"dailyPnl\":%.2f,"
      "\"openPositions\":%d,\"tradesCount\":%d,\"reason\":\"%s\","
      "\"account\":\"%s\",\"timestamp\":\"%s\"}",
      equity,
      balance,
      dailyPnl,
      openPositions,
      tradesCount,
      reason,
      IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)),
      TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS)
   );

   // Headers
   string headers =
      "Content-Type: application/json\r\n"
      "X-PipLock-Secret: " + WebhookSecret + "\r\n";

   // Convert string to char array
   uchar postData[];
   StringToCharArray(payload, postData, 0, StringLen(payload));

   // Response buffers
   uchar  result[];
   string resultHeaders;

   int res = WebRequest(
      "POST",
      WebhookURL,
      headers,
      5000,       // timeout 5s
      postData,
      result,
      resultHeaders
   );

   if(res == 200 || res == 201)
   {
      Print("[PipLock] Webhook inviato con successo. Ragione: ", reason,
            " | Equity: ", equity, " | DailyPnL: ", dailyPnl);
   }
   else if(res == -1)
   {
      Print("[PipLock] ERRORE WebRequest: aggiungi '", WebhookURL,
            "' agli URL consentiti in Strumenti → Opzioni → Consulenti Esperti.");
   }
   else
   {
      Print("[PipLock] Webhook risposta HTTP ", res, ". Ragione: ", reason);
   }
}

// ─── Count today's trades ─────────────────────────────────────────────────────

int _CountTodayTrades()
{
   int count        = 0;
   datetime dayStart = _StartOfDay(TimeCurrent());

   HistorySelect(dayStart, TimeCurrent() + 1);
   int total = HistoryDealsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      long dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);
      long entryType = HistoryDealGetInteger(ticket, DEAL_ENTRY);

      // Conta solo aperture di posizione (DEAL_ENTRY_IN)
      if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL)
      {
         if(entryType == DEAL_ENTRY_IN)
            count++;
      }
   }
   return count;
}

// ─── Revenge trading detection ────────────────────────────────────────────────
// Rileva: 2+ perdite sullo stesso simbolo negli ultimi 10 minuti
// con lot size crescente (segnale di revenge trading)

bool _DetectRevengeTradingPattern()
{
   const int   LOOKBACK_DEALS     = 10;
   const int   LOOKBACK_SECONDS   = 600; // 10 minuti

   datetime cutoff = TimeCurrent() - LOOKBACK_SECONDS;

   HistorySelect(cutoff, TimeCurrent() + 1);
   int total = HistoryDealsTotal();
   if(total < 2) return false;

   // Raccoglie gli ultimi LOOKBACK_DEALS deal di chiusura in perdita
   struct DealInfo
   {
      string   symbol;
      double   lots;
      double   profit;
      datetime time;
   };

   DealInfo deals[];
   int dealCount = 0;
   ArrayResize(deals, LOOKBACK_DEALS);

   for(int i = total - 1; i >= 0 && dealCount < LOOKBACK_DEALS; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      long entryType = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entryType != DEAL_ENTRY_OUT) continue; // Solo chiusure

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      if(profit >= 0) continue; // Solo perdite

      deals[dealCount].symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      deals[dealCount].lots   = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      deals[dealCount].profit = profit;
      deals[dealCount].time   = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      dealCount++;
   }

   if(dealCount < 2) return false;

   // Cerca 2+ perdite sullo stesso simbolo con lot size crescente
   for(int i = 0; i < dealCount - 1; i++)
   {
      for(int j = i + 1; j < dealCount; j++)
      {
         if(deals[i].symbol == deals[j].symbol)
         {
            // deals[i] è più recente (j è il precedente)
            if(deals[i].lots > deals[j].lots * 1.1) // +10% di lot size
            {
               Print("[PipLock] Pattern revenge trading rilevato su ", deals[i].symbol,
                     " | Lot precedente: ", deals[j].lots,
                     " → Lot attuale: ", deals[i].lots);
               return true;
            }
         }
      }
   }
   return false;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

datetime _StartOfDay(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour   = 0;
   dt.min    = 0;
   dt.sec    = 0;
   return StructToTime(dt);
}

// ─── OnTick (non usato, EA è timer-based) ────────────────────────────────────
void OnTick() {}
//+------------------------------------------------------------------+
