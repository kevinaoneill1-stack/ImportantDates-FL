import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/app_settings.dart';
import '../data/app_store.dart';
import '../models/important_date.dart';
import '../utils/date_utils.dart';
import 'cloud_sync.dart';

/// Complete JSON backups in the same format as the native iOS app
/// (`AppBackup`), so backups can be restored in either app.
class BackupService {
  static const maximumBackups = 10;

  static Future<Directory> automaticBackupDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/Automatic Backups');
    await dir.create(recursive: true);
    return dir;
  }

  static Future<Uint8List> buildBackupBytes() async {
    final store = AppStore.instance;
    final s = AppSettings.instance;
    final dates = <Map<String, dynamic>>[];
    for (final d in store.dates) {
      final atts = <Map<String, dynamic>>[];
      for (final a in d.attachments) {
        final f = store.attachmentFile(a.id);
        final onDevice = await f.exists();
        // A file that is only in the cloud (Cloud Sync, not downloaded to this
        // device) is listed with its cloud id and no bytes; restoring the
        // backup here links it to the cloud copy again.
        if (!onDevice && a.cloudDocId == null) continue;
        atts.add({
          'id': a.id,
          'fileName': a.fileName,
          'mimeType': a.mimeType,
          'data': onDevice ? base64Encode(await f.readAsBytes()) : '',
          'createdAt': DateFormatting.toIso(a.createdAt),
          if (a.cloudDocId != null) 'cloudDocId': a.cloudDocId,
        });
      }
      final j = d.toJson();
      j['attachments'] = atts;
      dates.add(j);
    }
    final homeImage = await store.readHomeImage();
    final backup = <String, dynamic>{
      'dates': dates,
      'items': store.items.map((n) => {'name': n}).toList(),
      'people': store.people.map((n) => {'name': n}).toList(),
      if (homeImage != null) 'homeImageData': base64Encode(homeImage),
      if (s.homeDisplayModeRaw != null) 'homeImageDisplayMode': s.homeDisplayModeRaw,
      if (s.hasHomeBrightness) 'homeImageBrightness': s.homeBrightness,
      if (s.hasHomeBlur) 'homeImageBlur': s.homeBlur,
      if (s.hasHomeTitle) 'homeTitle': s.homeTitle,
    };
    return Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(backup)));
  }

  /// Restores a backup created by this app or by the native iOS app.
  /// Throws a [FormatException] if the file is not an Important Dates backup;
  /// in that case current data is left untouched.
  static Future<void> restoreFromBytes(Uint8List bytes) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map || decoded['dates'] is! List) {
      throw const FormatException('This file is not an Important Dates backup.');
    }
    final json = Map<String, dynamic>.from(decoded);

    final dates = <ImportantDate>[];
    final attachmentBytes = <String, Uint8List>{};
    for (final raw in (json['dates'] as List).whereType<Map>()) {
      final m = Map<String, dynamic>.from(raw);
      final date = ImportantDate.fromJson(m);
      final rawAtts = ((m['attachments'] as List?) ?? []).whereType<Map>().toList();
      for (var i = 0; i < rawAtts.length && i < date.attachments.length; i++) {
        final data = rawAtts[i]['data'];
        if (data is String && data.isNotEmpty) attachmentBytes[date.attachments[i].id] = base64Decode(data);
      }
      // Keep attachments that have their bytes, or a cloud copy to download.
      date.attachments.removeWhere((a) => !attachmentBytes.containsKey(a.id) && a.cloudDocId == null);
      dates.add(date);
    }
    List<String> names(Object? v) =>
        ((v as List?) ?? []).map((e) => e is Map ? (e['name'] as String? ?? '') : e.toString()).toList();

    final store = AppStore.instance;
    // Restoring replaces everything on purpose, on every synced device too.
    CloudSync.instance.allowBulkDeleteOnce();
    await store.replaceAll(
      dates: dates,
      items: names(json['items']),
      people: names(json['people']),
      attachmentBytes: attachmentBytes,
    );

    final s = AppSettings.instance;
    final img = json['homeImageData'];
    await store.saveHomeImage(img is String ? base64Decode(img) : null);
    if (json['homeImageDisplayMode'] is String) s.homeDisplayModeRaw = json['homeImageDisplayMode'] as String;
    if (json['homeImageBrightness'] is num) s.homeBrightness = (json['homeImageBrightness'] as num).toDouble();
    if (json['homeImageBlur'] is num) s.homeBlur = (json['homeImageBlur'] as num).toDouble();
    if (json['homeTitle'] is String) s.homeTitle = json['homeTitle'] as String;
  }

  // ---- Automatic backups ----

  static Future<List<File>> automaticBackups() async {
    final dir = await automaticBackupDirectory();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  static Future<File?> latestAutomaticBackup() async {
    final all = await automaticBackups();
    return all.isEmpty ? null : all.first;
  }

  /// Creates an automatic backup and updates today's daily copy.
  ///
  /// Safety (from MyTravelApp 4.6.143FL): when there is no data at all but the
  /// latest backup has some, nothing is written, so an emptied or unreadable
  /// data set never replaces a good backup. Returns null in that case.
  static Future<File?> createAutomaticBackup() async {
    final dir = await automaticBackupDirectory();
    final store = AppStore.instance;
    final empty = store.dates.isEmpty && store.items.isEmpty && store.people.isEmpty;
    if (empty) {
      final latest = await latestAutomaticBackup();
      if (latest != null && await _hasData(latest)) {
        debugPrint('Automatic backup skipped: no data, and the latest backup has data.');
        return null;
      }
    }
    final n = DateTime.now();
    final stamp = '${_day(n)}_${_two(n.hour)}-${_two(n.minute)}-${_two(n.second)}';
    final file = File('${dir.path}/ImportantDates_AutoBackup_$stamp.json');
    final bytes = await buildBackupBytes();
    await file.writeAsBytes(bytes, flush: true);
    AppSettings.instance.lastBackupDate = DateTime.now();
    final all = await automaticBackups();
    for (final old in all.skip(maximumBackups)) {
      await old.delete();
    }
    await _writeDaily(bytes, n);
    return file;
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
  static String _day(DateTime n) => '${n.year}-${_two(n.month)}-${_two(n.day)}';

  static Future<bool> _hasData(File f) async {
    try {
      final j = jsonDecode(await f.readAsString());
      return j is Map && [j['dates'], j['items'], j['people']].any((v) => v is List && v.isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  // ---- Daily backups ----

  static const dailyBackupsKept = 7;

  static Future<Directory> dailyBackupDirectory() async {
    final dir = Directory('${(await automaticBackupDirectory()).path}/Daily');
    await dir.create(recursive: true);
    return dir;
  }

  /// One backup per day for the last [dailyBackupsKept] days (today's copy is
  /// updated with every automatic backup), newest first.
  static Future<List<File>> dailyBackups() async {
    final dir = await dailyBackupDirectory();
    final files = dir.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.json')).toList();
    files.sort((a, b) => b.path.compareTo(a.path)); // names sort by date
    return files;
  }

  /// The day a daily backup is for, from its file name.
  static DateTime? dailyBackupDate(File f) {
    final m = RegExp(r'(\d{4})-(\d{2})-(\d{2})\.json$').firstMatch(f.path);
    return m == null ? null : DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  static Future<void> _writeDaily(Uint8List bytes, DateTime n) async {
    final dir = await dailyBackupDirectory();
    final file = File('${dir.path}/ImportantDates_Daily_${_day(n)}.json');
    await file.writeAsBytes(bytes, flush: true);
    final all = await dailyBackups();
    for (final old in all.skip(dailyBackupsKept)) {
      await old.delete();
    }
  }

  /// Creates an automatic backup if enabled and the chosen interval has passed.
  static Future<bool> performIfNeeded() async {
    final s = AppSettings.instance;
    if (!s.autoBackupEnabled) return false;
    final last = s.lastBackupDate;
    final freq = s.autoBackupFrequencyDays < 1 ? 1 : s.autoBackupFrequencyDays;
    if (last != null && last.add(Duration(days: freq)).isAfter(DateTime.now())) return false;
    await createAutomaticBackup();
    return true;
  }

  static Future<void> restoreLatestAutomatic() async {
    final f = await latestAutomaticBackup();
    if (f == null) throw const FileSystemException('No automatic backup is available yet.');
    await restoreFromBytes(await f.readAsBytes());
  }
}
