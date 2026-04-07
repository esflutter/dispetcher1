import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';

/// Экран отзыва — 5 звёзд + поле комментария + «Отправить».
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 0;
  final TextEditingController _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Как всё прошло?', style: AppTextStyles.titleS),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: AppSpacing.lg),
              Text('Оцените пользователя',
                  style: AppTextStyles.bodyMedium),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Ваш отзыв поможет другим понять, с кем лучше работать. Оцените заказчика и при желании оставьте комментарий.',
                style: AppTextStyles.subBody
                    .copyWith(color: AppColors.textTertiary),
              ),
              SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < _rating;
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                    child: GestureDetector(
                      onTap: () => setState(() => _rating = i + 1),
                      child: Icon(
                        Icons.star_rounded,
                        size: 44.r,
                        color: filled ? AppColors.primary : AppColors.divider,
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: AppSpacing.lg),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: TextField(
                  controller: _comment,
                  maxLines: 5,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Введите комментарий',
                    hintStyle: AppTextStyles.body
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Оставить отзыв',
                enabled: _rating > 0,
                onPressed: _rating > 0
                    ? () => Navigator.of(context).maybePop()
                    : null,
              ),
              SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
