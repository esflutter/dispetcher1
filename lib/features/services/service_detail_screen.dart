import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';

import 'widgets/service_alerts.dart';

/// Экран «Просмотр услуги».
class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context) {
    const title = 'Аренда экскаватора-погрузчика';
    const category = 'Спецтехника';
    const description =
        'Опытный машинист, собственный экскаватор-погрузчик JCB 3CX. '
        'Выполняю земляные работы любой сложности: рытьё котлованов, '
        'траншей, планировка участков, погрузо-разгрузочные работы.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text('Детали услуги', style: AppTextStyles.titleS),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20.sp, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusL),
                child: Container(
                  width: double.infinity,
                  height: 200.h,
                  color: AppColors.surfaceVariant,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_outlined,
                    size: 56.sp,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.md),
              Text(title, style: AppTextStyles.h3),
              SizedBox(height: AppSpacing.xs),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  category,
                  style: AppTextStyles.chip
                      .copyWith(color: AppColors.primaryDark),
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              _PriceRow(label: '₽ / час', value: '1 000 ₽'),
              SizedBox(height: AppSpacing.sm),
              _PriceRow(label: '₽ / день', value: '14 000 ₽'),
              SizedBox(height: AppSpacing.sm),
              _PriceRow(label: 'Минимальный заказ:', value: 'от 4 часов'),
              SizedBox(height: AppSpacing.lg),
              Text('Описание', style: AppTextStyles.titleS),
              SizedBox(height: AppSpacing.xs),
              Text(
                description,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
              ),
              SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: 'Редактировать',
                onPressed: () => context.push('/services/$serviceId/edit'),
              ),
              SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: OutlinedButton(
                  onPressed: () async {
                    final ok = await showDeleteServiceSheet(
                      context,
                      serviceTitle: title,
                    );
                    if (ok == true && context.mounted) {
                      Navigator.of(context).maybePop();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    'Удалить',
                    style: AppTextStyles.button
                        .copyWith(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
