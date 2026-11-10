import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:document_store/document_store.dart';
import 'package:flutter/foundation.dart';

import '../data/app_store.dart';
import '../models/important_date.dart';
import 'app_log.dart';
import 'cloud_sync.dart';
import 'sync_backend.dart';

/// Keeps attachment files (PDFs, photos, scans) in the shared DocumentStore,
/// so the files themselves are on every device, not just the one that added
/// them. Same design as MyTravelApp-FL's TripDocumentSync.
///
/// * The master copy is in Firebase Storage under
///   `users/{uid}/important-dates/docs/{docId}/…` with a record in
///   `users/{uid}/documents/{docId}` (see DOCUMENT_STORE_SPEC.md in the
///   document-store folder). The record links to its Important Date with
///   `links: {dateId: …}`.
/// * The app's Attachments folder is this device's cache: a file is
///   downloaded the first time it is opened, and automatically for dates due
///   within 30 days.
/// * Attachments added here upload in the background, including ones that
///   were only on this device before Cloud Sync was turned on.
/// * Documents added elsewhere (e.g. uploaded with the document-store import
///   script) appear on their Important Date automatically.
///
/// Only active while Cloud Sync is set up, switched on and signed in.
/// Otherwise attachments work exactly as before, on this device only.
class AttachmentSync extends ChangeNotifier implements AttachmentCloud {
  AttachmentSync._();
  static final AttachmentSync instance = AttachmentSync._();

  static const appId = 'important-dates';

  AppStore get _store => AppStore.instance;
  CloudSync get _cloud => CloudSync.instance;

  DocumentStore? _docs;
  StreamSubscription<List<DocumentRecord>>? _sub;
  List<DocumentRecord> _records = [];
  String? _activeUid;
  Timer? _storeTimer;
  bool _uploading = false;
  bool _prefetching = false;

  /// Cloud ids being uploaded right now. The id is only written into the
  /// attachment once the upload has finished.
  final Set<String> _inFlight = {};

  /// Attachment ids that could not be uploaded this session (missing file,
  /// too large, error); not retried until the app restarts.
  final Set<String> _skipUpload = {};

  /// Attachment ids currently downloading (for progress indicators).
  @override
  final Set<String> downloading = {};

  String lastError = '';

  bool get active => _activeUid != null;

  /// The store whenever someone is signed in, even with sync paused, so that
  /// deletes and downloads still reach the cloud.
  DocumentStore? get _signedInDocs {
    if (!_cloud.configured || _cloud.user == null) return null;
    try {
      return _docs ??= DocumentStore(appId: appId);
    } catch (e) {
      AppLog.error('Could not open attachment cloud storage', e);
      return null;
    }
  }

  void init() {
    _store.onAttachmentRemoved = deleted;
    _cloud.addListener(_onCloudChanged);
    _store.addListener(_onStoreChanged);
    _onCloudChanged();
  }

  // ---------------------------------------------------------------- lifecycle

  void _onCloudChanged() {
    final uid = (_cloud.configured && _cloud.enabled) ? _cloud.user?.uid : null;
    if (uid == _activeUid) return;
    _sub?.cancel();
    _sub = null;
    _records = [];
    _activeUid = uid;
    if (uid != null) {
      try {
        _docs ??= DocumentStore(appId: appId);
        _sub = _docs!.watch().listen(
          (records) {
            _records = records;
            _adopt();
          },
          onError: (Object e) {
            lastError = '$e';
            notifyListeners();
          },
        );
        // Give Cloud Sync a moment to bring the records down first.
        Timer(const Duration(seconds: 5), () {
          if (_activeUid != uid) return;
          uploadPending();
          prefetchUpcoming();
        });
      } catch (e) {
        lastError = '$e';
        _activeUid = null;
      }
    }
    notifyListeners();
  }

  void _onStoreChanged() {
    if (!active) return;
    _storeTimer?.cancel();
    _storeTimer = Timer(const Duration(seconds: 2), () {
      _adopt();
      if (_hasPendingUploads) uploadPending();
    });
  }

  // ---------------------------------------------------------------- adopting

  /// Adds an attachment for every cloud record linked to an Important Date
  /// that does not have one yet.
  void _adopt() {
    var added = 0;
    for (final r in _records) {
      final dateId = r.links['dateId'];
      if (dateId == null || dateId.isEmpty) continue;
      final date = _store.byId(dateId.toUpperCase());
      if (date == null) continue;
      if (_inFlight.contains(r.id)) continue; // being uploaded from this device
      if (date.attachments.any((a) => a.cloudDocId == r.id)) continue;
      final localId = localIdForCloudDoc(r.id);
      final existing = date.attachments.where((a) => a.id == localId).firstOrNull;
      if (existing != null) {
        existing.cloudDocId ??= r.id;
        continue;
      }
      date.attachments.add(ItemAttachment(
        id: localId,
        fileName: r.filename,
        mimeType: r.mimeType.contains('pdf') ? 'application/pdf' : 'image',
        createdAt: r.createdAt ?? DateTime.now(),
        cloudDocId: r.id,
      ));
      added++;
    }
    if (added > 0) {
      _store.attachmentsChanged();
      notifyListeners();
    }
  }

