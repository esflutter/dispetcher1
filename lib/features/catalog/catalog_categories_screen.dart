import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/features/catalog/catalog_filter_screen.dart';
import 'package:dispatcher_1/features/catalog/order_detail_screen.dart';
import 'package:dispatcher_1/features/catalog/order_feed_screen.dart';
import 'package:dispatcher_1/features/catalog/widgets/category_card.dart';
import 'package:dispatcher_1/features/catalog/widgets/order_card.dart';

/// Экран «Каталог / категории» — заголовок «Поиск исполнителей» в тёмном
/// nav-баре, поле поиска и сетка категорий техники (Figma заказчик).
class CatalogCategoriesScreen extends StatefulWidget {
  const CatalogCategoriesScreen({super.key});

  @override
  State<CatalogCategoriesScreen> createState() =>
      _CatalogCategoriesScreenState();
}

class _CatalogCategoriesScreenState extends State<CatalogCategoriesScreen> {
  static const List<_Category> _categories = <_Category>[
    _Category('excavator_loader', 'Экскаватор-погрузчик',
        'assets/images/catalog/excavator_loader.webp',
        scale: 0.90),
    _Category('excavator', 'Экскаватор', 'assets/images/catalog/excavator.webp',
        offset: Offset(-2, 0)),
    _Category('loader', 'Погрузчик', 'assets/images/catalog/loader.webp',
        scale: 1.15),
    _Category('mini_excavator', 'Миниэкскаватор',
        'assets/images/catalog/mini_excavator.webp',
        scale: 0.95, offset: Offset(-2, 0)),
    _Category('auger', 'Буроям', 'assets/images/catalog/auger.webp'),
    _Category('samogruz', 'Самогруз', 'assets/images/catalog/samogruz.webp'),
    _Category('autocrane', 'Автокран', 'assets/images/catalog/autocrane.webp'),
    _Category('concrete_pump', 'Бетононасос',
        'assets/images/catalog/concrete_pump.webp'),
    _Category('tow_truck', 'Эвакуатор', 'assets/images/catalog/tow_truck.webp'),
    _Category('aerial_platform', 'Автовышка',
        'assets/images/catalog/aerial_platform.webp',
        offset: Offset(-2, 0)),
    _Category('manipulator', 'Манипулятор',
        'assets/images/catalog/manipulator.webp',
        scale: 1.03),
    _Category('mini_loader', 'Минипогрузчик',
        'assets/images/catalog/mini_loader.webp',
        scale: 0.95),
    _Category('dump_truck', 'Самосвал',
        'assets/images/catalog/dump_truck.webp',
        scale: 1.03),
    _Category('mini_tractor', 'Минитрактор',
        'assets/images/catalog/mini_tractor.webp',
        scale: 0.9025),
  ];

