import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/important_date.dart';
import '../services/app_log.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import 'app_settings.dart';
import 'default_items.dart';

/// Single source of truth for Important Dates records, item types and names.
///
/// Records are saved as JSON in the app's private Application Support folder.
/// Attachment files are saved next to it, one file per attachment.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();
  static const _uuid = Uuid();

  final List<ImportantDate> _dates = [];
  final List<String> _items = [];
  final List<String> _people = [];

  late Directory _root;
  late Directory _attachmentsDir;
  Timer? _backupDebounce;

  /// Cloud Sync hooks (set by CloudSync / AttachmentSync when they start).
  /// [onLocalChange] runs after every change made on this device.
  void Function()? onLocalChange;

  /// Runs when an attachment is removed on this device, so its cloud copy
  /// can be deleted too.
  Future<void> Function(ItemAttachment attachment)? onAttachmentRemoved;

  /// True when the data file existed but could not be read at start-up. The
  /// file is copied aside first (important_dates.json.unreadable-…), so it is
  /// never lost when the app later saves.
  bool loadFailed = false;

  List<ImportantDate> get dates => List.unmodifiable(_dates);
  List<String> get items => List.unmodifiable(_items);
  List<String> get people => List.unmodifiable(_people);

  Directory get rootDirectory => _root;
  File get _dataFile => File('${_root.path}/important_dates.json');
  File get homeImageFile => File('${_root.path}/SelectedHomeImage.jpg');

  static String newId() => _uuid.v4().toUpperCase();

  Future<void> load() async {
    final support = await getApplicationSupportDirectory();
    _root = Directory('${support.path}/ImportantDates');
    _attachmentsDir = Directory('${_root.path}/Attachments');
    await _attachmentsDir.create(recursive: true);

    if (await _dataFile.exists()) {
      try {
        final json = jsonDecode(await _dataFile.readAsString()) as Map<String, dynamic>;
        _dates
          ..clear()
          ..addAll(((json['dates'] as List?) ?? [])
              .whereType<Map>()
              .map((m) => ImportantDate.fromJson(Map<String, dynamic>.from(m))));
        _items
          ..clear()
          ..addAll(((json['items'] as List?) ?? []).map(_nameOf));
        _people
          ..clear()
          ..addAll(((json['people'] as List?) ?? []).map(_nameOf));
        _sortLists();
      } catch (e) {
        loadFailed = true;
        AppLog.error('Could not read the data file (a copy was set aside)', e);
        try {
          await _dataFile.copy('${_dataFile.path}.unreadable-${DateTime.now().millisecondsSinceEpoch}');
        } catch (e) {
          AppLog.error('Could not set aside the unreadable data file', e);
        }
      }
    }
    await _addDefaultItemsOnce();
  }

  /// Puts default Items this device has not had yet into the list (new and
  /// existing installs). Items the user deletes later stay deleted. Skipped
  /// when the data file could not be read.
  Future<void> _addDefaultItemsOnce() async {
    final settings = AppSettings.instance;
    final done = settings.defaultItemGroupsAdded;
    if (done >= defaultItemGroups.length || loadFailed) return;
    final missing = missingDefaultItems(_items, groupsDone: done);
    if (missing.isNotEmpty) {
      _items.addAll(missing);
      _sortLists();
      await _save(triggerBackup: false);
    }
    settings.defaultItemGroupsAdded = defaultItemGroups.length;
  }

  static String _nameOf(dynamic v) => v is Map ? (v['name'] as String? ?? '') : v.toString();

  void _sortLists() {
    _items.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _people.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> _save({bool triggerBackup = true, bool local = true}) async {
    final json = {
      'schema': 1,
      'dates': _dates.map((d) => d.toJson()).toList(),
      'items': _items.map((n) => {'name': n}).toList(),
      'people': _people.map((n) => {'name': n}).toList(),
    };
    final tmp = File('${_dataFile.path}.tmp');
    await tmp.writeAsString(jsonEncode(json), flush: true);
    await tmp.rename(_dataFile.path);
    notifyListeners();
    if (triggerBackup) _scheduleChangeBackup();
    if (local) onLocalChange?.call();
  }

  // ---- Cloud Sync access ----

  /// The live lists, for CloudSync to apply changes from other devices.
  List<ImportantDate> get syncDates => _dates;
  List<String> get syncItems => _items;
  List<String> get syncPeople => _people;

  /// Saves changes that came from the cloud without sending them back.
  Future<void> remoteChanged() async {
    _sortLists();
    await _save(local: false);
  }

  /// Deletes the local copies of attachment files (not their cloud copies).
  Future<void> deleteLocalAttachmentFiles(Iterable<ItemAttachment> attachments) async {
    for (final a in attachments) {
      await _deleteAttachmentFile(a.id);
    }
  }

  /// Saves after an attachment's cloud id changed (no backup needed).
  Future<void> attachmentsChanged() => _save(triggerBackup: false);

  /// Changes made close together share one backup, four seconds after the
  /// last change (same behaviour as the native app).
  void _scheduleChangeBackup() {
    if (!AppSettings.instance.autoBackupEnabled) return;
    _backupDebounce?.cancel();
    _backupDebounce = Timer(const Duration(seconds: 4), () async {
      try {
        await BackupService.createAutomaticBackup();
      } catch (e) {
        AppLog.error('Automatic backup after a change failed', e);
      }
    });
  }

  ImportantDate? byId(String id) {
    for (final d in _dates) {
      if (d.id == id) return d;
    }
    return null;
  }

  // ---- Records ----

  Future<void> upsert(ImportantDate date, {bool requestNotificationPermission = false}) async {
    final i = _dates.indexWhere((d) => d.id == date.id);
    if (i >= 0) {
      _dates[i] = date;
    } else {
      _dates.add(date);
    }
    await _save();
    await NotificationService.schedule(date, requestPermission: requestNotificationPermission);
  }

  Future<void> delete(ImportantDate date) async {
    await NotificationService.cancel(date);
    _dates.removeWhere((d) => d.id == date.id);
    for (final a in date.attachments) {
      await _deleteAttachmentFile(a.id);
      await onAttachmentRemoved?.call(a);
    }
    await _save();
  }

  Future<void> toggleComplete(ImportantDate date) async {
    date.isAccomplished = !date.isAccomplished;
    date.accomplishedDate = date.isAccomplished ? DateTime.now() : null;
    await _save();
    await NotificationService.schedule(date);
  }

  Future<ImportantDate> duplicate(ImportantDate date) async {
    final copy = date.copyAsNew(newId());
    _dates.add(copy);
    await _save();
    await NotificationService.schedule(copy);
    return copy;
  }

  // ---- Attachments ----

  File attachmentFile(String attachmentId) => File('${_attachmentsDir.path}/$attachmentId');

  Future<void> addAttachment(ImportantDate date, String fileName, Uint8List bytes) async {
    final lower = fileName.toLowerCase();
    final mime = lower.endsWith('.pdf') ? 'application/pdf' : 'image';
    final att = ItemAttachment(id: newId(), fileName: fileName, mimeType: mime, createdAt: DateTime.now());
    await attachmentFile(att.id).writeAsBytes(bytes, flush: true);
    date.attachments.add(att);
    await _save();
  }

  Future<void> removeAttachment(ImportantDate date, ItemAttachment att) async {
    await _deleteAttachmentFile(att.id);
    date.attachments.removeWhere((a) => a.id == att.id);
    await onAttachmentRemoved?.call(att);
    await _save();
  }

  Future<void> _deleteAttachmentFile(String id) async {
    final f = attachmentFile(id);
    if (await f.exists()) await f.delete();
  }

  // ---- Item types & names ----

  /// Returns false when the value already exists (case-insensitive).
  Future<bool> addItemType(String name) => _addTo(_items, name);
  Future<bool> addPerson(String name) => _addTo(_people, name);
  Future<void> removeItemType(String name) async {
    _items.remove(name);
    await _save();
  }

  Future<void> removePerson(String name) async {
    _people.remove(name);
    await _save();
  }

  Future<bool> _addTo(List<String> list, String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return false;
    if (list.any((n) => n.toLowerCase() == name.toLowerCase())) return false;
    list.add(name);
    _sortLists();
    await _save();
    return true;
  }

  // ---- Bulk operations ----

  Future<void> deleteAll() async {
    await NotificationService.cancelAll();
    final attachments = [for (final d in _dates) ...d.attachments];
    _dates.clear();
    _items.clear();
    _people.clear();
    if (await _attachmentsDir.exists()) {
      await _attachmentsDir.delete(recursive: true);
    }
    await _attachmentsDir.create(recursive: true);
    for (final a in attachments) {
      await onAttachmentRemoved?.call(a);
    }
    await _save();
  }

  /// Replaces every record with backup contents. Attachment bytes are written
  /// to disk before the records are saved.
  Future<void> replaceAll({
    required List<ImportantDate> dates,
    required List<String> items,
    required List<String> people,
    required Map<String, Uint8List> attachmentBytes,
  }) async {
    if (await _attachmentsDir.exists()) {
      await _attachmentsDir.delete(recursive: true);
    }
    await _attachmentsDir.create(recursive: true);
    for (final e in attachmentBytes.entries) {
      await attachmentFile(e.key).writeAsBytes(e.value, flush: true);
    }
    _dates
      ..clear()
      ..addAll(dates);
    _items
      ..clear()
      ..addAll(items.where((n) => n.trim().isNotEmpty).toSet());
    _people
      ..clear()
      ..addAll(people.where((n) => n.trim().isNotEmpty).toSet());
    _sortLists();
    await _save(triggerBackup: false);
    await NotificationService.rescheduleAll(_dates);
  }

  // ---- Home image ----

  Future<Uint8List?> readHomeImage() async {
    final f = homeImageFile;
    return await f.exists() ? f.readAsBytes() : null;
  }

  bool get hasCustomHomeImage => homeImageFile.existsSync();

  Future<void> saveHomeImage(Uint8List? bytes) async {
    final f = homeImageFile;
    if (bytes == null) {
      if (await f.exists()) await f.delete();
    } else {
      await f.writeAsBytes(bytes, flush: true);
    }
    AppSettings.instance.bumpHomeImageVersion();
    notifyListeners();
  }
}
