import 'package:flutter_test/flutter_test.dart';
import 'package:important_dates/data/default_items.dart';

void main() {
  test('there are 15 default items, no duplicates', () {
    expect(defaultItems, hasLength(15));
    expect(defaultItems.map((e) => e.toLowerCase()).toSet(), hasLength(15));
  });

  test('a new install gets them all', () {
    expect(missingDefaultItems(const []), defaultItems);
  });

  test('items already there are not added twice, whatever the case', () {
    final missing = missingDefaultItems(const ['passport', ' Car Tax ', 'Dentist']);
    expect(missing, isNot(contains('Passport')));
    expect(missing, isNot(contains('Car Tax')));
    expect(missing, hasLength(13));
  });
}
