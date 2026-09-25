import 'package:femora/models/auth_state.dart';
import 'package:femora/models/chat_state.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/models/models.dart';
import 'package:femora/models/reminders.dart';
import 'package:femora/models/self_exam.dart';
import 'package:femora/screens/home_dashboard_screen.dart';
import 'package:femora/services/auth_service.dart';
import 'package:femora/widgets/profile_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_auth.dart';
import 'fake_reminders.dart';

final _now = DateTime(2026, 9, 20, 9, 30);

Future<(HealthStore, FakeAuth)> _open(WidgetTester tester, {AppUser? user}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final store = HealthStore()
    ..now = (() => _now)
    ..profile = HealthProfile(name: 'Ayesha Khan', age: 27, heightCm: 162, weightKg: 68, onboarded: true);
  final fake = FakeAuth(signedInAs: user);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: AppState()..now = (() => _now)),
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider.value(value: SelfExamState(reminders: Recorder())),
      ChangeNotifierProvider.value(value: ChatState()),
      ChangeNotifierProvider.value(value: AuthState(service: fake)),
      ChangeNotifierProvider.value(value: RemindersState(service: Recorder())),
    ],
    child: const MaterialApp(home: HomeDashboardScreen()),
  ));
  await tester.pumpAndSettle();
  return (store, fake);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('initials, never a stock photo', () {
    expect(ProfileAvatar.initials('Ayesha Khan'), 'AK');
    expect(ProfileAvatar.initials('  ayesha  '), 'A');
    expect(ProfileAvatar.initials(''), '');
    expect(ProfileAvatar.initials('عائشہ خان'), 'عخ');
  });

  testWidgets('tapping the avatar opens the panel with her name, account and details', (tester) async {
    await _open(tester, user: const AppUser(id: 'u1', email: 'ayesha@example.com'));
    expect(find.text('AK'), findsOneWidget);
    await tester.tap(find.byKey(const Key('header_avatar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_panel')), findsOneWidget);
    expect(find.byKey(const Key('profile_name')), findsOneWidget);
    expect(find.text('ayesha@example.com'), findsOneWidget);
    expect(find.text('27 years  ·  BMI 25.9'), findsOneWidget);
    for (final k in ['profile_edit', 'profile_dashboard', 'profile_doctor', 'profile_report', 'profile_heart', 'profile_reminders', 'profile_delete', 'profile_sign_out']) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
  });

  testWidgets('the language can be switched from the panel', (tester) async {
    final (store, _) = await _open(tester);
    await tester.tap(find.byKey(const Key('header_avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();
    expect(store.profile.language, 'ur');
    expect(find.text('پروفائل میں ترمیم'), findsOneWidget);
  });

  testWidgets('a link opens its screen and closes the panel', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('header_avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_doctor')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_panel')), findsNothing);
    expect(find.text('Show my doctor'), findsOneWidget);
  });

  testWidgets('sign out signs out', (tester) async {
    final (_, fake) = await _open(tester, user: const AppUser(id: 'u1', email: 'a@b.c'));
    await tester.tap(find.byKey(const Key('header_avatar')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('profile_sign_out')));
    await tester.tap(find.byKey(const Key('profile_sign_out')));
    await tester.pumpAndSettle();
    expect(fake.current, isNull);
  });

  testWidgets('delete all my data asks first, then clears everything', (tester) async {
    final (store, _) = await _open(tester);
    await tester.tap(find.byKey(const Key('header_avatar')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('profile_delete')));
    await tester.tap(find.byKey(const Key('profile_delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete everything?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile_delete_confirm')));
    await tester.pumpAndSettle();
    expect(store.profile.name, isEmpty);
  });

  testWidgets('the bell opens the reminders', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('header_reminders')));
    await tester.pumpAndSettle();
    expect(find.text('Reminders'), findsWidgets);
  });
}
