import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

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

  /// Sends the code and returns the id needed to confirm it. [onAutoVerified] fires when Android
  /// reads the SMS by itself, which it often does in Pakistan, and then no code has to be typed.
  Future<String> startPhoneSignIn(String phoneNumber, {void Function(AppUser user)? onAutoVerified});

  Future<AppUser> confirmPhoneCode({required String verificationId, required String code});

  Future<void> signOut();
}

/// Raised for every failure, already worded for a woman rather than a developer.
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
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

  AppUser? _wrap(fb.User? u) => u == null
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
        return 'This way of signing in is not enabled for the app yet.';
      default:
        return 'Could not sign in (${e.code}). Please try again.';
    }
  }

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) =>
      _guard(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<AppUser> registerWithEmail({required String email, required String password, required String name}) async {
    final user = await _guard(() => _auth.createUserWithEmailAndPassword(email: email.trim(), password: password));
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      await _auth.currentUser?.updateDisplayName(trimmed);
      await _auth.currentUser?.reload();
    }
    return AppUser(id: user.id, email: user.email, name: trimmed.isEmpty ? user.name : trimmed);
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
  Future<String> startPhoneSignIn(String phoneNumber, {void Function(AppUser user)? onAutoVerified}) async {
    final sent = Completer<String>();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber.trim(),
        verificationCompleted: (credential) async {
          // Android can read the SMS itself; if it does, she never types the code.
          final result = await _auth.signInWithCredential(credential);
          final user = _wrap(result.user);
          if (user != null) onAutoVerified?.call(user);
        },
        verificationFailed: (e) {
          if (!sent.isCompleted) sent.completeError(AuthException(_message(e)));
        },
        codeSent: (verificationId, _) {
          if (!sent.isCompleted) sent.complete(verificationId);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!sent.isCompleted) sent.complete(verificationId);
        },
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
    return sent.future;
  }

  @override
  Future<AppUser> confirmPhoneCode({required String verificationId, required String code}) {
    final credential = fb.PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code.trim());
    return _guard(() => _auth.signInWithCredential(credential));
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
  Future<String> startPhoneSignIn(String phoneNumber, {void Function(AppUser user)? onAutoVerified}) async {
    final user = AppUser(id: 'phone_web_user', phone: phoneNumber.trim());
    onAutoVerified?.call(user);
    return 'demo_verification_id';
  }

  @override
  Future<AppUser> confirmPhoneCode({required String verificationId, required String code}) async {
    _user = const AppUser(id: 'phone_web_user', phone: '+923001234567');
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }
}

