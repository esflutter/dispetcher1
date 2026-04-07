import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';

/// Плитка для загрузки документа (фото / PDF) на экране верификации.
class DocumentUploadTile extends StatelessWidget {
  const DocumentUploadTile({
    super.key,
    required this.title,
    required this.onTap,
    this.uploaded = false,
  });

  final String title;
  final VoidCallback onTap;
  final bool uploaded;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusM),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(AppSpacing.radiusS),
              ),
              child: Icon(
                uploaded
                    ? Icons.check_circle_outline
                    : Icons.file_upload_outlined,
                color: AppColors.primary,
                size: 22.r,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(title, style: AppTextStyles.bodyMedium),
            ),
            Icon(Icons.chevron_right,
                color: AppColors.textTertiary, size: 24.r),
          ],
        ),
      ),
    );
  }
}
