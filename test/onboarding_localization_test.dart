import 'package:femora/models/health_store.dart';
import 'package:femora/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _onboarding(HealthStore store, {bool editing = false}) => ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(home: OnboardingScreen(editing: editing)),
    );

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> _show(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('an Urdu profile opens the whole form in Urdu, right to left', (tester) async {
    _tallScreen(tester);
    final store = HealthStore()..profile = HealthProfile(language: 'ur', onboarded: true);
    await tester.pumpWidget(_onboarding(store, editing: true));

    expect(find.text('میری پروفائل'), findsOneWidget);
    expect(find.text('آپ کے بارے میں'), findsOneWidget);
    expect(find.text('نام (آپ کی رپورٹ پر ظاہر ہوگا)'), findsOneWidget);
    expect(find.text('عمر'), findsOneWidget);
    expect(find.text('قد'), findsOneWidget);
    expect(find.text('وزن'), findsOneWidget);
    expect(find.text('آپ کے لیے کیا اہم ہے؟'), findsOneWidget);
    expect(find.text('PCOS یا بے قاعدہ پیریڈز'), findsOneWidget);
    expect(find.text('بریسٹ کی صحت'), findsOneWidget);
    expect(find.text('زبان'), findsOneWidget);
    expect(find.text('پرائیویسی'), findsOneWidget);
    expect(find.text('AI کمپینین کو ذاتی بنائیں'), findsOneWidget);
    await _show(tester, find.text('محفوظ کریں'));
    expect(find.text('محفوظ کریں'), findsOneWidget); // "Save", in Urdu
    expect(find.text('Save'), findsNothing);

    final root = tester.element(find.byKey(const Key('onboarding_name')));
    expect(Directionality.of(root), TextDirection.rtl);
  });

  testWidgets('the first-launch screen previews Urdu the moment she taps اردو, before Skip or Get started', (tester) async {
    _tallScreen(tester);
    final store = HealthStore();
    await tester.pumpWidget(_onboarding(store));
    expect(find.text('Get started'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byKey(const Key('onboarding_name')))), TextDirection.ltr);

    await _show(tester, find.text('اردو'));
    await tester.tap(find.text('اردو'));
    await tester.pump();

    expect(find.text('شروع کریں'), findsOneWidget);
    expect(find.text('ابھی کے لیے چھوڑیں'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
    expect(find.text('Skip for now'), findsNothing);
    expect(Directionality.of(tester.element(find.byKey(const Key('onboarding_name')))), TextDirection.rtl);
    // nothing is saved yet just from previewing
    expect(store.profile.language, 'en');

    // switching back to English restores the English form, live
    await _show(tester, find.text('English'));
    await tester.tap(find.text('English'));
    await tester.pump();
    expect(find.text('Get started'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byKey(const Key('onboarding_name')))), TextDirection.ltr);
  });

  testWidgets('Skip for now while Urdu is previewed saves the Urdu choice', (tester) async {
    _tallScreen(tester);
    final store = HealthStore();
    await tester.pumpWidget(_onboarding(store));
    await _show(tester, find.text('اردو'));
    await tester.tap(find.text('اردو'));
    await tester.pump();
    await _show(tester, find.text('ابھی کے لیے چھوڑیں'));
    await tester.tap(find.text('ابھی کے لیے چھوڑیں'));
    await tester.pumpAndSettle();
    expect(store.profile.language, 'ur');
    expect(store.profile.onboarded, isTrue);
  });
}
