import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  // Internal key — always English (sent in email subject)
  String _selectedCategoryKey = 'Bug Report';

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    final category = _selectedCategoryKey;
    final subject = '[PipLock] [$category] ${_subjectController.text.trim()}';
    final body = _messageController.text.trim();

    final uri = Uri(
      scheme: 'mailto',
      path: 'support.piplock@gmail.com',
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        final s = ref.read(appStringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.t(
                'Could not open email app. Write to: support.piplock@gmail.com',
                'Impossibile aprire l\'email. Scrivi a: support.piplock@gmail.com',
              ),
              style: GoogleFonts.manrope(color: Colors.white),
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);

    // (EN key used in email subject, translated label shown in dropdown)
    final categories = [
      ('Bug Report', s.t('Bug Report', 'Segnalazione Bug')),
      ('Feature Request', s.t('Feature Request', 'Richiesta Funzione')),
      ('Account Issue', s.t('Account Issue', 'Problema Account')),
      ('Other', s.t('Other', 'Altro')),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Feedback',
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t(
                  'Found a bug or have a suggestion? Write to us.',
                  'Hai trovato un bug o vuoi suggerire qualcosa? Scrivici.',
                ),
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // ── Category ─────────────────────────────────────────────────
              _label(s.t('Category', 'Categoria')),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategoryKey,
                    dropdownColor: AppColors.cardBg,
                    isExpanded: true,
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary),
                    items: categories
                        .map((c) => DropdownMenuItem(
                              value: c.$1,
                              child: Text(c.$2),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedCategoryKey = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Subject ──────────────────────────────────────────────────
              _label(s.t('Subject', 'Oggetto')),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: _inputDecoration(
                  s.t('Short description...', 'Breve descrizione...'),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? s.t('Required field', 'Campo obbligatorio')
                    : null,
              ),
              const SizedBox(height: 20),

              // ── Message ──────────────────────────────────────────────────
              _label(s.t('Message', 'Messaggio')),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                maxLines: 6,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: _inputDecoration(
                  s.t(
                    'Describe the issue or your idea...',
                    'Descrivi il problema o la tua idea...',
                  ),
                ),
                validator: (v) => (v == null || v.trim().length < 10)
                    ? s.t('Write at least 10 characters', 'Scrivi almeno 10 caratteri')
                    : null,
              ),
              const SizedBox(height: 32),

              // ── Send ─────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sendFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    s.t('Open email app', 'Apri email'),
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'support.piplock@gmail.com',
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.manrope(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: -0.1,
        ),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        filled: true,
        fillColor: AppColors.cardBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
      );
}
