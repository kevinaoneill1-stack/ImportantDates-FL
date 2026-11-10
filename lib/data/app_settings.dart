import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HomeImageDisplayMode { fill, fit, center }

extension HomeImageDisplayModeName on HomeImageDisplayMode {
  /// Raw values match the Swift enum ("Fill", "Fit", "Center") for backups.
  String get rawValue => switch (this) {
        HomeImageDisplayMode.fill => 'Fill',
        HomeImageDisplayMode.fit => 'Fit',
        HomeImageDisplayMode.center => 'Center',
      };

  static HomeImageDisplayMode fromRaw(String? raw) => switch (raw) {
        'Fit' => HomeImageDisplayMode.fit,
        'Center' => HomeImageDisplayMode.center,
        _ => HomeImageDisplayMode.fill,
      };
}

/// Device-local preferences (the equivalent of the Swift @AppStorage values).
/// Keys are kept identical to the native app.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);
  static late AppSettings instance;

  static Future<void> load() async {
    instance = AppSettings._(await SharedPreferences.getInstance());
  }

  final SharedPreferences _prefs;

  /// Shown on the Home page until the user enters their own title
  /// (Manage › App Settings › Home Appearance, or tap the title on Home).
  static const defaultHomeTitle = 'Your Name here';

  bool _b(String k, bool d) => _prefs.getBool(k) ?? d;
  String _s(String k, String d) => _prefs.getString(k) ?? d;
  double _d(String k, double d) => _prefs.getDouble(k) ?? d;
  int _i(String k, int d) => _prefs.getInt(k) ?? d;

  Future<void> _set(String k, Object? v) async {
    if (v == null) {
      await _prefs.remove(k);
    } else if (v is bool) {
      await _prefs.setBool(k, v);
    } else if (v is String) {
      await _prefs.setString(k, v);
    } else if (v is int) {
      await _prefs.setInt(k, v);
    } else if (v is double) {
      await _prefs.setDouble(k, v);
    }
    notifyListeners();
  }

  // App passcode (the passcode itself is hashed in PasscodeStore).
  bool get passcodeEnabled => _b('passcodeEnabled', false);
  set passcodeEnabled(bool v) => _set('passcodeEnabled', v);

  /// Also allow Face ID / Touch ID / fingerprint on the lock screen.
  bool get biometricUnlockEnabled => _b('biometricUnlockEnabled', false);
  set biometricUnlockEnabled(bool v) => _set('biometricUnlockEnabled', v);

  // Delete All passcode (hashed in PasscodeStore).
  bool get deleteAllPasscodeEnabled => _b('deleteAllPasscodeEnabled', false);
  set deleteAllPasscodeEnabled(bool v) => _set('deleteAllPasscodeEnabled', v);

  // Tools shortcuts
  bool get showSearch => _b('showHomeSearch', true);
  set showSearch(bool v) => _set('showHomeSearch', v);
  bool get showTimeline => _b('showHomeTimeline', true);
  set showTimeline(bool v) => _set('showHomeTimeline', v);
  bool get showReports => _b('showHomeReports', true);
  set showReports(bool v) => _set('showHomeReports', v);
  bool get showStatistics => _b('showHomeStatistics', true);
  set showStatistics(bool v) => _set('showHomeStatistics', v);

  // Home appearance
  int get homeImageVersion => _i('homeAppearanceImageVersion', 0);
  void bumpHomeImageVersion() => _set('homeAppearanceImageVersion', homeImageVersion + 1);
  HomeImageDisplayMode get homeDisplayMode =>
      HomeImageDisplayModeName.fromRaw(_prefs.getString('homeAppearanceDisplayMode'));
  set homeDisplayMode(HomeImageDisplayMode v) => _set('homeAppearanceDisplayMode', v.rawValue);
  String? get homeDisplayModeRaw => _prefs.getString('homeAppearanceDisplayMode');
  set homeDisplayModeRaw(String? v) => _set('homeAppearanceDisplayMode', v);
  double get homeBrightness => _d('homeAppearanceBrightness', 0.0);
  set homeBrightness(double v) => _set('homeAppearanceBrightness', v);
  bool get hasHomeBrightness => _prefs.containsKey('homeAppearanceBrightness');
  double get homeBlur => _d('homeAppearanceBlur', 0.0);
  set homeBlur(double v) => _set('homeAppearanceBlur', v);
  bool get hasHomeBlur => _prefs.containsKey('homeAppearanceBlur');
  String get homeTitle => _s('homeAppearanceTitle', defaultHomeTitle);
  set homeTitle(String v) => _set('homeAppearanceTitle', v);
  bool get hasHomeTitle => _prefs.containsKey('homeAppearanceTitle');
  String get displayHomeTitle {
    final t = homeTitle.trim();
    return t.isEmpty ? defaultHomeTitle : t;
  }

  // Automatic backup
  bool get autoBackupEnabled => _b('automaticBackupEnabled', true);
  set autoBackupEnabled(bool v) => _set('automaticBackupEnabled', v);
  int get autoBackupFrequencyDays => _i('automaticBackupFrequencyDays', 1);
  set autoBackupFrequencyDays(int v) => _set('automaticBackupFrequencyDays', v);
  DateTime? get lastBackupDate {
    final ms = _prefs.getInt('automaticBackupLastDateMs');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
  set lastBackupDate(DateTime? v) => _set('automaticBackupLastDateMs', v?.millisecondsSinceEpoch);

  // Cloud Sync
  bool get cloudSyncEnabled => _b('cloudSyncEnabled', false);
  set cloudSyncEnabled(bool v) => _set('cloudSyncEnabled', v);

  /// Preferences that follow the account to every device. Passcodes, backup
  /// settings and the disclaimer stay on each device, as in the iOS app.
  /// The Home title is only sent once the user has set one, so a new device
  /// never replaces a real title on other devices with the placeholder.
  Map<String, dynamic> toSyncValues() => {
        if (hasHomeTitle) 'homeTitle': homeTitle,
        'homeImageDisplayMode': homeDisplayMode.rawValue,
        'homeImageBrightness': homeBrightness,
        'homeImageBlur': homeBlur,
        'showHomeSearch': showSearch,
        'showHomeTimeline': showTimeline,
        'showHomeReports': showReports,
        'showHomeStatistics': showStatistics,
      };

  Future<void> applySyncValues(Map<String, dynamic> m) async {
    Future<void> put(String key, Object? v) async {
      if (v == null) return;
      if (v is bool) await _prefs.setBool(key, v);
      if (v is String) await _prefs.setString(key, v);
      if (v is num) await _prefs.setDouble(key, v.toDouble());
    }

    await put('homeAppearanceTitle', m['homeTitle'] as String?);
    await put('homeAppearanceDisplayMode', m['homeImageDisplayMode'] as String?);
    await put('homeAppearanceBrightness', m['homeImageBrightness'] as num?);
    await put('homeAppearanceBlur', m['homeImageBlur'] as num?);
    await put('showHomeSearch', m['showHomeSearch'] as bool?);
    await put('showHomeTimeline', m['showHomeTimeline'] as bool?);
    await put('showHomeReports', m['showHomeReports'] as bool?);
    await put('showHomeStatistics', m['showHomeStatistics'] as bool?);
    notifyListeners();
  }

  // First launch: Help & Instructions is shown once.
  bool get firstLaunchHelpShown => _b('firstLaunchHelpShown', false);
  set firstLaunchHelpShown(bool v) => _set('firstLaunchHelpShown', v);

  // Disclaimer
  bool get developerDisclaimerEnabled => _b('developerDisclaimerEnabled', true);
  set developerDisclaimerEnabled(bool v) => _set('developerDisclaimerEnabled', v);
  String get disclaimerAcknowledgedVersion => _s('disclaimerAcknowledgedVersion', '');
  set disclaimerAcknowledgedVersion(String v) => _set('disclaimerAcknowledgedVersion', v);
}
