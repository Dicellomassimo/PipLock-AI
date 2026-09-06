import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Change Password Dialog
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showChangePasswordDialog(BuildContext context, AppStrings s) async {
  final newPassCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  bool obscureNew = true;
  bool obscureConfirm = true;
  bool isLoading = false;
  String? errorText;

  await showDialog(
    context: context,
    barrierDismissible: !isLoading,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            s.profileChangePassword,
            style: GoogleFonts.manrope(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorText != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(errorText!,
                      style: GoogleFonts.manrope(
                          color: AppColors.danger, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: newPassCtrl,
                obscureText: obscureNew,
                style: GoogleFonts.manrope(
                    color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: s.t('New password', 'Nuova password'),
                  hintStyle:
                      GoogleFonts.manrope(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.cardBg2,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.accent, width: 1.5)),
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                        size: 18),
                    onPressed: () =>
                        setState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: obscureConfirm,
                style: GoogleFonts.manrope(
                    color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: s.t('Confirm password', 'Conferma password'),
                  hintStyle:
                      GoogleFonts.manrope(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.cardBg2,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.accent, width: 1.5)),
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                        size: 18),
                    onPressed: () =>
                        setState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text(s.t('Cancel', 'Annulla'),
                  style:
                      GoogleFonts.manrope(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      final newPass = newPassCtrl.text.trim();
                      final confirm = confirmCtrl.text.trim();
                      if (newPass.length < 8) {
                        setState(() => errorText = s.t(
                            'Password must be at least 8 characters.',
                            'La password deve avere almeno 8 caratteri.'));
                        return;
                      }
                      if (newPass != confirm) {
                        setState(() => errorText = s.t(
                            'Passwords do not match.',
                            'Le password non coincidono.'));
                        return;
                      }
                      setState(() {
                        isLoading = true;
                        errorText = null;
                      });
                      try {
                        await Supabase.instance.client.auth
                            .updateUser(UserAttributes(password: newPass));
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                s.t('Password updated successfully.',
                                    'Password aggiornata con successo.'),
                                style: GoogleFonts.manrope()),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ));
                        }
                      } catch (e) {
                        setState(() {
                          isLoading = false;
                          errorText = s.t(
                              'Failed to update password. Please try again.',
                              'Errore nell\'aggiornamento. Riprova.');
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : Text(s.t('Update', 'Aggiorna'),
                      style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700)),
            ),
          ],
        );
      });
    },
  );

  newPassCtrl.dispose();
  confirmCtrl.dispose();
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _avatarPrefKey = 'profile_avatar_path';
  String? _avatarPath;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_avatarPrefKey);
    if (path != null && File(path).existsSync()) {
      if (mounted) setState(() => _avatarPath = path);
    }
  }

  /// Validates real MIME type via magic bytes — extension alone can be spoofed.
  bool _isValidImageMime(Uint8List bytes) {
    if (bytes.length < 12) return false;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 && bytes[1] == 0x50 &&
        bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    // WebP: RIFF....WEBP (bytes 0-3 = RIFF, bytes 8-11 = WEBP)
    if (bytes[0] == 0x52 && bytes[1] == 0x49 &&
        bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 &&
        bytes[10] == 0x42 && bytes[11] == 0x50) return true;
    return false;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (picked == null) return;

    // Valida estensione — solo immagini comuni
    final ext = picked.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      if (mounted) {
        final s = ref.read(appStringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.t('Unsupported file type. Use JPG, PNG or WebP.', 'Tipo di file non supportato. Usa JPG, PNG o WebP.')),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    // Valida dimensione — max 5 MB
    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) {
        final s = ref.read(appStringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.t('Image too large. Max 5 MB.', 'Immagine troppo grande. Max 5 MB.')),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    // Valida MIME reale tramite magic bytes — l'estensione può essere falsificata
    if (!_isValidImageMime(bytes)) {
      if (mounted) {
        final s = ref.read(appStringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.t('Invalid image file. Use a real JPG, PNG or WebP.', 'File immagine non valido. Usa un vero JPG, PNG o WebP.')),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarPrefKey, picked.path);
    if (mounted) setState(() => _avatarPath = picked.path);
  }

  void _copyToClipboard(String text, AppStrings s) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.accountCopied, style: GoogleFonts.manrope()),
        backgroundColor: AppColors.cardBg,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _showDeleteDialog(AppStrings s) async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          s.profileDeleteTitle,
          style: GoogleFonts.manrope(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          s.profileDeleteWarning,
          style: GoogleFonts.manrope(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.profileDeleteCancel,
                style: GoogleFonts.manrope(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.profileDeleteConfirmButton,
                style: GoogleFonts.manrope(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded, color: AppColors.danger, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.profileDeleteFinalTitle,
                style: GoogleFonts.manrope(
                    color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        content: Text(
          s.profileDeleteFinalContent,
          style: GoogleFonts.manrope(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.profileDeleteCancel,
                style: GoogleFonts.manrope(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.profileDeleteFinalButton,
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (secondConfirm != true || !mounted) return;
    await _performDelete(s);
  }

  Future<void> _performDelete(AppStrings s) async {
    setState(() => _isDeleting = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId != null && !kDevMode) {
        await SupabaseService.deleteUserData(userId);
      }
      await ref.read(authProvider.notifier).signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.profileDeleteError, style: GoogleFonts.manrope()),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;
    final s = ref.watch(appStringsProvider);
    final email = kDevMode
        ? 'dev@piplock.ai'
        : Supabase.instance.client.auth.currentUser?.email ?? '—';
    final displayName = email.split('@').first;
    final isPro = profile?.subscriptionTier == 'pro';
    final joinYear = profile?.createdAt.year ?? DateTime.now().year;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          s.profileTitle,
          style: GoogleFonts.manrope(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      body: _isDeleting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.danger),
                  const SizedBox(height: 20),
                  Text(s.profileDeletingData,
                      style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                // ── Avatar hero ──────────────────────────────────────────────
                _buildAvatarHero(displayName, email, isPro, s),
                const SizedBox(height: 28),

                // ── Info account ─────────────────────────────────────────────
                _sectionLabel(s.profileSectionInfo),
                const SizedBox(height: 10),
                _groupedCard([
                  _InfoTileData(
                    icon: Icons.mail_outline_rounded,
                    label: s.profileEmail,
                    value: email,
                    onTap: () => _copyToClipboard(email, s),
                    trailing: const Icon(Icons.copy_outlined, color: AppColors.textTertiary, size: 14),
                  ),
                  _InfoTileData(
                    icon: Icons.badge_outlined,
                    label: s.profileUserId,
                    value: profile?.id != null ? '${profile!.id.substring(0, 8)}…' : '—',
                    onTap: profile?.id != null ? () => _copyToClipboard(profile!.id, s) : null,
                    trailing: profile?.id != null
                        ? const Icon(Icons.copy_outlined, color: AppColors.textTertiary, size: 14)
                        : null,
                  ),
                  _InfoTileData(
                    icon: Icons.calendar_today_outlined,
                    label: s.profileMemberSince,
                    value: joinYear.toString(),
                  ),
                  _InfoTileData(
                    icon: Icons.toll_rounded,
                    label: s.profileTokens,
                    value: '${profile?.tokensAvailable ?? 0} / 2',
                    valueColor: AppColors.accent,
                    onTap: () => Navigator.pushNamed(context, '/tokens'),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 16),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Sicurezza ────────────────────────────────────────────────
                _sectionLabel(s.profileSectionSecurity),
                const SizedBox(height: 10),
                _groupedCard([
                  _InfoTileData(
                    icon: Icons.lock_reset_outlined,
                    label: s.profileChangePassword,
                    value: '',
                    onTap: () => showChangePasswordDialog(context, s),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 16),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Danger zone ──────────────────────────────────────────────
                _sectionLabel(s.profileSectionDanger),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _showDeleteDialog(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 19),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            s.profileDeleteAccount,
                            style: GoogleFonts.manrope(
                                color: AppColors.danger, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.danger.withValues(alpha: 0.5), size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildAvatarHero(String name, String email, bool isPro, AppStrings s) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: _avatarPath == null ? AppColors.logoGradient : null,
                    shape: BoxShape.circle,
                    image: _avatarPath != null
                        ? DecorationImage(image: FileImage(File(_avatarPath!)), fit: BoxFit.cover)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _avatarPath == null
                      ? Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'T',
                            style: GoogleFonts.manrope(
                                color: Colors.black, fontSize: 38, fontWeight: FontWeight.w800),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: AppColors.accent, size: 15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            email,
            style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickAvatar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cardBg2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                s.profileEditPhoto,
                style: GoogleFonts.manrope(
                    color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/tokens'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isPro
                    ? AppColors.accent.withValues(alpha: 0.12)
                    : AppColors.cardBg2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPro
                      ? AppColors.accent.withValues(alpha: 0.35)
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPro ? Icons.diamond_rounded : Icons.lock_open_rounded,
                    color: isPro ? AppColors.accent : AppColors.textSecondary,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPro ? 'Pro Plan' : 'Trial · Upgrade to Pro',
                    style: GoogleFonts.manrope(
                      color: isPro ? AppColors.accent : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.manrope(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _groupedCard(List<_InfoTileData> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              _buildInfoRow(tiles[i]),
              if (i < tiles.length - 1)
                const Divider(height: 1, color: AppColors.border, indent: 52),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(_InfoTileData tile) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tile.onTap,
        highlightColor: AppColors.accent.withValues(alpha: 0.06),
        splashColor: AppColors.accent.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(tile.icon, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  tile.label,
                  style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
              if (tile.value.isNotEmpty)
                Text(
                  tile.value,
                  style: GoogleFonts.manrope(
                    color: tile.valueColor ?? AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (tile.trailing != null) ...[
                const SizedBox(width: 6),
                tile.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTileData {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _InfoTileData({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
    this.trailing,
  });
}
