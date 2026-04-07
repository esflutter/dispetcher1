import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';

/// Карточка категории каталога — фон, иллюстрация (asset) или иконка-fallback,
/// подпись снизу. Совпадает с Figma node 8:2139 (cards 168×112 + подпись 14sp).
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.title,
    this.background = AppColors.categoryCard,
    this.imageAsset,
    this.icon,
    this.onTap,
  });

  final String title;
  final Color background;
  final String? imageAsset;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppSpacing.radiusM),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Center(
                child: imageAsset != null
                    ? Image.asset(
                        imageAsset!,
                        fit: BoxFit.contain,
                        errorBuilder: (BuildContext _, Object _, StackTrace? _) => Icon(
                          icon ?? Icons.image_outlined,
                          size: 56.r,
                          color: AppColors.textTertiary,
                        ),
                      )
                    : Icon(
                        icon ?? Icons.image_outlined,
                        size: 56.r,
                        color: AppColors.textPrimary,
                      ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                title,
                style: AppTextStyles.subBody,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
