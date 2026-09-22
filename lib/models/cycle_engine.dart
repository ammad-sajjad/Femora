import 'dart:math' as math;

import 'cycle_params.dart';

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole days from [a] to [b] (calendar days, immune to daylight-saving changes).
int daysBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// One period the user logged: the first day of bleeding and, once it stops, the last day.
class PeriodEntry {
  final DateTime start;
  final DateTime? end;

  PeriodEntry({required DateTime start, DateTime? end})
      : start = dayOf(start),
        end = end == null ? null : dayOf(end);

  /// Days of bleeding, counting both ends (null while the period has not been ended).
  int? get length => end == null ? null : daysBetween(start, end!) + 1;

  PeriodEntry withEnd(DateTime? e) => PeriodEntry(start: start, end: e);

  Map<String, dynamic> toJson() => {'start': start.toIso8601String(), 'end': end?.toIso8601String()};

  factory PeriodEntry.fromJson(Map<String, dynamic> j) =>
      PeriodEntry(start: DateTime.parse(j['start'] as String), end: j['end'] == null ? null : DateTime.parse(j['end'] as String));
}

enum CyclePhase { menstrual, follicular, ovulation, luteal }

extension CyclePhaseText on CyclePhase {
  String get label => switch (this) {
        CyclePhase.menstrual => 'Menstrual phase',
        CyclePhase.follicular => 'Follicular phase',
        CyclePhase.ovulation => 'Ovulation window',
        CyclePhase.luteal => 'Luteal phase',
      };

  /// [label], but in Urdu when asked: for on-screen display only. The companion's own context text and the
  /// PDF report keep the English [label] regardless of the profile language.
  String labelIn(String language) => language == 'ur'
      ? switch (this) {
          CyclePhase.menstrual => 'حیض کا مرحلہ',
          CyclePhase.follicular => 'فولیکیولر مرحلہ',
          CyclePhase.ovulation => 'بیضہ دانی کی کھڑکی',
          CyclePhase.luteal => 'لیوٹیل مرحلہ',
        }
      : label;

  String get tip => switch (this) {
        CyclePhase.menstrual => 'Your period is here. Rest, warmth and iron-rich food can help with cramps and tiredness.',
        CyclePhase.follicular => 'Estrogen is rising after your period. Many women feel more energetic now.',
        CyclePhase.ovulation => 'Around ovulation. This is the most fertile part of the cycle.',
        CyclePhase.luteal => 'Progesterone is higher. Tiredness, bloating and mood changes are common before a period.',
      };

  /// [tip], but in Urdu when asked: for on-screen display only, same rule as [labelIn].
  String tipIn(String language) => language == 'ur'
      ? switch (this) {
          CyclePhase.menstrual => 'آپ کا پیریڈ چل رہا ہے۔ آرام، گرمائش اور آئرن سے بھرپور خوراک درد اور تھکاوٹ میں مدد دے سکتی ہے۔',
          CyclePhase.follicular => 'پیریڈ کے بعد ایسٹروجن بڑھ رہا ہے۔ بہت سی خواتین اب زیادہ توانا محسوس کرتی ہیں۔',
          CyclePhase.ovulation => 'بیضہ دانی کے قریب۔ یہ سائیکل کا سب سے زرخیز حصہ ہے۔',
          CyclePhase.luteal => 'پروجیسٹرون زیادہ ہے۔ پیریڈ سے پہلے تھکاوٹ، پھولنا اور موڈ میں تبدیلی عام ہے۔',
        }
      : tip;
}

/// A point worth telling the user about (never a diagnosis).
class CycleFlag {
  final String id;
  final String text;
  final bool seeDoctor;
  const CycleFlag(this.id, this.text, {this.seeDoctor = false});
}

/// How one calendar day looks.
class DayInfo {
  final bool period; // bleeding logged for this day
  final bool predictedPeriod;
  final bool fertile;
  final bool ovulation;
  const DayInfo({this.period = false, this.predictedPeriod = false, this.fertile = false, this.ovulation = false});
}

