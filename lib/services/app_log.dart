import 'package:flutter/foundation.dart';

/// One logged problem.
class AppLogEntry {
  AppLogEntry(this.time, this.message, this.detail);
  final DateTime time;
  final String message;
  final String detail;
}

/// A small in-memory log of recent problems, so errors that the app recovers
/// from are not lost silently. Shown in Manage › App Settings › Data & Sync
/// Status (Recent Problems). Nothing is sent anywhere.
class AppLog {
  AppLog._();

  static const _capacity = 50;
  static final List<AppLogEntry> _entries = [];

  /// Changes when an entry is added or the log is cleared.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  /// Newest first.
  static List<AppLogEntry> get entries => List.unmodifiable(_entries.reversed);

  /// Records a problem the app has handled. [message] says what was being
  /// done, in plain words; [error] is the exception.
  static void error(String message, [Object? error, StackTrace? stack]) {
    final detail = error == null ? '' : error.toString();
    debugPrint('Important Dates: $message${detail.isEmpty ? '' : ': $detail'}');
    if (stack != null && kDebugMode) debugPrint(stack.toString());
    _entries.add(AppLogEntry(DateTime.now(), message, detail));
    if (_entries.length > _capacity) _entries.removeAt(0);
    changes.value++;
  }

  static void clear() {
    _entries.clear();
    changes.value++;
  }
}
