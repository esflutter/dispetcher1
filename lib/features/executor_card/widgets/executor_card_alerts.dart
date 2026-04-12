import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/features/catalog/widgets/respond_bottom_sheet.dart';

Future<void> showCreateExecutorCardAlert(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => const RespondModalDialog(verified: false),
  );
}

/// Bottom-sheet алерт подтверждения удаления карточки исполнителя.
Future<bool?> showDeleteExecutorCardAlert(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AppSpacing.sm),
            Text(
              'Вы уверены, что хотите\nудалить карточку?',
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 54.h,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                  ),
                ),
                child: Text('Удалить',
                    style:
                        AppTextStyles.button.copyWith(color: Colors.white)),
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Отмена',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    ),
  );
}
