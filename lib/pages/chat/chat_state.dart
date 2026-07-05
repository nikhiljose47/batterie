import '../../models/chat_message.dart';

class ChatState {
  const ChatState({
    this.messages = const <ChatMessage>[],
    this.isSending = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool isSending;
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}
