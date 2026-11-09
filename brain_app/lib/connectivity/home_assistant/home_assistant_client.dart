/// Home Assistant client for EDITH/Hermes integration.
///
/// Architecture: User speech -> Phone STT -> Home Assistant -> Hermes agent
/// -> Tool execution -> Response -> Phone TTS -> Bluetooth earbuds.
///
/// This client uses supported Home Assistant APIs only:
/// - REST: GET /api/ (auth check), POST /api/conversation/process
/// - WebSocket: /api/websocket (auth, conversation agent discovery)
///
/// Do not invent endpoints. If Hermes is not exposed as a conversation
/// agent, the connection test will report that clearly.
/// Never log tokens. Never expose HA to the public internet.
library;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class HaConnectionResult {
  final bool ok;
  final String message;
  final List<String> conversationAgents;
  const HaConnectionResult({required this.ok, required this.message, this.conversationAgents = const []});
}

class HomeAssistantClient {
  String baseUrl;
  String? token;
  String? agentId;

  HomeAssistantClient({required this.baseUrl, this.token, this.agentId});

  String get _apiUrl => baseUrl.endsWith('/') ? '${baseUrl}api/' : '$baseUrl/api/';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${token ?? ''}',
        'Content-Type': 'application/json',
      };

  /// Test connection and discover conversation agents.
  Future<HaConnectionResult> testConnection() async {
    if (baseUrl.isEmpty) {
      return const HaConnectionResult(ok: false, message: 'Home Assistant URL not configured. Set it in Settings > EDITH.');
    }
    if (token == null || token!.isEmpty) {
      return const HaConnectionResult(ok: false, message: 'Home Assistant token not configured. Create a long-lived token in HA and paste it in Settings.');
    }
    try {
      final res = await http.get(Uri.parse(_apiUrl), headers: _headers).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        return HaConnectionResult(ok: false, message: 'HA auth failed (HTTP ${res.statusCode}). Check token and URL.');
      }
      // Discover conversation agents via WebSocket
      final agents = await _discoverConversationAgents();
      if (agents.isEmpty) {
        return const HaConnectionResult(
          ok: true,
          message: 'Connected to Home Assistant, but no conversation agent found. Expose Hermes as a conversation agent in HA, or set the agent ID manually.',
        );
      }
      return HaConnectionResult(ok: true, message: 'Connected. Conversation agents: ${agents.join(", ")}', conversationAgents: agents);
    } catch (e) {
      return HaConnectionResult(ok: false, message: 'Connection failed: $e. Check URL is reachable on local network (do not expose HA publicly).');
    }
  }

  Future<List<String>> _discoverConversationAgents() async {
    final agents = <String>[];
    try {
      final wsUrl = '${baseUrl.replaceFirst('http', 'ws')}/api/websocket';
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      // Auth handshake
      final authMsg = await channel.stream.first.timeout(const Duration(seconds: 5));
      final authJson = jsonDecode(authMsg as String) as Map<String, dynamic>;
      if (authJson['type'] != 'auth_required') return [];
      channel.sink.add(jsonEncode({'type': 'auth', 'access_token': token}));
      final authRes = await channel.stream.first.timeout(const Duration(seconds: 5));
      final authResJson = jsonDecode(authRes as String) as Map<String, dynamic>;
      if (authResJson['type'] != 'auth_ok') return [];
      // List conversation agents
      channel.sink.add(jsonEncode({'id': 1, 'type': 'conversation/agent/list'}));
      final listRes = await channel.stream.first.timeout(const Duration(seconds: 5));
      final listJson = jsonDecode(listRes as String) as Map<String, dynamic>;
      final result = listJson['result'] as Map<String, dynamic>?;
      final list = result?['agents'] as List<dynamic>? ?? [];
      for (final a in list) {
        final name = (a as Map<String, dynamic>)['name']?.toString();
        if (name != null) agents.add(name);
      }
      await channel.sink.close();
    } catch (_) {}
    return agents;
  }

  /// Send a conversation request via REST.
  /// Returns the assistant response text, or throws on error.
  Future<String> sendConversation(String text, {String? language}) async {
    if (baseUrl.isEmpty || token == null) {
      throw Exception('Home Assistant not configured.');
    }
    final body = <String, dynamic>{
      'text': text,
      'language': language ?? 'en',
    };
    if (agentId != null && agentId!.isNotEmpty) {
      body['agent_id'] = agentId;
    }
    final res = await http.post(
      Uri.parse('${_apiUrl}conversation/process'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw Exception('HA conversation failed (HTTP ${res.statusCode}): ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final response = json['response'] as Map<String, dynamic>?;
    final speech = response?['speech'] as Map<String, dynamic>?;
    final plain = speech?['plain'] as Map<String, dynamic>?;
    return plain?['speech']?.toString() ?? 'No response from assistant.';
  }
}
