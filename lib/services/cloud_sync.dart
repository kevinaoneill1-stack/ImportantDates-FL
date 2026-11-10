import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:document_store/document_store.dart' show sha256Hex;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/app_settings.dart';
import '../data/app_store.dart';
import '../firebase_options.dart';
import '../models/important_date.dart';
import 'notification_service.dart';
import 'app_log.dart';
import 'sync_backend.dart';
import 'sync_rules.dart';

/// Two-way sync of all Important Dates data through Firebase (Cloud
/// Firestore), so the app on iPhone, iPad, Mac and Android shares one set of
/// records. Same design as MyTravelApp-FL's CloudSync.
///
/// Layout in Firestore (all under the signed-in user):
/// * `users/{uid}/dates/{dateId}`: one document per Important Date, with its
///   attachment list (file names and cloud ids, not the file bytes).
/// * `users/{uid}/itemTypes/{key}` and `users/{uid}/people/{key}`: the Manage
///   Items and Manage Names lists; key = hash of the lower-case name.
/// * `users/{uid}/meta/settings`: Home title and appearance, Tools shortcuts.
///
/// Each document stores the record as `json` text in the app's own JSON
/// format. Changes are compared record by record; the most recent edit of a
/// record wins. Firestore keeps an offline copy, so edits made without signal
/// are sent when the device is back online.
///
/// Attachment files are synced separately by AttachmentSync through the
/// shared DocumentStore (Firebase Storage).
///
/// Safety rules (from MyTravelApp 4.6.142FL):
/// * a record is only deleted in the cloud when it was on this device and was
///   deleted here, never just because it is missing;
/// * a device that synced before but whose data is now empty downloads
///   everything again;
/// * deleting more than 10 records and more than half of everything at once
///   is blocked, unless the user did it on purpose (Delete All Data, Restore).
class CloudSync extends ChangeNotifier implements SyncState {
  CloudSync._();
  static final CloudSync instance = CloudSync._();

  AppStore get _store => AppStore.instance;
  AppSettings get _settings => AppSettings.instance;

  bool configured = false;
  String setupError = '';
  User? user;
  @override
  bool running = false;
  bool busy = false;
  String status = '';
  String error = '';
  DateTime? lastSync;

  /// Set when this account already has cloud data and this device has its own
  /// data too: the user chooses how to combine them.
  bool needsFirstSyncChoice = false;

  static const _collections = ['dates', 'itemTypes', 'people'];

  /// 'collection/id' -> last JSON this device sent or received.
  Map<String, String> _known = {};
  String _knownUid = '';

  /// Records this device has actually had in its local data since sync
  /// started. Only these can be deleted from the cloud.
  Set<String> _seenLocal = {};


  /// Set for one push after a deliberate bulk change (Delete All Data,
  /// Restore Backup), so the bulk-delete guard lets it through.
  bool _allowBulkDelete = false;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  StreamSubscription<User?>? _authSub;
  Timer? _pushTimer;
  Timer? _persistTimer;
  bool _applyingRemote = false;

  bool get enabled => _settings.cloudSyncEnabled;

  @override
  bool get isSyncOn => configured && user != null && enabled;

  @override
  String get statusSummary => !configured
      ? 'Cloud Sync is not set up yet'
      : user == null
          ? 'Not signed in – local device storage'
          : enabled
              ? (status.isEmpty ? 'Starting…' : status)
              : 'Sync is off – local device storage';

  @override
  String? get accountLabel => user?.email;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _col(String uid, String c) =>
      _db.collection('users').doc(uid).collection(c);

