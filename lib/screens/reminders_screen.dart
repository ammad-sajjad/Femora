import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/health_store.dart';
import '../models/reminders.dart';
import '../models/self_exam.dart';
import '../theme/app_theme.dart';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtTime(int h, int m) {
  final hour = h % 12 == 0 ? 12 : h % 12;
  return '$hour:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

TextStyle _s(double size, {FontWeight w = FontWeight.w400, Color c = AppColors.textDark, double? h}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, height: h);

/// Scope 6.8: reminders for the next period, the fertile window, logging your day, medication and the monthly self-exam.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  Future<void> _change(BuildContext context, ReminderSettings next) async {
    final store = context.read<HealthStore>();
    final err = await context.read<RemindersState>().update(next, store.cycle);
    if (err != null && context.mounted) _say(context, err);
  }

  void _say(BuildContext context, String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF7A2E3E)),
      );

  Future<void> _pickTime(BuildContext context, int h, int m, Future<void> Function(int, int) done) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: h, minute: m));
    if (t != null) await done(t.hour, t.minute);
  }

  Future<void> _addMedication(BuildContext context) async {
    final store = context.read<HealthStore>();
    final state = context.read<RemindersState>();
    final name = TextEditingController();
    var hour = 8;
    var minute = 0;
    final err = await showDialog<String?>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setState) => AlertDialog(
          title: const Text('Medication reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(key: const Key('med_name'), controller: name, maxLength: ReminderSettings.maxNameLength, decoration: const InputDecoration(labelText: 'Name of the medicine')),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                key: const Key('med_pick_time'),
                onPressed: () async {
                  final t = await showTimePicker(context: dialog, initialTime: TimeOfDay(hour: hour, minute: minute));
                  if (t != null) setState(() => (hour, minute) = (t.hour, t.minute));
                },
                icon: const Icon(Icons.access_time_rounded),
                label: Text('Every day at ${fmtTime(hour, minute)}'),
              ),
              const SizedBox(height: 8),
              Text('Femora only reminds you. Ask your doctor or pharmacist how to take any medicine.', style: _s(11.5, c: AppColors.textMuted, h: 1.35)),
            ],
          ),
          actions: [
            TextButton(key: const Key('med_cancel'), onPressed: () => Navigator.pop(dialog, 'cancelled'), child: const Text('Cancel')),
            FilledButton(
              key: const Key('med_confirm'),
              onPressed: () async {
                final e = await state.addMedication(name.text, hour, minute, store.cycle);
                if (dialog.mounted) Navigator.pop(dialog, e);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (err != null && err != 'cancelled' && context.mounted) _say(context, err);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RemindersState>();
    final store = context.watch<HealthStore>();
    final exam = context.watch<SelfExamState>();
    final engine = store.cycle;
    final s = state.settings;
    final upcoming = state.upcoming(engine);

    Widget card({required Widget child}) => Container(
          margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(22), boxShadow: AppTheme.softShadow),
          child: Material(color: Colors.transparent, child: child), // switch tiles paint their ink on the nearest Material
        );

    Widget switchRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged, Key key) => SwitchListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primaryBerry,
          title: Text(title, style: _s(14.5, w: FontWeight.w700)),
          subtitle: Text(subtitle, style: _s(12, c: AppColors.textMuted, h: 1.35)),
          value: value,
          onChanged: onChanged,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        leading: IconButton(key: const Key('reminders_back'), icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.maybePop(context)),
        title: const Text('Reminders', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            if (!state.supported)
              Container(
                key: const Key('rem_unsupported'),
                margin: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.aiInsightBg, borderRadius: BorderRadius.circular(16)),
                child: Text('Reminders are sent by the Femora app on your phone. You can set them up here, but they only arrive on Android or iPhone.', style: _s(12.5, h: 1.4)),
              ),
            card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  switchRow('Period coming up', 'A reminder before your next period is expected.', s.period, (v) => _change(context, s.copyWith(period: v)), const Key('rem_period')),
                  if (s.period) ...[
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final n in [0, 1, 2, 3])
                          ChoiceChip(
                            key: Key('rem_before_$n'),
                            label: Text(n == 0 ? 'On the day' : '$n day${n == 1 ? '' : 's'} before'),
                            selected: s.periodDaysBefore == n,
                            selectedColor: const Color(0xFFFFDFE8),
                            onSelected: (_) => _change(context, s.copyWith(periodDaysBefore: n)),
                          ),
                      ],
                    ),
                    if (!engine.hasHistory)
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text('Log the first day of your last period in the Cycle tab so there is a date to remind you about.', key: const Key('rem_need_period'), style: _s(12, c: AppColors.textMuted, h: 1.35))),
                  ],
                  const Divider(height: 22),
                  switchRow('Fertile window and ovulation', 'When your estimated fertile window starts and on your estimated ovulation day. An estimate, not contraception.', s.fertile, (v) => _change(context, s.copyWith(fertile: v)), const Key('rem_fertile')),
                ],
              ),
            ),
            card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  switchRow('Log my day', 'A daily nudge to log symptoms, mood and sleep.', s.dailyLog, (v) => _change(context, s.copyWith(dailyLog: v)), const Key('rem_daily')),
                  if (s.dailyLog)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const Key('rem_daily_time'),
                        onPressed: () => _pickTime(context, s.dailyHour, s.dailyMinute, (h, m) => _change(context, s.copyWith(dailyHour: h, dailyMinute: m))),
                        icon: const Icon(Icons.access_time_rounded, size: 18),
                        label: Text('Every day at ${fmtTime(s.dailyHour, s.dailyMinute)}'),
                      ),
                    ),
                  const Divider(height: 22),
                  switchRow(
                    'Monthly breast self-exam',
                    exam.lastExam == null ? 'A monthly reminder to check your breasts.' : 'A monthly reminder, on the day of your last exam.',
                    exam.reminderOn,
                    (v) async {
                      final err = await exam.setReminder(v);
                      if (err != null && context.mounted) _say(context, err);
                    },
                    const Key('rem_selfexam'),
                  ),
                ],
              ),
            ),
            card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Medication', style: _s(15, w: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Daily reminders for medicines or supplements you take.', style: _s(12, c: AppColors.textMuted)),
                  for (final m in s.medications)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name, style: _s(14, w: FontWeight.w600)),
                                GestureDetector(
                                  key: Key('med_time_${m.id}'),
                                  onTap: () => _pickTime(context, m.hour, m.minute, (h, min) async {
                                    final err = await state.setMedicationTime(m.id, h, min, store.cycle);
                                    if (err != null && context.mounted) _say(context, err);
                                  }),
                                  child: Text('Every day at ${fmtTime(m.hour, m.minute)}', style: _s(12, c: AppColors.primaryBerry, w: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            key: Key('med_switch_${m.id}'),
                            activeColor: AppColors.primaryBerry,
                            value: m.enabled,
                            onChanged: (v) async {
                              final err = await state.setMedicationEnabled(m.id, v, store.cycle);
                              if (err != null && context.mounted) _say(context, err);
                            },
                          ),
                          IconButton(key: Key('med_delete_${m.id}'), icon: const Icon(Icons.delete_outline_rounded, size: 20), onPressed: () => state.removeMedication(m.id, store.cycle)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  TextButton.icon(key: const Key('med_add'), onPressed: () => _addMedication(context), icon: const Icon(Icons.add_rounded), label: const Text('Add a medication reminder')),
                  Text('Femora only reminds you. It does not suggest medicines or doses; ask your doctor or pharmacist.', style: _s(11, c: AppColors.textLight, h: 1.35)),
                ],
              ),
            ),
            card(
              child: Column(
                key: const Key('rem_upcoming'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Coming up', style: _s(15, w: FontWeight.w700)),
                  const SizedBox(height: 6),
                  if (upcoming.isEmpty)
                    Text('No reminders are set. Switch one on above.', key: const Key('rem_none'), style: _s(12.5, c: AppColors.textMuted))
                  else
                    for (final r in upcoming.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 118,
                              child: Text(
                                r.repeatsDaily ? 'Every day, ${fmtTime(r.when.hour, r.when.minute)}' : '${_days[r.when.weekday - 1]} ${r.when.day} ${_months[r.when.month - 1]}, ${fmtTime(r.when.hour, r.when.minute)}',
                                style: _s(11.5, c: AppColors.primaryBerry, w: FontWeight.w700, h: 1.3),
                              ),
                            ),
                            Expanded(child: Text(r.kind == ReminderKind.medication ? '${r.title}: ${r.body}' : r.title, style: _s(12.5, h: 1.3))),
                          ],
                        ),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text('Reminders are scheduled on your phone and never leave it. Period and fertile-window dates are estimates that move when you log a new period.', style: _s(11, c: AppColors.textLight, h: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}
