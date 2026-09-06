# Privacy Policy — PipLock AI

**Effective date:** September 6, 2026  
**App:** PipLock AI (com.piplock.piplock_ai)  
**Developer:** PipLock  
**Contact:** support.piplock@gmail.com

---

## 1. Data We Collect

### 1.1 Account Data
- **Email address** — used for authentication (Supabase Auth)
- **User ID** — anonymous identifier linked to your account

### 1.2 App Usage Data
- **Trading rules and challenge settings** — profit targets, daily loss limits, drawdown limits you configure (stored in our database to sync across sessions)
- **AI usage counters** — number of AI plan generations and chat messages used per day (for rate limiting purposes only)
- **Subscription tier** — whether you are on Trial or Pro plan (managed via RevenueCat)

### 1.3 Device Data
- **Push notification token (FCM)** — used to send market alerts and challenge reminders
- **Broker app detection** — the Accessibility Service detects when you open a broker app (e.g. MetaTrader 5) to show protection overlays. **We do not read, record, or transmit any trading data, account balances, open positions, or personal trading activity.**

### 1.4 Data We Do NOT Collect
- We do not collect payment card numbers (payments are processed by Google Play / RevenueCat)
- We do not read your broker account credentials
- We do not access your trading history or account statements
- We do not sell your data to third parties

---

## 2. How We Use Your Data

| Purpose | Legal Basis |
|---|---|
| Account authentication and session management | Contract |
| Syncing your trading rules across sessions | Contract |
| Sending push notifications (market alerts, reminders) | Consent |
| AI plan generation and chat (via our secure server-side proxy) | Contract |
| Rate limiting AI features | Legitimate interest |
| Subscription management and billing | Contract |

---

## 3. Third-Party Services

| Service | Purpose | Privacy Policy |
|---|---|---|
| **Supabase** | Database, authentication, Edge Functions | supabase.com/privacy |
| **Firebase (Google)** | Push notifications (FCM) | firebase.google.com/support/privacy |
| **RevenueCat** | Subscription and in-app purchase management | revenuecat.com/privacy |
| **Groq** | AI language model (accessed only via our server-side proxy — your messages are sent to Groq's API to generate responses) | groq.com/privacy |
| **MetaAPI** | Optional: connect MetaTrader 5 accounts for session detection | metaapi.cloud/privacy |

Your data is processed in the EU and/or the United States depending on the service provider's infrastructure.

---

## 4. Accessibility Service

PipLock AI uses Android's Accessibility Service to detect when you open a broker trading app (e.g. MetaTrader 5, MT4) and display a protection overlay (Killswitch or FOMO Gatekeeper).

**This service does NOT:**
- Read the content of any app on your screen
- Record keystrokes or passwords
- Capture screenshots
- Transmit any data from your broker app

It only reads the package name of the foreground application to determine whether to show a PipLock overlay.

---

## 5. System Alert Window (Overlay Permission)

PipLock AI requires the "Display over other apps" permission to show the Killswitch overlay on top of your broker app when you have an active challenge. This overlay is displayed locally on your device and does not transmit any data.

---

## 6. Data Retention

- Account data is retained as long as your account is active
- If you delete your account, all personal data is deleted within 30 days
- AI usage counters are reset daily and permanently deleted after 90 days

---

## 7. Your Rights (GDPR)

If you are in the European Economic Area, you have the right to:
- **Access** the personal data we hold about you
- **Correct** inaccurate data
- **Delete** your account and all associated data
- **Object** to processing based on legitimate interest
- **Data portability** — request an export of your data

To exercise these rights, contact: support.piplock@gmail.com

---

## 8. Children

PipLock AI is not directed at children under 18. We do not knowingly collect data from minors.

---

## 9. Changes to This Policy

We may update this policy. If changes are significant, we will notify you via the app or email. The "Effective date" at the top will always reflect the latest version.

---

## 10. Contact

For privacy questions or data requests: **support.piplock@gmail.com**
