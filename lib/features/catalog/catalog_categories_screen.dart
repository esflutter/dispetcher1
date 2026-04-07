import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/features/catalog/widgets/category_card.dart';
import 'package:dispatcher_1/features/catalog/order_feed_screen.dart';

/// Экран «Каталог / категории» — заголовок «Поиск заказов» в тёмном
/// nav-баре, поле поиска и сетка 2×5 категорий (Figma 8:2139).
class CatalogCategoriesScreen extends StatelessWidget {
  const CatalogCategoriesScreen({super.key});

  static const List<_Category> _categories = <_Category>[
    _Category('excavator_loader', 'Экскаватор-погрузчик',
        'assets/images/catalog/excavator_loader.webp'),
    _Category('loader', 'Погрузчик', 'assets/images/catalog/loader.webp'),
    _Category('mini_excavator', 'Миниэкскаватор',
        'assets/images/catalog/mini_excavator.webp'),
    _Category('auger', 'Буроям', 'assets/images/catalog/auger.webp'),
    _Category('samogruz', 'Самогруз', 'assets/images/catalog/samogruz.webp'),
    _Category('autocrane', 'Автокран', 'assets/images/catalog/autocrane.webp'),
    _Category('concrete_pump', 'Бетононасос',
        'assets/images/catalog/concrete_pump.webp'),
    _Category('tow_truck', 'Эвакуатор', 'assets/images/catalog/tow_truck.webp'),
    _Category('aerial_platform', 'Автовышка',
        'assets/images/catalog/aerial_platform.webp'),
    _Category('manipulator', 'Манипулятор',
        'assets/images/catalog/manipulator.webp'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: <Widget>[
          _CatalogHeader(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              child: GridView.builder(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                itemCount: _categories.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12.h,
                  crossAxisSpacing: 12.w,
                  childAspectRatio: 168 / 170,
                ),
                itemBuilder: (BuildContext context, int i) {
                  final _Category c = _categories[i];
                  return CategoryCard(
                    title: c.title,
                    imageAsset: c.asset,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => OrderFeedScreen(
                              categoryId: c.id, categoryTitle: c.title),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navBarDark,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        MediaQuery.of(context).padding.top + 8.h,
        AppSpacing.screenH,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Поиск заказов',
                style: AppTextStyles.h1.copyWith(color: AppColors.surface),
              ),
              IconButton(
                onPressed: () => context.push('/catalog/orders-map'),
                icon: Icon(Icons.map_outlined,
                    color: AppColors.primary, size: 24.r),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.search,
                          color: AppColors.textTertiary, size: 20.r),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        'Поиск',
                        style: AppTextStyles.bodyMRegular
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: () => context.push('/catalog/filter'),
                child: Container(
                  width: 44.r,
                  height: 44.r,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                  ),
                  child: Icon(Icons.tune,
                      color: AppColors.surface, size: 20.r),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Category {
  const _Category(this.id, this.title, this.asset);
  final String id;
  final String title;
  final String asset;
}
