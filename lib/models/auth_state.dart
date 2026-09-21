import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

/// Who is signed in, and every way of changing that, for the widgets to watch.
///
/// Only the account lives in Firebase. Her results, logs and conversation stay on the phone, kept under
/// this account's own keys, so signing out never sends a woman's health data anywhere.
class AuthState extends ChangeNotifier {
  AuthState({required AuthService service}) : _service = service {
    _user = _service.current;
    _sub = _service.changes().listen((u) {
      _user = u;
      _ready = true;
      notifyListeners();
    });
  }

  final AuthService _service;
  StreamSubscription<AppUser?>? _sub;

  AppUser? _user;
  AppUser? get user => _user;
  bool get signedIn => _user != null;

  /// False until the first answer arrives from the sign-in service, so the app can hold on a splash
  /// instead of flashing the sign-in screen at someone who is already signed in.
  bool _ready = false;
  bool get ready => _ready;

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  /// Set while a code has been sent and she is expected to type it.
  String? _verificationId;
  bool get awaitingCode => _verificationId != null;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) =>
      _run(() => _service.signInWithEmail(email: email, password: password));

  Future<bool> register(String name, String email, String password) =>
      _run(() => _service.registerWithEmail(email: email, password: password, name: name));

  Future<bool> resetPassword(String email) => _run(() => _service.sendPasswordReset(email));

  Future<bool> signInWithGoogle() => _run(() => _service.signInWithGoogle());

  Future<bool> continueAsGuest() => _run(() => _service.continueAsGuest());

  Future<bool> sendCode(String phoneNumber) => _run(() async {
        _verificationId = await _service.startPhoneSignIn(phoneNumber);
      });

  Future<bool> confirmCode(String code) => _run(() async {
        final id = _verificationId;
        if (id == null) throw AuthException('Please ask for a code first.');
        await _service.confirmPhoneCode(verificationId: id, code: code);
        _verificationId = null;
      });

  void cancelCode() {
    _verificationId = null;
    _error = null;
    notifyListeners();
  }

  Future<bool> signOut() => _run(() => _service.signOut());

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
