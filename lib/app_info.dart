/// Release identity shared by the app UI, backups and reports.
///
/// Keep [build] in step with `version:` in pubspec.yaml (3.0.0+63).
class AppInfo {
  static const String appName = 'Important Dates';
  static const String version = '3';

  /// Numeric build number - must match the number after "+" in pubspec.yaml.
  static const String build = '63';

  /// Marks this as the Flutter build. Shown in the app only: Apple and Google
  /// require the real build number to be digits, so letters can't go there.
  static const String buildSuffix = 'FL';

  /// What the app displays, e.g. "63FL".
  static const String displayBuild = '$build$buildSuffix';

  static const String versionString = 'Version $version • Build $displayBuild';
}
