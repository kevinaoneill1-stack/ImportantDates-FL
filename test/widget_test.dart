import 'package:flutter_test/flutter_test.dart';
import 'package:important_dates/models/important_date.dart';
import 'package:important_dates/utils/date_utils.dart';

void main() {
  test('ISO dates match the Swift .iso8601 format', () {
    final d = DateTime.utc(2026, 10, 25, 9, 5, 7, 123);
    expect(DateFormatting.toIso(d), '2026-10-25T09:05:07Z');
  });

  test('Backup JSON from the native iOS app decodes with defaults', () {
    final item = ImportantDate.fromJson({
      'id': '6a1f6c3e-6c8e-4b4b-9b44-111111111111',
      'name': 'Kevin',
      'item': 'Passport',
      'dueDate': '2027-03-01T00:00:00Z',
    });
    expect(item.id, '6A1F6C3E-6C8E-4B4B-9B44-111111111111');
    expect(item.remind30Days, isTrue);
    expect(item.remind90Days, isFalse);
    expect(item.notificationDays, 15);
    expect(item.attachments, isEmpty);
  });

  test('daysBetween ignores time of day', () {
    expect(DateFormatting.daysBetween(DateTime(2026, 3, 28, 23), DateTime(2026, 3, 30, 1)), 2);
  });
}