class _Cycle {
  final DateTime start;
  final int length; // expected or real length, used to place ovulation
  final int span; // days this cycle covers on the calendar (longer than [length] while a period is overdue)
  final int periodLength;
  final bool projected;
  _Cycle(this.start, this.length, this.periodLength, {required this.projected, int? span}) : span = span ?? length;

  DateTime get end => addDays(start, span - 1);
  int get ovulationIndex => length - kCycleParams.lutealDays;
  DateTime get ovulation => addDays(start, ovulationIndex);
}

/// Predicts the next period, ovulation and fertile window from the periods a user has logged.
///
/// The method and its constants come from ml/cycle_eval.py (Fehring data, 159 women, 1,665 cycles): her own average cycle
/// length, pulled towards the population average while she has only a few cycles logged. In that study it matched or beat a
/// Random Forest, so the simpler, explainable model is the one used. Ovulation is estimated as the expected next period minus
/// a 13-day luteal phase; without hormone tests this stays an estimate, not a measurement.
class CycleEngine {
  static const minCycle = 15; // shorter gaps between logged starts are treated as a duplicate log
  static const maxCycle = 60; // longer gaps mean a missed log, so they are not used for averaging
  static const horizonCycles = 3; // how many future periods the calendar projects

  final DateTime today;
  final List<PeriodEntry> periods; // oldest first, one per start day

  late final List<int> lengths; // usable cycle lengths between logged starts
  late final int n; // how many of them
  late final double lengthEstimate;
  late final int lengthDays;
  late final int windowHalf;
  late final int periodDays;
  late final bool hasHistory;
  late final DateTime? lastStart;
  late final DateTime? nextStart;
  late final DateTime? nextStartEarliest;
  late final DateTime? nextStartLatest;
  late final DateTime? ovulation;
  late final DateTime? fertileStart;
  late final DateTime? fertileEnd;
  late final int cycleDay;
  late final int? daysUntilNext; // negative when the period is late
  late final bool isLate; // expected date has passed and no new period is logged
  late final bool periodOngoing;
  late final CyclePhase? phase;
  late final double? averageLength; // of her own logged cycles
  late final double? averagePeriod;
  late final int? spread; // longest minus shortest of her recent cycles
  late final List<_Cycle> _cycles;

  CycleEngine(Iterable<PeriodEntry> logged, DateTime now)
      : today = dayOf(now),
        periods = _clean(logged) {
    hasHistory = periods.isNotEmpty;
    final ls = <int>[];
    for (var i = 0; i + 1 < periods.length; i++) {
      final len = daysBetween(periods[i].start, periods[i + 1].start);
      if (len >= minCycle && len <= maxCycle) ls.add(len);
    }
    lengths = ls;
    n = ls.length;
    final p = kCycleParams;
    final mean = n == 0 ? null : ls.reduce((a, b) => a + b) / n;
    averageLength = mean;
    lengthEstimate = mean == null ? p.lengthMean : (n * mean + p.tau * p.lengthMean) / (n + p.tau);
    lengthDays = lengthEstimate.round();

    // Width of the 'expected between' window: her own spread, pulled towards the population spread
    var sdOwn = 0.0;
    if (n >= 2) {
      final m = mean!;
      sdOwn = math.sqrt(ls.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / (n - 1));
    }
    final w = math.max(n - 1, 0);
    final sdEst = math.sqrt((w * sdOwn * sdOwn + p.sdWeight * p.withinSd * p.withinSd) / (w + p.sdWeight));
    windowHalf = math.max((p.windowZ * sdEst).ceil(), 2);
    final recent = ls.length > 6 ? ls.sublist(ls.length - 6) : ls;
    spread = recent.length >= 2 ? recent.reduce(math.max) - recent.reduce(math.min) : null;

    final ended = <int>[for (final e in periods) if (e.length != null && e.length! >= 1 && e.length! <= 15) e.length!];
    averagePeriod = ended.isEmpty ? null : ended.reduce((a, b) => a + b) / ended.length;
    final m = ended.length;
    periodDays = ((m * (averagePeriod ?? 0) + p.mensesWeight * p.mensesMean) / (m + p.mensesWeight)).round();

    if (!hasHistory) {
      lastStart = null;
      nextStart = null;
      nextStartEarliest = null;
      nextStartLatest = null;
      ovulation = null;
      fertileStart = null;
      fertileEnd = null;
      cycleDay = 0;
      daysUntilNext = null;
      isLate = false;
      periodOngoing = false;
      phase = null;
      _cycles = const [];
      return;
    }

    final last = periods.last;
    lastStart = last.start;
    nextStart = addDays(last.start, lengthDays);
    nextStartEarliest = addDays(nextStart!, -windowHalf);
    nextStartLatest = addDays(nextStart!, windowHalf);
    ovulation = addDays(last.start, lengthDays - p.lutealDays);
    fertileStart = addDays(ovulation!, -5);
    fertileEnd = addDays(ovulation!, 1);
    cycleDay = daysBetween(last.start, today) + 1;
    daysUntilNext = daysBetween(today, nextStart!);
    isLate = daysUntilNext! < 0;
    periodOngoing = last.end == null && daysBetween(last.start, today) <= 14;

    // Every cycle the calendar knows about: logged ones with their real length, then projected ones
    final cs = <_Cycle>[];
    for (var i = 0; i < periods.length; i++) {
      final e = periods[i];
      final isLast = i == periods.length - 1;
      final len = isLast ? lengthDays : daysBetween(e.start, periods[i + 1].start);
      final span = isLast && isLate ? math.max(lengthDays, daysBetween(e.start, today) + 1) : len;
      cs.add(_Cycle(e.start, len, e.length ?? periodDays, projected: isLast, span: span));
    }
    if (!isLate) {
      var s = nextStart!;
      for (var k = 0; k < horizonCycles; k++) {
        cs.add(_Cycle(s, lengthDays, periodDays, projected: true));
        s = addDays(s, lengthDays);
      }
    }
    _cycles = cs;

    phase = phaseOn(today);
  }

