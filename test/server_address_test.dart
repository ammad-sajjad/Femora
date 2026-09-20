import 'package:femora/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a saved server address overrides the default, and reset restores it', () async {
    final defaultUrl = ApiService.baseUrl;
    expect(await ApiService.setServerOverride(' https://demo.trycloudflare.com/ '), isTrue);
    expect(ApiService.baseUrl, 'https://demo.trycloudflare.com');
    expect((await SharedPreferences.getInstance()).getString('api_base_url'), 'https://demo.trycloudflare.com');
    expect(await ApiService.setServerOverride(''), isTrue);
    expect(ApiService.baseUrl, defaultUrl);
  });

  test('addresses that are not http(s) are rejected and change nothing', () async {
    final defaultUrl = ApiService.baseUrl;
    expect(await ApiService.setServerOverride('not a url'), isFalse);
    expect(await ApiService.setServerOverride('ftp://example.com'), isFalse);
    expect(ApiService.baseUrl, defaultUrl);
  });

  test('the saved address is loaded at startup', () async {
    SharedPreferences.setMockInitialValues({'api_base_url': 'http://192.168.1.5:8000'});
    await ApiService.loadServerOverride();
    expect(ApiService.baseUrl, 'http://192.168.1.5:8000');
    await ApiService.setServerOverride(null);
  });
}