  /// The same local id on every device for the same cloud document, so two
  /// devices adopting it at once do not create duplicates.
  static String localIdForCloudDoc(String cloudId) {
    final h = sha256Hex(utf8.encode('important-dates-attachment:$cloudId')).substring(0, 32).toUpperCase().split('');
    h[12] = '4';
    h[16] = '89AB'[int.parse(h[16], radix: 16) & 3];
    final s = h.join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  // ---------------------------------------------------------------- uploading

  bool get _hasPendingUploads => _store.dates
      .any((d) => d.attachments.any((a) => a.cloudDocId == null && !_skipUpload.contains(a.id)));

  /// Uploads every attachment that is only on this device.
  Future<void> uploadPending() async {
    final docs = _docs;
    if (!active || docs == null || _uploading) return;
    _uploading = true;
    notifyListeners();
    try {
      for (final date in [..._store.dates]) {
        for (final a in [...date.attachments]) {
          if (!active) return;
          if (a.cloudDocId != null || _skipUpload.contains(a.id)) continue;
          final file = _store.attachmentFile(a.id);
          if (!await file.exists()) {
            _skipUpload.add(a.id);
            continue;
          }
          final bytes = await file.readAsBytes();
          if (bytes.length > DocumentStore.maxFileBytes) {
            _skipUpload.add(a.id);
            continue;
          }
          String? newId;
          try {
            final same = await docs.findByHash(sha256Hex(bytes));
            if (same != null) {
              a.cloudDocId = same.id;
            } else {
              newId = docs.newId();
              _inFlight.add(newId);
              await docs.add(
                bytes,
                a.fileName,
                id: newId,
                mimeType: a.isPdf ? 'application/pdf' : mimeTypeForName(a.fileName),
                title: '${date.item} – ${date.name}',
                links: {'dateId': date.id},
              );
              a.cloudDocId = newId;
            }
            await _store.attachmentsChanged();
          } catch (e) {
            lastError = e is DocumentStoreException ? e.userMessage : '$e';
            if (e is DocumentStoreException &&
                (e.code == DocumentStoreError.notSignedIn || e.code == DocumentStoreError.network)) {
              return; // try again later
            }
            _skipUpload.add(a.id);
          } finally {
            if (newId != null) _inFlight.remove(newId);
          }
        }
      }
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- downloading

  /// The attachment's file on this device, downloading it from the cloud
  /// first if needed. Returns null when it is not on this device and has no
  /// cloud copy. Throws [DocumentStoreException] when the download fails.
  @override
  Future<File?> ensureLocal(ItemAttachment a) async {
    final local = _store.attachmentFile(a.id);
    if (await local.exists()) return local;
    final docs = _signedInDocs, id = a.cloudDocId;
    if (id == null) return null;
    if (docs == null) throw DocumentStoreException(DocumentStoreError.notSignedIn);
    downloading.add(a.id);
    notifyListeners();
    try {
      final record = await docs.get(id);
      if (record == null) throw DocumentStoreException(DocumentStoreError.notFound);
      final Uint8List bytes = await docs.download(record);
      await local.writeAsBytes(bytes, flush: true);
      return local;
    } finally {
      downloading.remove(a.id);
      notifyListeners();
    }
  }

  @override
  bool isInCloud(ItemAttachment a) => a.cloudDocId != null;

  @override
  bool isOnDevice(ItemAttachment a) => _store.attachmentFile(a.id).existsSync();

  /// Downloads every cloud attachment of [date] not on this device yet.
  /// Returns (downloaded, failed).
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
    if (!active || _prefetching) return;
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

  /// Downloads every cloud attachment (for a complete backup on this device).
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

  // ---------------------------------------------------------------- deleting

  /// [a] was removed on this device: delete the cloud copy too, unless
  /// another attachment still uses the same cloud file. Best effort.
  Future<void> deleted(ItemAttachment a) async {
    final docs = _signedInDocs, id = a.cloudDocId;
    if (docs == null || id == null) return;
    if (_store.dates.any((d) => d.attachments.any((o) => o.cloudDocId == id && o.id != a.id))) return;
    try {
      await docs.delete(id);
    } catch (e) {
      AppLog.error('Could not delete an attachment from the cloud', e);
    }
  }
}
