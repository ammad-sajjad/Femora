import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/breast.dart';
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

  T _parse<T>(T Function() fromJson) {
    try {
      return fromJson();
    } catch (_) {
      throw ApiException('Received an unexpected response from the server. Please update the app.');
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) => _send(
        () => _client.post(
          Uri.parse('$baseUrl$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
        timeout: const Duration(seconds: 15),
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

    if (response.statusCode == 413 || response.statusCode == 422) {
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
