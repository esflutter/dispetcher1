import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';

const String _kAbout =
    'Частный заказчик. Периодически нужны услуги спецтехники для строительных '
    'работ и благоустройства участка.';

const List<_CustomerOrder> _kOrders = <_CustomerOrder>[
  _CustomerOrder(
    equipment: 'Экскаватор',
    posted: '2 часа назад',
    title: 'Нужен экскаватор для копки траншеи',
    price: null,
  ),
  _CustomerOrder(
    equipment: 'Автокран',
    posted: 'Сегодня в 11:30',
    title: 'Разработка котлована под фундамент',
    price: '60 000 ₽',
  ),
];

class _CustomerOrder {
  const _CustomerOrder({
    required this.equipment,
    required this.posted,
    required this.title,
    required this.price,
  });
  final String equipment;
  final String posted;
  final String title;
  final String? price;
}

/// Карточка заказчика — публичный профиль.
class CustomerCardScreen extends StatelessWidget {
  const CustomerCardScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('Заказчик', style: AppTextStyles.titleS),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Column(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 48.r,
                      backgroundColor: AppColors.primaryTint,
                      child: Icon(Icons.person,
                          size: 48.r, color: AppColors.primary),
                    ),
                    SizedBox(height: AppSpacing.md),
                    Text('Александр Иванов', style: AppTextStyles.h3),
                    SizedBox(height: AppSpacing.xxs),
                    Text('15 отзывов',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              Text('Номер телефона',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textTertiary)),
              SizedBox(height: AppSpacing.xxs),
              Text('+7 999 123-45-67', style: AppTextStyles.bodyMedium),
              SizedBox(height: AppSpacing.md),
              Text('Статус',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textTertiary)),
              SizedBox(height: AppSpacing.xxs),
              Text('Физ. лицо', style: AppTextStyles.bodyMedium),
              SizedBox(height: AppSpacing.md),
              Text('О себе',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textTertiary)),
              SizedBox(height: AppSpacing.xxs),
              Text(_kAbout, style: AppTextStyles.bodyMRegular),
              SizedBox(height: AppSpacing.lg),
              for (final _CustomerOrder o in _kOrders) ...<Widget>[
                Container(
                  padding: EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(o.equipment,
                              style: AppTextStyles.bodyMMedium),
                          Text(o.posted,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textTertiary)),
                        ],
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(o.title, style: AppTextStyles.bodyMRegular),
                      if (o.price != null) ...<Widget>[
                        SizedBox(height: AppSpacing.xs),
                        Text(o.price!,
                            style: AppTextStyles.bodyMMedium
                                .copyWith(color: AppColors.primary)),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
