import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

/// Who is signed in, and every way of changing that, for the widgets to watch.
///
/// Only the account lives in Firebase. Her results, logs and conversation stay on the phone, kept under
/// this account's own keys, so signing out never sends a woman's health data anywhere.
class AuthState extends ChangeNotifier {
  /// With [accountCheckEvery], the account is re-checked on that interval while signed in, so one
  /// deactivated from the admin panel is signed out within seconds.
  AuthState({required AuthService service, Duration? accountCheckEvery}) : _service = service {
    _user = _service.current;
    _sub = _service.changes().listen((u) {
      _user = u;
      _ready = true;
      notifyListeners();
    });
    if (accountCheckEvery != null) {
      _checkTimer = Timer.periodic(accountCheckEvery, (_) => checkAccount());
    }
  }

  static const deactivatedMessage = 'Your account has been deactivated. Please contact Femora support.';

  final AuthService _service;
  StreamSubscription<AppUser?>? _sub;
  Timer? _checkTimer;
  bool _checking = false;

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

  /// Good news worth showing, such as "check your inbox to confirm your email".
  String? _notice;
  String? get notice => _notice;

  /// Set while a code has been sent and she is expected to type it.
  String? _codeEmail;
  bool get awaitingCode => _codeEmail != null;

  void clearError() {
    if (_error == null && _notice == null) return;
    _error = null;
    _notice = null;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    _notice = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on VerifyEmailNotice catch (e) {
      _notice = e.message;
      return false;
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

  Future<bool> sendCode(String email) => _run(() async {
        await _service.sendEmailCode(email);
        _codeEmail = email;
      });

  Future<bool> confirmCode(String code) => _run(() async {
        final email = _codeEmail;
        if (email == null) throw AuthException('Please ask for a code first.');
        await _service.confirmEmailCode(email: email, code: code);
        _codeEmail = null;
      });

  void cancelCode() {
    _codeEmail = null;
    _error = null;
    notifyListeners();
  }

  Future<bool> signOut() => _run(() => _service.signOut());

  /// Signs her out, with a message saying why, if the account has been deactivated or deleted.
  Future<void> checkAccount() async {
    if (_user == null || _checking) return;
    _checking = true;
    try {
      if (await _service.stillActive()) return;
      await _service.signOut();
      _user = null;
      _codeEmail = null;
      _notice = null;
      _error = deactivatedMessage;
      notifyListeners();
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
