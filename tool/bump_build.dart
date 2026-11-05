// Increases the build number by one (e.g. 3.0.63FL -> 3.0.64FL) in
// lib/app_info.dart, pubspec.yaml and README.md.
// Run from the project root:  dart run tool/bump_build.dart
//
// Then commit and tag the build in git, e.g.
//   git add -A && git commit -m "ImportantDates 3.0.64FL: ..." && git tag v3.0.64FL && git push && git push --tags
import 'dart:io';

void main() {
  final info = File('lib/app_info.dart');
  final src = info.readAsStringSync();
  final m = RegExp(r"static const String build = '(\d+)';").firstMatch(src);
  if (m == null) {
    stderr.writeln('Could not find the build number in lib/app_info.dart');
    exit(1);
  }
  final current = int.parse(m[1]!);
  final next = current + 1;
  info.writeAsStringSync(src
      .replaceFirst(m[0]!, "static const String build = '$next';")
      .replaceAll('+$current)', '+$next)'));

  final pubspec = File('pubspec.yaml');
  pubspec.writeAsStringSync(pubspec
      .readAsStringSync()
      .replaceFirstMapped(
        RegExp(r'^version: (\d+\.\d+\.\d+)\+\d+', multiLine: true),
        (v) => 'version: ${v[1]}+$next',
      )
      .replaceFirst(RegExp(r'^# Version (\S+), Build \d+', multiLine: true), '# Version 3, Build $next'));

  // Only the version line at the top of README.md; examples and history
  // further down keep their build numbers.
  final readme = File('README.md');
  if (readme.existsSync()) {
    readme.writeAsStringSync(readme.readAsStringSync().replaceFirstMapped(
          RegExp(r'^\*\*Version .*$', multiLine: true),
          (line) => line[0]!.replaceAll('.${current}FL', '.${next}FL').replaceAll('Build ${current}FL', 'Build ${next}FL'),
        ));
  }
  final version = RegExp(r'^version: (\d+\.\d+\.\d+)', multiLine: true).firstMatch(pubspec.readAsStringSync())?[1] ?? '3.0.0';
  stdout.writeln('Build number is now ${next}FL');
  stdout.writeln('When done: git add -A && git commit -m "ImportantDates $version.${next}FL: ..." '
      '&& git tag v$version.${next}FL && git push && git push --tags');
}
