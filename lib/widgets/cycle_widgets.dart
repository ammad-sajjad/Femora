import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/cycle_engine.dart';
import '../models/health_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthShortUr = ['جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون', 'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر'];
const _pluralWordsUr = {'day': 'دن', 'cycle': 'سائیکل'};

String fmtDay(DateTime d, {String language = 'en'}) => language == 'ur' ? '${d.day} ${_monthShortUr[d.month - 1]}' : '${d.day} ${_monthShort[d.month - 1]}';
String fmtMonth(DateTime d, {String language = 'en'}) =>
    language == 'ur' ? '${_monthShortUr[d.month - 1]} ${d.year}' : '${_monthNames[d.month - 1]} ${d.year}';

String _lang(BuildContext context) => Provider.of<HealthStore?>(context)?.profile.language ?? 'en';

String regularityIn(String regularity, String language) => language != 'ur'
    ? regularity
    : const {'regular': 'باقاعدہ', 'irregular': 'بے قاعدہ', 'not enough cycles yet': 'ابھی کافی سائیکل نہیں'}[regularity] ?? regularity;

String plural(int n, String one, {String language = 'en'}) => language == 'ur' ? '$n ${_pluralWordsUr[one] ?? one}' : '$n $one${n == 1 ? '' : 's'}';

const _green = Color(0xFF10B981);
const _softGreen = Color(0xFFCCFBF1);
const _softPink = Color(0xFFFFF1F4);
const _pinkBorder = Color(0xFFFECDD3);

TextStyle _t(double size, {FontWeight w = FontWeight.w400, Color c = const Color(0xFF1E1B1E), double? h, double? ls}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, height: h, letterSpacing: ls);

/// Spring interactive touch compression.
class _FluidPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _FluidPress({required this.child, this.onTap});

  @override
  State<_FluidPress> createState() => _FluidPressState();
}

class _FluidPressState extends State<_FluidPress> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 180),
    lowerBound: 0.965,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) => _ctrl.forward(),
      onTapCancel: () => _ctrl.forward(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(scale: _ctrl.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// Runs a store action that can refuse (returns a message) and shows the result.
Future<void> runLog(BuildContext context, Future<String?> action, String done) async {
  final msg = await action;
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg ?? done),
    backgroundColor: msg == null ? const Color(0xFFE11D48) : const Color(0xFF7A2E3E),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ));
}

Future<void> pickPeriodDate(BuildContext context, {required bool start}) async {
  final store = context.read<HealthStore>();
  final l = store.profile.language;
  final today = dayOf(store.now());
  final picked = await showDatePicker(
    context: context,
    initialDate: today,
    firstDate: addDays(today, -180),
    lastDate: today,
    helpText: start ? t(l, 'First day of the period', 'پیریڈ کا پہلا دن') : t(l, 'Last day of bleeding', 'خون آنے کا آخری دن'),
  );
  if (picked == null || !context.mounted) return;
  await runLog(context, start ? store.logPeriodStart(picked) : store.logPeriodEnd(picked),
      start ? t(l, 'Period start saved.', 'پیریڈ کا آغاز محفوظ ہو گیا۔') : t(l, 'Period end saved.', 'پیریڈ کا اختتام محفوظ ہو گیا۔'));
}

/// Where she is in her cycle and what to expect next. Includes primary period actions inside the card matching CALENDER.png.
class CycleSummaryCard extends StatelessWidget {
  final CycleEngine engine;
  const CycleSummaryCard({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final e = engine;
    return Container(
      key: const Key('cycle_summary'),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE11D48), // Rose Crimson
            Color(0xFFBE185D), // Deep Berry Pink
            Color(0xFF6B1135), // Dark Plum Wine
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: e.hasHistory ? _tracked(context) : _empty(context),
    );
  }

