import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Who is signed in, in the app's own terms.
///
/// The rest of Femora never sees a Firebase type: [id] is what the on-device store is keyed by, so her
/// results follow her account on this phone and nobody else's account can read them.
class AppUser {
  const AppUser({required this.id, this.email, this.name, this.phone, this.isGuest = false});

  final String id;
  final String? email;
  final String? name;
  final String? phone;

  /// Signed in anonymously: she is trying the app without giving any details yet.
  final bool isGuest;

  /// What to call her before the profile has a name.
  String get label => name?.trim().isNotEmpty == true ? name!.trim() : (email ?? phone ?? 'Guest');
}

/// Anything that can sign a woman in. Behind an interface so widget tests run without Firebase.
abstract class AuthService {
  /// Fires on sign-in, sign-out and account linking. Emits the current value first.
  Stream<AppUser?> changes();

  AppUser? get current;

  Future<AppUser> signInWithEmail({required String email, required String password});

  Future<AppUser> registerWithEmail({required String email, required String password, required String name});

  Future<void> sendPasswordReset(String email);

  Future<AppUser> signInWithGoogle();

  /// Anonymous sign-in, so she can look around before deciding to register.
  Future<AppUser> continueAsGuest();

  /// Emails her a 6-digit sign-in code. Replaces SMS codes, which Firebase only sends on its paid plan.
  Future<void> sendEmailCode(String email);

  Future<AppUser> confirmEmailCode({required String email, required String code});

  Future<void> signOut();

  /// False once the account has been deactivated or deleted (e.g. from the admin panel). A failed network
  /// check counts as still active, so a bad connection never signs her out.
  Future<bool> stillActive();
}

/// Raised for every failure, already worded for a woman rather than a developer.
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Not a failure: the account exists but its email must be confirmed first. Shown as a notice, not an error.
class VerifyEmailNotice extends AuthException {
  VerifyEmailNotice(super.message);
}

