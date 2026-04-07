import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/order_detail_screen.dart';

/// Просмотр заказа на карте — плейсхолдер карты + bottom-sheet с краткой
/// карточкой заказа.
class OrderOnMapScreen extends StatelessWidget {
  const OrderOnMapScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          Container(
            color: AppColors.surfaceVariant,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.map_outlined,
                      size: 80.sp, color: AppColors.textTertiary),
                  SizedBox(height: AppSpacing.sm),
                  Text('Карта (демо)',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textTertiary)),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: AppSpacing.screenH,
            child: CircleAvatar(
              backgroundColor: AppColors.surface,
              child: IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: EdgeInsets.all(AppSpacing.screenH),
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusL),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('Экскаватор', style: AppTextStyles.bodyMMedium),
                      Text('2 часа назад',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textTertiary)),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text('Нужен экскаватор для копки траншеи',
                      style: AppTextStyles.titleS),
                  SizedBox(height: AppSpacing.xs),
                  Text('Дата аренды:',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textTertiary)),
                  Text('15-19 июня · 09:00–18:00',
                      style: AppTextStyles.bodyMRegular),
                  SizedBox(height: AppSpacing.xxs),
                  Text('Адрес:',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textTertiary)),
                  Text('Московская область, Москва, Улица1, д 144',
                      style: AppTextStyles.bodyMRegular),
                  SizedBox(height: AppSpacing.xs),
                  Text('80 000 – 100 000 ₽',
                      style: AppTextStyles.bodyMMedium
                          .copyWith(color: AppColors.primary)),
                  SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Контакты',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OrderDetailScreen(orderId: orderId),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
