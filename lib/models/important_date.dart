import '../utils/date_utils.dart';

/// Attachment metadata. The file bytes live on disk in the attachments folder
/// (see AppStore), and are embedded as base64 only inside backup files.
class ItemAttachment {
  ItemAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.createdAt,
  });

  final String id;
  String fileName;
  String mimeType;
  DateTime createdAt;

  bool get isPdf => mimeType.contains('pdf') || fileName.toLowerCase().endsWith('.pdf');
  bool get isImage {
    final n = fileName.toLowerCase();
    return mimeType.startsWith('image') ||
        n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg') ||
        n.endsWith('.heic') || n.endsWith('.gif') || n.endsWith('.webp');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'mimeType': mimeType,
        'createdAt': DateFormatting.toIso(createdAt),
      };

  factory ItemAttachment.fromJson(Map<String, dynamic> j) => ItemAttachment(
        id: (j['id'] as String).toUpperCase(),
        fileName: j['fileName'] as String? ?? 'Attachment',
        mimeType: j['mimeType'] as String? ?? 'application/octet-stream',
        createdAt: DateFormatting.parseIso(j['createdAt']) ?? DateTime.now(),
      );
}

/// Flutter equivalent of the SwiftData `ImportantDate` model.
class ImportantDate {
  ImportantDate({
    required this.id,
    required this.name,
    required this.item,
    required this.dueDate,
    this.notes = '',
    this.isTravelDocument = false,
    this.isAccomplished = false,
    this.accomplishedDate,
    this.notificationDays = 15,
    this.remind90Days = false,
    this.remind60Days = false,
    this.remind30Days = true,
    this.remind7Days = true,
    List<ItemAttachment>? attachments,
  }) : attachments = attachments ?? [];

  final String id;
  String name;
  String item;
  DateTime dueDate;
  String notes;
  bool isTravelDocument;
  bool isAccomplished;
  DateTime? accomplishedDate;
  int notificationDays;
  bool remind90Days;
  bool remind60Days;
  bool remind30Days;
  bool remind7Days;
  List<ItemAttachment> attachments;

  int get daysRemaining => DateFormatting.daysBetween(DateTime.now(), dueDate);

  List<int> get selectedReminderDays => [
        if (remind90Days) 90,
        if (remind60Days) 60,
        if (remind30Days) 30,
        if (remind7Days) 7,
      ];

  ImportantDate copyAsNew(String newId) => ImportantDate(
        id: newId,
        name: name,
        item: item,
        dueDate: dueDate,
        notes: notes,
        isTravelDocument: isTravelDocument,
        notificationDays: notificationDays,
        remind90Days: remind90Days,
        remind60Days: remind60Days,
        remind30Days: remind30Days,
        remind7Days: remind7Days,
      );

  /// Storage JSON (attachment bytes are not included).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'item': item,
        'dueDate': DateFormatting.toIso(dueDate),
        'notes': notes,
        'isTravelDocument': isTravelDocument,
        'isAccomplished': isAccomplished,
        if (accomplishedDate != null) 'accomplishedDate': DateFormatting.toIso(accomplishedDate!),
        'notificationDays': notificationDays,
        'remind90Days': remind90Days,
        'remind60Days': remind60Days,
        'remind30Days': remind30Days,
        'remind7Days': remind7Days,
        'attachments': attachments.map((a) => a.toJson()).toList(),
      };

  /// Reads both the app's own storage JSON and backup JSON created by the
  /// native iOS app. Missing fields get the same safe defaults as the Swift
  /// `BackupDate` decoder.
  factory ImportantDate.fromJson(Map<String, dynamic> j) => ImportantDate(
        id: (j['id'] as String).toUpperCase(),
        name: j['name'] as String? ?? '',
        item: j['item'] as String? ?? '',
        dueDate: DateFormatting.parseIso(j['dueDate']) ?? DateTime.now(),
        notes: j['notes'] as String? ?? '',
        isTravelDocument: j['isTravelDocument'] as bool? ?? false,
        isAccomplished: j['isAccomplished'] as bool? ?? false,
        accomplishedDate: DateFormatting.parseIso(j['accomplishedDate']),
        notificationDays: (j['notificationDays'] as num?)?.toInt() ?? 15,
        remind90Days: j['remind90Days'] as bool? ?? false,
        remind60Days: j['remind60Days'] as bool? ?? false,
        remind30Days: j['remind30Days'] as bool? ?? true,
        remind7Days: j['remind7Days'] as bool? ?? true,
        attachments: ((j['attachments'] as List?) ?? [])
            .whereType<Map>()
            .map((m) => ItemAttachment.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}
