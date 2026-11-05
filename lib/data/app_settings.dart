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

  static const defaultHomeTitle = 'Laura & Kevin';

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

  // App passcode
  bool get passcodeEnabled => _b('passcodeEnabled', false);
  set passcodeEnabled(bool v) => _set('passcodeEnabled', v);
  String get appPasscode => _s('appPasscode', '');
  set appPasscode(String v) => _set('appPasscode', v);

  // Delete All passcode
  bool get deleteAllPasscodeEnabled => _b('deleteAllPasscodeEnabled', false);
  set deleteAllPasscodeEnabled(bool v) => _set('deleteAllPasscodeEnabled', v);
  String get deleteAllPasscode => _s('deleteAllPasscode', '');
  set deleteAllPasscode(String v) => _set('deleteAllPasscode', v);

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

  // Disclaimer
  bool get developerDisclaimerEnabled => _b('developerDisclaimerEnabled', true);
  set developerDisclaimerEnabled(bool v) => _set('developerDisclaimerEnabled', v);
  String get disclaimerAcknowledgedVersion => _s('disclaimerAcknowledgedVersion', '');
  set disclaimerAcknowledgedVersion(String v) => _set('disclaimerAcknowledgedVersion', v);
}
