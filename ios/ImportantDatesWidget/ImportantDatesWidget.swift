import SwiftUI
import WidgetKit

// "Upcoming Dates" widget for the home screen and lock screen.
//
// The app (lib/services/home_widget_sync.dart) saves the active items as JSON
// under "upcoming_dates" in the shared App Group:
//   {"showDetails": bool, "items": [{"due": "yyyy-MM-dd", "item", "name", "travel"}]}
// soonest first. Days left are worked out here, and the timeline has an entry
// for each of the next midnights, so the widget moves on with the date even
// when the app isn't opened.
//
// The App Group id comes from Info.plist (AppGroupId = $(APP_GROUP_ID), set
// per flavor in ios/Flutter/Flavor-<flavor>.xcconfig).

// MARK: - Data

struct WidgetItem: Identifiable {
  let id: Int
  let due: Date
  let item: String
  let name: String
  let travel: Bool
}

struct DatesEntry: TimelineEntry {
  let date: Date
  let items: [WidgetItem]
  let showDetails: Bool

  func days(to item: WidgetItem) -> Int {
    let cal = Calendar.current
    return cal.dateComponents([.day], from: cal.startOfDay(for: date), to: item.due).day ?? 0
  }

  var overdueCount: Int { items.filter { days(to: $0) < 0 }.count }
  func count(within range: ClosedRange<Int>) -> Int { items.filter { range.contains(days(to: $0)) }.count }

  static let sample = DatesEntry(
    date: Date(),
    items: [
      WidgetItem(id: 0, due: Calendar.current.date(byAdding: .day, value: 12, to: Date())!, item: "Passport", name: "Me", travel: true),
      WidgetItem(id: 1, due: Calendar.current.date(byAdding: .day, value: 27, to: Date())!, item: "Car Insurance", name: "Family car", travel: false),
      WidgetItem(id: 2, due: Calendar.current.date(byAdding: .day, value: 64, to: Date())!, item: "Boiler Service", name: "Home", travel: false),
      WidgetItem(id: 3, due: Calendar.current.date(byAdding: .day, value: 140, to: Date())!, item: "Driving Licence", name: "Me", travel: false),
    ],
    showDetails: true)
}

enum WidgetStore {
  static let dataKey = "upcoming_dates"

  static var appGroupId: String? {
    guard let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String,
          !id.isEmpty, !id.hasPrefix("$(") else { return nil }
    return id
  }

  static func load(at date: Date = Date()) -> DatesEntry {
    guard let group = appGroupId,
          let raw = UserDefaults(suiteName: group)?.string(forKey: dataKey),
          let data = raw.data(using: .utf8),
          let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    else {
      return DatesEntry(date: date, items: [], showDetails: true)
    }
    let showDetails = json["showDetails"] as? Bool ?? true
    let list = json["items"] as? [[String: Any]] ?? []
    var items: [WidgetItem] = []
    for (index, o) in list.enumerated() {
      guard let due = parseDay(o["due"] as? String) else { continue }
      items.append(WidgetItem(
        id: index,
        due: due,
        item: o["item"] as? String ?? "",
        name: o["name"] as? String ?? "",
        travel: o["travel"] as? Bool ?? false))
    }
    return DatesEntry(date: date, items: items, showDetails: showDetails)
  }

  /// "2027-03-09" -> local midnight of that day.
  static func parseDay(_ s: String?) -> Date? {
    guard let parts = s?.split(separator: "-").compactMap({ Int($0) }), parts.count == 3 else { return nil }
    return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
  }
}