  Widget _empty(BuildContext context) {
    final l = _lang(context);
    final store = context.read<HealthStore>();
    final today = dayOf(store.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phase Pill Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDA4AF),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                t(l, 'START TRACKING', 'ٹریکنگ شروع کریں'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          t(l, 'Track your cycle', 'اپنا سائیکل ٹریک کریں'),
          style: _t(28, w: FontWeight.w800, c: Colors.white, ls: -0.5),
        ),
        const SizedBox(height: 6),
        Text(
          t(l, 'Log the first day of your last period. Femora then predicts your next period and fertile window, and points out anything unusual.',
              'اپنے آخری پیریڈ کا پہلا دن درج کریں۔ پھر Femora آپ کے اگلے پیریڈ اور زرخیز دنوں کا اندازہ لگائے گا، اور کوئی غیر معمولی بات ہو تو بتائے گا۔'),
          style: _t(13.5, c: Colors.white.withOpacity(0.92), h: 1.4),
        ),
        const SizedBox(height: 20),
        // Primary White Button
        _FluidPress(
          onTap: () => runLog(context, store.logPeriodStart(today), t(l, 'Period start saved.', 'پیریڈ کا آغاز محفوظ ہو گیا۔')),
          child: Container(
            key: const Key('log_period_start'),
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.water_drop_rounded, color: Color(0xFF881337), size: 20),
                const SizedBox(width: 8),
                Text(
                  t(l, 'My period started today', 'میرا پیریڈ آج شروع ہوا'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF881337),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            key: const Key('period_other_day'),
            onPressed: () => pickPeriodDate(context, start: true),
            child: Text(
              t(l, 'It started on another day', 'کسی اور دن شروع ہوا'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tracked(BuildContext context) {
    final e = engine;
    final phase = e.phase;
    final l = _lang(context);
    final store = context.read<HealthStore>();
    final today = dayOf(store.now());
    final ongoing = e.periodOngoing;

    final title = ongoing
        ? t(l, 'Period day ${e.cycleDay}', 'پیریڈ کا دن ${e.cycleDay}')
        : t(l, 'Cycle day ${e.cycleDay}', 'سائیکل کا دن ${e.cycleDay}') + (phase == null ? '' : ' · ${phase.labelIn(l)}');

    final phaseLabel = ongoing
        ? t(l, 'MENSTRUAL PHASE', 'حیض کا مرحلہ')
        : (phase != null ? phase.labelIn(l).toUpperCase() : t(l, 'CYCLE', 'سائیکل'));

    final until = e.daysUntilNext ?? 0;
    final next = e.nextStart != null ? fmtDay(e.nextStart!, language: l) : '';
    final nextText = e.isLate
        ? t(l, '$next · ${plural(-until, 'day')} late', '$next · ${plural(-until, 'day', language: 'ur')} تاخیر')
        : (until == 0 ? t(l, '$next · today', '$next · آج') : t(l, '$next · in ${plural(until, 'day')}', '$next · ${plural(until, 'day', language: 'ur')} میں'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phase Pill Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDA4AF),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                phaseLabel,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          key: const Key('cycle_title'),
          style: _t(30, w: FontWeight.w800, c: Colors.white, ls: -0.5),
        ),
        const SizedBox(height: 6),
        Text(
          phase?.tipIn(l) ??
              (ongoing
                  ? t(l, 'Your period is here. Rest, warmth and iron-rich food can help with cramps and tiredness.',
                      'آپ کا پیریڈ جاری ہے۔ آرام، گرمائش اور آئرن سے بھرپور غذا درد اور تھکن میں مدد کر سکتی ہے۔')
                  : t(l, 'Log your daily signals to refine your cycle predictions.', 'اپنے سائیکل کی پیشین گوئیوں کو بہتر بنانے کے لیے روزانہ لاگ کریں۔')),
          style: _t(13.5, c: Colors.white.withOpacity(0.92), h: 1.4),
        ),
        const SizedBox(height: 16),

        // Inner Translucent Details Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
          ),
          child: Column(
            children: [
              _detailRow(t(l, 'Next period', 'اگلا پیریڈ'), nextText, key: const Key('cycle_next')),
              if (!e.isLate && e.nextStartEarliest != null && e.nextStartLatest != null) ...[
                Divider(color: Colors.white.withOpacity(0.08), height: 18),
                _detailRow(
                  t(l, 'Prediction range', 'متوقع حد'),
                  '${fmtDay(e.nextStartEarliest!, language: l)} – ${fmtDay(e.nextStartLatest!, language: l)}',
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 2, top: 4, bottom: 2),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      t(l, 'Likely between ${fmtDay(e.nextStartEarliest!)} and ${fmtDay(e.nextStartLatest!)}',
                          'غالباً ${fmtDay(e.nextStartEarliest!, language: 'ur')} سے ${fmtDay(e.nextStartLatest!, language: 'ur')} کے درمیان'),
                      key: const Key('cycle_window'),
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.white.withOpacity(0.75)),
                    ),
                  ),
                ),
              ],
              if (!e.isLate && e.ovulation != null) ...[
                Divider(color: Colors.white.withOpacity(0.08), height: 18),
                _detailRow(t(l, 'Ovulation (estimate)', 'بیضہ بننا (اندازہ)'), fmtDay(e.ovulation!, language: l)),
              ],
              if (!e.isLate && e.fertileStart != null && e.fertileEnd != null) ...[
                Divider(color: Colors.white.withOpacity(0.08), height: 18),
                _detailRow(
                  t(l, 'Fertile window (estimate)', 'زرخیز دن (اندازہ)'),
                  t(l, '${fmtDay(e.fertileStart!)} – ${fmtDay(e.fertileEnd!)}', '${fmtDay(e.fertileStart!, language: 'ur')} سے ${fmtDay(e.fertileEnd!, language: 'ur')}'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Research note & basis
        Text(
          e.basis,
          key: const Key('cycle_basis'),
          style: _t(11, c: Colors.white.withOpacity(0.85), h: 1.35),
        ),
        const SizedBox(height: 4),
        Text(
          t(l, 'These are estimates, not a medical result and not a way to prevent pregnancy.', 'یہ اندازے ہیں، طبی نتیجہ نہیں، اور حمل سے بچاؤ کا طریقہ بھی نہیں۔'),
          style: _t(10.5, c: Colors.white.withOpacity(0.7)),
        ),
        const SizedBox(height: 20),

        // Primary White Button (Ended / Started)
        _FluidPress(
          onTap: () => runLog(
            context,
            ongoing ? store.logPeriodEnd(today) : store.logPeriodStart(today),
            ongoing ? t(l, 'Period end saved.', 'پیریڈ کا اختتام محفوظ ہو گیا۔') : t(l, 'Period start saved.', 'پیریڈ کا آغاز محفوظ ہو گیا۔'),
          ),
          child: Container(
            key: Key(ongoing ? 'log_period_end' : 'log_period_start'),
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  ongoing ? Icons.check_rounded : Icons.water_drop_rounded,
                  color: const Color(0xFF881337),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  ongoing ? t(l, 'My period ended today', 'میرا پیریڈ آج ختم ہوا') : t(l, 'My period started today', 'میرا پیریڈ آج شروع ہوا'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF881337),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Secondary Link
        Center(
          child: TextButton(
            key: const Key('period_other_day'),
            onPressed: () => pickPeriodDate(context, start: !ongoing),
            child: Text(
              ongoing ? t(l, 'It ended on another day', 'کسی اور دن ختم ہوا') : t(l, 'It started on another day', 'کسی اور دن شروع ہوا'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value, {Key? key}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: _t(13, c: Colors.white.withOpacity(0.85)))),
            Text(value, key: key, style: _t(13.5, w: FontWeight.w700, c: Colors.white)),
          ],
        ),
      );
}

/// Kept for backwards compatibility if needed, but its actions are housed inside CycleSummaryCard.
class PeriodLogRow extends StatelessWidget {
  final CycleEngine engine;
  const PeriodLogRow({super.key, required this.engine});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A month grid: logged period days, predicted period days, fertile window and ovulation.
class MonthCalendar extends StatelessWidget {
  final CycleEngine engine;
  final DateTime month; // any day of the month shown
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onDay;
  const MonthCalendar({super.key, required this.engine, required this.month, required this.onMonth, required this.onDay});

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final blanks = first.weekday - 1; // Monday first (1 -> 0 blanks)
    final prevMonthLastDay = DateTime(month.year, month.month, 0).day;
    final l = _lang(context);

    final cells = <Widget>[
      // Previous month ending days in faint grey
      for (var i = blanks - 1; i >= 0; i--)
        _overflowCell(prevMonthLastDay - i),
      // Active days of the month
      for (var day = 1; day <= daysInMonth; day++)
        _cell(DateTime(month.year, month.month, day)),
      // Next month starting days to complete the week
      for (var t = 1; (blanks + daysInMonth + t - 1) % 7 != 0; t++)
        _overflowCell(t),
    ];

    return Container(
      key: const Key('cycle_calendar'),
      margin: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with Month, Day Badge, and Navigation Chevrons
          Row(
            children: [
              Text(
                fmtMonth(month, language: l),
                key: const Key('month_title'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B1E),
                ),
              ),
              if (engine.hasHistory && engine.cycleDay != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4EC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE11D48),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'DAY ${engine.cycleDay}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE11D48),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              _FluidPress(
                onTap: () => onMonth(DateTime(month.year, month.month - 1)),
                child: Container(
                  key: const Key('month_prev'),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: const Icon(Icons.chevron_left_rounded, size: 20, color: Color(0xFF475569)),
                ),
              ),
              const SizedBox(width: 8),
              _FluidPress(
                onTap: () => onMonth(DateTime(month.year, month.month + 1)),
                child: Container(
                  key: const Key('month_next'),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Days of week header
          Row(
            children: [
              for (final d in l == 'ur' ? const ['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار'] : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      maxLines: 1,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Calendar Grid
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.0,
            children: cells,
          ),
          const SizedBox(height: 16),

          // Bottom Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _legendDot(const Color(0xFF9F1239), t(l, 'Period', 'پیریڈ')),
              _legendPill(_softPink, _pinkBorder, t(l, 'Expected', 'متوقع')),
              _legendPill(_softGreen, const Color(0xFF0F766E), t(l, 'Fertile', 'زرخیز')),
              _legendDot(_green, t(l, 'Ovulation', 'بیضہ بننا')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        ],
      );

  Widget _legendPill(Color bg, Color border, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: 1.2),
            ),
          ),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        ],
      );

  Widget _overflowCell(int day) => Center(
        child: Text(
          '$day',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFFCBD5E1), // faint grey
          ),
        ),
      );

  Widget _cell(DateTime date) {
    final info = engine.dayInfo(date);
    final isToday = date == engine.today;
    Color? fill;
    Color textColor = const Color(0xFF1E293B);
    Border? border;
    bool hasDotUnderneath = false;
    Color dotColor = const Color(0xFF0F766E);
    bool isConcentricToday = false;

    if (info.period) {
      fill = const Color(0xFF9F1239);
      textColor = Colors.white;
      if (isToday) {
        isConcentricToday = true;
      }
    } else if (info.ovulation) {
      fill = const Color(0xFF10B981);
      textColor = Colors.white;
    } else if (info.predictedPeriod) {
      fill = _softPink;
      border = Border.all(color: _pinkBorder, width: 1.5);
      textColor = const Color(0xFF9F1239);
    } else if (info.fertile) {
      fill = _softGreen;
      textColor = const Color(0xFF0F766E);
      hasDotUnderneath = true;
    }

    if (isToday && !info.period && border == null) {
      border = Border.all(color: const Color(0xFF1E293B), width: 1.8);
    }

    final key = 'cycle_day_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return GestureDetector(
      key: Key(key),
      behavior: HitTestBehavior.opaque,
      onTap: () => onDay(date),
      child: Center(
        child: isConcentricToday
            ? Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFDA4AF), width: 1.8),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${date.day}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            : Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: border,
                  boxShadow: info.ovulation
                      ? [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: isToday || info.period || info.ovulation ? FontWeight.w800 : FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    if (hasDotUnderneath)
                      Container(
                        width: 3.5,
                        height: 3.5,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Things worth mentioning, from the engine's rules. Never a diagnosis.
class CycleFlagsCard extends StatelessWidget {
  final CycleEngine engine;
  const CycleFlagsCard({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final flags = engine.flags;
    if (flags.isEmpty) return const SizedBox.shrink();
    final pcos = flags.any((f) => f.id == 'irregular' || f.id == 'long');
    final l = _lang(context);
    return Container(
      key: const Key('cycle_flags'),
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFED7DC), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.info_outline_rounded, color: Color(0xFFE11D48), size: 18),
              ),
              const SizedBox(width: 10),
              Text(t(l, 'Worth knowing', 'جاننے کی بات'), style: _t(15, w: FontWeight.w700, c: const Color(0xFF1E1B1E))),
            ],
          ),
          const SizedBox(height: 10),
          for (final f in flags)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(f.seeDoctor ? Icons.medical_services_outlined : Icons.info_outline_rounded, size: 18, color: f.seeDoctor ? const Color(0xFF9E1B46) : AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f.text, style: _t(12.8, h: 1.4))),
                ],
              ),
            ),
          if (pcos)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('flags_pcos'),
                onPressed: () => context.read<AppState>().setTab(2),
                icon: const Icon(Icons.bubble_chart_outlined, size: 18),
                label: Text(t(l, 'Open the PCOS check', 'PCOS چیک کھولیں'), style: _t(12.5, w: FontWeight.w700, c: const Color(0xFFE11D48))),
              ),
            ),
        ],
      ),
    );
  }
}

