/// Hermes adapter — thin layer over Home Assistant.
///
/// The Brain App does NOT create a second EDITH intelligence.
/// It does NOT replace Hermes, duplicate its memory, skills, plugins,
/// Telegram bot, or gateway. It talks to the existing Hermes agent
/// via Home Assistant's conversation API.
///
/// If Hermes is not exposed through HA, this adapter reports that
/// clearly instead of inventing a direct endpoint.
library;

import '../home_assistant/home_assistant_client.dart';

enum HermesActivityStage {
  understanding,
  searching,
  reading,
  reasoning,
  executingTool,
  waiting,
  requestingConfirmation,
  preparingResponse,
  completed,
  failed,
}

class HermesAdapter {
  final HomeAssistantClient ha;

  HermesAdapter({required this.ha});

  /// Send a user request to Hermes via HA. Returns response text.
  /// Activity stages are only reported when HA/Hermes exposes them;
  /// otherwise only understanding -> preparingResponse -> completed/failed
  /// are shown. Never fabricate tool execution.
  Future<String> sendRequest(
    String text, {
    String? language,
    void Function(HermesActivityStage stage)? onStage,
  }) async {
    onStage?.call(HermesActivityStage.understanding);
    try {
      final response = await ha.sendConversation(text, language: language);
      onStage?.call(HermesActivityStage.preparingResponse);
      onStage?.call(HermesActivityStage.completed);
      return response;
    } catch (e) {
      onStage?.call(HermesActivityStage.failed);
      rethrow;
    }
  }

  Future<bool> isAvailable() async {
    final result = await ha.testConnection();
    return result.ok && result.conversationAgents.isNotEmpty;
  }
}
