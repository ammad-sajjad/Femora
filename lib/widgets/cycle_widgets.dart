import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../models/cycle_engine.dart';
import '../models/health_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
// Month names are written out in Urdu (not transliterated) since that is how they are normally read; the
// day number keeps Western digits, which is how dates are written in Urdu apps too.
const _monthShortUr = ['جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون', 'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر'];
const _pluralWordsUr = {'day': 'دن', 'cycle': 'سائیکل'};

String fmtDay(DateTime d, {String language = 'en'}) => language == 'ur' ? '${d.day} ${_monthShortUr[d.month - 1]}' : '${d.day} ${_monthShort[d.month - 1]}';
String fmtMonth(DateTime d, {String language = 'en'}) =>
    language == 'ur' ? '${_monthShortUr[d.month - 1]} ${d.year}' : '${_monthNames[d.month - 1]} ${d.year}';

/// The app language, for widgets used without the language being passed in (English when there is no store).
String _lang(BuildContext context) => Provider.of<HealthStore?>(context)?.profile.language ?? 'en';

String regularityIn(String regularity, String language) => language != 'ur'
    ? regularity
    : const {'regular': 'باقاعدہ', 'irregular': 'بے قاعدہ', 'not enough cycles yet': 'ابھی کافی سائیکل نہیں'}[regularity] ?? regularity;

/// "$n day" / "$n days" in English; Urdu nouns do not change for a plural count, so just "$n دن".
String plural(int n, String one, {String language = 'en'}) => language == 'ur' ? '$n ${_pluralWordsUr[one] ?? one}' : '$n $one${n == 1 ? '' : 's'}';

const _green = Color(0xFF2E9E68);
const _softGreen = Color(0xFFD8F1E3);
const _softPink = Color(0xFFFFE1EA);

TextStyle _t(double size, {FontWeight w = FontWeight.w400, Color c = AppColors.textDark, double? h}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, height: h);

/// Runs a store action that can refuse (returns a message) and shows the result.
Future<void> runLog(BuildContext context, Future<String?> action, String done) async {
  final msg = await action;
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg ?? done),
    backgroundColor: msg == null ? AppColors.primaryBerry : const Color(0xFF7A2E3E),
    behavior: SnackBarBehavior.floating,
  ));
}

/// Where she is in her cycle and what to expect next.
class CycleSummaryCard extends StatelessWidget {
  final CycleEngine engine;
  const CycleSummaryCard({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final e = engine;
    return Container(
      key: const Key('cycle_summary'),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.softShadow),
      child: e.hasHistory ? _tracked(context) : _empty(_lang(context)),
    );
  }

  Widget _empty(String l) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t(l, 'Track your cycle', 'اپنا سائیکل ٹریک کریں'), style: _t(20, w: FontWeight.w700, c: Colors.white)),
          const SizedBox(height: 6),
          Text(
            t(l, 'Log the first day of your last period. Femora then predicts your next period and fertile window, and points out anything unusual.',
                'اپنے آخری پیریڈ کا پہلا دن درج کریں۔ پھر Femora آپ کے اگلے پیریڈ اور زرخیز دنوں کا اندازہ لگائے گا، اور کوئی غیر معمولی بات ہو تو بتائے گا۔'),
            style: _t(13, c: Colors.white.withValues(alpha: 0.9), h: 1.4),
          ),
        ],
      );

  Widget _tracked(BuildContext context) {
    final e = engine;
    final phase = e.phase;
    final l = _lang(context);
    final title = e.periodOngoing
        ? t(l, 'Period day ${e.cycleDay}', 'پیریڈ کا دن ${e.cycleDay}')
        : t(l, 'Cycle day ${e.cycleDay}', 'سائیکل کا دن ${e.cycleDay}') + (phase == null ? '' : ' · ${phase.labelIn(l)}');
    final until = e.daysUntilNext!;
    final next = fmtDay(e.nextStart!, language: l);
    final nextText = e.isLate
        ? t(l, '$next · ${plural(-until, 'day')} late', '$next · ${plural(-until, 'day', language: 'ur')} تاخیر')
        : (until == 0 ? t(l, '$next · today', '$next · آج') : t(l, '$next · in ${plural(until, 'day')}', '$next · ${plural(until, 'day', language: 'ur')} میں'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, key: const Key('cycle_title'), style: _t(20, w: FontWeight.w700, c: Colors.white)),
        if (phase != null) ...[
          const SizedBox(height: 4),
          Text(phase.tipIn(l), style: _t(12.5, c: Colors.white.withValues(alpha: 0.9), h: 1.35)),
        ],
        const SizedBox(height: 14),
        _row(t(l, 'Next period', 'اگلا پیریڈ'), nextText, key: const Key('cycle_next')),
        if (!e.isLate) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
                t(l, 'Likely between ${fmtDay(e.nextStartEarliest!)} and ${fmtDay(e.nextStartLatest!)}',
                    'غالباً ${fmtDay(e.nextStartEarliest!, language: 'ur')} سے ${fmtDay(e.nextStartLatest!, language: 'ur')} کے درمیان'),
                key: const Key('cycle_window'), style: _t(11.5, c: Colors.white.withValues(alpha: 0.85))),
          ),
          _row(t(l, 'Ovulation (estimate)', 'بیضہ بننا (اندازہ)'), fmtDay(e.ovulation!, language: l)),
          _row(t(l, 'Fertile window (estimate)', 'زرخیز دن (اندازہ)'),
              t(l, '${fmtDay(e.fertileStart!)} to ${fmtDay(e.fertileEnd!)}', '${fmtDay(e.fertileStart!, language: 'ur')} سے ${fmtDay(e.fertileEnd!, language: 'ur')}')),
        ],
        const SizedBox(height: 8),
        Text(e.basis, key: const Key('cycle_basis'), style: _t(11, c: Colors.white.withValues(alpha: 0.85), h: 1.35)),
        const SizedBox(height: 4),
        Text(t(l, 'These are estimates, not a medical result and not a way to prevent pregnancy.', 'یہ اندازے ہیں، طبی نتیجہ نہیں، اور حمل سے بچاؤ کا طریقہ بھی نہیں۔'), style: _t(10.5, c: Colors.white.withValues(alpha: 0.75))),
      ],
    );
  }

  Widget _row(String label, String value, {Key? key}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: _t(12.5, c: Colors.white.withValues(alpha: 0.85)))),
            Text(value, key: key, style: _t(13.5, w: FontWeight.w700, c: Colors.white)),
          ],
        ),
      );
}

