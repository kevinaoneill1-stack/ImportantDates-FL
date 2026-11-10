import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:google_sign_in/google_sign_in.dart' show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';

import '../config/google_drive_config.dart';
import '../data/app_settings.dart';
import '../data/app_store.dart';
import '../models/important_date.dart';
import 'google_drive_auth.dart';
import 'notification_service.dart';
import 'app_log.dart';
import 'sync_backend.dart';
import 'sync_rules.dart';

class DriveSyncException implements Exception {
  DriveSyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sync for the public edition, through the user's own Google Drive.
///
/// Everything lives in the hidden **app data folder** of the user's Drive
/// (scope `drive.appdata`): only this app can see it, it does not show in
/// their Drive, and it counts against their own storage. The developer has no
/// server and never sees the data.
///
/// * `important_dates_sync.json` – every record as JSON text with the time it
///   was last changed, plus "tombstones" for deleted records:
///   `{schema, records: {key: {json, modified}}, deleted: {key: time}}`.
///   Keys: `dates/{id}`, `itemTypes/{name}`, `people/{name}`, `meta/settings`.
/// * `attachment-{attachmentId}` – one Drive file per attachment. Its Drive
///   file id is stored in the attachment's `cloudDocId`, so other devices know
///   which file to download.
///
/// A sync downloads the file, merges it with this device record by record
/// (a record changed on one side only takes that side; changed on both, the
/// newer edit wins) and uploads the result if anything changed. It runs at
/// start-up, when the app comes back to the foreground, a few seconds after
/// each change, and every few minutes while the app is open.
///
/// The same safety rules as the Firebase Cloud Sync:
/// * a record is only deleted in the cloud when it was on this device and was
///   deleted here, never just because it is missing;
/// * a device whose data is now empty downloads everything again;
/// * deleting more than 10 records and more than half of everything at once
///   is blocked, unless the user did it on purpose (Delete All Data, Restore);
/// * a sync file that cannot be read is never overwritten.
class DriveSync extends ChangeNotifier implements SyncState, AttachmentCloud {
  DriveSync._();
  static final DriveSync instance = DriveSync._();

  static const dataFileName = 'important_dates_sync.json';
  static const _attachmentPrefix = 'attachment-';
  static const _maxAttachmentBytes = 50 * 1024 * 1024;
  static const _keepTombstones = Duration(days: 180);
  static const _orphanAge = Duration(days: 1);

  AppStore get _store => AppStore.instance;
  AppSettings get _settings => AppSettings.instance;
  final GoogleDriveAuth _auth = GoogleDriveAuth();

  bool configured = false;
  String setupError = '';
  bool busy = false;
  @override
  bool running = false;
  String status = '';
  String error = '';
  String attachmentError = '';
  DateTime? lastSync;

  /// This Google account already has data in Drive and this device has its
  /// own data too: the user chooses how to combine them.
  bool needsFirstSyncChoice = false;

  bool get signedIn => _auth.signedIn;
  String? get email => _auth.email;
  bool get enabled => _settings.cloudSyncEnabled;

  /// key -> JSON last agreed between this device and Drive.
  Map<String, String> _known = {};

  /// Google account the [_known] map belongs to ('' = never synced here).
  String _knownAccount = '';

  /// Records this device has had locally since sync started. Only these can
  /// be deleted from Drive.
  Set<String> _seenLocal = {};

  DateTime _lastLocalChange = DateTime.now().toUtc();
  bool _allowBulkDelete = false;
  bool _applyingRemote = false;
  bool _syncing = false;
  bool _again = false;
  Timer? _debounce;
  Timer? _periodic;
  Timer? _persistTimer;
  AppLifecycleListener? _lifecycle;

  /// Attachment files in Drive by Drive file id (from the last listing).
  Map<String, _DriveFile> _driveAttachments = {};
  bool _attachmentsBusy = false;
  bool _prefetching = false;
  final Set<String> _skipUpload = {};

  @override
  final Set<String> downloading = {};

  // ---------------------------------------------------------------- SyncState

  @override
  bool get isSyncOn => configured && signedIn && enabled;

  @override
  String get statusSummary => !configured
      ? 'Google Drive Sync is not set up in this build'
      : !signedIn
          ? 'Not signed in – local device storage'
          : enabled
              ? (status.isEmpty ? 'Starting…' : status)
              : 'Sync is off – local device storage';

