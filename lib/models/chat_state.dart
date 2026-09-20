import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'health_store.dart';

class ChatMsg {
  final String id;
  final String text;
  final bool isUser;
  final DateTime time;
  final bool urgent; // the server flagged this exchange as needing a doctor now
  final bool offline; // answered by the server's offline fallback, not the language model

  const ChatMsg({required this.id, required this.text, required this.isUser, required this.time, this.urgent = false, this.offline = false});

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'isUser': isUser, 'time': time.toIso8601String(), 'urgent': urgent, 'offline': offline};

  factory ChatMsg.fromJson(Map<String, dynamic> j) => ChatMsg(
        id: j['id'] as String,
        text: j['text'] as String,
        isUser: j['isUser'] as bool,
        time: DateTime.parse(j['time'] as String),
        urgent: (j['urgent'] as bool?) ?? false,
        offline: (j['offline'] as bool?) ?? false,
      );
}

/// The conversation with the AI companion. History is kept on the phone.
class ChatState extends ChangeNotifier {
  static const _key = 'companion_chat_v1';
  static const maxStored = 60;
  static const maxHistoryForModel = 9; // previous messages sent along with the new one (the server accepts 12 in total)

  final ApiService _api;

  ChatState({ApiService? api}) : _api = api ?? ApiService();

  List<ChatMsg> _messages = [];
  List<ChatMsg> get messages => List.unmodifiable(_messages);

  bool _sending = false;
  bool get sending => _sending;

  String? _error;
  String? get error => _error;

  String? _lastQuestion;
  String? get lastQuestion => _lastQuestion;

  int _seq = 0;
  String _nextId() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  Future<void> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw != null) {
        _messages = (jsonDecode(raw) as List).map((e) => ChatMsg.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      _messages = [];
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final keep = _messages.length > maxStored ? _messages.sublist(_messages.length - maxStored) : _messages;
      await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(keep.map((m) => m.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> clear() async {
    _messages = [];
    _error = null;
    notifyListeners();
    await _save();
  }

  /// Sends [text] to the companion. Returns the reply text on success, or null on failure ([error] then says why).
  Future<String?> send(String text, {required HealthStore store, DateTime? lastSelfExam}) async {
    final question = text.trim();
    if (question.isEmpty || _sending) return null;
    _error = null;
    _lastQuestion = question;

    // Recent turns for the model: it must start with a user message
    var history = List<ChatMsg>.of(_messages);
    if (history.length > maxHistoryForModel) history = history.sublist(history.length - maxHistoryForModel);
    while (history.isNotEmpty && !history.first.isUser) {
      history = history.sublist(1);
    }
    final wire = [
      for (final m in history) {'role': m.isUser ? 'user' : 'assistant', 'text': m.text},
      {'role': 'user', 'text': question},
    ];

    _messages = [..._messages, ChatMsg(id: _nextId(), text: question, isUser: true, time: DateTime.now())];
    _sending = true;
    notifyListeners();
    await _save();

    String? reply;
    try {
      final context = store.profile.personalize ? store.companionContext(lastSelfExam: lastSelfExam) : null;
      final r = await _api.chat(messages: wire, context: (context == null || context.isEmpty) ? null : context);
      _messages = [..._messages, ChatMsg(id: _nextId(), text: r.reply, isUser: false, time: DateTime.now(), urgent: r.urgency == 'urgent', offline: !r.fromModel)];
      reply = r.reply;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _sending = false;
      notifyListeners();
      await _save();
    }
    return reply;
  }

  /// Removes the last unanswered question so it can be re-sent (used by "Try again").
  String? takeLastUnanswered() {
    if (_messages.isNotEmpty && _messages.last.isUser) {
      final q = _messages.last.text;
      _messages = _messages.sublist(0, _messages.length - 1);
      _error = null;
      notifyListeners();
      return q;
    }
    return null;
  }
}
