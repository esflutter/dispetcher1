import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/ai/ai_client.dart';
import 'package:dispatcher_1/core/ai/stt_recorder.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/utils/photo_source.dart';
import 'package:dispatcher_1/features/support/widgets/chat_bubble.dart';
import 'package:dispatcher_1/features/support/widgets/chat_input_bar.dart';

/// Экран чата с ИИ-ассистентом «Поддержка».
///
/// Режимы:
///   - chat            — обычный FAQ
///   - slotFillOrder   — пошаговое создание заказа
///   - search          — поиск исполнителя по описанию
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.initialMessage});

  final String? initialMessage;

  static void resetHistory() {
    _ChatScreenState.resetHistory();
    AiClient.instance.resetSessions();
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static final List<ChatMessage> _messages = <ChatMessage>[
    const ChatMessage(
      id: 'm1',
      text: 'Здравствуйте! Я помогу создать заказ, найти исполнителя или '
            'ответить на вопрос по приложению. С чего начнём?',
      fromUser: false,
    ),
  ];

  static AiChatKind _mode = AiChatKind.chat;
  static int _idCounter = 0;

  static void resetHistory() {
    _messages
      ..clear()
      ..add(const ChatMessage(
        id: 'm1',
        text: 'Здравствуйте! Я помогу создать заказ, найти исполнителя или '
              'ответить на вопрос по приложению. С чего начнём?',
        fromUser: false,
      ));
    _mode = AiChatKind.chat;
    _idCounter = 0;
  }

  final List<String> _pendingImages = <String>[];
  final ScrollController _scrollController = ScrollController();
  bool _isRecording = false;
  bool _isProcessing = false;

  bool get _showQuickActions =>
      _messages.length == 1 && !_messages.first.fromUser && _pendingImages.isEmpty && !_isProcessing;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMessage?.trim();
    if (initial == null || initial.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: true));
      return;
    }

    if (initial == 'create_order' || initial == 'Разместить заказ') {
      _mode = AiChatKind.slotFillOrder;
      _addBotMessage('Опишите заказ — текстом или голосом, я заполню всё за вас.');
      return;
    }
    if (initial == 'find_executor' || initial == 'Найти исполнителя') {
      _mode = AiChatKind.search;
      _addBotMessage('Опишите задачу и регион — найду подходящих исполнителей.');
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mode = AiChatKind.chat;
      _handleSend(initial);
    });
  }

  void _addBotMessage(String text, {Map<String, dynamic>? data, ChatMessageType type = ChatMessageType.text}) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        id:   _nextId(),
        text: text,
        fromUser: false,
        type: type,
        data: data,
      ));
    });
    _scrollToBottom();
  }

  String _nextId() {
    _idCounter += 1;
    return 'm${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: jump));
      return;
    }
    final pos = _scrollController.position.maxScrollExtent;
    if (jump) {
      _scrollController.jumpTo(pos);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _handleSend(String text) async {
    final hasImages = _pendingImages.isNotEmpty;
    if (text.isEmpty && !hasImages) return;
    if (_isProcessing) return;

    setState(() {
      if (hasImages) {
        _messages.add(ChatMessage(
          id:   _nextId(),
          text: '',
          fromUser: true,
          type: ChatMessageType.image,
          imageAssets: List<String>.from(_pendingImages),
        ));
        _pendingImages.clear();
      }
      if (text.isNotEmpty) {
        _messages.add(ChatMessage(id: _nextId(), text: text, fromUser: true));
      }
    });
    _scrollToBottom();
    if (text.isEmpty) return;
    await _sendToAssistant(text);
  }

  Future<void> _sendToAssistant(String text) async {
    setState(() => _isProcessing = true);
    _scrollToBottom();
    try {
      final AiReply reply;
      switch (_mode) {
        case AiChatKind.search:
          reply = await AiClient.instance.search(text);
          break;
        case AiChatKind.slotFillOrder:
          reply = await AiClient.instance.slotFillOrder(text);
          break;
        case AiChatKind.slotFillService:
          reply = await AiClient.instance.chat(text);
          break;
        case AiChatKind.chat:
          reply = await AiClient.instance.chat(text);
          break;
      }
      _appendReply(reply);
    } on AiQuotaExceeded catch (e) {
      _addBotMessage(e.message);
    } on AiContentFilterError catch (e) {
      _addBotMessage(e.message);
    } catch (_) {
      _addBotMessage(
        'Не удалось получить ответ. Проверьте интернет и попробуйте снова.',
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _appendReply(AiReply reply) {
    final kind = reply.dataKind;
    if (kind == 'executor_cards' && reply.items.isNotEmpty) {
      _addBotMessage(reply.text, type: ChatMessageType.executorCards, data: reply.data);
      return;
    }
    if (kind == 'order_cards' && reply.items.isNotEmpty) {
      _addBotMessage(reply.text, type: ChatMessageType.orderCards, data: reply.data);
      return;
    }
    if ((kind == 'order_draft' || kind == 'service_draft') && reply.isDraftReady) {
      _addBotMessage(reply.text, type: ChatMessageType.draftReady, data: reply.data);
      return;
    }
    _addBotMessage(reply.text);
  }

  Future<void> _handleAttach() async {
    final int remaining = 8 - _pendingImages.length;
    if (remaining <= 0) return;
    final picked = await pickMultipleImagesFromGallery(limit: remaining, context: context);
    if (picked.isEmpty || !mounted) return;
    final kept = picked.length > remaining ? picked.sublist(0, remaining) : picked;
    setState(() => _pendingImages.addAll(kept));
    if (picked.length > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          'Можно добавить не более 8 фото. Добавлены первые ${kept.length}.',
        )),
      );
    }
  }

  void _removePendingImage(int index) {
    setState(() => _pendingImages.removeAt(index));
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _cancelRecording();
      return;
    }
    final ok = await SttRecorder.instance.ensurePermission();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'Нет доступа к микрофону. Откройте настройки приложения и включите его.',
          )),
        );
      }
      return;
    }
    final started = await SttRecorder.instance.start();
    if (!started) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось начать запись')),
        );
      }
      return;
    }
    setState(() => _isRecording = true);
  }

  Future<void> _cancelRecording() async {
    await SttRecorder.instance.cancel();
    if (mounted) setState(() => _isRecording = false);
  }

  Future<void> _sendVoice() async {
    final File? audio = await SttRecorder.instance.stop();
    if (mounted) setState(() => _isRecording = false);
    if (audio == null) return;

    setState(() => _isProcessing = true);
    try {
      final text = await AiClient.instance.transcribeAudio(audio);
      try { await audio.delete(); } catch (_) {}
      if (!mounted) return;
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось распознать речь — попробуйте ещё раз')),
        );
        setState(() => _isProcessing = false);
        return;
      }
      setState(() {
        _messages.add(ChatMessage(id: _nextId(), text: text, fromUser: true));
      });
      _scrollToBottom();
      await _sendToAssistant(text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка распознавания голоса')),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: EdgeInsets.only(top: 4.h),
          child: Text(
            'Поддержка',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textBlack,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 4.w),
            child: IconButton(
              padding: EdgeInsets.only(top: 4.h),
              icon: Image.asset('assets/icons/support/close.webp', width: 26.r, height: 26.r),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/shell');
                }
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.h),
          child: Container(height: 1.h, color: AppColors.divider),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              itemCount: _messages.length + (_isProcessing ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox.shrink(),
              itemBuilder: (context, index) {
                if (index < _messages.length) {
                  return ChatBubble(message: _messages[index]);
                }
                return const TypingBubble();
              },
            ),
          ),
          if (_showQuickActions)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 54.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QuickActionChip(
                      label: 'Разместить заказ',
                      onTap: () {
                        _mode = AiChatKind.slotFillOrder;
                        _handleSend('Хочу разместить заказ');
                      },
                    ),
                    SizedBox(height: 8.h),
                    _QuickActionChip(
                      label: 'Найти исполнителя',
                      onTap: () {
                        _mode = AiChatKind.search;
                        _handleSend('Найди подходящего исполнителя');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ChatInputBar(
            isRecording: _isRecording,
            pendingImages: _pendingImages,
            onRemovePendingImage: _removePendingImage,
            onSend: _handleSend,
            onAttach: _handleAttach,
            onMicTap: _toggleRecording,
            onCancelRecording: _cancelRecording,
            onSendVoice: _sendVoice,
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            height: 36.h,
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
