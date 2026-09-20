import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/breast.dart';
import '../models/pcos.dart';

class ChatReply {
  final String reply;
  final bool fromModel; // false when the server used its offline fallback
  final String urgency; // none | soon | urgent
  final String language; // en | ur

  const ChatReply({required this.reply, required this.fromModel, required this.urgency, required this.language});

  factory ChatReply.fromJson(Map<String, dynamic> json) => ChatReply(
        reply: json['reply'] as String,
        fromModel: json['source'] == 'gemini',
        urgency: json['urgency'] as String,
        language: json['language'] as String,
      );
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  /// Override with `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000`
  /// when running on a physical phone (use your computer's Wi-Fi IP address).
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  // Server address chosen inside the app (long-press the header): lets a demo point the same APK at a new tunnel address.
  static const String _prefsKey = 'api_base_url';
  static String? _serverOverride;

  static Future<void> loadServerOverride() async {
    try {
      _serverOverride = (await SharedPreferences.getInstance()).getString(_prefsKey);
    } catch (_) {}
  }

  /// Saves the address and returns true, or returns false if [value] is not an http(s) address.
  /// An empty value goes back to the built-in default.
  static Future<bool> setServerOverride(String? value) async {
    final trimmed = (value ?? '').trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) {
      _serverOverride = null;
    } else {
      final uri = Uri.tryParse(trimmed);
      if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) return false;
      _serverOverride = trimmed;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_serverOverride == null) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, _serverOverride!);
      }
    } catch (_) {}
    return true;
  }

  static String get baseUrl {
    if (_serverOverride != null) return _serverOverride!;
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    // The Android emulator reaches the host computer's localhost via 10.0.2.2
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<PcosResult> predictPcos(PcosAnswers answers) async {
    final json = await _post('/predict/pcos', answers.toJson());
    return _parse(() => PcosResult.fromJson(json));
  }

  Future<BreastRiskResult> predictBreastRisk(BreastRiskAnswers answers) async {
    final json = await _post('/predict/breast/risk', answers.toJson());
    return _parse(() => BreastRiskResult.fromJson(json));
  }

  Future<BreastScanResult> predictBreastScan(Uint8List image, String filename) async {
    final json = await _send(
      () async {
        final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/predict/breast/scan'))
          ..files.add(http.MultipartFile.fromBytes('image', image, filename: filename));
        return http.Response.fromStream(await _client.send(request));
      },
      timeout: const Duration(seconds: 45), // upload + CNN inference
    );
    return _parse(() => BreastScanResult.fromJson(json));
  }

  /// One turn with the AI companion. [context] is the compact, name-free summary of the user's own results.
  Future<ChatReply> chat({required List<Map<String, String>> messages, String? context, String language = 'auto'}) async {
    final json = await _post('/chat', {'messages': messages, 'context': context, 'language': language},
        timeout: const Duration(seconds: 40));
    return _parse(() => ChatReply.fromJson(json));
  }

  /// Speech to text: [wav] is a short recording (16 kHz mono WAV).
  Future<String> transcribe(Uint8List wav, {String language = 'auto'}) async {
    final json = await _send(
      () async {
        final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/voice/transcribe'))
          ..fields['language'] = language
          ..files.add(http.MultipartFile.fromBytes('audio', wav, filename: 'recording.wav', contentType: MediaType('audio', 'wav')));
        return http.Response.fromStream(await _client.send(request));
      },
      timeout: const Duration(seconds: 50),
    );
    return _parse(() => (json['text'] as String).trim());
  }

  /// Text to speech: returns a WAV file spoken by the server's voice.
  Future<Uint8List> speak(String text, {String language = 'auto'}) async {
    final http.Response response;
    try {
      response = await _client
          .post(Uri.parse('$baseUrl/voice/speak'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'text': text, 'language': language}))
          .timeout(const Duration(seconds: 70));
    } on TimeoutException {
      throw ApiException('The voice took too long. Please read the text instead.');
    } catch (_) {
      throw ApiException('Could not reach the Femora server. Check your connection and try again.');
    }
    if (response.statusCode != 200) {
      throw ApiException(_detail(response) ?? 'Voice is not available right now.');
    }
    return response.bodyBytes;
  }

  T _parse<T>(T Function() fromJson) {
    try {
      return fromJson();
    } catch (_) {
      throw ApiException('Received an unexpected response from the server. Please update the app.');
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {Duration timeout = const Duration(seconds: 15)}) => _send(
        () => _client.post(
          Uri.parse('$baseUrl$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
        timeout: timeout,
      );

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() request, {required Duration timeout}) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Please try again.');
    } catch (_) {
      throw ApiException('Could not reach the Femora server. Check your connection and try again.');
    }

    if (const {413, 422, 429, 502, 503}.contains(response.statusCode)) {
      // The server explains rejected uploads (e.g. "not an ultrasound") in `detail`;
      // form validation errors come back as a list instead.
      throw ApiException(_detail(response) ?? 'Some answers look invalid. Please review the form.');
    }
    if (response.statusCode != 200) {
      throw ApiException('Server error (${response.statusCode}). Please try again later.');
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Received an unexpected response from the server. Please update the app.');
    }
  }

  String? _detail(http.Response response) {
    try {
      final detail = (jsonDecode(response.body) as Map<String, dynamic>)['detail'];
      return detail is String ? detail : null;
    } catch (_) {
      return null;
    }
  }
}
