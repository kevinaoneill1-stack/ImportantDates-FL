import 'package:flutter_test/flutter_test.dart';
import 'package:important_dates/models/important_date.dart';
import 'package:important_dates/services/home_widget_sync.dart';

ImportantDate _date(String id, DateTime due, {bool done = false, bool travel = false}) => ImportantDate(
      id: id,
      name: 'Name $id',
      item: 'Item $id',
      dueDate: due,
      isAccomplished: done,
      isTravelDocument: travel,
    );

void main() {
  test('active items only, soonest first, as local calendar dates', () {
    final payload = HomeWidgetSync.buildPayload([
      _date('A', DateTime(2027, 3, 9, 23, 30)),
      _date('B', DateTime(2026, 1, 2)),
      _date('C', DateTime(2026, 6, 1), done: true),
      _date('D', DateTime(2026, 5, 20), travel: true),
    ], showDetails: true);

    final items = payload['items'] as List;
    expect(items.map((i) => i['item']), ['Item B', 'Item D', 'Item A']);
    expect(items.map((i) => i['due']), ['2026-01-02', '2026-05-20', '2027-03-09']);
    expect(items[1]['travel'], isTrue);
    expect(items[1]['name'], 'Name D');
    expect(payload['showDetails'], isTrue);
  });

  test('without details, no item or name leaves the app', () {
    final payload = HomeWidgetSync.buildPayload([_date('A', DateTime(2026, 1, 2))], showDetails: false);
    final item = (payload['items'] as List).single as Map;
    expect(item.containsKey('item'), isFalse);
    expect(item.containsKey('name'), isFalse);
    expect(item['due'], '2026-01-02');
    expect(payload['showDetails'], isFalse);
  });

  test('at most maxItems are sent', () {
    final many = [for (var i = 0; i < 60; i++) _date('$i', DateTime(2026, 1, 1).add(Duration(days: i)))];
    final items = HomeWidgetSync.buildPayload(many, showDetails: true)['items'] as List;
    expect(items, hasLength(HomeWidgetSync.maxItems));
    expect(items.first['due'], '2026-01-01');
  });
}
