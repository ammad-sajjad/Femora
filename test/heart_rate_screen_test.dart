import 'dart:math' as math;

import 'package:femora/models/health_store.dart';
import 'package:femora/models/pulse.dart';
import 'package:femora/screens/heart_rate_screen.dart';
import 'package:femora/services/pulse_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Replays a synthetic fingertip recording when started, as the camera would deliver it.
class FakePulse implements PulseSource {
  final int bpm;
  final bool finger;
  final String? error;
  bool stopped = false;
  FakePulse({this.bpm = 68, this.finger = true, this.error});

  @override
  bool get isSupported => true;

  @override
  Future<String?> start(void Function(PulseSample) onSample) async {
    if (error != null) return error;
    for (var i = 0; i < 25 * 30; i++) {
      final t = i / 30;
      final phase = 2 * math.pi * bpm / 60 * t;
      onSample(PulseSample(t, 180 - 2.5 * (math.sin(phase) + 0.35 * math.sin(2 * phase + 0.6)), finger ? 40 : 170));
    }
    return null;
  }

  @override
  Future<void> stop() async => stopped = true;
}

final _now = DateTime(2026, 9, 20, 7, 30);

Widget _app(HealthStore store, PulseSource source) => ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(home: HeartRateScreen(source: source, duration: const Duration(seconds: 2))),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a measurement shows the rate, and saving keeps it as a resting reading', (tester) async {
    final store = HealthStore()..now = (() => _now);
    final source = FakePulse(bpm: 68);
    await tester.pumpWidget(_app(store, source));
    expect(find.byKey(const Key('heart_empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('heart_start')));
    await tester.pump();
    expect(find.byKey(const Key('heart_hint')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final bpm = int.parse(tester.widget<Text>(find.byKey(const Key('heart_result'))).data!);
    expect((bpm - 68).abs(), lessThanOrEqualTo(3));
    expect(source.stopped, isTrue); // the torch is switched off

    await tester.tap(find.byKey(const Key('heart_save')));
    await tester.pumpAndSettle();
    expect(store.heartReadings.single.bpm, bpm);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byKey(const Key('heart_usual')), findsOneWidget);
  });

  testWidgets('without a fingertip over the lens it asks her to try again instead of guessing', (tester) async {
    final store = HealthStore()..now = (() => _now);
    await tester.pumpWidget(_app(store, FakePulse(finger: false)));
    await tester.tap(find.byKey(const Key('heart_start')));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('heart_failed')), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(store.heartReadings, isEmpty);
  });

  testWidgets('a camera problem is explained', (tester) async {
    final store = HealthStore()..now = (() => _now);
    await tester.pumpWidget(_app(store, FakePulse(error: 'Femora needs the camera to read your pulse.')));
    await tester.tap(find.byKey(const Key('heart_start')));
    await tester.pumpAndSettle();
    expect(find.text('Femora needs the camera to read your pulse.'), findsOneWidget);
  });

  test('readings are saved with the rest of her data and cleared with it', () async {
    final store = HealthStore()..now = (() => _now);
    await store.addHeartReading(HeartReading(date: _now, bpm: 64, resting: true));
    final again = HealthStore();
    await again.load();
    expect(again.heartReadings.single.bpm, 64);
    await again.clearAll();
    expect(again.heartReadings, isEmpty);
  });
}
