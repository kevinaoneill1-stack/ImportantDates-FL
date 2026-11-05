import 'package:flutter/foundation.dart';

/// Hidden developer support access (same codes as the native app).
///
/// Enabled in Debug and Profile builds only. Release builds - including
/// TestFlight and store builds - keep developer access disabled, because
/// Flutter cannot reliably tell a TestFlight install from an App Store one.
/// To test developer controls in TestFlight, temporarily set
/// [forceEnableInRelease] to true for that build.
class DeveloperAccess {
  static const overridePasscode = '707';
  static const controlsPasscode = '1028';
  static const bool forceEnableInRelease = false;

  static bool get isEnabled => !kReleaseMode || forceEnableInRelease;

  static bool matchesUserOrDeveloperPasscode(String entered, String userPasscode) {
    final value = entered.trim();
    final user = userPasscode.trim();
    if (isEnabled && value == overridePasscode) return true;
    return user.isNotEmpty && value == user;
  }
}