  static const List<_SearchableOrder> _allOrders = <_SearchableOrder>[
    _SearchableOrder(
      id: '1',
      name: 'Александр Иванов',
      rating: 4.5,
      experience: '8 лет',
      legalStatus: 'Юр. лицо',
      equipment: <String>['Экскаватор', 'Автокран', 'Эвакуатор', 'Автовышка'],
      categories: <String>[
        'Строительные работы',
        'Дорожные работы',
        'Буровые работы',
        'Высотные работы',
      ],
    ),
    _SearchableOrder(
      id: '2',
      name: 'Сергей Петров',
      rating: 4.8,
      experience: '10 лет',
      legalStatus: 'ИП',
      equipment: <String>['Автокран', 'Экскаватор'],
      categories: <String>[
        'Строительные работы',
        'Погрузочно-разгрузочные работы',
      ],
    ),
    _SearchableOrder(
      id: '3',
      name: 'Дмитрий Сидоров',
      rating: 4.2,
      experience: '3 года',
      legalStatus: 'Самозанятый',
      equipment: <String>['Экскаватор', 'Автокран', 'Манипулятор'],
      categories: <String>['Земляные работы', 'Строительные работы'],
    ),
    _SearchableOrder(
      id: '4',
      name: 'Андрей Козлов',
      rating: 4.9,
      experience: '12 лет',
      legalStatus: 'Юр. лицо',
      equipment: <String>['Самосвал', 'Погрузчик'],
      categories: <String>['Перевозка материалов', 'Земляные работы'],
    ),
    _SearchableOrder(
      id: '5',
      name: 'Виктор Морозов',
      rating: 4.6,
      experience: '6 лет',
      legalStatus: 'Физ. лицо',
      equipment: <String>['Автовышка'],
      categories: <String>['Высотные работы'],
    ),
  ];

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_SearchableOrder> get _filtered {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return const <_SearchableOrder>[];
    return _allOrders.where((_SearchableOrder o) {
      if (o.name.toLowerCase().contains(q)) return true;
      for (final String e in o.equipment) {
        if (e.toLowerCase().contains(q)) return true;
      }
      for (final String c in o.categories) {
        if (c.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool searching = _query.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: <Widget>[
          _CatalogHeader(
            controller: _searchCtrl,
            onChanged: (String v) => setState(() => _query = v),
          ),
          Expanded(
            child: searching
                ? _buildSearchResults()
                : _buildCategoriesGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: GridView.builder(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        itemCount: _categories.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12.h,
          crossAxisSpacing: 12.w,
          childAspectRatio: 168 / 112,
        ),
        itemBuilder: (BuildContext context, int i) {
          final _Category c = _categories[i];
          return CategoryCard(
            title: c.title,
            imageAsset: c.asset,
            imageScale: c.scale,
            imageOffset: c.offset,
            onTap: () {
              // Выбор категории = быстрый фильтр: заменяем список техники
              // на одну выбранную и инкрементим ревизию, чтобы лента
              // перерисовалась с учётом фильтра.
              AppliedFilter.equipment
                ..clear()
                ..add(c.title);
              AppliedFilter.revision.value =
                  AppliedFilter.revision.value + 1;
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
    );
  }

  Widget _buildSearchResults() {
    final List<_SearchableOrder> results = _filtered;
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Ничего не найдено',
            style: AppTextStyles.bodyMRegular
                .copyWith(color: AppColors.textTertiary),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      itemCount: results.length,
      separatorBuilder: (_, _) => SizedBox(height: 16.h),
      itemBuilder: (BuildContext context, int i) {
        final _SearchableOrder o = results[i];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(14.r),
          ),
          clipBehavior: Clip.antiAlias,
          child: OrderCard(
            name: o.name,
            rating: o.rating,
            experience: o.experience,
            legalStatus: o.legalStatus,
            equipment: o.equipment,
            categories: o.categories,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OrderDetailScreen(
                  orderId: o.id,
                  multipleEquipment: o.equipment.length > 1,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navBarDark,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        MediaQuery.of(context).padding.top + 24.h,
        AppSpacing.screenH,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Поиск исполнителя',
            style: AppTextStyles.h1.copyWith(color: AppColors.surface),
          ),
          SizedBox(height: 18.h),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  padding: EdgeInsets.only(left: 9.w, right: AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.search,
                          color: AppColors.textTertiary, size: 24.r),
                      SizedBox(width: 5.w),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          onChanged: onChanged,
                          inputFormatters: [LengthLimitingTextInputFormatter(100)],
                          textInputAction: TextInputAction.search,
                          cursorColor: AppColors.primary,
                          style: AppTextStyles.bodyMRegular.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 17.sp,
                          ),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: 'Поиск',
                            hintStyle:
                                AppTextStyles.bodyMRegular.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 17.sp,
                            ),
                          ),
                        ),
                      ),
                      if (controller.text.isNotEmpty)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            controller.clear();
                            onChanged('');
                          },
                          child: Icon(Icons.close_rounded,
                              color: AppColors.textTertiary, size: 20.r),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () async {
                  final bool? applied =
                      await context.push<bool>('/catalog/filter');
                  if (applied == true && context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OrderFeedScreen(
                          categoryId: 'all',
                          categoryTitle: 'Список исполнителей',
                        ),
                      ),
                    );
                  }
                },
                child: Image.asset(
                  'assets/icons/ui/filter.webp',
                  width: 44.h,
                  height: 44.h,
                  fit: BoxFit.contain,
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
  const _Category(
    this.id,
    this.title,
    this.asset, {
    this.scale = 1.0,
    this.offset = Offset.zero,
  });
  final String id;
  final String title;
  final String asset;
  /// Множитель визуального размера иллюстрации (см. CategoryCard.imageScale).
  final double scale;
  /// Пиксельный сдвиг иллюстрации (см. CategoryCard.imageOffset).
  final Offset offset;
}

class _SearchableOrder {
  const _SearchableOrder({
    required this.id,
    required this.name,
    required this.rating,
    required this.experience,
    required this.legalStatus,
    required this.equipment,
    required this.categories,
  });
  final String id;
  final String name;
  final double rating;
  final String experience;
  final String legalStatus;
  final List<String> equipment;
  final List<String> categories;
}
