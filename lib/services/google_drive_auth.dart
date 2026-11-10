import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../config/google_drive_config.dart';
import 'app_log.dart';

/// Thrown when Google Drive access has to be granted again with a sign-in
/// screen (it was revoked, or never granted on this device).
class DriveAuthorizationNeeded implements Exception {
  const DriveAuthorizationNeeded();
  @override
  String toString() => 'Google Drive access is needed. Open Manage › Cloud Sync and tap Sign In with Google.';
}

/// Google sign-in (google_sign_in 7.x) plus an HTTP client that sends the
/// access token for the Drive app-data scope.
///
/// Only the `drive.appdata` scope is requested: the app sees its own hidden
/// folder in the user's Drive and nothing else.
class GoogleDriveAuth {
  static const scopes = <String>['https://www.googleapis.com/auth/drive.appdata'];

  GoogleSignInAccount? _account;
  _BearerClient? _client;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;
  void Function()? _onChanged;

  /// True during [signIn]: the sign-in event is handled when it has finished
  /// (after Drive access was granted), not as soon as Google reports it.
  bool _signingIn = false;

  bool get signedIn => _account != null;
  String? get email => _account?.email;

  /// Stable Google account id (not the email, which can change).
  String? get accountId => _account?.id;

  Future<void> init({required void Function() onChanged, required bool trySilentSignIn}) async {
    _onChanged = onChanged;
    final signIn = GoogleSignIn.instance;
    await signIn.initialize(clientId: GoogleDriveConfig.clientId, serverClientId: GoogleDriveConfig.serverClientId);
    _sub = signIn.authenticationEvents.listen(
      (event) {
        if (_signingIn) return;
        _setAccount(event is GoogleSignInAuthenticationEventSignIn ? event.user : null);
      },
      onError: (Object _) {},
    );
    if (trySilentSignIn) {
      try {
        // Restores the previous sign-in without showing anything where
        // possible; the result also arrives as an authentication event.
        final account = await signIn.attemptLightweightAuthentication();
        if (account != null) _setAccount(account);
      } catch (e) {
        AppLog.error('Could not restore the Google sign-in', e);
      }
    }
  }

  void _setAccount(GoogleSignInAccount? account) {
    if (account?.id == _account?.id) return;
    _account = account;
    _client?.close();
    _client = null;
    _onChanged?.call();
  }

  /// Shows Google's sign-in, then asks for Drive app-folder access.
  /// Throws [GoogleSignInException] (code canceled when the user backs out).
  Future<void> signIn() async {
    _signingIn = true;
    try {
      final account = await GoogleSignIn.instance.authenticate(scopeHint: scopes);
      await _accessToken(account, interactive: true);
      _signingIn = false;
      _setAccount(account);
    } finally {
      _signingIn = false;
    }
  }

  Future<String> _accessToken(GoogleSignInAccount account, {required bool interactive}) async {
    var authorization = await account.authorizationClient.authorizationForScopes(scopes);
    if (authorization == null) {
      if (!interactive) throw const DriveAuthorizationNeeded();
      authorization = await account.authorizationClient.authorizeScopes(scopes);
    }
    return authorization.accessToken;
  }

  /// HTTP client for the Drive API with a fresh access token.
  Future<http.Client> client({bool interactive = false}) async {
    final account = _account;
    if (account == null) throw const DriveAuthorizationNeeded();
    final token = await _accessToken(account, interactive: interactive);
    return (_client ??= _BearerClient())..token = token;
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    _setAccount(null);
  }

  /// Signs out and removes this app's access to the Google account.
  Future<void> disconnect() async {
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {
      await GoogleSignIn.instance.signOut();
    }
    _setAccount(null);
  }

  void dispose() {
    _sub?.cancel();
    _client?.close();
  }
}

class _BearerClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  String token = '';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $token';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
