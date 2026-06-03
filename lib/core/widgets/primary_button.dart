import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Главная кнопка — оранжевая, скруглённая, full-width.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  /// Показать индикатор загрузки вместо текста и заблокировать нажатие.
  /// Кнопка при этом остаётся «живой» оранжевой — это состояние «идёт
  /// работа», а не выключенная кнопка.
  final bool loading;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final bool active = enabled && !loading && onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: height ?? 54.h,
      child: ElevatedButton(
        onPressed: active ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: loading
              ? AppColors.primary
              : AppColors.primaryButtonDisabledBg,
          foregroundColor: Colors.white,
          disabledForegroundColor: loading
              ? Colors.white
              : AppColors.primary.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 22.r,
                height: 22.r,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: AppTextStyles.button.copyWith(
                  color: active
                      ? Colors.white
                      : AppColors.primary.withValues(alpha: 0.5),
                ),
              ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height ?? 54.h,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        child: Text(label, style: AppTextStyles.button.copyWith(color: AppColors.primary)),
      ),
    );
  }
}
