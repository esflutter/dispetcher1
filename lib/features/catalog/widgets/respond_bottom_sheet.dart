import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';

/// Bottom-sheet «Отклик на заказ»: два состояния — без верификации и
/// верифицированный пользователь.
class RespondBottomSheet extends StatelessWidget {
  const RespondBottomSheet({super.key, required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXL),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.xl + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
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
          if (verified) ..._verifiedContent(context) else ..._unverifiedContent(context),
        ],
      ),
    );
  }

  List<Widget> _verifiedContent(BuildContext context) {
    return <Widget>[
      Text('Ваш отклик отправлен!', style: AppTextStyles.h3),
      SizedBox(height: AppSpacing.xs),
      Text(
        'Заказчик рассмотрит вашу заявку на заказ. Если он выберет вас — '
        'заказ появится в разделе Мои заказы.',
        style: AppTextStyles.bodyMRegular
            .copyWith(color: AppColors.textSecondary),
      ),
      SizedBox(height: AppSpacing.lg),
      PrimaryButton(
        label: 'Ок',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ];
  }

  List<Widget> _unverifiedContent(BuildContext context) {
    return <Widget>[
      Icon(Icons.lock_outline,
          size: 56.r, color: AppColors.primary),
      SizedBox(height: AppSpacing.sm),
      Text('Подтвердите свои данные', style: AppTextStyles.h3),
      SizedBox(height: AppSpacing.xs),
      Text(
        'Чтобы откликаться на заказы, нужно отправить документы на проверку. '
        'Это займёт пару минут.',
        style: AppTextStyles.bodyMRegular
            .copyWith(color: AppColors.textSecondary),
      ),
      SizedBox(height: AppSpacing.lg),
      PrimaryButton(
        label: 'Отправить документы',
        onPressed: () => Navigator.of(context).pop(),
      ),
      SizedBox(height: AppSpacing.xs),
      SecondaryButton(
        label: 'Может быть позже',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ];
  }
}