/// Buttons to log the start and the end of a period.
class PeriodLogRow extends StatelessWidget {
  final CycleEngine engine;
  const PeriodLogRow({super.key, required this.engine});

  Future<void> _pick(BuildContext context, {required bool start}) async {
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

  @override
  Widget build(BuildContext context) {
    final store = context.read<HealthStore>();
    final today = dayOf(store.now());
    final ongoing = engine.periodOngoing;
    final l = _lang(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: Key(ongoing ? 'log_period_end' : 'log_period_start'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBerry, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () => runLog(context, ongoing ? store.logPeriodEnd(today) : store.logPeriodStart(today),
                      ongoing ? t(l, 'Period end saved.', 'پیریڈ کا اختتام محفوظ ہو گیا۔') : t(l, 'Period start saved.', 'پیریڈ کا آغاز محفوظ ہو گیا۔')),
                  icon: Icon(ongoing ? Icons.check_circle_outline_rounded : Icons.water_drop_rounded, size: 20),
                  label: Text(ongoing ? t(l, 'My period ended today', 'میرا پیریڈ آج ختم ہوا') : t(l, 'My period started today', 'میرا پیریڈ آج شروع ہوا'), style: _t(13.5, w: FontWeight.w700, c: Colors.white)),
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const Key('period_other_day'),
              onPressed: () => _pick(context, start: !ongoing),
              child: Text(ongoing ? t(l, 'It ended on another day', 'کسی اور دن ختم ہوا') : t(l, 'It started on another day', 'کسی اور دن شروع ہوا'), style: _t(12.5, w: FontWeight.w600, c: AppColors.primaryBerry)),
            ),
          ),
        ],
      ),
    );
  }
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
    final blanks = first.weekday - 1; // Monday first
    final l = _lang(context);
    final cells = <Widget>[
      for (var i = 0; i < blanks; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++) _cell(DateTime(month.year, month.month, day)),
    ];
    return Container(
      key: const Key('cycle_calendar'),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.softShadow),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(key: const Key('month_prev'), icon: const Icon(Icons.chevron_left_rounded), onPressed: () => onMonth(DateTime(month.year, month.month - 1))),
              Expanded(child: Center(child: Text(fmtMonth(month, language: l), key: const Key('month_title'), style: _t(15, w: FontWeight.w700)))),
              IconButton(key: const Key('month_next'), icon: const Icon(Icons.chevron_right_rounded), onPressed: () => onMonth(DateTime(month.year, month.month + 1))),
            ],
          ),
          Row(children: [for (final d in l == 'ur' ? const ['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار'] : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
            Expanded(child: Center(child: Text(d, maxLines: 1, style: _t(l == 'ur' ? 10 : 11, w: FontWeight.w700, c: AppColors.textMuted))))]),
          const SizedBox(height: 4),
          GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.05, children: cells),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _legend(AppColors.primaryBerry, t(l, 'Period', 'پیریڈ')),
              _legend(_softPink, t(l, 'Expected period', 'متوقع پیریڈ'), border: AppColors.primaryBerry),
              _legend(_softGreen, t(l, 'Fertile window', 'زرخیز دن')),
              _legend(_green, t(l, 'Ovulation', 'بیضہ بننا')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String text, {Color? border}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: border == null ? null : Border.all(color: border, width: 1))),
          const SizedBox(width: 5),
          Text(text, style: _t(10.5, c: AppColors.textMuted)),
        ],
      );

  Widget _cell(DateTime date) {
    final info = engine.dayInfo(date);
    final isToday = date == engine.today;
    Color? fill;
    Color text = AppColors.textDark;
    Border? border;
    if (info.period) {
      fill = AppColors.primaryBerry;
      text = Colors.white;
    } else if (info.ovulation) {
      fill = _green;
      text = Colors.white;
    } else if (info.predictedPeriod) {
      fill = _softPink;
      border = Border.all(color: AppColors.primaryBerry, width: 1);
    } else if (info.fertile) {
      fill = _softGreen;
    }
    if (isToday && border == null) border = Border.all(color: AppColors.textDark, width: 1.6);
    final key = 'cycle_day_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return GestureDetector(
      key: Key(key),
      behavior: HitTestBehavior.opaque,
      onTap: () => onDay(date),
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: border),
          child: Text('${date.day}', style: _t(12.5, w: isToday || info.period ? FontWeight.w700 : FontWeight.w500, c: text)),
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
      margin: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.aiInsightBg, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t(l, 'Worth knowing', 'جاننے کی بات'), style: _t(15, w: FontWeight.w700)),
          const SizedBox(height: 8),
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
                label: Text(t(l, 'Open the PCOS check', 'PCOS چیک کھولیں'), style: _t(12.5, w: FontWeight.w700, c: AppColors.primaryBerry)),
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
    if (ps.isEmpty) return const SizedBox.shrink();
    final l = _lang(context);
    final rows = <Widget>[];
    for (var i = ps.length - 1; i >= 0 && rows.length < 6; i--) {
      final e = ps[i];
      final next = i + 1 < ps.length ? ps[i + 1] : null;
      final cycleLen = next == null ? null : daysBetween(e.start, next.start);
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(fmtDay(e.start, language: l), style: _t(13, w: FontWeight.w600))),
            Expanded(flex: 3, child: Text(cycleLen == null ? t(l, 'current cycle', 'موجودہ سائیکل') : t(l, '$cycleLen-day cycle', '$cycleLen دن کا سائیکل'), style: _t(12.5, c: AppColors.textMuted))),
            Expanded(flex: 3, child: Text(e.length == null ? (i == ps.length - 1 && engine.periodOngoing ? t(l, 'ongoing', 'جاری') : t(l, 'end not logged', 'اختتام درج نہیں')) : t(l, 'period ${plural(e.length!, 'day')}', 'پیریڈ ${plural(e.length!, 'day', language: 'ur')}'), style: _t(12.5, c: AppColors.textMuted))),
          ],
        ),
      ));
    }
    return Container(
      key: const Key('cycle_history'),
      margin: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(22), boxShadow: AppTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(t(l, 'Your cycles', 'آپ کے سائیکل'), style: _t(15, w: FontWeight.w700))),
            if (engine.averageLength != null) Text('${t(l, 'average ${engine.averageLength!.toStringAsFixed(1)} days', 'اوسط ${engine.averageLength!.toStringAsFixed(1)} دن')} · ${regularityIn(engine.regularity, l)}', style: _t(11.5, c: AppColors.textMuted)),
          ]),
          const SizedBox(height: 6),
          ...rows,
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
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fmtDay(d), style: _t(17, w: FontWeight.w700)),
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
              style: _t(12.5, c: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            if (!d.isAfter(today))
              ListTile(
                key: const Key('day_log_start'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.water_drop_rounded, color: AppColors.primaryBerry),
                title: const Text('My period started this day'),
                onTap: () {
                  Navigator.pop(sheet);
                  runLog(context, store.logPeriodStart(d), 'Period start saved.');
                },
              ),
            if (canEnd)
              ListTile(
                key: const Key('day_log_end'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline_rounded, color: AppColors.primaryBerry),
                title: const Text('My period ended this day'),
                onTap: () {
                  Navigator.pop(sheet);
                  runLog(context, store.logPeriodEnd(d), 'Period end saved.');
                },
              ),
            if (isStart)
              ListTile(
                key: const Key('day_remove'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFF7A2E3E)),
                title: const Text('Remove this period'),
                onTap: () {
                  Navigator.pop(sheet);
                  store.removePeriod(d);
                },
              ),
            if (d.isAfter(today)) Text('You can log a period once it has started.', style: _t(12.5, c: AppColors.textMuted)),
          ],
        ),
      ),
    ),
  );
}
