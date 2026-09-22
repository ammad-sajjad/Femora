import 'dart:convert';

import 'package:femora/l10n/lang.dart';
import 'package:femora/main.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/screens/main_shell.dart';
import 'package:femora/screens/onboarding_screen.dart';
import 'package:femora/services/auth_service.dart';
import 'package:femora/widgets/companion_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_auth.dart';

const _uid = 'uid-loc';

/// Seeds the saved profile exactly as [HealthStore] itself would write it, under the signed-in account's
/// own key: the same thing a previous app launch (or Edit my profile) would have left behind.
Map<String, Object> _savedProfile(String language) => {
      'health_store_v1_$_uid': jsonEncode({
        'profile': {'name': '', 'age': null, 'heightCm': null, 'weightKg': null, 'concerns': <String>[], 'language': language, 'personalize': true, 'onboarded': true, 'reportReaderConsent': false},
      }),
    };

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    companionAnimations = false;
  });
  tearDown(() => companionAnimations = true);

  group('the pure helpers', () {
    test('looksUrdu finds Urdu script and ignores plain English', () {
      expect(looksUrdu('میرے پیریڈز بے قاعدہ کیوں ہیں؟'), isTrue);
      expect(looksUrdu('Why are my periods irregular?'), isFalse);
      expect(looksUrdu('PCOS 71%'), isFalse); // digits and an English acronym only
    });

    test('directionOf follows the language code, directionOfText follows the script', () {
      expect(directionOf('ur'), TextDirection.rtl);
      expect(directionOf('en'), TextDirection.ltr);
      expect(directionOfText('نیند'), TextDirection.rtl);
      expect(directionOfText('sleep'), TextDirection.ltr);
    });

    testWidgets('AutoDirection wraps its child in the right direction', (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: AutoDirection(text: 'اردو', child: Text('اردو')),
      ));
      expect(Directionality.of(tester.element(find.text('اردو'))), TextDirection.rtl);
    });
  });

  group('the running app', () {
    Future<void> _launch(WidgetTester tester, {required String language}) async {
      _tallScreen(tester);
      SharedPreferences.setMockInitialValues(_savedProfile(language));
      await tester.pumpWidget(FemoraApp(authService: FakeAuth(signedInAs: const AppUser(id: _uid, email: 'a@example.com', name: 'Ayesha'))));
      await tester.pumpAndSettle();
      expect(find.byType(MainShellScreen), findsOneWidget); // the seeded profile is already onboarded
    }

    testWidgets('an English profile keeps the whole app left to right', (tester) async {
      await _launch(tester, language: 'en');
      expect(Directionality.of(tester.element(find.byType(MainShellScreen))), TextDirection.ltr);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.locale, const Locale('en'));
    });

    testWidgets('an Urdu profile flips the whole app to right to left, including stock dialogs', (tester) async {
      await _launch(tester, language: 'ur');
      expect(Directionality.of(tester.element(find.byType(MainShellScreen))), TextDirection.rtl);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.locale, const Locale('ur'));
      expect(app.supportedLocales, contains(const Locale('ur')));
    });

    testWidgets('saving a language change from Edit my profile flips direction live, without losing the app', (tester) async {
      await _launch(tester, language: 'en');
      expect(Directionality.of(tester.element(find.byType(MainShellScreen))), TextDirection.ltr);

      // Home -> companion tab -> menu -> Edit my profile (the same route a real user takes)
      await tester.tap(find.byIcon(Icons.person_outline_rounded).last); // the bottom nav's companion tab
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('companion_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit my profile'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);

      await tester.tap(find.text('اردو'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(MainShellScreen), findsOneWidget); // back in the app, not restarted
      expect(Directionality.of(tester.element(find.byType(MainShellScreen))), TextDirection.rtl);
    });

    testWidgets('every Text in the tree can fall back to the bundled Urdu font', (tester) async {
      await _launch(tester, language: 'ur');
      final style = DefaultTextStyle.of(tester.element(find.byType(MainShellScreen))).style;
      expect(style.fontFamilyFallback, contains(kUrduFontFamily));
    });
  });
}
