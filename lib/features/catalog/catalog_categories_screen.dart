import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/catalog/catalog_service.dart';
import 'package:dispatcher_1/core/catalog/machinery_visual.dart';
import 'package:dispatcher_1/core/catalog/models.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/features/catalog/catalog_filter_screen.dart';
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
  late Future<List<MachineryRef>> _machineryFuture;
  Future<List<ExecutorCardListItem>>? _searchFuture;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _machineryFuture = CatalogService.instance.listActiveMachinery();
  }

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    final String q = v.trim();
    if (q.isEmpty) {
      setState(() => _searchFuture = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchFuture =
            CatalogService.instance.listPublishedExecutors(search: q);
      });
    });
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
            onChanged: _onSearchChanged,
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
    return FutureBuilder<List<MachineryRef>>(
      future: _machineryFuture,
      builder: (BuildContext context, AsyncSnapshot<List<MachineryRef>> snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: TextButton(
                onPressed: () => setState(() {
                  _machineryFuture =
                      CatalogService.instance.listActiveMachinery();
                }),
                child: const Text('Не удалось загрузить. Повторить'),
              ),
            ),
          );
        }
        final List<MachineryRef> items = snap.data ?? const <MachineryRef>[];
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: GridView.builder(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12.h,
              crossAxisSpacing: 12.w,
              childAspectRatio: 168 / 112,
            ),
            itemBuilder: (BuildContext context, int i) {
              final MachineryRef m = items[i];
              final MachineryVisual v = MachineryVisual.lookup(m.title);
              return CategoryCard(
                title: m.title,
                imageAsset: v.asset,
                imageScale: v.scale,
                imageOffset: v.offset,
                onTap: () {
                  AppliedFilter.equipment
                    ..clear()
                    ..add(m.title);
                  AppliedFilter.revision.value =
                      AppliedFilter.revision.value + 1;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => OrderFeedScreen(
                        categoryId: 'all',
                        categoryTitle: m.title,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    final Future<List<ExecutorCardListItem>>? future = _searchFuture;
    if (future == null) {
      // Поле поиска есть, но debounce ещё не сработал — пусто.
      return const SizedBox.shrink();
    }
    return FutureBuilder<List<ExecutorCardListItem>>(
      future: future,
      builder: (BuildContext context,
          AsyncSnapshot<List<ExecutorCardListItem>> snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<ExecutorCardListItem> results =
            snap.data ?? const <ExecutorCardListItem>[];
        if (snap.hasError || results.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                snap.hasError
                    ? 'Не удалось загрузить'
                    : 'Ничего не найдено',
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
            final ExecutorCardListItem e = results[i];
            return Container(
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(14.r),
              ),
              clipBehavior: Clip.antiAlias,
              child: OrderCard(
                name: e.name,
                avatarUrl: e.avatarUrl,
                rating: e.ratingAsExecutor,
                equipment: e.machineryTitles,
                categories: e.categoryTitles,
                onTap: () =>
                    context.push('/catalog/executor/${e.userId}'),
              ),
            );
          },
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

