import 'package:femora/models/auth_state.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/screens/auth_screen.dart';
import 'package:femora/widgets/companion_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_auth.dart';

Widget _screen(FakeAuth auth) => ChangeNotifierProvider(
      create: (_) => AuthState(service: auth),
      child: const MaterialApp(home: AuthScreen()),
    );

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    companionAnimations = false; // the glow ring on the logo repeats for ever
  });
  tearDown(() => companionAnimations = true);

  testWidgets('signing in sends the email and password she typed', (tester) async {
    _tallScreen(tester);
    final auth = FakeAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(_screen(auth));

    await tester.enterText(find.byKey(const Key('auth_email')), 'ayesha@example.com');
    await tester.enterText(find.byKey(const Key('auth_password')), 'secret123');
    await tester.tap(find.byKey(const Key('auth_submit')));
    await tester.pumpAndSettle();

    expect(auth.calls, contains('signInWithEmail:ayesha@example.com'));
    expect(auth.current?.email, 'ayesha@example.com');
  });

  testWidgets('a short password is refused before anything is sent', (tester) async {
    _tallScreen(tester);
    final auth = FakeAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(_screen(auth));

    await tester.enterText(find.byKey(const Key('auth_email')), 'ayesha@example.com');
    await tester.enterText(find.byKey(const Key('auth_password')), '123');
    await tester.tap(find.byKey(const Key('auth_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Use at least six characters.'), findsOneWidget);
    expect(auth.calls, isEmpty); // nothing left the phone
  });

  testWidgets('registering asks for her name as well', (tester) async {
    _tallScreen(tester);
    final auth = FakeAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(_screen(auth));

    await tester.tap(find.byKey(const Key('auth_toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth_name')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('auth_name')), 'Ayesha');
    await tester.enterText(find.byKey(const Key('auth_email')), 'new@example.com');
    await tester.enterText(find.byKey(const Key('auth_password')), 'secret123');
    await tester.tap(find.byKey(const Key('auth_submit')));
    await tester.pumpAndSettle();

    expect(auth.calls, contains('registerWithEmail:new@example.com:Ayesha'));
  });

  testWidgets('a refused sign-in is explained in plain words and she can try again', (tester) async {
    _tallScreen(tester);
    final auth = FakeAuth()..failWith = 'That email or password is not correct.';
    addTearDown(auth.dispose);
    await tester.pumpWidget(_screen(auth));

    await tester.enterText(find.byKey(const Key('auth_email')), 'ayesha@example.com');
    await tester.enterText(find.byKey(const Key('auth_password')), 'wrongpass');
    await tester.tap(find.byKey(const Key('auth_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_error')), findsOneWidget);
    expect(find.text('That email or password is not correct.'), findsOneWidget);
    expect(auth.current, isNull);

    auth.failWith = null;
    await tester.tap(find.byKey(const Key('auth_submit')));
    await tester.pumpAndSettle();
    expect(auth.current?.email, 'ayesha@example.com');
  });

  testWidgets('she can look around without giving any details', (tester) async {
    _tallScreen(tester);
    final auth = FakeAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(_screen(auth));

    await tester.tap(find.byKey(const Key('auth_guest')));
    await tester.pumpAndSettle();

    expect(auth.calls, contains('continueAsGuest'));
    expect(auth.current?.isGuest, isTrue);
  });

  testWidgets('phone sign-in sends a code, then confirms it', (tester) async {
    _tallScreen(tester);
    final auth = FakeAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(_screen(auth));

    await tester.tap(find.byKey(const Key('auth_phone')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('auth_phone_number')), '+923001234567');
    await tester.tap(find.byKey(const Key('auth_phone_submit')));
    await tester.pumpAndSettle();
    expect(auth.calls, contains('startPhoneSignIn:+923001234567'));

    await tester.enterText(find.byKey(const Key('auth_sms_code')), '123456');
    await tester.tap(find.byKey(const Key('auth_phone_submit')));
    await tester.pumpAndSettle();
    expect(auth.calls, contains('confirmPhoneCode:123456'));
    expect(auth.current?.phone, '+923001234567');
  });

  testWidgets('two accounts on one phone never see each other\'s results', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final first = HealthStore();
    await first.useAccount('uid-one');
    first.profile = HealthProfile(name: 'Ayesha', age: 27, onboarded: true);
    await first.saveProfile(first.profile);

    final second = HealthStore();
    await second.useAccount('uid-two');
    expect(second.profile.name, isEmpty);
    expect(second.profile.onboarded, isFalse);

    // Going back to the first account brings her own profile back.
    final again = HealthStore();
    await again.useAccount('uid-one');
    expect(again.profile.name, 'Ayesha');
  });
}