/// The last few cycles: when they started, how long they were.
class CycleHistory extends StatelessWidget {
  final CycleEngine engine;
  const CycleHistory({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final ps = engine.periods;
    final l = _lang(context);
    final rows = <Widget>[];

    for (var i = ps.length - 1; i >= 0 && rows.length < 6; i--) {
      final e = ps[i];
      final next = i + 1 < ps.length ? ps[i + 1] : null;
      final cycleLen = next == null ? null : daysBetween(e.start, next.start);
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(fmtDay(e.start, language: l), style: _t(13, w: FontWeight.w600, c: const Color(0xFF1E1B1E)))),
            Expanded(flex: 3, child: Text(cycleLen == null ? t(l, 'current cycle', 'موجودہ سائیکل') : t(l, '$cycleLen-day cycle', '$cycleLen دن کا سائیکل'), style: _t(12.5, c: const Color(0xFF64748B)))),
            Expanded(flex: 3, child: Text(e.length == null ? (i == ps.length - 1 && engine.periodOngoing ? t(l, 'ongoing', 'جاری') : t(l, 'end not logged', 'اختتام درج نہیں')) : t(l, 'period ${plural(e.length!, 'day')}', 'پیریڈ ${plural(e.length!, 'day', language: 'ur')}'), style: _t(12.5, c: const Color(0xFF64748B)))),
          ],
        ),
      ));
    }

    final latestStart = ps.isNotEmpty ? ps.last.start : null;

    return Container(
      key: const Key('cycle_history'),
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4EC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.sync_rounded, color: Color(0xFFE11D48), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(l, 'Your cycles', 'آپ کے سائیکل'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1B1E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      latestStart != null
                          ? '${fmtDay(latestStart, language: l)} · ${engine.periodOngoing ? t(l, 'current cycle · ongoing', 'موجودہ سائیکل · جاری') : (engine.averageLength != null ? '${engine.averageLength!.toStringAsFixed(1)} days · ${regularityIn(engine.regularity, l)}' : t(l, 'cycle ongoing', 'سائیکل جاری'))}'
                          : t(l, 'No cycle history yet', 'ابھی تک کوئی تاریخ نہیں'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (engine.hasHistory && engine.cycleDay != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4EC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Cycle Day ${engine.cycleDay}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                ),
            ],
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: const Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 8),
            ...rows,
          ],
        ],
      ),
    );
  }
}

