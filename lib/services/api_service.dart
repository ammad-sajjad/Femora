import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/pcos.dart';

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

  static String get baseUrl {
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
    try {
      return PcosResult.fromJson(json);
    } catch (_) {
      throw ApiException('Received an unexpected response from the server. Please update the app.');
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Please try again.');
    } catch (_) {
      throw ApiException('Could not reach the Femora server. Check your connection and try again.');
    }

    if (response.statusCode == 422) {
      throw ApiException('Some answers look invalid. Please review the form.');
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
}
