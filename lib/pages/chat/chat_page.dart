import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import 'chat_controller.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatController _controller;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = ChatController();
    _controller.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    _controller.removeListener(_scrollToBottom);
    _controller.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text;
    _textController.clear();
    await _controller.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: <Widget>[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.bolt, color: Colors.white, size: 18),
            ),
            SizedBox(width: AppSpacing.small),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'AI Energy Coach',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Powered by OpenRouter',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final state = _controller.state;
          return Column(
            children: <Widget>[
              Expanded(
                child: state.messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.large,
                          vertical: AppSpacing.medium,
                        ),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final msg = state.messages[index];
                          return _MessageBubble(
                            content: msg.content,
                            isUser: msg.role == 'user',
                          );
                        },
                      ),
              ),
              if (state.error != null)
                _ErrorBanner(message: state.error!),
              if (state.isSending)
                const _TypingIndicator(),
              _InputBar(
                controller: _textController,
                isSending: state.isSending,
                onSend: _send,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.surfaceTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bolt,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.large),
            Text(
              'Your Energy Coach',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              'Ask me about your energy levels, sleep quality, recovery tips, or anything wellness-related.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
            const SizedBox(height: AppSpacing.xLarge),
            ..._suggestions.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.small),
                child: ActionChip(
                  label: Text(s),
                  onPressed: () {
                    _textController.text = s;
                    _send();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<String> _suggestions = <String>[
    'How can I improve my energy today?',
    'I slept only 5 hours, what should I do?',
    'Tips for afternoon energy slump?',
  ];
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.content, required this.isUser});

  final String content;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: AppSpacing.small,
          bottom: AppSpacing.small,
          left: isUser ? 64 : 0,
          right: isUser ? 0 : 64,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.large,
          vertical: AppSpacing.medium,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surfaceTint,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppSpacing.xLarge),
            topRight: const Radius.circular(AppSpacing.xLarge),
            bottomLeft: Radius.circular(isUser ? AppSpacing.xLarge : 4),
            bottomRight: Radius.circular(isUser ? 4 : AppSpacing.xLarge),
          ),
        ),
        child: Text(
          content,
          style: TextStyle(
            color: isUser ? Colors.white : null,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
          left: AppSpacing.large,
          bottom: AppSpacing.small,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.large,
          vertical: AppSpacing.medium,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceTint,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppSpacing.xLarge),
            topRight: Radius.circular(AppSpacing.xLarge),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(AppSpacing.xLarge),
          ),
        ),
        child: const SizedBox(
          width: 40,
          height: 16,
          child: _ThreeDots(),
        ),
      ),
    );
  }
}

class _ThreeDots extends StatefulWidget {
  const _ThreeDots();

  @override
  State<_ThreeDots> createState() => _ThreeDotsState();
}

class _ThreeDotsState extends State<_ThreeDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final offset = ((_controller.value * 3 - i) % 1.0).abs();
            final opacity = offset < 0.5 ? 1.0 - offset * 2 : (offset - 0.5) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity.clamp(0.2, 1.0),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF0F0),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.large,
        vertical: AppSpacing.small,
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.error, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.large,
          AppSpacing.small,
          AppSpacing.small,
          AppSpacing.small,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Ask your energy coach...',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.xLarge),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.xLarge),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.large,
                    vertical: AppSpacing.medium,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.small),
            isSending
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.medium),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton.filled(
                    onPressed: onSend,
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
