import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_log.dart';

/// Which user passcode.
enum PasscodeKind { app, deleteAll }

/// The user's passcodes, kept as salted SHA-256 hashes in the iOS/macOS
/// keychain or Android keystore (flutter_secure_storage), never as plain text.
///
/// Also counts wrong entries: after [freeAttempts] wrong entries in a row,
/// each further wrong entry locks entry for a while (1, 2, 4 … up to 60
/// minutes). The count survives restarting the app.
///
/// Older builds kept the passcodes as plain text in shared_preferences; they
/// are moved here on first start and the plain copies deleted.
class PasscodeStore extends ChangeNotifier {
  PasscodeStore._(this._prefs, this._secure);
  static late PasscodeStore instance;

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;
  final Map<PasscodeKind, String> _hashes = {};

  static const freeAttempts = 5;
  static const _maxLockout = Duration(minutes: 60);

  static String _secureKey(PasscodeKind k) => switch (k) {
        PasscodeKind.app => 'appPasscodeHash',
        PasscodeKind.deleteAll => 'deleteAllPasscodeHash',
      };

  // Plain-text keys used by builds up to 3.0.67FL (and the native app).
  static String _legacyKey(PasscodeKind k) => switch (k) {
        PasscodeKind.app => 'appPasscode',
        PasscodeKind.deleteAll => 'deleteAllPasscode',
      };

  static const _installMarker = 'passcodeStoreInstalled';
  static const _failedKey = 'passcodeFailedAttempts';
  static const _lockedUntilKey = 'passcodeLockedUntilMs';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final store = PasscodeStore._(prefs, const FlutterSecureStorage());
    await store._load();
    instance = store;
  }

  Future<void> _load() async {
    // Keychain items survive deleting the app on iOS. A fresh install must not
    // be locked by an old passcode, so clear them when the marker is missing.
    if (!(_prefs.getBool(_installMarker) ?? false)) {
      for (final k in PasscodeKind.values) {
        await _safeDelete(_secureKey(k));
      }
      await _prefs.setBool(_installMarker, true);
    }
    for (final k in PasscodeKind.values) {
      final legacy = _prefs.getString(_legacyKey(k)) ?? '';
      if (legacy.trim().isNotEmpty) {
        try {
          await _write(k, legacy.trim());
          await _prefs.remove(_legacyKey(k));
        } catch (_) {
          // _write already logged it and kept the hash in memory; the plain
          // copy stays until a later start can move it.
        }
      } else {
        await _prefs.remove(_legacyKey(k));
        final h = await _safeRead(_secureKey(k));
        if (h != null && h.isNotEmpty) _hashes[k] = h;
      }
    }
  }

  bool has(PasscodeKind k) => _hashes.containsKey(k);

  Future<void> set(PasscodeKind k, String passcode) async {
    await _write(k, passcode.trim());
    notifyListeners();
  }

  Future<void> clear(PasscodeKind k) async {
    _hashes.remove(k);
    await _safeDelete(_secureKey(k));
    notifyListeners();
  }

  /// Checks [entered] against the stored passcode. Does not count attempts;
  /// use [attempt] for entry screens.
  bool matches(PasscodeKind k, String entered) {
    final stored = _hashes[k];
    if (stored == null) return false;
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    return _constantTimeEquals(_hash(parts[0], entered.trim()), parts[1]);
  }

  // ---------- Wrong-entry limit ----------

  int get failedAttempts => _prefs.getInt(_failedKey) ?? 0;

  /// When entry is allowed again, or null if it is allowed now.
  DateTime? get lockedUntil {
    final ms = _prefs.getInt(_lockedUntilKey);
    if (ms == null) return null;
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    return t.isAfter(DateTime.now()) ? t : null;
  }

  /// Records the outcome of one entry. Call only when [lockedUntil] is null.
  Future<void> recordAttempt({required bool success}) async {
    if (success) {
      await _prefs.remove(_failedKey);
      await _prefs.remove(_lockedUntilKey);
    } else {
      final n = failedAttempts + 1;
      await _prefs.setInt(_failedKey, n);
      final wait = lockoutFor(n);
      if (wait > Duration.zero) {
        await _prefs.setInt(_lockedUntilKey, DateTime.now().add(wait).millisecondsSinceEpoch);
      }
    }
    notifyListeners();
  }

  /// How long entry is blocked after the [failures]-th wrong entry in a row.
  @visibleForTesting
  static Duration lockoutFor(int failures) {
    if (failures < freeAttempts) return Duration.zero;
    final minutes = 1 << min(failures - freeAttempts, 6); // 1, 2, 4 … 64
    final d = Duration(minutes: minutes);
    return d > _maxLockout ? _maxLockout : d;
  }

  /// "Try again in 3 minutes" style text for [lockedUntil].
  static String waitText(DateTime until) {
    final left = until.difference(DateTime.now());
    if (left.inSeconds < 60) return 'Try again in ${max(1, left.inSeconds)} seconds.';
    final m = (left.inSeconds / 60).ceil();
    return 'Try again in $m minute${m == 1 ? '' : 's'}.';
  }

  // ---------- Hashing ----------

  Future<void> _write(PasscodeKind k, String passcode) async {
    final salt = _newSalt();
    final value = '$salt:${_hash(salt, passcode)}';
    _hashes[k] = value;
    try {
      await _secure.write(key: _secureKey(k), value: value);
    } catch (e, st) {
      AppLog.error('Could not save the passcode securely', e, st);
      rethrow;
    }
  }

  @visibleForTesting
  static String hashForTest(String salt, String passcode) => _hash(salt, passcode);

  static String _hash(String salt, String passcode) {
    // Many rounds make guessing a stolen hash slower (well under a second).
    var bytes = utf8.encode('$salt:$passcode');
    for (var i = 0; i < 10000; i++) {
      bytes = Uint8List.fromList(sha256.convert(bytes).bytes);
    }
    return base64Url.encode(bytes);
  }

  static String _newSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<String?> _safeRead(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (e, st) {
      AppLog.error('Could not read a passcode from secure storage', e, st);
      return null;
    }
  }

  Future<void> _safeDelete(String key) async {
    try {
      await _secure.delete(key: key);
    } catch (e, st) {
      AppLog.error('Could not remove a passcode from secure storage', e, st);
    }
  }
}
