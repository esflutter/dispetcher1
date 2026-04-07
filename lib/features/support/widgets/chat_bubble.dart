import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';

/// Тип сообщения чата.
enum ChatMessageType { text, image }

/// Модель одного сообщения для ленты чата поддержки.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.fromUser,
    this.type = ChatMessageType.text,
    this.imageAsset,
  });

  final String id;
  final String text;
  final bool fromUser;
  final ChatMessageType type;
  final String? imageAsset;
}

/// Пузырь сообщения. Входящие — серый surfaceVariant слева,
/// исходящие — оранжевый primary справа.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    final bg = isUser ? AppColors.primary : AppColors.primaryTint;
    final fg = isUser ? Colors.white : AppColors.textPrimary;
    final radius = Radius.circular(8.r);
    final tail = Radius.circular(2.r);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 280.w),
        margin: EdgeInsets.symmetric(vertical: 6.h),
        padding: message.type == ChatMessageType.image
            ? EdgeInsets.all(4.w)
            : EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: isUser ? radius : tail,
            bottomRight: isUser ? tail : radius,
          ),
        ),
        child: message.type == ChatMessageType.image
            ? _ImageContent(message: message, fg: fg)
            : Text(
                message.text,
                style: AppTextStyles.body.copyWith(color: fg),
              ),
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.message, required this.fg});

  final ChatMessage message;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          child: Container(
            width: 220.w,
            height: 160.h,
            color: AppColors.surfaceMuted,
            alignment: Alignment.center,
            child: Icon(
              Icons.image_outlined,
              size: 48.sp,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        if (message.text.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 4.h),
            child: Text(
              message.text,
              style: AppTextStyles.body.copyWith(color: fg),
            ),
          ),
      ],
    );
  }
}

/// Индикатор «печатает…» — три точки в сером пузыре.
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = ((_c.value * 3) - i).clamp(0.0, 1.0);
                final scale = 0.6 + 0.4 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3.w),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: const BoxDecoration(
                        color: AppColors.textTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