  @override
  String? get accountLabel => email;

  @override
  void allowBulkDeleteOnce() => _allowBulkDelete = true;

  // ---------------------------------------------------------------- start-up

  Future<void> init() async {
    await _loadState();
    _store.onLocalChange = _onLocalChange;
    _store.onAttachmentRemoved = _attachmentRemoved;
    _settings.addListener(_onLocalChange);
    _lifecycle = AppLifecycleListener(onResume: () => syncSoon(delay: Duration.zero));
    configured = GoogleDriveConfig.isConfigured;
    if (!configured) {
      setupError = 'The Google sign-in client ids are not filled in yet (lib/config/google_drive_config.dart, '
          'see FLAVORS_SETUP.md).';
      notifyListeners();
      return;
    }
    try {
      await _auth.init(onChanged: () => unawaited(_restart()), trySilentSignIn: _knownAccount.isNotEmpty);
    } catch (e) {
      configured = false;
      setupError = 'Google sign-in could not start: $e';
      notifyListeners();
      return;
    }
    await _restart();
  }

  Future<void> setEnabled(bool on) async {
    _settings.cloudSyncEnabled = on;
    await _restart();
  }

  Future<void> _restart() async {
    _periodic?.cancel();
    _debounce?.cancel();
    running = false;
    if (isSyncOn) {
      running = true;
      _seenLocal = _localRecords().keys.where((k) => !k.startsWith('meta/')).toSet();
      _periodic = Timer.periodic(const Duration(minutes: 3), (_) => syncSoon(delay: Duration.zero));
      notifyListeners();
      await syncNow();
    } else {
      status = !enabled ? 'Sync is off' : (!signedIn ? 'Signed out' : '');
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- account

  /// Shows Google sign-in. Returns an error message, or null when signed in
  /// (or the user cancelled).
  Future<String?> signIn() async {
    try {
      if (!enabled) _settings.cloudSyncEnabled = true;
      await _auth.signIn();
      await _restart();
      return null;
    } catch (e) {
      if (e is GoogleSignInException && e.code == GoogleSignInExceptionCode.canceled) return null;
      return _describe(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      AppLog.error('Google sign-out failed', e);
    }
    await _restart();
  }

  /// Deletes everything this app keeps in the user's Google Drive (records and
  /// attachment files) and removes its access to the Google account. The data
  /// on this device is kept and sync is switched off.
  Future<String?> deleteDriveData() async {
    busy = true;
    status = 'Deleting your data from Google Drive…';
    notifyListeners();
    try {
      final api = await _api();
      _settings.cloudSyncEnabled = false;
      running = false;
      _periodic?.cancel();
      _debounce?.cancel();
      for (final f in await _listAll(api)) {
        try {
          await api.files.delete(f.id);
        } on drive.DetailedApiRequestError catch (e) {
          if (e.status != 404) rethrow;
        }
      }
      _known = {};
      _knownAccount = '';
      _seenLocal = {};
      _driveAttachments = {};
      lastSync = null;
      _persistState();
      for (final d in _store.syncDates) {
        for (final a in d.attachments) {
          a.cloudDocId = null; // the Drive copies are gone
        }
      }
      await _store.attachmentsChanged();
      await _auth.disconnect();
      status = 'Your Google Drive data has been deleted';
      error = '';
      return null;
    } catch (e) {
      error = 'Could not delete everything: ${_describe(e)}';
      return error;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// [useCloud]: replace this device's data with the Drive data. Otherwise
  /// merge: records from both are kept; where the same record is in both, the
  /// Drive version is used.
  Future<void> resolveFirstSync({required bool useCloud}) async {
    final account = _auth.accountId;
    if (account == null) return;
    needsFirstSyncChoice = false;
    if (useCloud) {
      _applyingRemote = true;
      try {
        await _store.deleteLocalAttachmentFiles([for (final d in _store.dates) ...d.attachments]);
        _store.syncDates.clear();
        _store.syncItems.clear();
        _store.syncPeople.clear();
        await NotificationService.cancelAll();
        await _store.remoteChanged();
      } finally {
        _applyingRemote = false;
      }
      _seenLocal.clear();
    }
    _known = {};
    _knownAccount = account;
    _persistState();
    await syncNow();
  }

  // ---------------------------------------------------------------- syncing

  void _onLocalChange() {
    if (_applyingRemote) return;
    _lastLocalChange = DateTime.now().toUtc();
    syncSoon();
  }

  /// Syncs after [delay]; repeated calls within the delay share one sync.
  void syncSoon({Duration delay = const Duration(seconds: 3)}) {
    if (!running || _applyingRemote) return;
    _debounce?.cancel();
    _debounce = Timer(delay, () => unawaited(syncNow()));
  }

  /// Syncs records, then attachment files.
  Future<void> syncNow() async {
    if (!isSyncOn) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    busy = true;
    error = '';
    notifyListeners();
    try {
      var rounds = 0;
      do {
        _again = false;
        await _syncRecords();
      } while (_again && ++rounds < 4);
      if (!needsFirstSyncChoice) {
        await _syncAttachments();
        lastSync = DateTime.now();
        status = 'Up to date';
      }
    } catch (e) {
      error = _describe(e);
      AppLog.error('Google Drive Sync error', e);
      status = 'Could not sync';
    } finally {
      _syncing = false;
      busy = false;
      notifyListeners();
      _persistState();
    }
    // A change arrived while this sync was finishing: sync again for it.
    if (_again) {
      _again = false;
      syncSoon();
    }
  }

  bool get _localLooksEmpty => _store.dates.isEmpty && _store.items.isEmpty && _store.people.isEmpty;

  Future<void> _syncRecords() async {
    final account = _auth.accountId;
    if (account == null) return;
    final api = await _api();
    status = 'Checking Google Drive…';
    notifyListeners();
    final remote = await _downloadData(api);

    var preferRemote = false;
    if (_knownAccount != account) {
      // First sync of this Google account on this device.
      if (remote.records.keys.any((k) => !k.startsWith('meta/')) && !_localLooksEmpty) {
        needsFirstSyncChoice = true;
        status = 'Choose how to combine this device with Google Drive';
        return;
      }
      _known = {};
      _knownAccount = account;
      preferRemote = true;
    } else if (_known.isEmpty) {
      preferRemote = true; // first sync after "merge" / "use cloud"
    }
    needsFirstSyncChoice = false;

    final local = _localRecords();
    final now = DateTime.now().toUtc();

    final allowBulk = _allowBulkDelete;
    _allowBulkDelete = false;

    final records = Map<String, _Record>.of(remote.records);
    final deleted = Map<String, DateTime>.of(remote.deleted)..removeWhere((_, t) => now.difference(t) > _keepTombstones);
    var upload = remote.fileId == null || remote.extraFileIds.isNotEmpty || deleted.length != remote.deleted.length;

    final merge = SyncRules.mergeDrive(
      local: local,
      known: _known,
      remote: records.map((k, r) => MapEntry(k, RemoteRecord(r.json, r.modified))),
      deleted: deleted,
      seenLocal: _seenLocal,
      allowBulk: allowBulk,
      preferRemote: preferRemote,
      lastLocalChange: _lastLocalChange,
    );
    final apply = merge.apply;
    final remove = merge.remove;
    final written = Map<String, String>.of(merge.written); // grows below
    final tombstoned = merge.tombstoned;
    final blocked = merge.blocked;

    // Put the Drive side's changes on this device.
    if (apply.isNotEmpty || remove.isNotEmpty) {
      _applyingRemote = true;
      try {
        final applied = <String>[];
        for (final e in apply.entries) {
          if (await _applyRecord(e.key, e.value)) applied.add(e.key);
        }
        for (final key in remove) {
          await _removeLocal(key);
          _known.remove(key);
        }
        await _store.remoteChanged();
        // Remember each record the way this device writes it. If that differs
        // from the Drive text (another app version, number formats), send this
        // device's form back once so both sides agree and it is not applied
        // again on every sync.
        final after = _localRecords();
        for (final key in applied) {
          final mine = after[key];
          if (mine == null) continue;
          if (mine == apply[key]) {
            _known[key] = mine;
          } else {
            written[key] = mine;
          }
        }
      } finally {
        _applyingRemote = false;
      }
    }

    if (blocked.isNotEmpty) {
      error = 'Google Drive Sync stopped ${blocked.length} records from being deleted in Drive at once. '
          'If you really meant to delete them, delete them in smaller groups.';
      AppLog.error(error);
    }

    if (written.isEmpty && tombstoned.isEmpty && !upload) return;
    for (final e in written.entries) {
      records[e.key] = _Record(e.value, now);
      deleted.remove(e.key);
    }
    for (final key in tombstoned) {
      records.remove(key);
      deleted[key] = now;
    }

    status = 'Saving to Google Drive…';
    notifyListeners();
    if (remote.fileId != null && await _remoteVersion(api, remote.fileId!) != remote.version) {
      // Another device saved in the meantime: merge again with its version.
      _again = true;
      return;
    }
    await _uploadData(api, remote.fileId, records, deleted);
    for (final id in remote.extraFileIds) {
      try {
        await api.files.delete(id);
      } catch (e) {
        AppLog.error('Could not remove a duplicate sync file from Google Drive', e);
      }
    }
    for (final e in written.entries) {
      _known[e.key] = e.value;
    }
    for (final key in tombstoned) {
      _known.remove(key);
    }
    _seenLocal.addAll(local.keys.where((k) => !k.startsWith('meta/')));
  }

  // ---------------------------------------------------------------- records

  static String _nameKey(String collection, String name) => '$collection/${name.trim().toLowerCase()}';

  Map<String, String> _localRecords() {
    final out = <String, String>{};
    for (final d in _store.dates) {
      out['dates/${d.id}'] = jsonEncode(d.toJson());
    }
    for (final n in _store.items) {
      out[_nameKey('itemTypes', n)] = jsonEncode({'name': n});
    }
    for (final n in _store.people) {
      out[_nameKey('people', n)] = jsonEncode({'name': n});
    }
    out['meta/settings'] = jsonEncode(_settings.toSyncValues());
    return out;
  }

  /// Puts one record from Drive on this device. Returns true if it was used.
  Future<bool> _applyRecord(String key, String json) async {
    final slash = key.indexOf('/');
    if (slash < 0) return false;
    final collection = key.substring(0, slash);
    final Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(jsonDecode(json) as Map);
    } catch (e) {
      AppLog.error('A record from Google Drive could not be read and was skipped', e);
      return false;
    }
    switch (collection) {
      case 'dates':
        final date = ImportantDate.fromJson(m);
        final list = _store.syncDates;
        final index = list.indexWhere((d) => d.id == date.id);
        if (index >= 0) {
          // Attachments removed on another device: drop their local files.
          final kept = date.attachments.map((a) => a.id).toSet();
          await _store.deleteLocalAttachmentFiles(list[index].attachments.where((a) => !kept.contains(a.id)));
          list[index] = date;
        } else {
          list.add(date);
        }
        await NotificationService.schedule(date);
      case 'itemTypes' || 'people':
        final name = (m['name'] as String? ?? '').trim();
        if (name.isEmpty) return false;
        final list = collection == 'itemTypes' ? _store.syncItems : _store.syncPeople;
        list.removeWhere((n) => n.toLowerCase() == name.toLowerCase());
        list.add(name);
      case 'meta':
        await _settings.applySyncValues(m);
      default:
        return false;
    }
    if (collection != 'meta') _seenLocal.add(key);
    return true;
  }

  Future<void> _removeLocal(String key) async {
    final slash = key.indexOf('/');
    final collection = key.substring(0, slash), id = key.substring(slash + 1);
    switch (collection) {
      case 'dates':
        final list = _store.syncDates;
        final index = list.indexWhere((d) => d.id == id);
        if (index >= 0) {
          final date = list.removeAt(index);
          await NotificationService.cancel(date);
          await _store.deleteLocalAttachmentFiles(date.attachments);
        }
      case 'itemTypes':
        _store.syncItems.removeWhere((n) => n.trim().toLowerCase() == id);
      case 'people':
        _store.syncPeople.removeWhere((n) => n.trim().toLowerCase() == id);
    }
    _seenLocal.remove(key);
  }

  // ---------------------------------------------------------------- Drive files

  Future<drive.DriveApi> _api({bool interactive = false}) async =>
      drive.DriveApi(await _auth.client(interactive: interactive));

  /// Every file in the app data folder.
  Future<List<_DriveFile>> _listAll(drive.DriveApi api, {String? query}) async {
    final out = <_DriveFile>[];
    String? page;
    do {
      final list = await api.files.list(
        spaces: 'appDataFolder',
        q: query,
        pageSize: 1000,
        pageToken: page,
        orderBy: 'createdTime',
        $fields: 'nextPageToken, files(id, name, version, createdTime, appProperties)',
      );
      for (final f in list.files ?? const <drive.File>[]) {
        if (f.id != null) out.add(_DriveFile.from(f));
      }
      page = list.nextPageToken;
    } while (page != null);
    return out;
  }

  Future<Uint8List> _download(drive.DriveApi api, String fileId) async {
    final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return Uint8List.fromList(bytes);
  }

  Future<String?> _remoteVersion(drive.DriveApi api, String fileId) async {
    final f = await api.files.get(fileId, $fields: 'version') as drive.File;
    return f.version;
  }

  Future<_RemoteData> _downloadData(drive.DriveApi api) async {
    final files = await _listAll(api, query: "name = '$dataFileName'");
    if (files.isEmpty) return _RemoteData.empty();
    final main = files.first; // the oldest, if two devices created one at once
    final data = _parse(await _download(api, main.id));
    final extras = <String>[];
    for (final extra in files.skip(1)) {
      try {
        final other = _parse(await _download(api, extra.id));
        other.records.forEach((k, r) {
          final mine = data.records[k];
          if (mine == null || r.modified.isAfter(mine.modified)) data.records[k] = r;
        });
        other.deleted.forEach((k, t) => data.deleted[k] ??= t);
        extras.add(extra.id);
      } catch (e) { // unreadable duplicate: leave it alone
        AppLog.error('A duplicate sync file in Google Drive could not be read', e);
      }
    }
    return _RemoteData(data.records, data.deleted, fileId: main.id, version: main.version, extraFileIds: extras);
  }

  _RemoteData _parse(Uint8List bytes) {
    try {
      final m = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final records = <String, _Record>{};
      (m['records'] as Map? ?? {}).forEach((k, v) {
        if (v is Map && v['json'] is String) {
          records['$k'] = _Record(v['json'] as String, DateTime.tryParse('${v['modified']}')?.toUtc() ?? DateTime.utc(2000));
        }
      });
      final deleted = <String, DateTime>{};
      (m['deleted'] as Map? ?? {}).forEach((k, v) {
        final t = DateTime.tryParse('$v');
        if (t != null) deleted['$k'] = t.toUtc();
      });
      return _RemoteData(records, deleted);
    } catch (_) {
      // Never overwrite a file we cannot read.
      throw DriveSyncException('The Important Dates sync file in Google Drive could not be read, so nothing was '
          'changed. Make a backup on this device (Manage › Backup & Restore) and contact support.');
    }
  }

  Future<void> _uploadData(
    drive.DriveApi api,
    String? fileId,
    Map<String, _Record> records,
    Map<String, DateTime> deleted,
  ) async {
    final bytes = utf8.encode(jsonEncode({
      'schema': 1,
      'app': 'important-dates',
      'updated': DateTime.now().toUtc().toIso8601String(),
      'records': {
        for (final e in records.entries) e.key: {'json': e.value.json, 'modified': e.value.modified.toIso8601String()},
      },
      'deleted': {for (final e in deleted.entries) e.key: e.value.toIso8601String()},
    }));
    final media = drive.Media(Stream<List<int>>.value(bytes), bytes.length, contentType: 'application/json');
    if (fileId == null) {
      await api.files.create(
        drive.File()
          ..name = dataFileName
          ..parents = ['appDataFolder']
          ..mimeType = 'application/json'
          ..appProperties = {'kind': 'data'},
        uploadMedia: media,
        $fields: 'id',
      );
    } else {
      await api.files.update(drive.File(), fileId, uploadMedia: media, $fields: 'id');
    }
  }

  // ---------------------------------------------------------------- attachments

  Future<void> _syncAttachments() async {
    if (_attachmentsBusy || !isSyncOn) return;
    _attachmentsBusy = true;
    attachmentError = '';
    try {
      final api = await _api();
      final files = {
        for (final f in await _listAll(api, query: "name contains '$_attachmentPrefix'"))
          if (f.attachmentId != null) f.id: f,
      };
      _driveAttachments = files;
      final byAttachment = {for (final f in files.values) f.attachmentId!: f.id};

      var changed = false;
      for (final date in [..._store.dates]) {
        for (final a in [...date.attachments]) {
          if (!isSyncOn) return;
          if (a.cloudDocId != null && files.containsKey(a.cloudDocId)) continue; // already in Drive
          final existing = byAttachment[a.id];
          if (existing != null) {
            a.cloudDocId = existing;
            changed = true;
            continue;
          }
          if (_skipUpload.contains(a.id)) continue;
          final file = _store.attachmentFile(a.id);
          if (!await file.exists()) continue; // in Drive from another device, or lost
          final bytes = await file.readAsBytes();
          if (bytes.length > _maxAttachmentBytes) {
            _skipUpload.add(a.id);
            attachmentError = '${a.fileName} is larger than 50 MB, so it stays on this device only.';
            continue;
          }
          status = 'Uploading ${a.fileName}…';
          notifyListeners();
          final mime = _mimeType(a);
          final created = await api.files.create(
            drive.File()
              ..name = '$_attachmentPrefix${a.id}'
              ..parents = ['appDataFolder']
              ..mimeType = mime
              ..appProperties = {'kind': 'attachment', 'attachmentId': a.id, 'dateId': date.id},
            uploadMedia: drive.Media(Stream<List<int>>.value(bytes), bytes.length, contentType: mime),
            $fields: 'id, name, createdTime, appProperties',
          );
          if (created.id == null) continue;
          files[created.id!] = _DriveFile.from(created);
          a.cloudDocId = created.id;
          changed = true;
        }
      }
      // Saving sends the new Drive file ids to the other devices (next sync).
      if (changed) await _store.attachmentsChanged();
      await _deleteOrphans(api, files);
      unawaited(prefetchUpcoming());
    } catch (e) {
      attachmentError = _describe(e);
    } finally {
      _attachmentsBusy = false;
      notifyListeners();
    }
  }

  /// Deletes attachment files no Important Date refers to any more (removed
  /// while this device was offline, for example). Only files older than a day,
  /// so a file another device has just uploaded is never touched.
  Future<void> _deleteOrphans(drive.DriveApi api, Map<String, _DriveFile> files) async {
    if (_localLooksEmpty || needsFirstSyncChoice) return;
    final used = <String>{};
    for (final d in _store.dates) {
      for (final a in d.attachments) {
        used.add(a.id);
        if (a.cloudDocId != null) used.add(a.cloudDocId!);
      }
    }
    final now = DateTime.now().toUtc();
    for (final f in [...files.values]) {
      if (used.contains(f.id) || used.contains(f.attachmentId)) continue;
      if (f.createdTime == null || now.difference(f.createdTime!) < _orphanAge) continue;
      try {
        await api.files.delete(f.id);
        files.remove(f.id);
      } catch (e) {
        AppLog.error('Could not remove an unused attachment from Google Drive', e);
      }
    }
  }

  /// [a] was removed on this device: delete its Drive copy too, unless another
  /// attachment still uses it. Best effort.
  Future<void> _attachmentRemoved(ItemAttachment a) async {
    final id = a.cloudDocId;
    if (!signedIn || id == null) return;
    if (_store.dates.any((d) => d.attachments.any((o) => o.cloudDocId == id && o.id != a.id))) return;
    try {
      final api = await _api();
      await api.files.delete(id);
      _driveAttachments.remove(id);
    } catch (e) {
      AppLog.error('Could not delete an attachment from Google Drive', e);
    }
  }

  @override
  bool isOnDevice(ItemAttachment a) => _store.attachmentFile(a.id).existsSync();

  @override
  bool isInCloud(ItemAttachment a) => a.cloudDocId != null;

  @override
  Future<File?> ensureLocal(ItemAttachment a) async {
    final local = _store.attachmentFile(a.id);
    if (await local.exists()) return local;
    final id = a.cloudDocId ??
        _driveAttachments.values.where((f) => f.attachmentId == a.id).map((f) => f.id).firstOrNull;
    if (id == null) return null;
    if (!signedIn) {
      throw DriveSyncException('Sign in with Google (Manage › Cloud Sync) to download this file.');
    }
    downloading.add(a.id);
    notifyListeners();
    try {
      final api = await _api();
      final Uint8List bytes;
      try {
        bytes = await _download(api, id);
      } on drive.DetailedApiRequestError catch (e) {
        if (e.status == 404) throw DriveSyncException('This file is no longer in Google Drive.');
        rethrow;
      }
      await local.writeAsBytes(bytes, flush: true);
      return local;
    } catch (e) {
      if (e is DriveSyncException) rethrow;
      throw DriveSyncException(_describe(e));
    } finally {
      downloading.remove(a.id);
      notifyListeners();
    }
  }

  /// Downloads every Drive attachment of [date] not on this device yet.
  Future<(int, int)> prefetch(ImportantDate date) async {
    var ok = 0, failed = 0;
    for (final a in [...date.attachments]) {
      if (a.cloudDocId == null || isOnDevice(a)) continue;
      try {
        if (await ensureLocal(a) != null) ok++;
      } catch (_) {
        failed++;
      }
    }
    return (ok, failed);
  }

  /// Keeps attachments of active dates due within 30 days (or overdue)
  /// available offline.
  Future<void> prefetchUpcoming() async {
    if (!isSyncOn || _prefetching) return;
    _prefetching = true;
    try {
      for (final d in [..._store.dates]) {
        if (d.isAccomplished || d.daysRemaining > 30) continue;
        await prefetch(d);
      }
    } finally {
      _prefetching = false;
    }
  }

  @override
  Future<(int, int)> downloadAll() async {
    var ok = 0, failed = 0;
    for (final d in [..._store.dates]) {
      final (o, f) = await prefetch(d);
      ok += o;
      failed += f;
    }
    return (ok, failed);
  }

  @override
  int get cloudOnlyCount =>
      _store.dates.fold(0, (n, d) => n + d.attachments.where((a) => a.cloudDocId != null && !isOnDevice(a)).length);

  static String _mimeType(ItemAttachment a) {
    final n = a.fileName.toLowerCase();
    if (a.isPdf) return 'application/pdf';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.heic')) return 'image/heic';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  // ---------------------------------------------------------------- messages

  String _describe(Object e) {
    if (e is DriveSyncException) return e.message;
    if (e is DriveAuthorizationNeeded) return e.toString();
    if (e is GoogleSignInException) {
      return switch (e.code) {
        GoogleSignInExceptionCode.canceled => 'Sign-in was cancelled.',
        _ => 'Google sign-in failed: ${e.description ?? e.code.name}',
      };
    }
    if (e is drive.DetailedApiRequestError) {
      return switch (e.status) {
        401 || 403 => 'Google Drive refused access. Sign out and sign in with Google again.',
        404 => 'A file was not found in Google Drive.',
        429 || 500 || 502 || 503 => 'Google Drive is busy. It will try again shortly.',
        _ => 'Google Drive error ${e.status}: ${e.message ?? ''}',
      };
    }
    if (e is SocketException || e is TimeoutException) return 'No internet connection.';
    return '$e';
  }

  // ---------------------------------------------------------------- state file

  Future<File> _stateFile() async => File('${(await getApplicationSupportDirectory()).path}/drive_sync_state.json');

  Future<void> _loadState() async {
    try {
      final f = await _stateFile();
      if (!await f.exists()) return;
      final m = jsonDecode(await f.readAsString()) as Map;
      _knownAccount = (m['account'] ?? '') as String;
      _known = Map<String, String>.from(m['known'] as Map);
      final last = m['lastSync'];
      if (last is String) lastSync = DateTime.tryParse(last);
    } catch (e) {
      AppLog.error('Could not read the saved Google Drive sync state', e);
    }
  }

  void _persistState() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(seconds: 1), () async {
      try {
        final f = await _stateFile();
        await f.writeAsString(
            jsonEncode({'account': _knownAccount, 'known': _known, 'lastSync': lastSync?.toIso8601String()}));
      } catch (e) {
        AppLog.error('Could not save the Google Drive sync state', e);
      }
    });
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _periodic?.cancel();
    _auth.dispose();
    super.dispose();
  }
}

class _Record {
  _Record(this.json, this.modified);
  final String json;
  final DateTime modified;
}

class _RemoteData {
  _RemoteData(this.records, this.deleted, {this.fileId, this.version, this.extraFileIds = const []});
  _RemoteData.empty() : this({}, {});
  final Map<String, _Record> records;
  final Map<String, DateTime> deleted;
  final String? fileId;
  final String? version;
  final List<String> extraFileIds;
}

class _DriveFile {
  _DriveFile(this.id, this.name, this.version, this.createdTime, this.attachmentId);
  factory _DriveFile.from(drive.File f) =>
      _DriveFile(f.id!, f.name ?? '', f.version, f.createdTime?.toUtc(), f.appProperties?['attachmentId']);
  final String id;
  final String name;
  final String? version;
  final DateTime? createdTime;
  final String? attachmentId;
}
