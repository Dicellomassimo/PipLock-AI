import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../config/app_strings.dart';

const accessibilityDisclosureConsentKey = 'accessibility_disclosure_2026_10';

Future<bool> requestAccessibilityDisclosure(
  BuildContext context,
  AppStrings strings,
) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(accessibilityDisclosureConsentKey) == true) return true;
  if (!context.mounted) return false;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.cardBg,
      scrollable: true,
      title: Text(
        strings.t(
          'How PipLock uses Accessibility Service',
          'Come PipLock usa il Servizio di accessibilità',
        ),
        style: GoogleFonts.manrope(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: Text(
        strings.t(
          'If you agree and enable this Android service, PipLock checks the foreground app package to recognize supported broker apps. While a supported broker is open, it reads visible accessibility text and fields to extract the account number when shown, balance, equity, floating profit/loss, margin, open positions, and daily trade count.\n\nPipLock processes the relevant fields on this device to compare extracted values with your trading limits, update your dashboard, and show or dismiss its overlays. Only extracted numeric fields are passed to PipLock app components. Numeric snapshots are stored in the app\'s private local storage; raw screen text is not stored. This Accessibility Service does not upload screen text or extracted broker values to PipLock servers or third parties.\n\nDuring an active Killswitch lockdown, the service also intercepts Back and Recents key presses to prevent leaving the lock screen. It does not take screenshots, record keystrokes, or read passwords. You can decline and continue using other broker connection methods, or turn this service off at any time in Android Accessibility settings.',
          'Se acconsenti e abiliti questo servizio Android, PipLock controlla il pacchetto dell\'app in primo piano per riconoscere le app broker supportate. Quando un broker supportato è aperto, legge il testo e i campi visibili tramite le API di accessibilità per estrarre, se mostrati, numero del conto, saldo, equity, profitto/perdita, margine, posizioni aperte e numero di operazioni giornaliere.\n\nPipLock elabora i campi pertinenti su questo dispositivo per confrontare i valori estratti con i limiti di trading, aggiornare la dashboard e gestire i propri overlay. Solo i campi numerici estratti vengono passati ai componenti dell\'app PipLock. Gli snapshot numerici sono salvati nello spazio privato locale dell\'app; il testo grezzo dello schermo non viene salvato. Questo Servizio di accessibilità non carica testo dello schermo o dati broker estratti sui server PipLock né li invia a terze parti.\n\nDurante un blocco Killswitch attivo, il servizio intercetta anche i tasti Indietro e Recenti per impedire di uscire dalla schermata di blocco. Non acquisisce screenshot, non registra la digitazione e non legge password. Puoi rifiutare e continuare a usare altri metodi di collegamento al broker, oppure disattivare il servizio in qualsiasi momento nelle impostazioni Android di accessibilità.',
        ),
        style: GoogleFonts.manrope(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            strings.t('Not now', 'Non ora'),
            style: GoogleFonts.manrope(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
          ),
          child: Text(
            strings.t('Agree and continue', 'Acconsento e continuo'),
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  if (accepted != true) return false;
  await prefs.setBool(accessibilityDisclosureConsentKey, true);
  return true;
}