  // ---------------------------------------------------------------- start-up

  Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      configured = true;
    } catch (e) {
      configured = false;
      setupError = '$e';
      notifyListeners();
      return;
    }
    await _loadState();
    _store.onLocalChange = schedulePush;
    _settings.addListener(schedulePush);
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      user = u;
      notifyListeners();
      _restart();
    });
  }

  Future<void> setEnabled(bool on) async {
    _settings.cloudSyncEnabled = on;
    await _restart();
  }

  Future<void> _restart() async {
    _stop();
    if (configured && user != null && enabled) await _start();
    notifyListeners();
  }

  void _stop() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    running = false;
    status = enabled ? (user == null ? 'Signed out' : 'Paused') : 'Sync is off';
  }

  Future<void> _start() async {
    final uid = user!.uid;
    error = '';
    _seenLocal = _localRecords().keys.where((k) => !k.startsWith('meta/')).toSet();
    if (_knownUid == uid && _localLooksEmpty && _known.keys.any((k) => k.startsWith('dates/'))) {
      // This device synced before but its data is now empty (reinstalled,
      // restored or not readable): bring everything down again instead of
      // treating the missing records as deletions.
      _known = {};
      await _downloadAll(replaceLocal: false);
    }
    if (_knownUid != uid) {
      // First sync of this account on this device.
      _known = {};
      _knownUid = uid;
      final remoteHasData = await _remoteHasData(uid);
      if (remoteHasData && !_localLooksEmpty) {
        needsFirstSyncChoice = true;
        status = 'Choose how to combine this device with the cloud';
        notifyListeners();
        return;
      }
      if (remoteHasData) {
        await _downloadAll(replaceLocal: true);
      } else {
        await pushNow();
      }
    }
    _listen(uid);
    running = true;
    status = 'Up to date';
    notifyListeners();
    schedulePush();
  }

  /// [useCloud]: replace this device's data with the cloud data.
  /// Otherwise merge: records from both are kept; where the same record exists
  /// in both, the cloud version is used, then everything is uploaded.
  Future<void> resolveFirstSync({required bool useCloud}) async {
    needsFirstSyncChoice = false;
    busy = true;
    notifyListeners();
    try {
      await _downloadAll(replaceLocal: useCloud);
      if (!useCloud) await pushNow();
      _listen(user!.uid);
      running = true;
      status = 'Up to date';
    } catch (e) {
      error = 'First sync failed: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  bool get _localLooksEmpty => _store.dates.isEmpty && _store.items.isEmpty && _store.people.isEmpty;

  Future<bool> _remoteHasData(String uid) async {
    for (final c in _collections) {
      final docs = await _col(uid, c).limit(1).get();
      if (docs.docs.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _downloadAll({required bool replaceLocal}) async {
    final uid = user!.uid;
    status = 'Downloading from the cloud…';
    notifyListeners();
    _applyingRemote = true;
    try {
      if (replaceLocal) {
        await _store.deleteLocalAttachmentFiles([for (final d in _store.dates) ...d.attachments]);
        _store.syncDates.clear();
        _store.syncItems.clear();
        _store.syncPeople.clear();
        _seenLocal.clear();
        await NotificationService.cancelAll();
      }
      for (final c in _collections) {
        final docs = await _col(uid, c).get();
        for (final d in docs.docs) {
          await _applyDoc(c, d.id, d.data());
        }
      }
      final meta = await _col(uid, 'meta').doc('settings').get();
      if (meta.exists) await _applyDoc('meta', 'settings', meta.data() ?? {});
    } finally {
      _applyingRemote = false;
    }
    await _store.remoteChanged();
    _persistState();
  }

  // ---------------------------------------------------------------- listening

  void _listen(String uid) {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    for (final c in _collections) {
      _subscriptions.add(_col(uid, c).snapshots().listen(
            (snap) => _onSnapshot(c, snap),
            onError: _onError,
          ));
    }
    _subscriptions.add(_col(uid, 'meta').doc('settings').snapshots().listen(
      (doc) async {
        if (!doc.exists || doc.metadata.hasPendingWrites) return;
        _applyingRemote = true;
        bool changed;
        try {
          changed = await _applyDoc('meta', 'settings', doc.data() ?? {});
        } finally {
          _applyingRemote = false;
        }
        if (changed) await _remoteApplied();
      },
      onError: _onError,
    ));
  }

  Future<void> _onSnapshot(String collection, QuerySnapshot<Map<String, dynamic>> snap) async {
    var changed = false;
    _applyingRemote = true;
    try {
      for (final change in snap.docChanges) {
        if (change.doc.metadata.hasPendingWrites) continue; // our own edit
        final id = change.doc.id;
        if (change.type == DocumentChangeType.removed) {
          if (_known.remove('$collection/$id') != null) {
            await _removeLocal(collection, id);
            changed = true;
          }
        } else {
          changed = await _applyDoc(collection, id, change.doc.data() ?? {}) || changed;
        }
      }
    } finally {
      _applyingRemote = false;
    }
    if (changed) await _remoteApplied();
  }

  Future<void> _remoteApplied() async {
    await _store.remoteChanged();
    lastSync = DateTime.now();
    status = 'Up to date';
    notifyListeners();
    _persistState();
  }

  void _onError(Object e) {
    error = 'Sync error: $e';
    AppLog.error('Cloud Sync error', e);
    notifyListeners();
  }

  // ---------------------------------------------------------------- records

  /// Firestore document id for an item type or name.
  static String nameKey(String name) => sha256Hex(utf8.encode(name.trim().toLowerCase())).substring(0, 32);

  List<String> _names(String collection) => collection == 'itemTypes' ? _store.syncItems : _store.syncPeople;

  Map<String, String> _localRecords() {
    final out = <String, String>{};
    for (final d in _store.dates) {
      out['dates/${d.id}'] = jsonEncode(d.toJson());
    }
    for (final c in ['itemTypes', 'people']) {
      for (final n in _names(c)) {
        out['$c/${nameKey(n)}'] = jsonEncode({'name': n});
      }
    }
    out['meta/settings'] = jsonEncode(_settings.toSyncValues());
    return out;
  }

  /// Applies one cloud document locally. Returns true if anything changed.
  Future<bool> _applyDoc(String collection, String id, Map<String, dynamic> doc) async {
    final json = doc['json'];
    if (json is! String) return false;
    final key = '$collection/$id';
    if (_known[key] == json) return false;
    final m = Map<String, dynamic>.from(jsonDecode(json) as Map);
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
        _known[key] = jsonEncode(date.toJson());
      case 'itemTypes' || 'people':
        final name = (m['name'] as String? ?? '').trim();
        if (name.isEmpty) return false;
        final list = _names(collection);
        list.removeWhere((n) => n.toLowerCase() == name.toLowerCase());
        list.add(name);
        _known[key] = jsonEncode({'name': name});
      case 'meta':
        await _settings.applySyncValues(m);
        _known[key] = jsonEncode(_settings.toSyncValues());
        return true;
      default:
        return false;
    }
    _seenLocal.add(key);
    return true;
  }

  Future<void> _removeLocal(String collection, String id) async {
    switch (collection) {
      case 'dates':
        final list = _store.syncDates;
        final index = list.indexWhere((d) => d.id == id);
        if (index >= 0) {
          final date = list.removeAt(index);
          await NotificationService.cancel(date);
          await _store.deleteLocalAttachmentFiles(date.attachments);
        }
      case 'itemTypes' || 'people':
        _names(collection).removeWhere((n) => nameKey(n) == id);
    }
    _seenLocal.remove('$collection/$id');
  }

  // ---------------------------------------------------------------- pushing

  /// Called after every local change (debounced).
  void schedulePush() {
    if (_applyingRemote || !running) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(seconds: 2), () => pushNow());
  }

  /// Lets the next push delete many records at once. Called by deliberate
  /// bulk changes (Delete All Data, Restore Backup) before they run.
  @override
  void allowBulkDeleteOnce() => _allowBulkDelete = true;

  /// Sends every new, changed or deleted record to the cloud.
  Future<void> pushNow() async {
    final u = user;
    if (!configured || u == null || !enabled || needsFirstSyncChoice) return;
    final local = _localRecords();
    final allowBulk = _allowBulkDelete;
    _allowBulkDelete = false;
    final plan = SyncRules.planCloudPush(local: local, known: _known, seenLocal: _seenLocal, allowBulk: allowBulk);
    final writes = plan.writes;
    final missing = plan.missing;
    _seenLocal.addAll(local.keys.where((k) => !k.startsWith('meta/')));
    if (missing.isNotEmpty) unawaited(_refetch(missing));
    if (plan.blockedBulkDelete) {
      error = 'Cloud Sync stopped ${plan.deletes} records from being deleted in the cloud at once. '
          'If you really meant to delete them, delete them in smaller groups.';
      AppLog.error(error);
    }
    if (writes.isEmpty) {
      lastSync = DateTime.now();
      notifyListeners();
      return;
    }
    status = 'Sending ${writes.length} change${writes.length == 1 ? '' : 's'}…';
    notifyListeners();
    try {
      for (var i = 0; i < writes.length; i += 400) {
        final batch = _db.batch();
        for (final (key, json) in writes.skip(i).take(400)) {
          final slash = key.indexOf('/');
          final ref = _col(u.uid, key.substring(0, slash)).doc(key.substring(slash + 1));
          if (json == null) {
            batch.delete(ref);
          } else {
            batch.set(ref, {
              'json': json,
              'modified': FieldValue.serverTimestamp(),
              'modifiedBy': u.uid,
            });
          }
        }
        // Firestore applies the batch locally at once and sends it when online.
        unawaited(batch.commit().catchError((Object e) => _onError(e)));
      }
      for (final (key, json) in writes) {
        if (json == null) {
          _known.remove(key);
        } else {
          _known[key] = json;
        }
      }
      lastSync = DateTime.now();
      status = 'Up to date';
      if (!plan.blockedBulkDelete) error = '';
    } catch (e) {
      error = 'Could not send changes: $e';
    }
    notifyListeners();
    _persistState();
  }

  /// Downloads records this device knows about but does not have locally.
  Future<void> _refetch(List<String> keys) async {
    final u = user;
    if (u == null) return;
    var changed = false;
    _applyingRemote = true;
    try {
      for (final key in keys) {
        final slash = key.indexOf('/');
        final collection = key.substring(0, slash), id = key.substring(slash + 1);
        try {
          final doc = await _col(u.uid, collection).doc(id).get();
          _known.remove(key);
          if (doc.exists && await _applyDoc(collection, id, doc.data() ?? {})) changed = true;
        } catch (e) {
          AppLog.error('Could not fetch a record from the cloud', e);
        }
      }
    } finally {
      _applyingRemote = false;
    }
    if (changed) await _remoteApplied();
    _persistState();
  }

  // ---------------------------------------------------------------- account

  Future<String?> signIn(String email, String password) => _auth(() =>
      FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: password));

  Future<String?> createAccount(String email, String password) => _auth(() =>
      FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.trim(), password: password));

  Future<String?> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    }
  }

  /// Changes the password after confirming the current one.
  Future<String?> changePassword(String currentPassword, String newPassword) async {
    try {
      final u = await _reauthenticate(currentPassword);
      await u.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    } catch (e) {
      return '$e';
    }
  }

  /// Sends a confirmation link to [newEmail]; the sign-in email changes when
  /// the link is opened. All data stays with the account.
  Future<String?> changeEmail(String currentPassword, String newEmail) async {
    try {
      final u = await _reauthenticate(currentPassword);
      await u.verifyBeforeUpdateEmail(newEmail.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    } catch (e) {
      return '$e';
    }
  }

  /// Deletes the account and everything it keeps in the cloud (records,
  /// settings, attachment files). The data on this device is kept and sync is
  /// switched off. Returns an error message, or null when done.
  Future<String?> deleteAccount(String currentPassword) async {
    final User u;
    try {
      u = await _reauthenticate(currentPassword);
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    } catch (e) {
      return '$e';
    }
    final uid = u.uid;
    _stop();
    busy = true;
    status = 'Deleting your cloud data…';
    notifyListeners();
    try {
      final userDoc = _db.collection('users').doc(uid);
      final deletes = <DocumentReference<Map<String, dynamic>>>[];

      // Attachment files first (only this app's), then their records.
      final docs = await userDoc.collection('documents').where('appId', isEqualTo: 'important-dates').get();
      for (final d in docs.docs) {
        final path = d.data()['storagePath'];
        if (path is String && path.isNotEmpty) {
          try {
            await FirebaseStorage.instance.ref(path).delete();
          } catch (_) {} // already gone
        }
        deletes.add(d.reference);
      }
      for (final c in [..._collections, 'meta']) {
        final s = await userDoc.collection(c).get();
        deletes.addAll(s.docs.map((d) => d.reference));
      }
      deletes.add(userDoc);
      for (var i = 0; i < deletes.length; i += 400) {
        final batch = _db.batch();
        for (final ref in deletes.skip(i).take(400)) {
          batch.delete(ref);
        }
        await batch.commit();
      }

      await u.delete();

      _known = {};
      _knownUid = '';
      _seenLocal = {};
      lastSync = null;
      _persistState();
      for (final d in _store.syncDates) {
        for (final a in d.attachments) {
          a.cloudDocId = null; // the cloud copies are gone
        }
      }
      await _store.attachmentsChanged();
      _settings.cloudSyncEnabled = false;
      status = 'Account deleted';
      error = '';
      return null;
    } on FirebaseAuthException catch (e) {
      error = 'Could not delete the account: ${_authMessage(e)}';
      return error;
    } catch (e) {
      error = 'Could not delete everything: $e';
      return error;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<User> _reauthenticate(String currentPassword) async {
    final u = FirebaseAuth.instance.currentUser;
    final email = u?.email;
    if (u == null || email == null) throw StateError('You are not signed in.');
    await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: currentPassword));
    return u;
  }

  Future<String?> _auth(Future<UserCredential> Function() action) async {
    try {
      await action();
      if (!enabled) await setEnabled(true);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    } catch (e) {
      return '$e';
    }
  }

  String _authMessage(FirebaseAuthException e) => switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' => 'The email or password is not correct.',
        'email-already-in-use' => 'An account already exists for this email. Use Sign In instead.',
        'weak-password' => 'Choose a password of at least 6 characters.',
        'invalid-email' => 'That email address is not valid.',
        'network-request-failed' => 'No internet connection.',
        'operation-not-allowed' => 'Email sign-in is not enabled in the Firebase project (Authentication › Sign-in method).',
        'requires-recent-login' => 'For security, sign out and sign in again, then try once more.',
        'too-many-requests' => 'Too many attempts. Please wait a few minutes and try again.',
        _ => e.message ?? e.code,
      };

  Future<void> signOut() async {
    _stop();
    await FirebaseAuth.instance.signOut();
  }

  // ---------------------------------------------------------------- state file

  Future<File> _stateFile() async => File('${(await getApplicationSupportDirectory()).path}/cloud_sync_state.json');

  Future<void> _loadState() async {
    try {
      final f = await _stateFile();
      if (!await f.exists()) return;
      final m = jsonDecode(await f.readAsString()) as Map;
      _knownUid = (m['uid'] ?? '') as String;
      _known = Map<String, String>.from(m['known'] as Map);
      final last = m['lastSync'];
      if (last is String) lastSync = DateTime.tryParse(last);
    } catch (e) {
      AppLog.error('Could not read the saved Cloud Sync state', e);
    }
  }

  void _persistState() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(seconds: 1), () async {
      try {
        final f = await _stateFile();
        await f.writeAsString(jsonEncode({'uid': _knownUid, 'known': _known, 'lastSync': lastSync?.toIso8601String()}));
      } catch (e) {
        AppLog.error('Could not save the Cloud Sync state', e);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
