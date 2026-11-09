// Integration tests for Home Assistant client.
// Verifies auth failure handling and no fabricated responses.
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_app/connectivity/home_assistant/home_assistant_client.dart';

void main() {
  group('HomeAssistantClient', () {
    test('reports not configured when URL empty', () async {
      final client = HomeAssistantClient(baseUrl: '', token: '');
      final result = await client.testConnection();
      expect(result.ok, false);
      expect(result.message, contains('not configured'));
    });

    test('reports token missing when URL set but token empty', () async {
      final client = HomeAssistantClient(baseUrl: 'http://192.168.1.30:8123', token: '');
      final result = await client.testConnection();
      expect(result.ok, false);
      expect(result.message, contains('token'));
    });

    test('never fabricates conversation response without config', () async {
      final client = HomeAssistantClient(baseUrl: '', token: '');
      expect(() => client.sendConversation('hello'), throwsException);
    });
  });
}