/// The real implementation, on Firebase Authentication.
///
/// Firebase was chosen because Femora's backend is a laptop behind a temporary tunnel: sign-in has to keep
/// working when that machine is off, and no one here should be storing passwords. Only the account lives in
/// Firebase; every health result stays on the phone.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({fb.FirebaseAuth? auth}) : _auth = auth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _auth;
  bool _googleReady = false;

  /// A password account whose email was never confirmed. It is treated as signed out, so a made-up
  /// address cannot get into the app. Google and email-code accounts are confirmed by their sign-in.
  static bool _unverified(fb.User u) =>
      !u.isAnonymous && !u.emailVerified && u.providerData.any((p) => p.providerId == 'password');

  AppUser? _wrap(fb.User? u) => u == null || _unverified(u)
      ? null
      : AppUser(
          id: u.uid,
          email: u.email,
          name: u.displayName,
          phone: u.phoneNumber,
          isGuest: u.isAnonymous,
        );

  @override
  Stream<AppUser?> changes() => _auth.userChanges().map(_wrap);

  @override
  AppUser? get current => _wrap(_auth.currentUser);

  /// Runs [action] and turns Firebase's error codes into something worth reading on a phone.
  Future<AppUser> _guard(Future<fb.UserCredential> Function() action) async {
    try {
      final credential = await action();
      final user = _wrap(credential.user);
      if (user == null) throw AuthException('Could not sign in. Please try again.');
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException('Could not reach the sign-in service. Please check your connection.');
    }
  }

  String _message(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address does not look right.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'That email or password is not correct.';
      case 'email-already-in-use':
        return 'An account already exists for that email. Please sign in instead.';
      case 'weak-password':
        return 'Please choose a password of at least six characters.';
      case 'network-request-failed':
        return 'No connection. Please check your internet and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'invalid-verification-code':
        return 'That code is not correct. Please check the message and try again.';
      case 'invalid-phone-number':
        return 'That phone number does not look right. Include the country code, like +92.';
      case 'operation-not-allowed':
        return 'Phone or Google sign-in is not enabled in Firebase Console yet.';
      case 'billing-not-enabled':
      case 'quota-exceeded':
        return 'Text-message codes are not available right now. Please sign in with email or Google instead.';
      default:
        final msg = e.message?.trim();
        if (msg != null && msg.isNotEmpty) {
          return 'Could not sign in: $msg';
        }
        return 'Could not sign in (${e.code}). Please try again.';
    }
  }

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      final u = credential.user;
      if (u == null) throw AuthException('Could not sign in. Please try again.');
      if (_unverified(u)) {
        await u.reload();
        final fresh = _auth.currentUser ?? u;
        if (_unverified(fresh)) {
          try {
            await fresh.sendEmailVerification();
          } catch (_) {} // too many requests: the earlier link still works
          await _auth.signOut();
          throw VerifyEmailNotice('Please confirm your email first. We have sent a link to ${email.trim()}: '
              'open it, then sign in again. Check your spam folder if you do not see it.');
        }
        return _wrap(fresh)!;
      }
      return _wrap(u)!;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  @override
  Future<AppUser> registerWithEmail({required String email, required String password, required String name}) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
    final trimmed = name.trim();
    final created = _auth.currentUser;
    if (trimmed.isNotEmpty) await created?.updateDisplayName(trimmed);
    try {
      await created?.sendEmailVerification();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
    // Stay signed out until the link is opened, so an address nobody owns never gets in.
    await _auth.signOut();
    throw VerifyEmailNotice('Account created. We have sent a confirmation link to ${email.trim()}. '
        'Open it, then sign in. Check your spam folder if you do not see it.');
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize();
        _googleReady = true;
      }
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw AuthException('Google sign-in is not available on this device.');
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw AuthException('Google did not return a sign-in token. Please try again.');
      final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
      return await _guard(() => _auth.signInWithCredential(credential));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw AuthException('Google sign-in was cancelled.');
      }
      throw AuthException('Google sign-in did not work. Please try another way.');
    }
  }

  @override
  Future<AppUser> continueAsGuest() => _guard(() => _auth.signInAnonymously());

  @override
  Future<void> sendEmailCode(String email) async {
    await _postToServer('/auth/email/start', {'email': email.trim()});
  }

  @override
  Future<AppUser> confirmEmailCode({required String email, required String code}) async {
    final body = await _postToServer('/auth/email/verify', {'email': email.trim(), 'code': code.trim()});
    final token = body['token'];
    if (token is! String) throw AuthException('Could not sign in. Please ask for a new code.');
    return _guard(() => _auth.signInWithCustomToken(token));
  }

  /// The email code lives on the Femora server, which emails it and swaps a correct code for a Firebase token.
  Future<Map<String, dynamic>> _postToServer(String path, Map<String, String> body) async {
    final http.Response r;
    try {
      r = await http
          .post(Uri.parse('${ApiService.baseUrl}$path'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw AuthException('No connection. Please check your internet and try again.');
    }
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    if (r.statusCode != 200) {
      final detail = data['detail'];
      throw AuthException(detail is String ? detail : 'That email address does not look right.');
    }
    return data;
  }

  @override
  Future<bool> stillActive() async {
    final u = _auth.currentUser;
    if (u == null) return true;
    try {
      await u.reload();
      return true;
    } on fb.FirebaseAuthException catch (e) {
      return !const {'user-disabled', 'user-not-found', 'user-token-expired', 'invalid-user-token'}.contains(e.code);
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> signOut() async {
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Signing out of Google is a courtesy; failing it must not trap her in the app.
      }
    }
    await _auth.signOut();
  }
}

/// In-memory auth service used on platforms where Firebase is not configured (e.g. Web).
class GuestAuthService implements AuthService {
  GuestAuthService({AppUser? initialUser})
      : _user = initialUser ?? const AppUser(id: 'web_guest', name: 'Ayesha', isGuest: true) {
    _controller.add(_user);
  }

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  @override
  Stream<AppUser?> changes() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  AppUser? get current => _user;

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    _user = AppUser(id: 'user_${email.hashCode.abs()}', email: email, name: email.split('@').first);
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AppUser> registerWithEmail({required String email, required String password, required String name}) async {
    _user = AppUser(id: 'user_${email.hashCode.abs()}', email: email, name: name.trim().isEmpty ? email.split('@').first : name.trim());
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<AppUser> signInWithGoogle() async {
    _user = const AppUser(id: 'google_web_user', email: 'ayesha@gmail.com', name: 'Ayesha');
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AppUser> continueAsGuest() async {
    _user = const AppUser(id: 'web_guest', name: 'Guest', isGuest: true);
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<void> sendEmailCode(String email) async {}

  @override
  Future<AppUser> confirmEmailCode({required String email, required String code}) async {
    _user = AppUser(id: 'user_${email.hashCode.abs()}', email: email, name: email.split('@').first);
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<bool> stillActive() async => true;

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }
}

