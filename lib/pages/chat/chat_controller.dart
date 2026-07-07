import 'package:flutter/foundation.dart';

import '../../models/chat_message.dart';
import '../../services/open_router_service.dart';
import '../../services/settings_service.dart';
import 'chat_state.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    OpenRouterService? openRouterService,
    SettingsService? settingsService,
  })  : _openRouterService = openRouterService ?? const OpenRouterService(),
        _settingsService = settingsService ?? SettingsService();

  final OpenRouterService _openRouterService;
  final SettingsService _settingsService;

  static const _systemPrompt =
      '''You are an empathetic energy and wellness coach inside the Batterie app. Your role is to help users understand their physical and mental energy patterns, offer practical advice, and support their day.

Keep answers concise, warm, and actionable. You can ask follow-up questions about sleep, nutrition, movement, stress, or mood. Never give medical diagnoses.''';

  ChatState _state = const ChatState();

  ChatState get state => _state;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _state.isSending) return;

    final userMsg = ChatMessage(role: 'user', content: text.trim());
    final updatedMessages = [..._state.messages, userMsg];

    _state = _state.copyWith(
      messages: updatedMessages,
      isSending: true,
      error: null,
    );
    notifyListeners();

    try {
      final apiKey = _settingsService.getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        _state = _state.copyWith(
          isSending: false,
          error: 'No API key set. Please add your OpenRouter key in Settings.',
        );
        notifyListeners();
        return;
      }

      final apiMessages = [
        const ChatMessage(role: 'system', content: _systemPrompt),
        ...updatedMessages,
      ];

      final reply = await _openRouterService.sendChatMessage(
        apiKey: apiKey,
        messages: apiMessages,
      );

      _state = _state.copyWith(
        messages: [
          ...updatedMessages,
          ChatMessage(role: 'assistant', content: reply),
        ],
        isSending: false,
      );
    } catch (e) {
      _state = _state.copyWith(
        isSending: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }

    notifyListeners();
  }
}