// MARK: - Timeline

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> DatesEntry { .sample }

  func getSnapshot(in context: Context, completion: @escaping (DatesEntry) -> Void) {
    let entry = WidgetStore.load()
    // The widget gallery shows sample data until the app has saved some.
    completion(context.isPreview && entry.items.isEmpty ? .sample : entry)
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<DatesEntry>) -> Void) {
    let now = Date()
    let cal = Calendar.current
    let today = cal.startOfDay(for: now)
    var entries = [WidgetStore.load(at: now)]
    for offset in 1...7 {
      if let midnight = cal.date(byAdding: .day, value: offset, to: today) {
        entries.append(WidgetStore.load(at: midnight))
      }
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

// MARK: - Presentation

enum Look {
  static let primary = Color(red: 0.16, green: 0.39, blue: 0.92)
  static let success = Color(red: 0.12, green: 0.66, blue: 0.43)
  static let warning = Color(red: 0.95, green: 0.55, blue: 0.12)
  static let danger = Color(red: 0.90, green: 0.22, blue: 0.27)

  /// Same thresholds as AppTheme.statusColor in the app.
  static func color(_ days: Int) -> Color {
    if days < 0 { return danger }
    if days <= 30 { return warning }
    return success
  }

  static func daysText(_ days: Int) -> String {
    switch days {
    case ..<(-1): return "\(-days) days overdue"
    case -1: return "1 day overdue"
    case 0: return "Today"
    case 1: return "Tomorrow"
    default: return "\(days) days"
    }
  }

  static let dueFormat: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("d MMM yyyy")
    return f
  }()

  static func title(_ item: WidgetItem, details: Bool) -> String {
    details ? (item.item.isEmpty ? "Item" : item.item) : "Due \(dueFormat.string(from: item.due))"
  }

  static func subtitle(_ item: WidgetItem, details: Bool) -> String {
    let due = dueFormat.string(from: item.due)
    guard details else { return due }
    return item.name.isEmpty ? due : "\(item.name) · \(due)"
  }

  static func icon(_ item: WidgetItem) -> String {
    if item.travel { return "airplane" }
    let v = item.item.lowercased()
    func has(_ words: [String]) -> Bool { words.contains { v.contains($0) } }
    if has(["passport", "visa"]) { return "airplane" }
    if has(["car", "vehicle", "licence", "license"]) { return "car.fill" }
    if has(["insurance"]) { return "shield.fill" }
    if has(["medical", "health", "doctor"]) { return "cross.case.fill" }
    if has(["house", "home", "boiler"]) { return "house.fill" }
    if has(["membership", "card"]) { return "creditcard.fill" }
    if has(["pet", "dog", "cat"]) { return "pawprint.fill" }
    if has(["warranty", "receipt"]) { return "doc.text.fill" }
    return "calendar"
  }
}

// MARK: - Views

struct ImportantDatesWidgetView: View {
  @Environment(\.widgetFamily) var family
  let entry: DatesEntry

  var body: some View {
    switch family {
    case .accessoryInline: InlineView(entry: entry)
    case .accessoryCircular: CircularView(entry: entry)
    case .accessoryRectangular: RectangularView(entry: entry)
    case .systemSmall: SmallView(entry: entry)
    case .systemLarge: ListView(entry: entry, rows: 6, showTotals: true)
    default: ListView(entry: entry, rows: 3, showTotals: false)
    }
  }
}

struct NothingDueView: View {
  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(Look.success)
      Text("Nothing coming up").font(.footnote).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct Header: View {
  let title: String
  let entry: DatesEntry

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "calendar").foregroundStyle(Look.primary)
      Text(title).font(.subheadline.bold())
      Spacer(minLength: 4)
      if entry.overdueCount > 0 {
        Text("\(entry.overdueCount) overdue").font(.caption.bold()).foregroundStyle(Look.danger)
      } else {
        Text("\(entry.count(within: 0...30)) in 30 days").font(.caption).foregroundStyle(.secondary)
      }
    }
    .lineLimit(1)
  }
}

struct SmallView: View {
  let entry: DatesEntry

  var body: some View {
    if let next = entry.items.first {
      let days = entry.days(to: next)
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Image(systemName: Look.icon(next)).foregroundStyle(Look.color(days))
          Spacer()
          Text("Next").font(.caption2.bold()).foregroundStyle(.secondary)
        }
        Spacer(minLength: 2)
        if days > 1 {
          Text("\(days)").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(Look.color(days))
            .minimumScaleFactor(0.6)
          Text("days").font(.caption).foregroundStyle(.secondary)
        } else {
          Text(Look.daysText(days)).font(.title3.bold()).foregroundStyle(Look.color(days))
            .minimumScaleFactor(0.6)
        }
        Spacer(minLength: 2)
        Text(Look.title(next, details: entry.showDetails)).font(.subheadline.bold()).lineLimit(1)
        Text(Look.subtitle(next, details: entry.showDetails)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      NothingDueView()
    }
  }
}

