import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Authentication Service managing Google Sign-In with read-only access.
///
/// Invariant: Strictly READ-ONLY.
/// Requests ONLY `email` and `https://www.googleapis.com/auth/youtube.readonly`.
/// Never requests write permissions; never modifies or mutates the user's YouTube account.
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  /// Default configured OAuth 2.0 Client ID for DilSe
  static const String defaultClientId =
      '130201428767-i1tt2et39of41d7mfs4j3d7fmnab5ug4.apps.googleusercontent.com';

  GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: defaultClientId,
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/youtube.readonly',
    ],
  );

  GoogleSignInAccount? _currentUser;
  String? _accessToken;
  bool _isInitializing = false;
  bool _isDemoMode = false;
  bool _isExplicitGuestMode = false;
  String? _clientId = defaultClientId;
  String? _lastError;
  bool _isMissingClientId = false;

  // Demo user fields
  String? _demoUserId;
  String? _demoUserName;
  String? _demoUserEmail;
  String? _demoUserPhotoUrl;

  /// Current signed-in Google account (null if signed out or in demo mode).
  GoogleSignInAccount? get currentUser => _currentUser;

  /// Whether a user is currently signed in (real or demo).
  bool get isAuthenticated =>
      !_isExplicitGuestMode && (_currentUser != null || _isDemoMode);

  /// Whether Guest Mode is currently active.
  bool get isGuestMode => !isAuthenticated;

  /// Whether running in Demo Account mode for UI testing.
  bool get isDemoMode => _isDemoMode && !_isExplicitGuestMode;

  /// Last error message encountered during sign-in, if any.
  String? get lastError => _lastError;

  /// Whether sign-in failed specifically due to a missing OAuth Client ID.
  bool get isMissingClientId => _isMissingClientId;

  /// Configured OAuth 2.0 Web Client ID.
  String? get configuredClientId => _clientId;

  /// Current cached OAuth 2.0 access token.
  String? get accessToken => _accessToken;

  /// Display name of the signed-in user.
  String? get userDisplayName =>
      _currentUser?.displayName ?? (_isDemoMode ? _demoUserName : null);

  /// Email address of the signed-in user.
  String? get userEmail =>
      _currentUser?.email ?? (_isDemoMode ? _demoUserEmail : null);

  /// Profile photo URL of the signed-in user.
  String? get userPhotoUrl =>
      _currentUser?.photoUrl ?? (_isDemoMode ? _demoUserPhotoUrl : null);

  /// Unique Google account identifier.
  String? get userId => _currentUser?.id ?? (_isDemoMode ? _demoUserId : null);

  /// Stream of user sign-in state changes.
  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _googleSignIn.onCurrentUserChanged;

  /// Configures custom Google OAuth Client ID and re-initializes client.
  void configure({String? clientId}) {
    if (clientId != null && clientId.trim().isNotEmpty) {
      _clientId = clientId.trim();
      _isMissingClientId = false;
      _googleSignIn = GoogleSignIn(
        clientId: _clientId,
        scopes: <String>[
          'email',
          'https://www.googleapis.com/auth/youtube.readonly',
        ],
      );
    }
  }

  /// Initializes authentication listener and attempts silent sign-in.
  Future<void> initialize() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      _googleSignIn.onCurrentUserChanged.listen((
        GoogleSignInAccount? account,
      ) async {
        _currentUser = account;
        if (account != null) {
          _isDemoMode = false;
          _isExplicitGuestMode = false;
          final auth = await account.authentication;
          _accessToken = auth.accessToken;
          debugPrint(
            '[AuthService] User signed in: ${account.email} (${account.displayName})',
          );
        } else if (!_isDemoMode) {
          _accessToken = null;
          debugPrint('[AuthService] User signed out');
        }
        notifyListeners();
      });

      // Attempt silent background restore if previously signed in
      await _googleSignIn.signInSilently().catchError((e) {
        debugPrint('[AuthService] Silent sign-in skipped: $e');
        return null;
      });
    } catch (e) {
      debugPrint('[AuthService] Init error: $e');
    } finally {
      _isInitializing = false;
    }
  }

  /// Triggers the native Google Sign-In interactive modal.
  /// Returns `true` if authentication succeeded, `false` if cancelled or failed.
  Future<bool> signIn() async {
    _lastError = null;
    _isMissingClientId = false;

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('[AuthService] Sign-in cancelled by user');
        return false;
      }

      _currentUser = account;
      _isDemoMode = false;
      _isExplicitGuestMode = false;
      final auth = await account.authentication;
      _accessToken = auth.accessToken;
      notifyListeners();
      return true;
    } catch (e) {
      final err = e.toString();
      _lastError = err;
      if (err.contains('clientId') ||
          err.contains('Missing') ||
          err.contains('channel-error') ||
          err.contains('Unimplemented')) {
        _isMissingClientId = true;
      }
      debugPrint('[AuthService] Sign-in failed: $e');
      return false;
    }
  }

  /// Signs in with an authentic Demo Account for immediate UI testing & verification.
  Future<bool> signInDemo({String? name, String? email}) async {
    _currentUser = null;
    _isDemoMode = true;
    _isExplicitGuestMode = false;
    _demoUserId = 'demo_user_${DateTime.now().millisecondsSinceEpoch}';
    _demoUserName = name ?? 'Charan Teja (Demo)';
    _demoUserEmail = email ?? 'charanteja.demo@gmail.com';
    _demoUserPhotoUrl =
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120';
    _accessToken = 'demo_oauth_token';
    _lastError = null;
    _isMissingClientId = false;
    notifyListeners();
    return true;
  }

  /// Switches active session to Guest Mode without discarding saved account tokens.
  void switchToGuestMode() {
    _isExplicitGuestMode = true;
    notifyListeners();
  }

  /// Re-engages Account Mode from Guest Mode.
  void switchToAccountMode() {
    if (_currentUser != null || _isDemoMode) {
      _isExplicitGuestMode = false;
      notifyListeners();
    }
  }

  /// Signs out of Google account, clearing local session tokens.
  Future<void> signOut() async {
    try {
      if (_currentUser != null) {
        await _googleSignIn.signOut();
      }
      _currentUser = null;
      _isDemoMode = false;
      _isExplicitGuestMode = false;
      _accessToken = null;
      _demoUserId = null;
      _demoUserName = null;
      _demoUserEmail = null;
      _demoUserPhotoUrl = null;
      notifyListeners();
      debugPrint('[AuthService] Successfully signed out');
    } catch (e) {
      debugPrint('[AuthService] Sign-out error: $e');
    }
  }

  /// Returns a fresh valid OAuth 2.0 access token, refreshing if necessary.
  Future<String?> getFreshAccessToken() async {
    if (_isDemoMode) return _accessToken;
    if (_currentUser == null) return null;
    try {
      final auth = await _currentUser!.authentication;
      _accessToken = auth.accessToken;
      return _accessToken;
    } catch (e) {
      debugPrint('[AuthService] Error refreshing access token: $e');
      return _accessToken;
    }
  }
}
