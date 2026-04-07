import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';

/// Чип одного дня в горизонтальном календаре графика.
/// Показывает число и сокращённый день недели. Активный — оранжевый фон.
class DayChip extends StatelessWidget {
  const DayChip({
    super.key,
    required this.day,
    required this.weekday,
    required this.selected,
    required this.onTap,
    this.dayOff = false,
  });

  final String day;
  final String weekday;
  final bool selected;
  final bool dayOff;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = selected
        ? AppColors.primary
        : (dayOff ? AppColors.surfaceVariant : AppColors.surface);
    final Color border = selected ? AppColors.primary : AppColors.divider;
    final Color textColor = selected ? Colors.white : AppColors.textPrimary;
    final Color subColor = selected
        ? Colors.white.withValues(alpha: 0.85)
        : AppColors.textTertiary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56.w,
        height: 72.h,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              day,
              style: AppTextStyles.titleS.copyWith(color: textColor),
            ),
            SizedBox(height: 4.h),
            Text(
              weekday,
              style: AppTextStyles.caption.copyWith(color: subColor),
            ),
          ],
        ),
      ),
    );
  }
}