  static List<PeriodEntry> _clean(Iterable<PeriodEntry> src) {
    final byDay = <DateTime, PeriodEntry>{for (final e in src) e.start: e};
    final list = byDay.values.toList()..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  _Cycle? _cycleOn(DateTime date) {
    final d = dayOf(date);
    for (final c in _cycles) {
      if (!d.isBefore(c.start) && !d.isAfter(c.end)) return c;
    }
    return null;
  }

  /// The phase on [date] (null before the first logged period, or beyond the projected months).
  CyclePhase? phaseOn(DateTime date) {
    final c = _cycleOn(date);
    if (c == null) return null;
    final i = daysBetween(c.start, date);
    if (i < c.periodLength) return CyclePhase.menstrual;
    final o = c.ovulationIndex;
    if (i >= o - 1 && i <= o + 1) return CyclePhase.ovulation;
    return i < o - 1 ? CyclePhase.follicular : CyclePhase.luteal;
  }

  DayInfo dayInfo(DateTime date) {
    if (!hasHistory) return const DayInfo();
    final d = dayOf(date);
    var period = false;
    var predicted = false;
    var fertile = false;
    var ovul = false;
    for (final e in periods) {
      final last = e.end ?? addDays(e.start, math.max(periodDays, 1) - 1);
      if (d.isBefore(e.start) || d.isAfter(last)) continue;
      if (e.end != null || !d.isAfter(today)) {
        period = true;
      } else {
        predicted = true; // an unfinished period expected to continue
      }
    }
    for (final c in _cycles) {
      if (!c.projected) continue;
      if (c.start != periods.last.start) {
        final endP = addDays(c.start, c.periodLength - 1);
        if (!d.isBefore(c.start) && !d.isAfter(endP)) predicted = true;
      }
      if (!d.isBefore(addDays(c.ovulation, -5)) && !d.isAfter(addDays(c.ovulation, 1)) && d.isAfter(addDays(today, -1))) fertile = true;
      if (d == c.ovulation && !d.isBefore(today)) ovul = true;
    }
    return DayInfo(period: period, predictedPeriod: predicted && !period, fertile: fertile, ovulation: ovul);
  }

  /// Things worth mentioning to the user, most important first.
  List<CycleFlag> get flags {
    final out = <CycleFlag>[];
    if (!hasHistory) return out;
    final sinceStart = daysBetween(lastStart!, today);
    if (sinceStart > 90 && !periodOngoing) {
      out.add(CycleFlag('missed3', 'It has been $sinceStart days since your last logged period. If you did not miss logging one, and you are not pregnant or breastfeeding, please see a doctor.', seeDoctor: true));
    } else if (isLate && !periodOngoing) {
      final by = -daysUntilNext!;
      if (by > windowHalf) {
        out.add(CycleFlag('late', 'Your period is $by day${by == 1 ? '' : 's'} later than expected. Stress, illness, travel and pregnancy can all delay a period. If it is more than a week late, a pregnancy test can help, and please see a doctor if it does not arrive.', seeDoctor: by >= 14));
      }
    }
    if (lengths.isNotEmpty) {
      final lastLen = lengths.last;
      if (lastLen < 21) {
        out.add(CycleFlag('short', 'Your last cycle was $lastLen days. Cycles of 21 to 35 days are typical; frequent shorter cycles are worth mentioning to a doctor.'));
      } else if (lastLen > 35) {
        out.add(CycleFlag('long', 'Your last cycle was $lastLen days. Cycles of 21 to 35 days are typical; repeated longer cycles are worth checking, and are one sign of PCOS.'));
      }
    }
    if (n >= 3 && spread != null && spread! > 7) {
      out.add(CycleFlag('irregular', 'Your recent cycles vary by $spread days, which is more than the 7 days doctors usually consider regular. Irregular cycles can have many causes, and PCOS is one of them: the PCOS check in Femora may help you decide about seeing a doctor.'));
    }
    final lastEnded = periods.reversed.firstWhere((e) => e.length != null, orElse: () => PeriodEntry(start: today));
    if (lastEnded.length != null && lastEnded.length! > 7) {
      out.add(CycleFlag('longperiod', 'Your last period lasted ${lastEnded.length} days. Periods longer than 7 days should be checked by a doctor.', seeDoctor: true));
    }
    return out;
  }

  /// 'regular' / 'irregular' once there are three cycles, otherwise 'not enough cycles yet'.
  String get regularity {
    if (n < 3 || spread == null) return 'not enough cycles yet';
    return spread! > 7 ? 'irregular' : 'regular';
  }

  /// How much to trust the prediction, from the study behind it (ml/cycle_eval.py).
  String get basis {
    if (!hasHistory) return '';
    if (n == 0) {
      return 'Based on the average of 1,665 cycles from a research study, because you have not logged a full cycle yet. '
          'At this stage the date is right within 3 days about two times in three; it becomes personal as you log more.';
    }
    if (n < 3) {
      return 'Based on $n logged cycle${n == 1 ? '' : 's'} mixed with the study average. '
          'It gets more accurate after three cycles.';
    }
    return 'Based on your $n logged cycles. In the research study, predictions like this were within 3 days about 8 times in 10.';
  }

  /// Plain-language lines for the companion (no name, no exact dates beyond what is needed).
  String? companionSummary() {
    if (!hasHistory) return null;
    final b = StringBuffer('Cycle tracking: ');
    if (periodOngoing) {
      b.write('period day $cycleDay (ongoing)');
    } else {
      b.write('day $cycleDay of the cycle${phase == null ? '' : ', ${phase!.label.toLowerCase()}'}');
    }
    if (isLate) {
      b.write('; the period is ${-daysUntilNext!} days later than expected');
    } else {
      b.write('; next period expected in $daysUntilNext days (window ${windowHalf * 2 + 1} days)');
    }
    b.write('; $n cycle${n == 1 ? '' : 's'} logged');
    if (averageLength != null) b.write(', average ${averageLength!.toStringAsFixed(1)} days, ${regularity}');
    if (averagePeriod != null) b.write('; usual period ${averagePeriod!.toStringAsFixed(1)} days');
    final fl = flags;
    if (fl.isNotEmpty) b.write('; notes: ${fl.map((f) => f.id).join(', ')}');
    b.write('.');
    return b.toString();
  }
}