/// What tapping a calendar day offers.
Future<void> showDayActions(BuildContext context, DateTime date) async {
  final store = context.read<HealthStore>();
  final today = dayOf(store.now());
  final d = dayOf(date);
  final engine = store.cycle;
  final info = engine.dayInfo(d);
  final isStart = store.periods.any((e) => e.start == d);
  final canEnd = !d.isAfter(today) && store.periods.any((e) => !e.start.isAfter(d) && daysBetween(e.start, d) < 15);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fmtDay(d), style: _t(18, w: FontWeight.w800, c: const Color(0xFF1E1B1E))),
            const SizedBox(height: 2),
            Text(
              info.period
                  ? 'A logged period day'
                  : info.ovulation
                      ? 'Estimated ovulation day'
                      : info.predictedPeriod
                          ? 'An expected period day'
                          : info.fertile
                              ? 'In the estimated fertile window'
                              : 'No period expected',
              style: _t(13, c: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            if (!d.isAfter(today))
              ListTile(
                key: const Key('day_log_start'),
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: Color(0xFFFFE4EC), shape: BoxShape.circle),
                  child: const Icon(Icons.water_drop_rounded, color: Color(0xFFE11D48), size: 20),
                ),
                title: const Text('My period started this day', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheet);
                  runLog(context, store.logPeriodStart(d), 'Period start saved.');
                },
              ),
            if (canEnd)
              ListTile(
                key: const Key('day_log_end'),
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: Color(0xFFFFE4EC), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFFE11D48), size: 20),
                ),
                title: const Text('My period ended this day', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheet);
                  runLog(context, store.logPeriodEnd(d), 'Period end saved.');
                },
              ),
            if (isStart)
              ListTile(
                key: const Key('day_remove'),
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: Color(0xFFFFF1F4), shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFF9E1B46), size: 20),
                ),
                title: const Text('Remove this period', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF9E1B46))),
                onTap: () {
                  Navigator.pop(sheet);
                  store.removePeriod(d);
                },
              ),
            if (d.isAfter(today))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('You can log a period once it has started.', style: _t(13, c: const Color(0xFF64748B))),
              ),
          ],
        ),
      ),
    ),
  );
}
