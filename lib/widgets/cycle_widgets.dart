import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cycle_engine.dart';
import '../models/health_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDay(DateTime d) => '${d.day} ${_monthShort[d.month - 1]}';
String fmtMonth(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';
String plural(int n, String one) => '$n $one${n == 1 ? '' : 's'}';

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
      child: e.hasHistory ? _tracked(context) : _empty(),
    );
  }

  Widget _empty() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Track your cycle', style: _t(20, w: FontWeight.w700, c: Colors.white)),
          const SizedBox(height: 6),
          Text(
            'Log the first day of your last period. Femora then predicts your next period and fertile window, and points out anything unusual.',
            style: _t(13, c: Colors.white.withValues(alpha: 0.9), h: 1.4),
          ),
        ],
      );

  Widget _tracked(BuildContext context) {
    final e = engine;
    final phase = e.phase;
    final title = e.periodOngoing ? 'Period day ${e.cycleDay}' : 'Cycle day ${e.cycleDay}${phase == null ? '' : ' · ${phase.label}'}';
    final until = e.daysUntilNext!;
    final nextText = e.isLate
        ? '${fmtDay(e.nextStart!)} · ${plural(-until, 'day')} late'
        : (until == 0 ? '${fmtDay(e.nextStart!)} · today' : '${fmtDay(e.nextStart!)} · in ${plural(until, 'day')}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, key: const Key('cycle_title'), style: _t(20, w: FontWeight.w700, c: Colors.white)),
        if (phase != null) ...[
          const SizedBox(height: 4),
          Text(phase.tip, style: _t(12.5, c: Colors.white.withValues(alpha: 0.9), h: 1.35)),
        ],
        const SizedBox(height: 14),
        _row('Next period', nextText, key: const Key('cycle_next')),
        if (!e.isLate) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text('Likely between ${fmtDay(e.nextStartEarliest!)} and ${fmtDay(e.nextStartLatest!)}', key: const Key('cycle_window'), style: _t(11.5, c: Colors.white.withValues(alpha: 0.85))),
          ),
          _row('Ovulation (estimate)', fmtDay(e.ovulation!)),
          _row('Fertile window (estimate)', '${fmtDay(e.fertileStart!)} to ${fmtDay(e.fertileEnd!)}'),
        ],
        const SizedBox(height: 8),
        Text(e.basis, key: const Key('cycle_basis'), style: _t(11, c: Colors.white.withValues(alpha: 0.85), h: 1.35)),
        const SizedBox(height: 4),
        Text('These are estimates, not a medical result and not a way to prevent pregnancy.', style: _t(10.5, c: Colors.white.withValues(alpha: 0.75))),
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
    final today = dayOf(store.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: addDays(today, -180),
      lastDate: today,
      helpText: start ? 'First day of the period' : 'Last day of bleeding',
    );
    if (picked == null || !context.mounted) return;
    await runLog(context, start ? store.logPeriodStart(picked) : store.logPeriodEnd(picked), start ? 'Period start saved.' : 'Period end saved.');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<HealthStore>();
    final today = dayOf(store.now());
    final ongoing = engine.periodOngoing;
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
                  onPressed: () => runLog(context, ongoing ? store.logPeriodEnd(today) : store.logPeriodStart(today), ongoing ? 'Period end saved.' : 'Period start saved.'),
                  icon: Icon(ongoing ? Icons.check_circle_outline_rounded : Icons.water_drop_rounded, size: 20),
                  label: Text(ongoing ? 'My period ended today' : 'My period started today', style: _t(13.5, w: FontWeight.w700, c: Colors.white)),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('period_other_day'),
              onPressed: () => _pick(context, start: !ongoing),
              child: Text(ongoing ? 'It ended on another day' : 'It started on another day', style: _t(12.5, w: FontWeight.w600, c: AppColors.primaryBerry)),
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
              Expanded(child: Center(child: Text(fmtMonth(month), key: const Key('month_title'), style: _t(15, w: FontWeight.w700)))),
              IconButton(key: const Key('month_next'), icon: const Icon(Icons.chevron_right_rounded), onPressed: () => onMonth(DateTime(month.year, month.month + 1))),
            ],
          ),
          Row(children: [for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Expanded(child: Center(child: Text(d, style: _t(11, w: FontWeight.w700, c: AppColors.textMuted))))]),
          const SizedBox(height: 4),
          GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.05, children: cells),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _legend(AppColors.primaryBerry, 'Period'),
              _legend(_softPink, 'Expected period', border: AppColors.primaryBerry),
              _legend(_softGreen, 'Fertile window'),
              _legend(_green, 'Ovulation'),
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
    return Container(
      key: const Key('cycle_flags'),
      margin: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.aiInsightBg, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Worth knowing', style: _t(15, w: FontWeight.w700)),
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
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('flags_pcos'),
                onPressed: () => context.read<AppState>().setTab(2),
                icon: const Icon(Icons.bubble_chart_outlined, size: 18),
                label: Text('Open the PCOS check', style: _t(12.5, w: FontWeight.w700, c: AppColors.primaryBerry)),
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
    final rows = <Widget>[];
    for (var i = ps.length - 1; i >= 0 && rows.length < 6; i--) {
      final e = ps[i];
      final next = i + 1 < ps.length ? ps[i + 1] : null;
      final cycleLen = next == null ? null : daysBetween(e.start, next.start);
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(fmtDay(e.start), style: _t(13, w: FontWeight.w600))),
            Expanded(flex: 3, child: Text(cycleLen == null ? 'current cycle' : '$cycleLen-day cycle', style: _t(12.5, c: AppColors.textMuted))),
            Expanded(flex: 3, child: Text(e.length == null ? (i == ps.length - 1 && engine.periodOngoing ? 'ongoing' : 'end not logged') : 'period ${plural(e.length!, 'day')}', style: _t(12.5, c: AppColors.textMuted))),
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
            Expanded(child: Text('Your cycles', style: _t(15, w: FontWeight.w700))),
            if (engine.averageLength != null) Text('average ${engine.averageLength!.toStringAsFixed(1)} days · ${engine.regularity}', style: _t(11.5, c: AppColors.textMuted)),
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
