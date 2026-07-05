class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
  });

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
}
