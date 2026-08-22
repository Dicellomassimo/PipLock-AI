import 'package:local_auth/local_auth.dart';

class FaceAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Verifica se il dispositivo supporta la biometria facciale o strong biometrics.
  static Future<bool> isFaceIdAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final availableBiometrics = await _auth.getAvailableBiometrics();
      return availableBiometrics.contains(BiometricType.face) ||
          availableBiometrics.contains(BiometricType.strong);
    } catch (_) {
      return false;
    }
  }

  /// Autentica l'utente tramite biometria (solo biometria, no PIN di fallback).
  static Future<bool> authenticate({
    String reason = 'Conferma la tua identità per continuare',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
