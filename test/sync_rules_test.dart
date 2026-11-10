import 'package:flutter_test/flutter_test.dart';
import 'package:important_dates/services/sync_rules.dart';

/// `count` records `dates/0` … `dates/<count-1>`.
Map<String, String> records(int count, [String json = 'v1']) => {for (var i = 0; i < count; i++) 'dates/$i': json};

final t0 = DateTime.utc(2026, 11, 1);
final t1 = DateTime.utc(2026, 11, 2);
final t2 = DateTime.utc(2026, 11, 3);

void main() {
  group('bulk-delete guard', () {
    test('allows up to 10 deletes', () {
      expect(SyncRules.blocksBulkDelete(deletes: 10, knownCount: 12, allowBulk: false), isFalse);
    });
    test('allows many deletes when they are under half of the records', () {
      expect(SyncRules.blocksBulkDelete(deletes: 20, knownCount: 100, allowBulk: false), isFalse);
    });
    test('blocks more than 10 deletes that are over half of the records', () {
      expect(SyncRules.blocksBulkDelete(deletes: 11, knownCount: 20, allowBulk: false), isTrue);
    });
    test('Delete All Data / Restore Backup lets it through once', () {
      expect(SyncRules.blocksBulkDelete(deletes: 50, knownCount: 50, allowBulk: true), isFalse);
    });
  });

  group('Cloud Sync push', () {
    test('sends new and changed records only', () {
      final plan = SyncRules.planCloudPush(
        local: {'dates/a': 'same', 'dates/b': 'changed', 'dates/c': 'new'},
        known: {'dates/a': 'same', 'dates/b': 'old'},
        seenLocal: {'dates/a', 'dates/b'},
        allowBulk: false,
      );
      expect(plan.writes, unorderedEquals([('dates/b', 'changed'), ('dates/c', 'new')]));
      expect(plan.deletes, 0);
    });

    test('deletes a record only when it was on this device', () {
      final plan = SyncRules.planCloudPush(
        local: {},
        known: {'dates/gone': 'v', 'dates/never-here': 'v'},
        seenLocal: {'dates/gone'},
        allowBulk: false,
      );
      expect(plan.writes, [('dates/gone', null)]);
      expect(plan.missing, ['dates/never-here']);
    });

    test('an emptied device deletes nothing and fetches everything again', () {
      final known = records(30);
      final plan = SyncRules.planCloudPush(local: {}, known: known, seenLocal: {}, allowBulk: false);
      expect(plan.writes, isEmpty);
      expect(plan.missing, hasLength(30));
    });

    test('mass delete on this device is held back', () {
      final known = records(20);
      final plan = SyncRules.planCloudPush(local: {}, known: known, seenLocal: known.keys.toSet(), allowBulk: false);
      expect(plan.blockedBulkDelete, isTrue);
      expect(plan.writes.where((w) => w.$2 == null), isEmpty);
    });

    test('mass delete goes through after allowBulkDeleteOnce', () {
      final known = records(20);
      final plan = SyncRules.planCloudPush(local: {}, known: known, seenLocal: known.keys.toSet(), allowBulk: true);
      expect(plan.blockedBulkDelete, isFalse);
      expect(plan.writes.where((w) => w.$2 == null), hasLength(20));
    });
  });

  group('Google Drive merge', () {
    DriveMerge merge({
      Map<String, String> local = const {},
      Map<String, String>? known,
      Map<String, RemoteRecord> remote = const {},
      Map<String, DateTime> deleted = const {},
      Set<String> seenLocal = const {},
      bool allowBulk = false,
      bool preferRemote = false,
      DateTime? lastLocalChange,
    }) =>
        SyncRules.mergeDrive(
          local: local,
          known: known ?? {},
          remote: remote,
          deleted: deleted,
          seenLocal: seenLocal,
          allowBulk: allowBulk,
          preferRemote: preferRemote,
          lastLocalChange: lastLocalChange ?? t0,
        );

    test('new on this device is uploaded; new in Drive is downloaded', () {
      final m = merge(local: {'dates/mine': 'a'}, remote: {'dates/theirs': RemoteRecord('b', t0)});
      expect(m.written, {'dates/mine': 'a'});
      expect(m.apply, {'dates/theirs': 'b'});
    });

    test('records both sides agree on are remembered as known', () {
      final known = <String, String>{};
      merge(local: {'dates/x': 'v'}, known: known, remote: {'dates/x': RemoteRecord('v', t0)});
      expect(known, {'dates/x': 'v'});
    });

    test('changed only here: this device wins', () {
      final m = merge(
        local: {'dates/x': 'mine'},
        known: {'dates/x': 'old'},
        remote: {'dates/x': RemoteRecord('old', t0)},
      );
      expect(m.written, {'dates/x': 'mine'});
      expect(m.apply, isEmpty);
    });

    test('changed on both sides: the later change wins', () {
      final newerHere = merge(
        local: {'dates/x': 'mine'},
        known: {'dates/x': 'old'},
        remote: {'dates/x': RemoteRecord('theirs', t1)},
        lastLocalChange: t2,
      );
      expect(newerHere.written, {'dates/x': 'mine'});

      final newerThere = merge(
        local: {'dates/x': 'mine'},
        known: {'dates/x': 'old'},
        remote: {'dates/x': RemoteRecord('theirs', t2)},
        lastLocalChange: t1,
      );
      expect(newerThere.apply, {'dates/x': 'theirs'});
    });

    test('first sync with an account: Drive wins conflicts', () {
      final m = merge(
        local: {'dates/x': 'mine'},
        known: {'dates/x': 'old'},
        remote: {'dates/x': RemoteRecord('theirs', t0)},
        preferRemote: true,
        lastLocalChange: t2,
      );
      expect(m.apply, {'dates/x': 'theirs'});
    });

    test('deleted on another device is removed here, unless edited here since', () {
      final removed = merge(local: {'dates/x': 'v'}, known: {'dates/x': 'v'}, deleted: {'dates/x': t1});
      expect(removed.remove, {'dates/x'});

      final kept = merge(
        local: {'dates/x': 'edited'},
        known: {'dates/x': 'v'},
        deleted: {'dates/x': t1},
        lastLocalChange: t2,
      );
      expect(kept.written, {'dates/x': 'edited'});
      expect(kept.remove, isEmpty);
    });

    test('deleted here is marked deleted in Drive', () {
      final m = merge(known: {'dates/x': 'v'}, remote: {'dates/x': RemoteRecord('v', t0)}, seenLocal: {'dates/x'});
      expect(m.tombstoned, {'dates/x'});
    });

    test('deleted here but changed elsewhere since: the other change is kept', () {
      final m = merge(known: {'dates/x': 'v'}, remote: {'dates/x': RemoteRecord('newer', t1)}, seenLocal: {'dates/x'});
      expect(m.tombstoned, isEmpty);
      expect(m.apply, {'dates/x': 'newer'});
    });

    test('an emptied device downloads everything instead of deleting it', () {
      final known = records(30);
      final m = merge(known: known, remote: {for (final k in known.keys) k: RemoteRecord('v1', t0)});
      expect(m.tombstoned, isEmpty);
      expect(m.apply, hasLength(30));
    });

    test('mass delete on this device is held back', () {
      final known = records(20);
      final m = merge(
        known: known,
        remote: {for (final k in known.keys) k: RemoteRecord('v1', t0)},
        seenLocal: known.keys.toSet(),
      );
      expect(m.blocked, hasLength(20));
      expect(m.tombstoned, isEmpty);
      expect(m.apply, isEmpty);
    });

    test('a key gone everywhere is forgotten', () {
      final known = {'dates/x': 'v'};
      merge(known: known);
      expect(known, isEmpty);
    });
  });
}
