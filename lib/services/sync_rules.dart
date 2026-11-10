/// The decisions Cloud Sync and Google Drive Sync make about records, kept
/// apart from Firebase and Drive so they can be tested (test/sync_rules_test.dart).
///
/// Records are keyed like `dates/<id>` or `people/<hash>`, each with its JSON.
/// * `local`     – what is on this device now.
/// * `known`     – what this device last agreed with the cloud.
/// * `seenLocal` – keys that have been on this device since sync started. Only
///   these can be "deleted on this device"; a key the device never had is
///   missing, not deleted, and is fetched again instead.
library;

/// The bulk-delete guard: more than [SyncRules.maxBulkDeletes] deletes that
/// are also more than half of everything synced look like an accident (an
/// emptied or broken device), so they are not sent.
class SyncRules {
  SyncRules._();

  static const maxBulkDeletes = 10;

  static bool blocksBulkDelete({required int deletes, required int knownCount, required bool allowBulk}) =>
      !allowBulk && deletes > maxBulkDeletes && deletes * 2 > knownCount;

  // ------------------------------------------------------------ Cloud Sync

  /// What one Cloud Sync push sends. Deletes are only for records that were on
  /// this device and are now gone.
  static CloudPushPlan planCloudPush({
    required Map<String, String> local,
    required Map<String, String> known,
    required Set<String> seenLocal,
    required bool allowBulk,
  }) {
    final writes = <(String, String?)>[]; // key, json (null = delete)
    local.forEach((key, json) {
      if (known[key] != json) writes.add((key, json));
    });
    final missing = <String>[];
    var deletes = 0;
    for (final key in known.keys) {
      if (local.containsKey(key)) continue;
      if (seenLocal.contains(key)) {
        writes.add((key, null)); // deleted on this device
        deletes++;
      } else {
        missing.add(key); // never here this session: fetch it, do not delete it
      }
    }
    final blocked = blocksBulkDelete(deletes: deletes, knownCount: known.length, allowBulk: allowBulk);
    if (blocked) writes.removeWhere((w) => w.$2 == null);
    return CloudPushPlan(writes, missing, deletes, blocked);
  }

  // ------------------------------------------------------ Google Drive Sync

  /// Merges this device with the Drive file.
  ///
  /// [known] is updated in place for records both sides already agree on, and
  /// for keys that no longer exist anywhere, exactly as the sync does it.
  /// [deleted] holds Drive's tombstones (already trimmed of old ones).
  /// [preferRemote] is set on the first sync with an account, when Drive wins
  /// conflicts. [lastLocalChange] decides other conflicts by time.
  static DriveMerge mergeDrive({
    required Map<String, String> local,
    required Map<String, String> known,
    required Map<String, RemoteRecord> remote,
    required Map<String, DateTime> deleted,
    required Set<String> seenLocal,
    required bool allowBulk,
    required bool preferRemote,
    required DateTime lastLocalChange,
  }) {
    // Records gone from this device since the last sync.
    final localDeletes = <String>{};
    for (final key in known.keys) {
      if (!local.containsKey(key) && seenLocal.contains(key)) localDeletes.add(key);
    }
    final blocked = <String>{};
    if (blocksBulkDelete(deletes: localDeletes.length, knownCount: known.length, allowBulk: allowBulk)) {
      blocked.addAll(localDeletes);
      localDeletes.clear();
    }

    final apply = <String, String>{}; // key -> JSON to put on this device
    final remove = <String>{}; // keys to delete on this device
    final written = <String, String>{}; // key -> JSON this device sends
    final tombstoned = <String>{};

    final keys = {...local.keys, ...remote.keys, ...deleted.keys, ...known.keys};
    for (final key in keys) {
      if (blocked.contains(key)) continue;
      final was = known[key];
      final mine = local[key];
      final theirs = remote[key];
      final deletedAt = deleted[key];

      if (mine != null) {
        if (theirs != null) {
          if (mine == theirs.json) {
            known[key] = mine;
            continue;
          }
          final mineChanged = mine != was;
          final theirsChanged = theirs.json != was;
          final takeMine = mineChanged && (!theirsChanged || (!preferRemote && lastLocalChange.isAfter(theirs.modified)));
          if (takeMine) {
            written[key] = mine;
          } else {
            apply[key] = theirs.json;
          }
        } else if (deletedAt != null && was != null) {
          // Deleted on another device. Keep it only if edited here since.
          if (mine != was && lastLocalChange.isAfter(deletedAt)) {
            written[key] = mine;
          } else {
            remove.add(key);
          }
        } else {
          written[key] = mine; // new on this device
        }
      } else if (localDeletes.contains(key)) {
        if (theirs != null && theirs.json != was) {
          apply[key] = theirs.json; // changed elsewhere after it was deleted here: keep it
        } else if (theirs != null || deletedAt == null) {
          tombstoned.add(key);
        } else {
          known.remove(key);
        }
      } else if (theirs != null) {
        apply[key] = theirs.json; // new elsewhere, or missing on this device
      } else {
        known.remove(key);
      }
    }
    return DriveMerge(apply: apply, remove: remove, written: written, tombstoned: tombstoned, blocked: blocked);
  }
}

class CloudPushPlan {
  CloudPushPlan(this.writes, this.missing, this.deletes, this.blockedBulkDelete);

  /// Key and JSON to write; JSON null means delete.
  final List<(String, String?)> writes;

  /// Known in the cloud but never on this device: fetch, never delete.
  final List<String> missing;

  /// Records deleted on this device (sent unless [blockedBulkDelete]).
  final int deletes;
  final bool blockedBulkDelete;
}

/// A record in the Drive file.
class RemoteRecord {
  const RemoteRecord(this.json, this.modified);
  final String json;
  final DateTime modified;
}

class DriveMerge {
  DriveMerge({
    required this.apply,
    required this.remove,
    required this.written,
    required this.tombstoned,
    required this.blocked,
  });

  /// Drive's version to put on this device.
  final Map<String, String> apply;

  /// Deleted on another device: remove here.
  final Set<String> remove;

  /// This device's version to save to Drive.
  final Map<String, String> written;

  /// Deleted on this device: mark deleted in Drive.
  final Set<String> tombstoned;

  /// Deletes held back by the bulk-delete guard.
  final Set<String> blocked;
}
