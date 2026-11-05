import 'package:flutter/material.dart';

import '../models/important_date.dart';

class AppTheme {
  static const primary = Color.fromRGBO(41, 99, 235, 1); // 0.16, 0.39, 0.92
  static const secondary = Color.fromRGBO(99, 64, 219, 1); // 0.39, 0.25, 0.86
  static const success = Color.fromRGBO(31, 168, 110, 1); // 0.12, 0.66, 0.43
  static const warning = Color.fromRGBO(242, 140, 31, 1); // 0.95, 0.55, 0.12
  static const danger = Color.fromRGBO(230, 56, 69, 1); // 0.90, 0.22, 0.27

  static const allItemsAccent = Colors.blue;
  static const travelDocsAccent = Colors.cyan;
  static const managementAccent = Colors.orange;
  static const manageItemsAccent = Colors.purple;
  static const manageNamesAccent = Colors.teal;
  static const backupAccent = Colors.indigo;

  static Color statusColor(int daysRemaining) {
    if (daysRemaining < 0) return danger;
    if (daysRemaining <= 30) return warning;
    return success;
  }

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: b, primary: b == Brightness.light ? primary : null);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }
}

/// Category-aware icon, colour and status wording (ItemPresentation.swift).
class ItemPresentation {
  static IconData icon(ImportantDate item) {
    final v = item.item.toLowerCase();
    bool has(List<String> words) => words.any(v.contains);
    if (item.isTravelDocument || has(['passport', 'visa'])) return Icons.flight_takeoff_rounded;
    if (has(['car', 'vehicle', 'licence', 'license'])) return Icons.directions_car_rounded;
    if (has(['insurance'])) return Icons.shield_rounded;
    if (has(['medical', 'health', 'doctor'])) return Icons.medical_services_rounded;
    if (has(['house', 'home', 'boiler'])) return Icons.home_rounded;
    if (has(['membership', 'card'])) return Icons.credit_card_rounded;
    if (has(['pet', 'dog', 'cat'])) return Icons.pets_rounded;
    if (has(['warranty', 'receipt'])) return Icons.receipt_long_rounded;
    return Icons.event_rounded;
  }

  static Color accent(ImportantDate item) =>
      item.isAccomplished ? AppTheme.success : AppTheme.statusColor(item.daysRemaining);

  static String statusText(ImportantDate item) {
    if (item.isAccomplished) return 'Completed';
    final d = item.daysRemaining;
    if (d < 0) return '${-d} days overdue';
    if (d == 0) return 'Due today';
    return '$d days remaining';
  }
}
