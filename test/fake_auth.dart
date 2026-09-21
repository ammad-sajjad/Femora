import 'dart:async';

import 'package:femora/services/auth_service.dart';

/// A sign-in service that answers from memory, so widget tests never need a Firebase app.
///
/// Start it with [signedInAs] to skip straight past the sign-in screen, or leave it empty to test the
/// screen itself. Set [failWith] to make the next attempt fail the way Firebase would.
class FakeAuth implements AuthService {
  FakeAuth({AppUser? signedInAs}) : _user = signedInAs {
    _controller.add(_user);
  }

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  /// The message the next sign-in attempt should fail with, or null to succeed.
  String? failWith;

  /// Every call made, so a test can check what was attempted.
  final calls = <String>[];

  AppUser _succeed(AppUser user) {
    _user = user;
    _controller.add(user);
    return user;
  }

  Never _fail() => throw AuthException(failWith!);

  @override
  Stream<AppUser?> changes() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  AppUser? get current => _user;

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    calls.add('signInWithEmail:$email');
    if (failWith != null) _fail();
    return _succeed(AppUser(id: 'uid-${email.hashCode}', email: email, name: 'Ayesha'));
  }

  @override
  Future<AppUser> registerWithEmail({required String email, required String password, required String name}) async {
    calls.add('registerWithEmail:$email:$name');
    if (failWith != null) _fail();
    return _succeed(AppUser(id: 'uid-${email.hashCode}', email: email, name: name));
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    calls.add('sendPasswordReset:$email');
    if (failWith != null) _fail();
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    calls.add('signInWithGoogle');
    if (failWith != null) _fail();
    return _succeed(const AppUser(id: 'uid-google', email: 'ayesha@gmail.com', name: 'Ayesha'));
  }

  @override
  Future<AppUser> continueAsGuest() async {
    calls.add('continueAsGuest');
    if (failWith != null) _fail();
    return _succeed(const AppUser(id: 'uid-guest', isGuest: true));
  }

  @override
  Future<String> startPhoneSignIn(String phoneNumber, {void Function(AppUser user)? onAutoVerified}) async {
    calls.add('startPhoneSignIn:$phoneNumber');
    if (failWith != null) _fail();
    return 'verification-id';
  }

  @override
  Future<AppUser> confirmPhoneCode({required String verificationId, required String code}) async {
    calls.add('confirmPhoneCode:$code');
    if (failWith != null) _fail();
    return _succeed(const AppUser(id: 'uid-phone', phone: '+923001234567'));
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _user = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
