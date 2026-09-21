import 'package:femora/services/reminder_service.dart';

/// Records what would be scheduled instead of touching the phone.
class Recorder extends ReminderService {
  bool supported = true;
  bool allow = true;
  int permissionAsks = 0;
  final scheduled = <({int id, String title, String body, DateTime when, bool daily, String channel})>[];
  final cancelled = <int>[];
  final monthlyDays = <int>[];
  bool monthlyCancelled = false;

  @override
  bool get isSupported => supported;

  @override
  Future<bool> ensurePermission() async {
    permissionAsks++;
    return allow;
  }

  @override
  Future<bool> scheduleAt({required int id, required String channel, required String channelName, required String title, required String body, required DateTime when, bool repeatDaily = false}) async {
    scheduled.add((id: id, title: title, body: body, when: when, daily: repeatDaily, channel: channel));
    return true;
  }

  @override
  Future<void> cancelIds(Iterable<int> ids) async => cancelled.addAll(ids);

  @override
  Future<bool> scheduleMonthly({required int day}) async {
    monthlyDays.add(day);
    return allow;
  }

  @override
  Future<void> cancel() async => monthlyCancelled = true;
}
