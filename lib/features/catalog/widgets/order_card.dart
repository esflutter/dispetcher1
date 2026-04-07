import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';

/// Карточка заказа в ленте каталога.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.title,
    required this.price,
    required this.address,
    required this.dateTime,
    required this.equipment,
    this.onTap,
  });

  final String title;
  final String price;
  final String address;
  final String dateTime;
  final String equipment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusL),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(AppSpacing.radiusL),
          ),
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.titleS,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    price,
                    style: AppTextStyles.titleS
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.xs),
              _Row(icon: Icons.precision_manufacturing_outlined, text: equipment),
              SizedBox(height: AppSpacing.xxs),
              _Row(icon: Icons.place_outlined, text: address),
              SizedBox(height: AppSpacing.xxs),
              _Row(icon: Icons.access_time, text: dateTime),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16.r, color: AppColors.textTertiary),
        SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
