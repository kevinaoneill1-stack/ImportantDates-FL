import 'package:local_auth/local_auth.dart';

import 'app_log.dart';

/// Face ID / Touch ID / fingerprint unlock, on top of the app passcode.
/// The passcode always remains as the fallback.
class BiometricUnlock {
  BiometricUnlock._();

  static final _auth = LocalAuthentication();
  static bool? _available;

  /// Whether this device can unlock with biometrics (checked once).
  static Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    try {
      _available = await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (e, st) {
      AppLog.error('Could not check Face ID / fingerprint support', e, st);
      _available = false;
    }
    return _available!;
  }

  /// Asks for Face ID / fingerprint. Returns true when the user passed.
  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(localizedReason: 'Unlock Important Dates');
    } catch (e, st) {
      AppLog.error('Face ID / fingerprint unlock failed', e, st);
      return false;
    }
  }
}
