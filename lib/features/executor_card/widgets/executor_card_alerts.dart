import 'package:flutter/material.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/bottom_sheet_handle.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';

/// Bottom-sheet алерт «Подтвердите свои данные» — приглашение
/// отправить документы на верификацию.
Future<void> showDeleteExecutorCardAlert(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXL),
      ),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BottomSheetHandle(),
            SizedBox(height: AppSpacing.md),
            Text(
              'Подтвердите свои данные',
              style: AppTextStyles.titleL,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Чтобы создать карточку исполнителя, нужно отправить документы '
              'на проверку. Это займёт пару минут.',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Отправить документы',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Может быть позже',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
