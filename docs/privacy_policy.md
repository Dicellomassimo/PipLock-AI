# Privacy Policy — PipLock AI

**Effective date:** October 6, 2026
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
- **Accessibility data (only if you enable Screen Reading)** — on-device foreground app package detection for supported broker apps; while a supported broker is open, visible accessibility text is processed to extract balance, equity, floating profit/loss, margin, open-position count, daily trade count, and an account number if it is visible. Numeric snapshots are stored in the app's private local storage and used on-device to evaluate your configured limits and update the dashboard. This Accessibility Service does not transmit screen text or extracted broker values to PipLock servers or third parties.

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

PipLock AI is not an accessibility tool for people with disabilities. If you choose the Screen Reading broker connection and affirmatively consent, Android's Accessibility Service checks the foreground app package to recognize supported broker apps (for example MetaTrader 4/5 and cTrader). While a supported broker is open, it reads visible accessibility text and fields to extract balance, equity, floating profit/loss, margin, open-position count, daily trade count, and an account number if shown. It uses these values on-device to evaluate your configured risk limits, update the dashboard, and show or dismiss PipLock protection and warning overlays.

The service passes extracted values only to PipLock components on the device and stores numeric snapshots in the app's private local storage. It does not transmit screen text or extracted financial values to PipLock servers or third parties. During an active Killswitch lockdown, it intercepts Back and Recents key presses to enforce the temporary lock. It does not take screenshots, record keystrokes, or read passwords.

You can decline this permission and use other broker connection methods. You can disable Accessibility Service at any time in Android Accessibility settings; Screen Reading monitoring and its related overlays will then stop.

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
