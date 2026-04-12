import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';

import 'widgets/service_card.dart';

/// Экран «Мои услуги» — список услуг исполнителя или пустое состояние.
class MyServicesScreen extends StatelessWidget {
  const MyServicesScreen({super.key, this.empty = true});

  final bool empty;

  static const List<_ServiceMock> _mock = [
    _ServiceMock(
      id: '1',
      title: 'Экскаватор для копки траншеи',
      category: 'Экскаватор',
      pricePerHour: 'от 1 000 ₽/час',
    ),
    _ServiceMock(
      id: '2',
      title: 'Самосвал для вывоза грунта',
      category: 'Самосвал',
      pricePerHour: 'от 3 000 ₽/час',
    ),
    _ServiceMock(
      id: '3',
      title: 'Работы на высоте',
      category: 'Автовышка',
      pricePerHour: 'от 5 000 ₽/час',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isEmpty = empty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: DarkSubAppBar(
        title: 'Мои услуги',
        actions: <Widget>[
          if (!isEmpty)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: IconButton(
                icon: Icon(Icons.add_rounded, color: Colors.white, size: 26.r),
                onPressed: () => context.push('/services/create'),
              ),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: isEmpty ? 88.h : 24.h),
        child: AiAssistantFab(onTap: () => context.push('/assistant/chat')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: isEmpty ? const _EmptyState() : _ServicesList(items: _mock),
      ),
      bottomNavigationBar: isEmpty
          ? SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
                    AppSpacing.screenH, AppSpacing.md),
                child: PrimaryButton(
                  label: 'Создать услугу',
                  onPressed: () => context.push('/services/create'),
                ),
              ),
            )
          : null,
    );
  }
}

class _ServiceMock {
  const _ServiceMock({
    required this.id,
    required this.title,
    required this.category,
    required this.pricePerHour,
  });
  final String id;
  final String title;
  final String category;
  final String pricePerHour;
}

class _ServicesList extends StatelessWidget {
  const _ServicesList({required this.items});
  final List<_ServiceMock> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final item = items[index];
        return ServiceCard(
          title: item.title,
          category: item.category,
          pricePerHour: item.pricePerHour,
          onTap: () => context.push('/services/${item.id}'),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Здесь появятся ваши услуги',
              style:
                  AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Создайте услугу\nи начните получать заказы',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
