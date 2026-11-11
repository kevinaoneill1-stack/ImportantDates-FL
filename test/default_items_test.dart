import 'package:flutter_test/flutter_test.dart';
import 'package:important_dates/data/default_items.dart';

void main() {
  test('there are 16 default items, no duplicates', () {
    expect(defaultItems, hasLength(16));
    expect(defaultItems.map((e) => e.toLowerCase()).toSet(), hasLength(16));
    expect(defaultItems, contains('Health Insurance'));
  });

  test('a new install gets them all', () {
    expect(missingDefaultItems(const []), defaultItems);
  });

  test('a device that had the first 15 gets only Health Insurance', () {
    expect(missingDefaultItems(const [], groupsDone: 1), ['Health Insurance']);
  });

  test('items already there are not added twice, whatever the case', () {
    final missing = missingDefaultItems(const ['passport', ' Car Tax ', 'Dentist']);
    expect(missing, isNot(contains('Passport')));
    expect(missing, isNot(contains('Car Tax')));
    expect(missing, hasLength(14));
  });

  test('travel document items', () {
    for (final item in ['Passport', 'Passport Card', 'Travel Insurance', 'Driving Licence', 'Health Insurance']) {
      expect(isTravelDocumentItem(item), isTrue, reason: item);
    }
    expect(isTravelDocumentItem(' passport '), isTrue);
    expect(isTravelDocumentItem('Car Tax'), isFalse);
    expect(travelDocumentItems.every(defaultItems.contains), isTrue);
  });
}
