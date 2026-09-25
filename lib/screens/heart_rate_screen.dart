import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/cycle_engine.dart';
import '../models/health_store.dart';
import '../models/pulse.dart';
import '../services/pulse_camera.dart';
import '../theme/app_theme.dart';

enum _Stage { intro, measuring, result, failed }

/// Morning heart rate check: fingertip over the rear camera and flash for about 25 seconds.
class HeartRateScreen extends StatefulWidget {
  final PulseSource? source; // injectable for tests
  final Duration duration;

  const HeartRateScreen({super.key, this.source, this.duration = const Duration(seconds: 25)});

  @override
  State<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends State<HeartRateScreen> with SingleTickerProviderStateMixin {
  late final PulseSource _source = widget.source ?? CameraPulseSource();
  late final _beat = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  final _samples = <PulseSample>[];
  _Stage _stage = _Stage.intro;
  String? _error;
  PulseResult? _result;
  bool _resting = true;
  bool _saved = false;
  double _elapsed = 0;
  bool _fingerOk = true;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _beat.dispose();
    _source.stop();
    super.dispose();
  }

  Future<void> _start() async {
    _samples.clear();
    setState(() {
      _stage = _Stage.measuring;
      _error = null;
      _elapsed = 0;
      _saved = false;
    });
    final error = await _source.start((s) {
      _samples.add(s);
    });
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _stage = _Stage.failed;
        _error = error;
      });
      return;
    }
    final total = widget.duration.inMilliseconds / 1000;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) return;
      final recent = _samples.length > 15 ? _samples.sublist(_samples.length - 15) : _samples;
      setState(() {
        _elapsed += 0.1;
        _fingerOk = recent.isEmpty || recent.where(PulseAnalyzer.fingerCovering).length >= recent.length * 0.7;
      });
      if (_elapsed >= total) {
        t.cancel();
        _finish();
      }
    });
    _beat.repeat();
  }

  Future<void> _finish() async {
    _beat.stop();
    await _source.stop();
    final r = PulseAnalyzer.analyze(_samples);
    if (!mounted) return;
    final hour = DateTime.now().hour;
    setState(() {
      _result = r;
      _resting = hour < 11; // a morning reading is most likely the resting kind; she can change it
      _stage = r == null ? _Stage.failed : _Stage.result;
      _error = r == null ? null : _error;
    });
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    _beat.stop();
    await _source.stop();
    if (mounted) setState(() => _stage = _Stage.intro);
  }

  Future<void> _save() async {
    final store = context.read<HealthStore>();
    await store.addHeartReading(HeartReading(date: store.now(), bpm: _result!.bpm, resting: _resting));
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final language = store.profile.language;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: Text(t(language, 'Heart rate check', 'دل کی دھڑکن کا چیک'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          _mainCard(language),
          const SizedBox(height: 16),
          _insights(store, language),
          const SizedBox(height: 14),
          Text(
            t(language,
                'A wellness check, not a medical device. It cannot detect heart rhythm problems. If you feel your heart racing, '
                    'fluttering or skipping, or you are short of breath or faint, see a doctor.',
                'یہ صحت کا عمومی چیک ہے، طبی آلہ نہیں۔ یہ دل کی دھڑکن کی بے ترتیبی نہیں پکڑ سکتا۔ اگر دل بہت تیز یا بے ترتیب دھڑکے، '
                    'سانس پھولے یا بے ہوشی محسوس ہو تو ڈاکٹر سے ملیں۔'),
            style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.softShadow),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      );

  Widget _heart(double size) => AnimatedBuilder(
        animation: _beat,
        builder: (context, _) {
          // a double "lub-dub" beat
          final v = _beat.value;
          final pulse = math.max(0.0, math.sin(v * math.pi * 4)) * (v < 0.5 ? 1 : 0);
          return Transform.scale(scale: 1 + 0.12 * pulse, child: Icon(Icons.favorite_rounded, size: size, color: const Color(0xFFE0457B)));
        },
      );

  Widget _mainCard(String language) {
    switch (_stage) {
      case _Stage.intro:
        return _card(
          child: Column(
            children: [
              _heart(64),
              const SizedBox(height: 10),
              Text(t(language, 'Measure your pulse with your phone', 'اپنے فون سے نبض ناپیں'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 12),
              for (final (i, step) in [
                t(language, 'Sit or lie still. Best in the morning, before getting up.', 'ساکت بیٹھیں یا لیٹیں۔ صبح اٹھنے سے پہلے بہترین ہے۔'),
                t(language, 'Gently cover the back camera and the flash with a fingertip.', 'انگلی کے سرے سے پچھلا کیمرہ اور فلیش ہلکے سے ڈھانپیں۔'),
                t(language, 'Hold still for about 25 seconds. The flash will feel warm.', 'تقریباً 25 سیکنڈ ساکت رہیں۔ فلیش گرم محسوس ہو گی۔'),
              ].indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                          radius: 11,
                          backgroundColor: const Color(0xFFFFE1EA),
                          child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryBerry))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(step, style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: AppColors.textDark, height: 1.35))),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('heart_start'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBerry, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _source.isSupported ? _start : null,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: Text(t(language, 'Start', 'شروع کریں')),
                ),
              ),
              if (!_source.isSupported)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(t(language, 'This needs the phone app (a camera with a flash).', 'اس کے لیے فون ایپ (فلیش والا کیمرہ) درکار ہے۔'),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textMuted)),
                ),
            ],
          ),
        );
      case _Stage.measuring:
        final total = widget.duration.inMilliseconds / 1000;
        final live = _samples.length > 60 ? PulseAnalyzer.analyze(_samples) : null;
        return _card(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _heart(40),
                  const SizedBox(width: 10),
                  Text(live == null ? '--' : '${live.bpm}',
                      key: const Key('heart_live'),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  const SizedBox(width: 4),
                  const Text('bpm', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(height: 80, width: double.infinity, child: CustomPaint(painter: _WavePainter(PulseAnalyzer.wave(_samples.length > 150 ? _samples.sublist(_samples.length - 150) : _samples)))),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: (_elapsed / total).clamp(0, 1), minHeight: 6, backgroundColor: const Color(0xFFF3E5EB), color: AppColors.primaryBerry),
              ),
              const SizedBox(height: 10),
              Text(
                _fingerOk
                    ? t(language, 'Keep still… ${(total - _elapsed).clamp(0, total).ceil()} s', 'ساکت رہیں… ${(total - _elapsed).clamp(0, total).ceil()} سیکنڈ')
                    : t(language, 'Cover the camera and flash fully with your fingertip', 'انگلی سے کیمرہ اور فلیش پوری طرح ڈھانپیں'),
                key: const Key('heart_hint'),
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _fingerOk ? AppColors.textMuted : AppColors.accentPink),
              ),
              TextButton(onPressed: _cancel, child: Text(t(language, 'Cancel', 'منسوخ'))),
            ],
          ),
        );
      case _Stage.failed:
        return _card(
          child: Column(
            children: [
              const Icon(Icons.touch_app_outlined, size: 48, color: AppColors.accentPink),
              const SizedBox(height: 10),
              Text(
                _error ??
                    t(language, 'The pulse was not clear enough to measure. Press your fingertip gently (not hard) over both the camera and the flash, and keep very still.',
                        'نبض واضح نہیں تھی۔ انگلی کا سرا کیمرہ اور فلیش دونوں پر ہلکے سے (زور سے نہیں) رکھیں اور بالکل ساکت رہیں۔'),
                key: const Key('heart_failed'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: AppColors.textDark, height: 1.4),
              ),
              const SizedBox(height: 12),
              FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBerry), onPressed: _start, child: Text(t(language, 'Try again', 'دوبارہ کوشش کریں'))),
            ],
          ),
        );
      case _Stage.result:
        final r = _result!;
        return _card(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${r.bpm}',
                      key: const Key('heart_result'),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 56, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1)),
                  const Padding(padding: EdgeInsets.only(bottom: 8, left: 6), child: Text('bpm', style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: AppColors.textMuted))),
                ],
              ),
              const SizedBox(height: 6),
              Text(_band(r.bpm, language), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: AppColors.textDark, height: 1.4)),
              const SizedBox(height: 10),
              SwitchListTile(
                key: const Key('heart_resting'),
                contentPadding: EdgeInsets.zero,
                value: _resting,
                onChanged: _saved ? null : (v) => setState(() => _resting = v),
                title: Text(t(language, 'Taken after waking, before getting up', 'جاگنے کے بعد، اٹھنے سے پہلے لیا گیا'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: Text(t(language, 'Only these resting readings are compared across your cycle', 'صرف یہی آرام کی ریڈنگز سائیکل میں موازنہ ہوتی ہیں'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _start, child: Text(t(language, 'Measure again', 'دوبارہ ناپیں')))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('heart_save'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBerry),
                      onPressed: _saved ? null : _save,
                      child: Text(_saved ? t(language, 'Saved', 'محفوظ') : t(language, 'Save', 'محفوظ کریں')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }

  String _band(int bpm, String language) {
    if (bpm < 50) {
      return t(language, 'Lower than usual. Normal for very fit people; if you feel dizzy, faint or tired, see a doctor.',
          'معمول سے کم۔ بہت فٹ لوگوں میں عام ہے؛ اگر چکر، کمزوری یا تھکاوٹ ہو تو ڈاکٹر سے ملیں۔');
    }
    if (bpm <= 100) return t(language, 'Within the usual resting range for adults (about 60 to 100).', 'بالغوں کی عام آرام کی حد (تقریباً 60 سے 100) کے اندر۔');
    return t(language, 'Higher than a usual resting rate. Rest for 5 minutes and measure again; caffeine, stress, fever and low iron can all raise it.',
        'آرام کی عام شرح سے زیادہ۔ 5 منٹ آرام کر کے دوبارہ ناپیں؛ چائے کافی، تناؤ، بخار اور خون کی کمی سب اسے بڑھا سکتے ہیں۔');
  }

  Widget _insights(HealthStore store, String language) {
    final readings = store.heartReadings;
    final h = HeartInsights(readings, CycleEngine(store.periods, store.now()), store.now());
    final anaemia = h.anaemiaHint([for (final l in store.logs) (date: l.date, symptoms: l.symptoms)]);
    final recent = readings.reversed.take(7).toList();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t(language, 'Your resting heart rate', 'آپ کی آرام کی دھڑکن'),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 8),
          if (readings.isEmpty)
            Text(
                t(language, 'No readings yet. A few mornings a week is enough: after a couple of cycles Femora can show how your heart rate changes across your cycle.',
                    'ابھی کوئی ریڈنگ نہیں۔ ہفتے میں چند صبحیں کافی ہیں: چند سائیکلز کے بعد Femora دکھا سکے گا کہ آپ کی دھڑکن سائیکل کے ساتھ کیسے بدلتی ہے۔'),
                key: const Key('heart_empty'),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textMuted, height: 1.4))
          else ...[
            if (h.usual != null)
              Text(t(language, 'Usual resting rate: ${h.usual} bpm (${h.resting.length} readings)', 'عام آرام کی دھڑکن: ${h.usual} (${h.resting.length} ریڈنگز)'),
                  key: const Key('heart_usual'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 6),
            Text(
              h.cycleNote ??
                  t(language, 'After ovulation the resting rate usually rises by 2 to 5 beats. With 3 or more morning readings before and after ovulation, Femora will show yours.',
                      'بیضہ بننے کے بعد آرام کی دھڑکن عموماً 2 سے 5 دھڑکن بڑھ جاتی ہے۔ بیضہ بننے سے پہلے اور بعد 3 یا زیادہ صبح کی ریڈنگز کے بعد Femora آپ کی دکھائے گا۔'),
              key: const Key('heart_cycle_note'),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textDark, height: 1.4),
            ),
            if (anaemia) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('heart_anaemia'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(14)),
                child: Text(
                  t(language,
                      'Your last three morning readings are well above your usual rate, and you recently logged tiredness or a long period. '
                          'Low iron (anaemia) is one common cause: a simple blood test (haemoglobin) can check it.',
                      'آپ کی پچھلی تین صبح کی ریڈنگز معمول سے کافی زیادہ ہیں، اور آپ نے حال ہی میں تھکاوٹ یا لمبی ماہواری درج کی۔ '
                          'خون کی کمی ایک عام وجہ ہے: خون کا سادہ ٹیسٹ (ہیموگلوبن) اسے جانچ سکتا ہے۔'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF7A4B00), height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 10),
            for (final r in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(r.resting ? Icons.wb_twilight_rounded : Icons.schedule_rounded, size: 15, color: AppColors.textLight),
                    const SizedBox(width: 8),
                    Expanded(child: Text(HealthStore.ago(r.date, store.now(), language: language), style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted))),
                    Text('${r.bpm} bpm', style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final List<double> wave;
  _WavePainter(this.wave);

  @override
  void paint(Canvas canvas, Size size) {
    if (wave.length < 2) return;
    final lo = wave.reduce(math.min), hi = wave.reduce(math.max);
    final span = (hi - lo).abs() < 1e-6 ? 1.0 : hi - lo;
    final path = Path();
    for (var i = 0; i < wave.length; i++) {
      final x = size.width * i / (wave.length - 1);
      final y = size.height * (wave[i] - lo) / span; // red dips at each beat, so it is drawn upside down: beats point up
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFE0457B));
  }

  @override
  bool shouldRepaint(_WavePainter old) => true;
}
