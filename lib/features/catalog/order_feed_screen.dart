import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/catalog/catalog_service.dart';
import 'package:dispatcher_1/core/catalog/models.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/features/catalog/catalog_filter_screen.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';
import 'package:dispatcher_1/features/catalog/widgets/order_card.dart';
import 'package:dispatcher_1/features/shell/main_shell.dart';
import 'package:dispatcher_1/features/shell/widgets/main_bottom_nav_bar.dart';

int? _parseIntOrNull(String? s) {
  if (s == null) return null;
  return int.tryParse(s.replaceAll(' ', ''));
}

/// Лента исполнителей категории. Соответствует Figma «Лента исполнителей»:
/// тёмный AppBar → строка поиска + оранжевый фильтр → список карточек.
class OrderFeedScreen extends StatefulWidget {
  const OrderFeedScreen({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
  });

  final String categoryId;
  final String categoryTitle;

  @override
  State<OrderFeedScreen> createState() => _OrderFeedScreenState();
}

class _OrderFeedScreenState extends State<OrderFeedScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _debounce;
  late Future<List<ExecutorCardListItem>> _future;

  @override
  void initState() {
    super.initState();
    AppliedFilter.revision.addListener(_onFilterChanged);
    _future = _fetch();
  }

  @override
  void dispose() {
    AppliedFilter.revision.removeListener(_onFilterChanged);
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<ExecutorCardListItem>> _fetch() {
    return CatalogService.instance.listPublishedExecutors(
      machineryTitles: AppliedFilter.equipment,
      categoryTitles: AppliedFilter.categories,
      search: _query.trim().isEmpty ? null : _query,
    );
  }

  void _onFilterChanged() {
    if (mounted) setState(() => _future = _fetch());
  }

  void _onSearchChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _future = _fetch());
    });
  }

  /// Локальные фильтры по цене (в сервисе их нет) + сортировка.
  List<ExecutorCardListItem> _applyLocalFilters(
      List<ExecutorCardListItem> input) {
    Iterable<ExecutorCardListItem> res = input;

    final int? maxHour = _parseIntOrNull(AppliedFilter.priceHour);
    if (maxHour != null) {
      res = res.where((ExecutorCardListItem e) =>
          e.minPricePerHour != null && e.minPricePerHour! <= maxHour);
    }
    final int? maxDay = _parseIntOrNull(AppliedFilter.priceDay);
    if (maxDay != null) {
      res = res.where((ExecutorCardListItem e) =>
          e.minPricePerDay != null && e.minPricePerDay! <= maxDay);
    }

    final List<ExecutorCardListItem> out = res.toList();
    if (AppliedFilter.sortByPriceAsc) {
      out.sort((ExecutorCardListItem a, ExecutorCardListItem b) {
        final double av = a.minPricePerHour ?? double.infinity;
        final double bv = b.minPricePerHour ?? double.infinity;
        return av.compareTo(bv);
      });
    }
    return out;
  }

  /// True только если реально отрисуется хотя бы один chip. Значения,
  /// которые не попадают ни в один chip (например, одиночный `timeFrom`
  /// без `timeTo`, `address` без `radiusKm`, пустая строка цены), не
  /// делают фильтр «активным» — иначе мы бы рисовали пустой ряд чипов и
  /// зажигали красную точку над иконкой без видимой причины.
  bool get _hasActiveFilter {
    if (AppliedFilter.categories.isNotEmpty) return true;
    if (AppliedFilter.equipment.isNotEmpty) return true;
    if (AppliedFilter.priceHour != null &&
        AppliedFilter.priceHour!.isNotEmpty) {
      return true;
    }
    if (AppliedFilter.priceDay != null &&
        AppliedFilter.priceDay!.isNotEmpty) {
      return true;
    }
    if (AppliedFilter.sortByPriceAsc) return true;
    if (AppliedFilter.dateFrom != null) return true;
    if (AppliedFilter.wholeDay) return true;
    if (AppliedFilter.timeFrom != null && AppliedFilter.timeTo != null) {
      return true;
    }
    if (AppliedFilter.radiusKm != null) return true;
    return false;
  }

  void _openFilter() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CatalogFilterScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navBarDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 48.h,
        // +2 сверху и -10 снизу: добавляем верхний паддинг статус-бару
        // самой AppBar, общий toolbarHeight сокращаем на 8 — в сумме
        // даёт сдвиг вверх на 10 снизу и прибавку 2 сверху.
        leading: Padding(
          padding: EdgeInsets.only(top: 2.h),
          child: IconButton(
            icon: Image.asset(
              'assets/icons/ui/back_arrow.webp',
              width: 24.r,
              height: 24.r,
              fit: BoxFit.contain,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Padding(
          padding: EdgeInsets.only(top: 2.h),
          child: Text(
            'Список исполнителей',
            style: AppTextStyles.titleS.copyWith(color: Colors.white),
          ),
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        items: kMainNavItems,
        currentIndex: 0,
        onTap: (int i) {
          // Сначала выставляем нужный таб в shell через общий notifier,
          // затем возвращаемся к корневому маршруту shell.
          MainShell.selectedTab.value = i;
          Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
        },
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 24.h),
        child: AiAssistantFab(
          onTap: () => context.push('/assistant/chat'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: <Widget>[
          Container(
            color: AppColors.navBarDark,
            child: CatalogSearchBar(
              controller: _searchCtrl,
              hintText: 'Поиск',
              onFilterTap: _openFilter,
              onChanged: _onSearchChanged,
              showFilterBadge: _hasActiveFilter,
            ),
          ),
          if (_hasActiveFilter)
            _AppliedFilterChips(onChanged: () => setState(() {})),
          Expanded(
            child: FutureBuilder<List<ExecutorCardListItem>>(
              future: _future,
              builder: (BuildContext context,
                  AsyncSnapshot<List<ExecutorCardListItem>> snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _future = _fetch()),
                        child: const Text('Не удалось загрузить'),
                      ),
                    ),
                  );
                }
                final List<ExecutorCardListItem> orders = _applyLocalFilters(
                    snap.data ?? const <ExecutorCardListItem>[]);
                if (orders.isEmpty) {
                  return const _EmptyExecutorsState();
                }
                return MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: ListView.separated(
                    // Когда фильтры применены — чип выше уже даёт
                    // вертикальный отступ снизу; иначе добавляем свой.
                    padding: EdgeInsets.fromLTRB(
                        16.w, _hasActiveFilter ? 0 : 16.h, 16.w, 16.h),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => SizedBox(height: 16.h),
                    itemBuilder: (BuildContext context, int i) {
                      final ExecutorCardListItem e = orders[i];
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.fieldFill,
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: OrderCard(
                          name: e.name,
                          rating: e.ratingAsExecutor,
                          equipment: e.machineryTitles,
                          categories: e.categoryTitles,
                          highlightEquipment: AppliedFilter.equipment,
                          highlightCategories: AppliedFilter.categories,
                          onTap: () =>
                              context.push('/catalog/executor/${e.userId}'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyExecutorsState extends StatelessWidget {
  const _EmptyExecutorsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Image.asset(
              'assets/icons/profile/no_orders.webp',
              width: 80.r,
              height: 80.r,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Исполнители не найдены',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6.h),
          Text(
            'Попробуйте изменить фильтры',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16.sp,
              fontWeight: FontWeight.w400,
              height: 1.3,
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Горизонтальный ряд оранжевых chip-ов с применёнными фильтрами.
/// По тапу на × чип удаляется и `AppliedFilter.revision` инкрементится.
class _AppliedFilterChips extends StatelessWidget {
  const _AppliedFilterChips({required this.onChanged});

  final VoidCallback onChanged;

  static const List<String> _months = <String>[
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];

  String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _bump() {
    AppliedFilter.revision.value = AppliedFilter.revision.value + 1;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final List<_ChipSpec> chips = <_ChipSpec>[];

    for (final String v in AppliedFilter.equipment) {
      chips.add(_ChipSpec(v, () {
        AppliedFilter.equipment.remove(v);
        _bump();
      }));
    }
    for (final String v in AppliedFilter.categories) {
      chips.add(_ChipSpec(v, () {
        AppliedFilter.categories.remove(v);
        _bump();
      }));
    }

    // Дата: один чип на диапазон или на «точную» дату.
    if (AppliedFilter.dateFrom != null) {
      final String label = AppliedFilter.exactDate ||
              AppliedFilter.dateTo == null ||
              AppliedFilter.dateTo == AppliedFilter.dateFrom
          ? _fmtDate(AppliedFilter.dateFrom!)
          : '${_fmtDate(AppliedFilter.dateFrom!)} – ${_fmtDate(AppliedFilter.dateTo!)}';
      chips.add(_ChipSpec(label, () {
        AppliedFilter.dateFrom = null;
        AppliedFilter.dateTo = null;
        AppliedFilter.exactDate = false;
        _bump();
      }));
    }

    // Время: один чип на диапазон, либо «Весь день».
    if (AppliedFilter.wholeDay) {
      chips.add(_ChipSpec('Весь день', () {
        AppliedFilter.wholeDay = false;
        _bump();
      }));
    } else if (AppliedFilter.timeFrom != null &&
        AppliedFilter.timeTo != null) {
      chips.add(_ChipSpec(
          '${_fmtTime(AppliedFilter.timeFrom!)}–${_fmtTime(AppliedFilter.timeTo!)}',
          () {
        AppliedFilter.timeFrom = null;
        AppliedFilter.timeTo = null;
        _bump();
      }));
    }

    if (AppliedFilter.priceHour != null && AppliedFilter.priceHour!.isNotEmpty) {
      chips.add(_ChipSpec('до ${AppliedFilter.priceHour} ₽ / час', () {
        AppliedFilter.priceHour = null;
        _bump();
      }));
    }
    if (AppliedFilter.priceDay != null && AppliedFilter.priceDay!.isNotEmpty) {
      chips.add(_ChipSpec('до ${AppliedFilter.priceDay} ₽ / день', () {
        AppliedFilter.priceDay = null;
        _bump();
      }));
    }
    if (AppliedFilter.sortByPriceAsc) {
      chips.add(_ChipSpec('По возрастанию цены', () {
        AppliedFilter.sortByPriceAsc = false;
        _bump();
      }));
    }
    // Один чип на «адрес + радиус» — это одна логическая настройка.
    // Показываем радиус, по крестику снимаем оба поля.
    if (AppliedFilter.radiusKm != null) {
      chips.add(_ChipSpec('В радиусе ${AppliedFilter.radiusKm} км', () {
        AppliedFilter.radiusKm = null;
        AppliedFilter.address = null;
        _bump();
      }));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    // SingleChildScrollView сам по себе ужимается до размера ребёнка
    // (Row), поэтому в Column его центрирует. Оборачиваем в полноширинный
    // SizedBox, чтобы чипы всегда начинались от левого края.
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < chips.length; i++) ...<Widget>[
              if (i > 0) SizedBox(width: 8.w),
              _FilterChip(label: chips[i].label, onRemove: chips[i].onRemove),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChipSpec {
  const _ChipSpec(this.label, this.onRemove);
  final String label;
  final VoidCallback onRemove;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // Стиль — идентичный выбранным чипам в фильтре (_ChipGrid).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onRemove,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: AppColors.primary,
          border: Border.all(color: AppColors.primary, width: 1),
          borderRadius: BorderRadius.circular(100.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: AppTextStyles.chip.copyWith(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(width: 6.w),
            Icon(Icons.close_rounded, size: 14.r, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