struct DateRow: View {
  let item: WidgetItem
  let entry: DatesEntry

  var body: some View {
    let days = entry.days(to: item)
    HStack(spacing: 10) {
      Image(systemName: Look.icon(item))
        .font(.footnote)
        .foregroundStyle(Look.color(days))
        .frame(width: 26, height: 26)
        .background(Look.color(days).opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
      VStack(alignment: .leading, spacing: 1) {
        Text(Look.title(item, details: entry.showDetails)).font(.footnote.bold()).lineLimit(1)
        if entry.showDetails {
          Text(Look.subtitle(item, details: true)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
      }
      Spacer(minLength: 4)
      Text(Look.daysText(days)).font(.caption.bold()).foregroundStyle(Look.color(days)).lineLimit(1)
    }
  }
}

struct Total: View {
  let value: Int
  let label: String
  let color: Color

  var body: some View {
    VStack(spacing: 0) {
      Text("\(value)").font(.title3.bold()).foregroundStyle(color)
      Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 6)
    .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
  }
}

struct ListView: View {
  let entry: DatesEntry
  let rows: Int
  let showTotals: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Header(title: "Upcoming", entry: entry)
      if showTotals {
        HStack(spacing: 8) {
          Total(value: entry.count(within: 0...30), label: "Within 30 days", color: Look.warning)
          Total(value: entry.count(within: 31...60), label: "31–60 days", color: .orange)
          Total(value: entry.count(within: 61...90), label: "61–90 days", color: Look.success)
        }
      }
      if entry.items.isEmpty {
        NothingDueView()
      } else {
        ForEach(entry.items.prefix(rows)) { DateRow(item: $0, entry: entry) }
        Spacer(minLength: 0)
      }
    }
  }
}

struct RectangularView: View {
  let entry: DatesEntry

  var body: some View {
    if let next = entry.items.first {
      let days = entry.days(to: next)
      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 4) {
          Image(systemName: Look.icon(next))
          Text(Look.title(next, details: entry.showDetails)).font(.headline).lineLimit(1)
        }
        Text(Look.daysText(days)).font(.subheadline).lineLimit(1)
        if entry.items.count > 1 {
          Text("+\(entry.items.count - 1) more").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      Text("Nothing coming up").font(.subheadline)
    }
  }
}

struct InlineView: View {
  let entry: DatesEntry

  var body: some View {
    if let next = entry.items.first {
      let days = entry.days(to: next)
      let when = Look.daysText(days).lowercased()
      Text(entry.showDetails ? "\(next.item): \(when)" : "Next due: \(when)")
    } else {
      Text("Nothing coming up")
    }
  }
}

struct CircularView: View {
  let entry: DatesEntry

  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      if let next = entry.items.first {
        let days = entry.days(to: next)
        VStack(spacing: -2) {
          Text(days < 0 ? "!" : "\(days)").font(.title3.bold()).minimumScaleFactor(0.5)
          Text(days < 0 ? "overdue" : "days").font(.system(size: 9))
        }
      } else {
        Image(systemName: "checkmark")
      }
    }
  }
}

// MARK: - Widget

struct UpcomingDatesWidget: Widget {
  /// Must match HomeWidgetSync.iOSKind in the app.
  let kind = "UpcomingDatesWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      ImportantDatesWidgetView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .configurationDisplayName("Upcoming Dates")
    .description("Your next renewal and expiry dates.")
    .supportedFamilies([
      .systemSmall, .systemMedium, .systemLarge,
      .accessoryInline, .accessoryCircular, .accessoryRectangular,
    ])
  }
}

@main
struct ImportantDatesWidgetBundle: WidgetBundle {
  var body: some Widget {
    UpcomingDatesWidget()
  }
}

#Preview(as: .systemMedium) {
  UpcomingDatesWidget()
} timeline: {
  DatesEntry.sample
}
