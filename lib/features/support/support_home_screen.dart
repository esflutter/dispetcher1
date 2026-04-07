import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/features/support/chat_screen.dart';
import 'package:dispatcher_1/features/support/widgets/chat_input_bar.dart';

/// Стартовый экран ИИ-ассистента поддержки «Диспетчер №1».
/// Приветствие, рекомендованные теги, поле ввода.
class SupportHomeScreen extends StatelessWidget {
  const SupportHomeScreen({super.key});

  static const List<String> _tags = <String>[
    'Задать вопрос',
    'Разместить услугу',
    'Создать карточку исполнителя',
    'Пропустить',
  ];

  void _openChat(BuildContext context, {String? initialMessage}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(initialMessage: initialMessage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text('Поддержка', style: AppTextStyles.titleS),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenH,
                  vertical: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 24.h),
                    Container(
                      width: 96.w,
                      height: 96.w,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryTint,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.support_agent,
                        size: 52.sp,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.lg),
                    Text(
                      'С чего хотите начать?',
                      style: AppTextStyles.h3,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'Задайте вопрос или выберите тему\nиз предложенных',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppSpacing.xxl),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final t in _tags)
                          _SuggestionChip(
                            label: t,
                            onTap: () => _openChat(context, initialMessage: t),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ChatInputBar(
              hint: 'Написать... ',
              showAttach: false,
              onSend: (text) => _openChat(context, initialMessage: text),
              onMicTap: () => _openChat(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryTint,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 10.h,
          ),
          child: Text(
            label,
            style: AppTextStyles.chip.copyWith(color: AppColors.primaryDark),
          ),
        ),
      ),
    );
  }
}
