import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';

/// Боттом-шит «Принять заказ?» — алерт перед подтверждением.
Future<void> showAcceptAlert(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXL)),
    ),
    builder: (ctx) => _SheetBody(
      title: 'Принять заказ?',
      message: 'Вы уверены, что хотите принять заказ?',
      primaryLabel: 'Подтвердить',
      onPrimary: () => Navigator.of(ctx).pop(),
      secondaryLabel: 'Вернуться',
    ),
  );
}

/// Боттом-шит «Оставьте отзыв» — приглашение оставить отзыв.
Future<void> showReviewPromptSheet(
  BuildContext context, {
  required VoidCallback onLeaveReview,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXL)),
    ),
    builder: (ctx) => _SheetBody(
      title: 'Оставьте отзыв',
      message: 'Поделитесь впечатлениями о заказчике — это поможет другим исполнителям.',
      primaryLabel: 'Оставить отзыв',
      onPrimary: () {
        Navigator.of(ctx).pop();
        onLeaveReview();
      },
      secondaryLabel: 'Позже',
    ),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.md,
          AppSpacing.screenH,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
            SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            PrimaryButton(label: primaryLabel, onPressed: onPrimary),
            SizedBox(height: AppSpacing.xs),
            SecondaryButton(
              label: secondaryLabel,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
