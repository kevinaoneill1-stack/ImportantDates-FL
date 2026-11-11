/// Items added to the Items list (Manage › Items) once on each device, so
/// users can pick them instead of typing. Users can delete any of them, and
/// deleted ones are not added again on that device.
const defaultItems = [
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
];

/// The default items that [existing] does not already have (ignoring case).
List<String> missingDefaultItems(Iterable<String> existing) {
  final have = {for (final e in existing) e.trim().toLowerCase()};
  return [for (final d in defaultItems) if (!have.contains(d.toLowerCase())) d];
}
