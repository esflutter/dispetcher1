import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';

/// Карточка услуги в списке «Мои услуги».
class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.title,
    required this.category,
    required this.pricePerHour,
    this.imageAsset,
    this.onTap,
  });

  final String title;
  final String category;
  final String pricePerHour;
  final String? imageAsset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusL),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusL),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                child: Container(
                  width: 72.w,
                  height: 72.w,
                  color: AppColors.surfaceVariant,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.photo_outlined,
                    size: 28.sp,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleS,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: AppSpacing.xxs),
                    Text(
                      category,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      pricePerHour,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 24.sp,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
