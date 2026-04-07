import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';

/// Плейсхолдер карты со списком заказов. Реальная карта будет подключена
/// позже через сторонний SDK.
class OrdersMapScreen extends StatelessWidget {
  const OrdersMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.map, size: 64.r, color: AppColors.textTertiary),
            SizedBox(height: AppSpacing.sm),
            Text('Карта (демо)',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }
}
