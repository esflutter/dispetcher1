import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';

/// Экран «Детали услуги».
class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context) {
    const title = 'Разработка котлована под\nфундамент';
    const description =
        'Экскаватор для земляных работ. Копка траншей, разработка '
        'котлованов, выравнивание участка. Работаю аккуратно, соблюдаю сроки. '
        'Возможен выезд в ближайшие районы.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const DarkSubAppBar(title: 'Детали услуги'),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 88.h),
        child: AiAssistantFab(onTap: () => context.push('/assistant/chat')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style:
                      AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700)),
              SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _Price(label: '₽ / час', value: '1 000 ₽'),
                  SizedBox(width: AppSpacing.lg),
                  _Price(label: '₽ / день', value: '14 000 ₽'),
                ],
              ),
              SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Text('Минимальный заказ:',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textSecondary)),
                  SizedBox(width: 6.w),
                  Text('от 4 часов',
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              Text(description, style: AppTextStyles.body),
              SizedBox(height: AppSpacing.lg),
              _SectionTitle('Спецтехника'),
              SizedBox(height: AppSpacing.xs),
              const _ChipRow(items: ['Экскаватор']),
              SizedBox(height: AppSpacing.md),
              _SectionTitle('Категория работ'),
              SizedBox(height: AppSpacing.xs),
              const _ChipRow(items: [
                'Земляные работы',
                'Погрузочно-разгрузочные работы',
              ]),
              SizedBox(height: AppSpacing.md),
              _SectionTitle('Фото'),
              SizedBox(height: AppSpacing.xs),
              _PhotosRow(),
              SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
              AppSpacing.screenH, AppSpacing.md),
          child: PrimaryButton(
            label: 'Редактировать',
            onPressed: () => context.push('/services/$serviceId/edit'),
          ),
        ),
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        SizedBox(width: 6.w),
        Text(value,
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
      );
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: items
          .map(
            (label) => Container(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                border: Border.all(color: AppColors.primary),
              ),
              child: Text(
                label,
                style: AppTextStyles.chip.copyWith(
                  fontSize: 13.sp,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PhotosRow extends StatelessWidget {
  static const _photos = [
    'assets/images/profile/photo_1.webp',
    'assets/images/profile/photo_2.webp',
    'assets/images/profile/photo_3.webp',
    'assets/images/profile/photo_4.webp',
    'assets/images/profile/photo_5.webp',
    'assets/images/profile/photo_6.webp',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80.r,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _photos.length,
        separatorBuilder: (_, _) => SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          child: Image.asset(
            _photos[i],
            width: 80.r,
            height: 80.r,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
