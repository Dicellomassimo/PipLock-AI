import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../models/journal_entry.dart';
import '../../providers/journal_provider.dart';
import '../../providers/auth_provider.dart';

const _quickSymbols = [
  'EURUSD',
  'GBPUSD',
  'XAUUSD',
  'US30',
  'NAS100',
  'GBPJPY',
  'USDJPY',
];

const _emotions = [
  ('calm', '😌', 'Calm'),
  ('confident', '🦁', 'Confident'),
  ('anxious', '😰', 'Anxious'),
  ('frustrated', '😤', 'Frustrated'),
  ('fomo', '😱', 'FOMO'),
  ('revenge', '🔥', 'Revenge'),
];

class JournalEntryFormScreen extends ConsumerStatefulWidget {
  const JournalEntryFormScreen({super.key});

  @override
  ConsumerState<JournalEntryFormScreen> createState() =>
      _JournalEntryFormScreenState();
}

class _JournalEntryFormScreenState
    extends ConsumerState<JournalEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _symbolController = TextEditingController();
  final _pnlController = TextEditingController();
  final _setupController = TextEditingController();
  final _mistakesController = TextEditingController();
  final _lessonsController = TextEditingController();

  String _direction = 'long';
  String _selectedEmotion = 'calm';
  double _emotionScore = 3.0;
  bool _wasPlanned = true;
  bool _isSaving = false;

  JournalEntry? _editEntry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is JournalEntry && _editEntry == null) {
      _editEntry = args;
      _symbolController.text = args.symbol;
      _direction = args.direction;
      if (args.pnl != null) {
        _pnlController.text = args.pnl!.toStringAsFixed(2);
      }
      _selectedEmotion = args.emotion;
      _emotionScore = args.emotionScore.toDouble();
      _setupController.text = args.setupDescription ?? '';
      _mistakesController.text = args.mistakes ?? '';
      _lessonsController.text = args.lessons ?? '';
      _wasPlanned = args.wasPlanned;
    }
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _pnlController.dispose();
    _setupController.dispose();
    _mistakesController.dispose();
    _lessonsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final userId = ref.read(currentUserIdProvider);
    final pnlText = _pnlController.text.trim();
    final double? pnl = pnlText.isNotEmpty ? double.tryParse(pnlText) : null;

    final entry = JournalEntry(
      id: _editEntry?.id ?? const Uuid().v4(),
      userId: userId.isNotEmpty ? userId : 'dev-user-000',
      date: _editEntry?.date ?? DateTime.now(),
      symbol: _symbolController.text.trim().toUpperCase(),
      direction: _direction,
      pnl: pnl,
      emotion: _selectedEmotion,
      emotionScore: _emotionScore.round(),
      setupDescription: _setupController.text.trim().isEmpty
          ? null
          : _setupController.text.trim(),
      mistakes: _mistakesController.text.trim().isEmpty
          ? null
          : _mistakesController.text.trim(),
      lessons: _lessonsController.text.trim().isEmpty
          ? null
          : _lessonsController.text.trim(),
      wasPlanned: _wasPlanned,
      createdAt: _editEntry?.createdAt ?? DateTime.now(),
    );

    await ref.read(journalProvider.notifier).addEntry(entry);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _editEntry != null;
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEdit ? s.t('Edit Trade', 'Modifica Trade') : s.t('New Trade', 'Nuovo Trade'),
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // ── Symbol ──────────────────────────────────────────────────────
            _SectionLabel(s.t('Instrument', 'Strumento')),
            TextFormField(
              controller: _symbolController,
              style: GoogleFonts.manrope(color: AppColors.textPrimary),
              decoration: _inputDecoration(s.t('e.g. EURUSD, XAUUSD', 'Es. EURUSD, XAUUSD')),
              textCapitalization: TextCapitalization.characters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? s.t('Enter the symbol', 'Inserisci il simbolo') : null,
            ),
            const SizedBox(height: 10),

            // Quick-select chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _quickSymbols.map((s) {
                final selected = _symbolController.text.toUpperCase() == s;
                return GestureDetector(
                  onTap: () => setState(() => _symbolController.text = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.accent : AppColors.border,
                      ),
                    ),
                    child: Text(
                      s,
                      style: GoogleFonts.manrope(
                        color: selected
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Direction ────────────────────────────────────────────────────
            _SectionLabel(s.t('Direction', 'Direzione')),
            Row(
              children: [
                Expanded(
                  child: _DirectionButton(
                    label: '📈 Long',
                    selected: _direction == 'long',
                    color: AppColors.success,
                    onTap: () => setState(() => _direction = 'long'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DirectionButton(
                    label: '📉 Short',
                    selected: _direction == 'short',
                    color: AppColors.danger,
                    onTap: () => setState(() => _direction = 'short'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── P&L ─────────────────────────────────────────────────────────
            _SectionLabel(s.t('P&L (optional)', 'P&L (opzionale)')),
            TextFormField(
              controller: _pnlController,
              style: GoogleFonts.manrope(color: AppColors.textPrimary),
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: _inputDecoration(s.t('e.g. +142.50 or -87.00', 'Es. +142.50 o -87.00')),
            ),

            const SizedBox(height: 20),

            // ── Emotion picker ───────────────────────────────────────────────
            _SectionLabel(s.t('Emotional state', 'Stato emotivo')),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.3,
              children: _emotions.map((e) {
                final key = e.$1;
                final emoji = e.$2;
                final label = e.$3;
                final selected = _selectedEmotion == key;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmotion = key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accent.withValues(alpha: 0.12)
                          : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.accent : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: GoogleFonts.manrope(
                            color: selected
                                ? AppColors.accent
                                : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Emotion score ────────────────────────────────────────────────
            _SectionLabel(s.t('Emotional intensity', 'Intensità emotiva')),
            Row(
              children: [
                const Text('😶', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Slider(
                    value: _emotionScore,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    onChanged: (v) => setState(() => _emotionScore = v),
                  ),
                ),
                const Text('🔥', style: TextStyle(fontSize: 16)),
              ],
            ),
            Center(
              child: Text(
                _scoreLabel(_emotionScore.round()),
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Was planned ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Text(
                    s.t('Was it planned?', 'Era nel piano?'),
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _wasPlanned,
                    onChanged: (v) => setState(() => _wasPlanned = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Setup description ─────────────────────────────────────────────
            _SectionLabel(s.t('Setup description', 'Descrizione setup')),
            TextFormField(
              controller: _setupController,
              style: GoogleFonts.manrope(color: AppColors.textPrimary),
              maxLines: 3,
              decoration: _inputDecoration(s.t('Describe the setup you saw...', 'Descrivi il setup che hai visto...')),
            ),

            const SizedBox(height: 16),

            // ── Mistakes ─────────────────────────────────────────────────────
            _SectionLabel(s.t('Mistakes made', 'Errori commessi')),
            TextFormField(
              controller: _mistakesController,
              style: GoogleFonts.manrope(color: AppColors.textPrimary),
              maxLines: 3,
              decoration: _inputDecoration(s.t('What would you have done differently?', 'Cosa avresti fatto diversamente?')),
            ),

            const SizedBox(height: 16),

            // ── Lessons ──────────────────────────────────────────────────────
            _SectionLabel(s.t('Lessons learned', 'Lezioni apprese')),
            TextFormField(
              controller: _lessonsController,
              style: GoogleFonts.manrope(color: AppColors.textPrimary),
              maxLines: 3,
              decoration: _inputDecoration(s.t('What did you learn?', 'Cosa hai imparato?')),
            ),

            const SizedBox(height: 32),

            // ── Save button ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isEdit ? s.t('Save changes', 'Salva modifiche') : s.t('Save trade', 'Salva trade'),
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 14),
      filled: true,
      fillColor: AppColors.cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    );
  }

  String _scoreLabel(int score) {
    switch (score) {
      case 1:
        return 'Very low';
      case 2:
        return 'Low';
      case 3:
        return 'Medium';
      case 4:
        return 'High';
      case 5:
        return 'Very high';
      default:
        return '';
    }
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Direction button ─────────────────────────────────────────────────────────

class _DirectionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _DirectionButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: selected ? color : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
