import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../config/flavor.dart';
import '../data/app_settings.dart';
import '../data/app_store.dart';
import '../models/important_date.dart';
import 'app_log.dart';

/// Keeps the home screen / lock screen widget ("Upcoming Dates") up to date.
///
/// The app writes a small JSON summary of the active items to storage the
/// widget can read (an App Group on iOS, SharedPreferences on Android) and
/// asks the system to redraw the widget. The widget works out the days left
/// itself from each due date, so the count stays right from day to day
/// without the app being opened.
///
/// Native code: `ios/ImportantDatesWidget/` (WidgetKit) and
/// `android/app/src/main/kotlin/.../UpcomingDatesWidgetProvider.kt`.
/// Setup notes: WIDGET_SETUP.md. macOS has no widget yet.
class HomeWidgetSync {
  HomeWidgetSync._();
  static final HomeWidgetSync instance = HomeWidgetSync._();

  /// Storage key read by the native widgets.
  static const dataKey = 'upcoming_dates';

  /// WidgetKit `kind` of the iOS widget.
  static const iOSKind = 'UpcomingDatesWidget';

  /// Full class name of the Android widget. The package is the Gradle
  /// namespace, which is the same for both flavors (the personal flavor only
  /// changes the application id), so the name is given in full.
  static const androidProvider = 'com.kevinaoneill.importantdates.UpcomingDatesWidgetProvider';

  /// How many items the widget gets at most (the large widget shows 6; the
  /// rest only count towards the 30 / 60 / 90 day totals).
  static const maxItems = 40;

  /// App Group shared with the widget extension; must match APP_GROUP_ID in
  /// ios/Flutter/Flavor-<flavor>.xcconfig.
  static String get appGroupId => switch (Flavor.current) {
        AppFlavor.personal => 'group.com.kevinaoneill.ImportantDates.personal',
        AppFlavor.public => 'group.com.kevinaoneill.ImportantDates',
      };

  static bool get supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Timer? _debounce;
  String? _lastSent;

  Future<void> init() async {
    if (!supported) return;
    try {
      if (Platform.isIOS) await HomeWidget.setAppGroupId(appGroupId);
    } catch (e) {
      AppLog.error('Could not connect to the home screen widget', e);
      return;
    }
    AppStore.instance.addListener(_schedule);
    AppSettings.instance.addListener(_schedule);
    await refresh();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), refresh);
  }

  /// Sends the current items to the widget (skipped when nothing changed).
  Future<void> refresh() async {
    if (!supported) return;
    final store = AppStore.instance;
    // Never replace the widget's last good data with an empty list because
    // the data file could not be read.
    if (store.loadFailed) return;
    final json = jsonEncode(buildPayload(
      store.dates,
      showDetails: AppSettings.instance.widgetShowDetails,
    ));
    if (json == _lastSent) return;
    try {
      await HomeWidget.saveWidgetData<String>(dataKey, json);
      await HomeWidget.updateWidget(iOSName: iOSKind, qualifiedAndroidName: androidProvider);
      _lastSent = json;
    } catch (e) {
      AppLog.error('Could not update the home screen widget', e);
    }
  }

  /// What the widget receives: the active (not completed) items, soonest
  /// first, overdue ones included. Due dates are local calendar dates
  /// (yyyy-MM-dd). With [showDetails] off, item and name are left out, so the
  /// widget shows only counts and days.
  @visibleForTesting
  static Map<String, dynamic> buildPayload(List<ImportantDate> dates, {required bool showDetails}) {
    final active = dates.where((d) => !d.isAccomplished).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    String two(int v) => v.toString().padLeft(2, '0');
    String day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
    return {
      'version': 1,
      'showDetails': showDetails,
      'items': [
        for (final d in active.take(maxItems))
          {
            'due': day(d.dueDate),
            'travel': d.isTravelDocument,
            if (showDetails) 'item': d.item,
            if (showDetails) 'name': d.name,
          },
      ],
    };
  }
}
