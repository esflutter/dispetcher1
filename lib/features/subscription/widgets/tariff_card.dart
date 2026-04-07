import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';

/// Тариф подписки.
class TariffOption {
  const TariffOption({
    required this.id,
    required this.title,
    required this.price,
    required this.period,
    this.badge,
    this.features = const <String>[],
  });

  final String id;
  final String title;
  final String price;
  final String period;
  final String? badge;
  final List<String> features;
}

/// Карточка тарифа в таблице тарифов.
class TariffCard extends StatelessWidget {
  const TariffCard({
    super.key,
    required this.tariff,
    required this.selected,
    required this.onTap,
  });

  final TariffOption tariff;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color border = selected ? AppColors.primary : AppColors.divider;
    final Color bg = selected ? AppColors.primaryTint : AppColors.surface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppSpacing.radiusL),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusL),
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(tariff.title, style: AppTextStyles.titleS),
                  ),
                  if (tariff.badge != null)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusS),
                      ),
                      child: Text(
                        tariff.badge!,
                        style: AppTextStyles.captionBold
                            .copyWith(color: Colors.white),
                      ),
                    ),
                ],
              ),
              SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(tariff.price, style: AppTextStyles.h3),
                  SizedBox(width: AppSpacing.xxs),
                  Text(
                    tariff.period,
                    style: AppTextStyles.subBody
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
              if (tariff.features.isNotEmpty) ...<Widget>[
                SizedBox(height: AppSpacing.sm),
                ...tariff.features.map(
                  (String f) => Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.xxs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.check_rounded,
                            color: AppColors.success, size: 18.r),
                        SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            f,
                            style: AppTextStyles.bodyMRegular
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
