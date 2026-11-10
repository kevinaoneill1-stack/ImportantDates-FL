import 'package:flutter_test/flutter_test.dart';
import 'package:important_dates/data/passcode_store.dart';
import 'package:important_dates/services/app_log.dart';

void main() {
  group('wrong-entry limit', () {
    test('the first four wrong entries have no wait', () {
      for (var n = 1; n < PasscodeStore.freeAttempts; n++) {
        expect(PasscodeStore.lockoutFor(n), Duration.zero, reason: 'after $n wrong entries');
      }
    });

    test('then the wait doubles: 1, 2, 4 … minutes', () {
      expect(PasscodeStore.lockoutFor(5), const Duration(minutes: 1));
      expect(PasscodeStore.lockoutFor(6), const Duration(minutes: 2));
      expect(PasscodeStore.lockoutFor(7), const Duration(minutes: 4));
    });

    test('and never goes over an hour', () {
      expect(PasscodeStore.lockoutFor(20), const Duration(minutes: 60));
      expect(PasscodeStore.lockoutFor(1000), const Duration(minutes: 60));
    });
  });

  group('passcode hashing', () {
    test('is repeatable for the same salt and passcode', () {
      expect(PasscodeStore.hashForTest('salt', '1234'), PasscodeStore.hashForTest('salt', '1234'));
    });

    test('differs for another passcode or another salt', () {
      final h = PasscodeStore.hashForTest('salt', '1234');
      expect(PasscodeStore.hashForTest('salt', '1235'), isNot(h));
      expect(PasscodeStore.hashForTest('other', '1234'), isNot(h));
    });

    test('does not contain the passcode', () {
      expect(PasscodeStore.hashForTest('salt', '987654').contains('987654'), isFalse);
    });
  });

  group('app log', () {
    test('keeps the newest 50 problems, newest first', () {
      AppLog.clear();
      for (var i = 0; i < 60; i++) {
        AppLog.error('problem $i');
      }
      expect(AppLog.entries, hasLength(50));
      expect(AppLog.entries.first.message, 'problem 59');
      expect(AppLog.entries.last.message, 'problem 10');
      AppLog.clear();
      expect(AppLog.entries, isEmpty);
    });
  });
}
