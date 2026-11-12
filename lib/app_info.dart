/// Release identity shared by the app UI, backups and reports.
///
/// The build number goes up by one for every change set: run
/// `dart run tool/bump_build.dart` from the project root, which updates this
/// file, pubspec.yaml and README.md together (pubspec.yaml: 3.0.0+73).
class AppInfo {
  static const String appName = 'Important Dates';
  static const String version = '3';

  /// Numeric build number - must match the number after "+" in pubspec.yaml.
  static const String build = '73';

  /// Marks this as the Flutter build. Shown in the app only: Apple and Google
  /// require the real build number to be digits, so letters can't go there.
  static const String buildSuffix = 'FL';

  /// What the app displays, e.g. "63FL".
  static const String displayBuild = '$build$buildSuffix';

  /// Full version, e.g. 3.0.64FL (used for git tags).
  static const String fullVersion = '3.0.$build$buildSuffix';

  static const String versionString = 'Version $version • Build $displayBuild';
}
