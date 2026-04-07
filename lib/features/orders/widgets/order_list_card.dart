import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';

/// Статус заказа в списке "Мои заказы".
enum OrderCardStatus { waiting, accepted, rejected, completed }

extension OrderCardStatusX on OrderCardStatus {
  String get label {
    switch (this) {
      case OrderCardStatus.waiting:
        return 'Ждёт подтверждения';
      case OrderCardStatus.accepted:
        return 'Свяжитесь с заказчиком';
      case OrderCardStatus.rejected:
        return 'Выбран другой исполнитель';
      case OrderCardStatus.completed:
        return 'Завершён';
    }
  }

  Color get color {
    switch (this) {
      case OrderCardStatus.waiting:
        return AppColors.primary;
      case OrderCardStatus.accepted:
        return AppColors.success;
      case OrderCardStatus.rejected:
        return AppColors.error;
      case OrderCardStatus.completed:
        return AppColors.textTertiary;
    }
  }
}

/// Карточка заказа в списке.
class OrderListCard extends StatelessWidget {
  const OrderListCard({
    super.key,
    required this.title,
    required this.dateTime,
    required this.equipment,
    required this.address,
    required this.status,
    this.onTap,
  });

  final String title;
  final String dateTime;
  final String equipment;
  final String address;
  final OrderCardStatus status;
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
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(AppSpacing.radiusL),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.titleS,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusBadge(status: status),
                ],
              ),
              SizedBox(height: AppSpacing.xs),
              _IconRow(icon: Icons.access_time_rounded, text: dateTime),
              SizedBox(height: AppSpacing.xxs),
              _IconRow(icon: Icons.build_rounded, text: equipment),
              SizedBox(height: AppSpacing.xxs),
              _IconRow(icon: Icons.location_on_outlined, text: address),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16.r, color: AppColors.textTertiary),
        SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final OrderCardStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 4.h),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusS),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.captionBold.copyWith(color: status.color),
      ),
    );
  }
}
