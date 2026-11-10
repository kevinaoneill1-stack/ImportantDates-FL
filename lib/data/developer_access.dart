import 'package:flutter/foundation.dart';

import 'passcode_store.dart';

/// Hidden developer support access.
///
/// The codes are NOT stored in the source code (the repository is public).
/// They are passed in at build time with `--dart-define-from-file`, from the
/// git-ignored file `dev_codes.json` in the project root:
///
///   flutter run --flavor personal -t lib/main_personal.dart --dart-define-from-file=dev_codes.json
///
/// Copy `dev_codes.example.json` to `dev_codes.json` and put your own codes in
/// it. A build made without the file has no developer codes, so developer
/// access is off whatever the build mode.
///
/// Enabled in Debug and Profile builds only. Release builds - including
/// TestFlight and store builds - keep developer access disabled, because
/// Flutter cannot reliably tell a TestFlight install from an App Store one.
/// To test developer controls in a TestFlight build, set
/// `"DEV_FORCE_ENABLE_IN_RELEASE": "true"` in dev_codes.json for that build
/// only.
class DeveloperAccess {
  /// Unlocks every user-passcode check (app lock and Delete All).
  static const overridePasscode = String.fromEnvironment('DEV_OVERRIDE_PASSCODE');

  /// Opens Developer Controls (tap App Information in App Settings).
  static const controlsPasscode = String.fromEnvironment('DEV_CONTROLS_PASSCODE');

  static const bool forceEnableInRelease = bool.fromEnvironment('DEV_FORCE_ENABLE_IN_RELEASE');

  /// True only when the build has developer codes and is not a release build
  /// (unless [forceEnableInRelease] was set for this build).
  static bool get isEnabled =>
      (overridePasscode.isNotEmpty || controlsPasscode.isNotEmpty) && (!kReleaseMode || forceEnableInRelease);

  /// True when [entered] is the developer override passcode (enabled builds only).
  static bool isOverride(String entered) =>
      isEnabled && overridePasscode.isNotEmpty && entered.trim() == overridePasscode;

  static bool matchesUserOrDeveloperPasscode(String entered, PasscodeKind kind) =>
      isOverride(entered) || PasscodeStore.instance.matches(kind, entered);

  static bool matchesControlsPasscode(String entered) =>
      isEnabled && controlsPasscode.isNotEmpty && entered.trim() == controlsPasscode;
}
