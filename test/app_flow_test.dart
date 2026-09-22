import 'package:femora/main.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/screens/main_shell.dart';
import 'package:femora/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:femora/widgets/companion_effects.dart';
import 'package:femora/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// Scrolls the (lazily built) form until [target] exists, then makes it fully visible.
Future<void> _show(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Widget _onboarding(HealthStore store, {bool editing = false}) => ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(home: OnboardingScreen(editing: editing)),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // This walks into the companion tab, whose glow and mood animations repeat for ever.
    companionAnimations = false;
  });
  tearDown(() => companionAnimations = true);

  testWidgets('first launch shows the welcome screen, skipping goes to the app, and it is remembered', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(FemoraApp(authService: FakeAuth(signedInAs: const AppUser(id: 'uid-test', email: 'ayesha@example.com', name: 'Ayesha'))));
    await tester.pump(); // load the saved data
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await _show(tester, find.byKey(const Key('onboarding_skip')));
    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();
    expect(find.byType(MainShellScreen), findsOneWidget);

    // next launch: straight into the app
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(FemoraApp(authService: FakeAuth(signedInAs: const AppUser(id: 'uid-test', email: 'ayesha@example.com', name: 'Ayesha'))));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MainShellScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('filling in the profile saves it', (tester) async {
    _tallScreen(tester);
    final store = HealthStore();
    await tester.pumpWidget(_onboarding(store));

    await tester.enterText(find.byKey(const Key('onboarding_name')), '  Ayesha Khan ');
    await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '27');
    await tester.enterText(find.widgetWithText(TextFormField, 'Height'), '162');
    await tester.enterText(find.widgetWithText(TextFormField, 'Weight'), '68.5');
    await _show(tester, find.text('PCOS or irregular periods'));
    await tester.tap(find.text('PCOS or irregular periods'));
    await _show(tester, find.text('Breast health'));
    await tester.tap(find.text('Breast health'));
    await _show(tester, find.text('اردو'));
    await tester.tap(find.text('اردو'));
    await _show(tester, find.byKey(const Key('onboarding_personalize')));
    await tester.tap(find.byKey(const Key('onboarding_personalize'))); // turn personalisation off
    await tester.pump();
    // The form previews the language she just picked, so the button is already in Urdu.
    expect(find.text('Get started'), findsNothing);
    await _show(tester, find.text('شروع کریں'));
    await tester.tap(find.text('شروع کریں'));
    await tester.pumpAndSettle();

    final p = store.profile;
    expect((p.name, p.age, p.heightCm, p.weightKg), ('Ayesha Khan', 27, 162.0, 68.5));
    expect(p.concerns, {'pcos', 'breast'});
    expect(p.language, 'ur');
    expect(p.personalize, isFalse);
    expect(p.onboarded, isTrue);
    expect(p.firstName, 'Ayesha');
  });

  testWidgets('out-of-range numbers are rejected and nothing is saved', (tester) async {
    _tallScreen(tester);
    final store = HealthStore();
    await tester.pumpWidget(_onboarding(store));
    await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '5');
    await _show(tester, find.text('Get started'));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('12–100'), findsOneWidget);
    expect(store.profile.onboarded, isFalse);
  });

  testWidgets('editing an existing profile starts from the saved values', (tester) async {
    _tallScreen(tester);
    final store = HealthStore()..profile = HealthProfile(name: 'Sara', age: 31, heightCm: 158, weightKg: 60, concerns: {'cycle'}, onboarded: true);
    await tester.pumpWidget(_onboarding(store, editing: true));
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    expect(find.text('Skip for now'), findsNothing); // editing has no skip
    expect(find.text('My profile'), findsOneWidget);
  });
}
