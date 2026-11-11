/// Items added to the Items list (Manage › Items) on each device, so users
/// can pick them instead of typing. Users can delete any of them, and deleted
/// ones are not added again on that device.
///
/// Grouped by when they were added: a device gets each group once. To add more
/// later, add a new group at the end (never change an earlier one), so devices
/// that already have the earlier groups get only the new items.
const defaultItemGroups = <List<String>>[
  // 3.0.70FL
  [
    'Boiler Service',
    'Car Insurance',
    'Car NCT',
    'Car Service',
    'Car Tax',
    'Driving Licence',
    'Drugs Payment Scheme Card',
    'House Insurance',
    'LPT',
    'Passport',
    'Passport Card',
    'Public Service Card',
    'Travel Insurance',
    'TV Licence',
    'VHI',
  ],
  // 3.0.71FL
  ['Health Insurance'],
];

/// Every default item.
final defaultItems = [for (final g in defaultItemGroups) ...g];

/// Items that switch on Travel Document when picked on the Add / Edit screen
/// (ignoring case). The user can still switch it off.
const travelDocumentItems = [
  'Driving Licence',
  'Health Insurance',
  'Passport',
  'Passport Card',
  'Travel Insurance',
];

bool isTravelDocumentItem(String item) {
  final i = item.trim().toLowerCase();
  return travelDocumentItems.any((t) => t.toLowerCase() == i);
}

/// The default items from groups after [groupsDone] that [existing] does not
/// already have (ignoring case).
List<String> missingDefaultItems(Iterable<String> existing, {int groupsDone = 0}) {
  final have = {for (final e in existing) e.trim().toLowerCase()};
  return [
    for (final g in defaultItemGroups.skip(groupsDone))
      for (final d in g)
        if (!have.contains(d.toLowerCase())) d,
  ];
}
