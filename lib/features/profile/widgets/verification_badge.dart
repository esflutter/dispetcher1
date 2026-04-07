import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';

/// Статус верификации профиля исполнителя.
enum VerificationStatus {
  verified,
  inProgress,
  rejected,
  notVerified,
  blocked,
}

class VerificationBadge extends StatelessWidget {
  const VerificationBadge({super.key, required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final cfg = _config(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6.h),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg.icon, size: 14.r, color: cfg.fg),
          SizedBox(width: 6.w),
          Text(
            cfg.label,
            style: AppTextStyles.captionBold.copyWith(color: cfg.fg),
          ),
        ],
      ),
    );
  }

  static _BadgeConfig _config(VerificationStatus s) {
    switch (s) {
      case VerificationStatus.verified:
        return _BadgeConfig(
          label: 'Верифицирован',
          icon: Icons.verified_rounded,
          fg: AppColors.success,
          bg: const Color(0xFFE6F9E7),
        );
      case VerificationStatus.inProgress:
        return _BadgeConfig(
          label: 'На проверке',
          icon: Icons.hourglass_top_rounded,
          fg: AppColors.primary,
          bg: AppColors.primaryTint,
        );
      case VerificationStatus.rejected:
        return _BadgeConfig(
          label: 'Отказано',
          icon: Icons.cancel_rounded,
          fg: AppColors.error,
          bg: const Color(0xFFFDECEA),
        );
      case VerificationStatus.notVerified:
        return _BadgeConfig(
          label: 'Не верифицирован',
          icon: Icons.help_outline_rounded,
          fg: AppColors.textTertiary,
          bg: AppColors.surfaceVariant,
        );
      case VerificationStatus.blocked:
        return _BadgeConfig(
          label: 'Заблокирован',
          icon: Icons.block_rounded,
          fg: AppColors.error,
          bg: const Color(0xFFFDECEA),
        );
    }
  }
}

class _BadgeConfig {
  _BadgeConfig({
    required this.label,
    required this.icon,
    required this.fg,
    required this.bg,
  });
  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
}
