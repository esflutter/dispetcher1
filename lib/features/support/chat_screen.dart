import 'package:flutter/material.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/features/support/widgets/chat_bubble.dart';
import 'package:dispatcher_1/features/support/widgets/chat_input_bar.dart';
import 'package:dispatcher_1/features/support/widgets/photo_picker_sheet.dart';

/// Экран чата с ИИ-ассистентом поддержки.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.initialMessage});

  final String? initialMessage;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const List<ChatMessage> _seed = <ChatMessage>[
    ChatMessage(
      id: 'm1',
      text: 'Здравствуйте! Чем могу помочь?',
      fromUser: false,
    ),
  ];

  final List<ChatMessage> _messages = List<ChatMessage>.from(_seed);
  bool _isTyping = false;
  bool _isRecording = false;
  int _idCounter = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMessage;
    if (initial != null && initial.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSend(initial.trim());
      });
    }
  }

  String _nextId() {
    _idCounter += 1;
    return 'u${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }

  void _handleSend(String text) {
    setState(() {
      _messages.insert(
        0,
        ChatMessage(id: _nextId(), text: text, fromUser: true),
      );
      _isTyping = true;
    });
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.insert(
          0,
          ChatMessage(
            id: _nextId(),
            text: 'Спасибо за вопрос! Я подготовлю ответ.',
            fromUser: false,
          ),
        );
      });
    });
  }

  Future<void> _handleAttach() async {
    final source = await PhotoPickerSheet.show(context);
    if (source == null || !mounted) return;
    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          id: _nextId(),
          text: '',
          fromUser: true,
          type: ChatMessageType.image,
        ),
      );
    });
  }

  void _toggleRecording() {
    setState(() => _isRecording = !_isRecording);
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _messages.length + (_isTyping ? 1 : 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        centerTitle: true,
        title: Text('Поддержка', style: AppTextStyles.titleS),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenH,
                  vertical: AppSpacing.sm,
                ),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (_isTyping && index == 0) {
                    return const TypingBubble();
                  }
                  final msg = _messages[index - (_isTyping ? 1 : 0)];
                  return ChatBubble(message: msg);
                },
              ),
            ),
            ChatInputBar(
              onSend: _handleSend,
              onAttach: _handleAttach,
              onMicTap: _toggleRecording,
              isRecording: _isRecording,
            ),
          ],
        ),
      ),
    );
  }
}
