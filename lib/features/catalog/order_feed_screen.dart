import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/features/catalog/catalog_filter_screen.dart';
import 'package:dispatcher_1/features/catalog/order_detail_screen.dart';
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

  @override
  void initState() {
    super.initState();
    AppliedFilter.revision.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    AppliedFilter.revision.removeListener(_onFilterChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    if (mounted) setState(() {});
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

  List<ExecutorMock> get _visibleOrders {
    final String q = _query.trim().toLowerCase();
    Iterable<ExecutorMock> res = ExecutorMock.all;

    // Фильтр по категориям — хотя бы одна из выбранных категорий
    // должна присутствовать у исполнителя.
    if (AppliedFilter.categories.isNotEmpty) {
      res = res.where((ExecutorMock o) =>
          o.categories.any(AppliedFilter.categories.contains));
    }

    // Фильтр по спецтехнике — аналогично.
    if (AppliedFilter.equipment.isNotEmpty) {
      res = res.where((ExecutorMock o) =>
          o.equipment.any(AppliedFilter.equipment.contains));
    }

    // Максимальные цены — заказчик задаёт потолок бюджета, поэтому
    // оставляем только тех, у кого цена не превышает указанную.
    final int? maxHour = _parseIntOrNull(AppliedFilter.priceHour);
    if (maxHour != null) {
      res = res.where((ExecutorMock o) => o.pricePerHour <= maxHour);
    }
    final int? maxDay = _parseIntOrNull(AppliedFilter.priceDay);
    if (maxDay != null) {
      res = res.where((ExecutorMock o) => o.pricePerDay <= maxDay);
    }

    if (q.isNotEmpty) {
      res = res.where((ExecutorMock o) {
        if (o.name.toLowerCase().contains(q)) return true;
        for (final String e in o.equipment) {
          if (e.toLowerCase().contains(q)) return true;
        }
        for (final String c in o.categories) {
          if (c.toLowerCase().contains(q)) return true;
        }
        return false;
      });
    }

    final List<ExecutorMock> out = res.toList();
    if (AppliedFilter.sortByPriceAsc) {
      out.sort((ExecutorMock a, ExecutorMock b) =>
          a.pricePerHour.compareTo(b.pricePerHour));
    }
    return out;
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
              onChanged: (String v) => setState(() => _query = v),
              showFilterBadge: _hasActiveFilter,
            ),
          ),
          if (_hasActiveFilter)
            _AppliedFilterChips(onChanged: () => setState(() {})),
          Expanded(
            child: _visibleOrders.isEmpty
                ? const _EmptyExecutorsState()
                : MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: ListView.separated(
                      // Когда фильтры применены — чип выше уже даёт
                      // вертикальный отступ снизу; иначе добавляем свой.
                      padding: EdgeInsets.fromLTRB(
                          16.w, _hasActiveFilter ? 0 : 16.h, 16.w, 16.h),
                      itemCount: _visibleOrders.length,
                      separatorBuilder: (_, _) => SizedBox(height: 16.h),
                      itemBuilder: (BuildContext context, int i) {
                        final ExecutorMock o = _visibleOrders[i];
                        // Активен фильтр по спецтехнике — показываем только
                        // подходящие услуги исполнителя с ценами. Те виды
                        // техники, которых у него нет, просто не попадают
                        // в список.
                        final Set<String> eqFilter = AppliedFilter.equipment;
                        final List<ExecutorServiceOffer>? matching =
                            eqFilter.isEmpty
                                ? null
                                : o.services
                                    .where((ExecutorServiceOffer s) =>
                                        eqFilter.contains(s.equipment))
                                    .toList();
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.fieldFill,
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: OrderCard(
                            name: o.name,
                            rating: o.rating,
                            equipment: o.equipment,
                            categories: o.categories,
                            matchingServices: matching,
                            highlightEquipment: AppliedFilter.equipment,
                            highlightCategories: AppliedFilter.categories,
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
                    ),
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

/// Одна услуга исполнителя: тип спецтехники, название, описание,
/// цена за час и за день, минимальный заказ в часах, категории работ.
/// Используется и в поиске (при фильтре по технике карточка показывает
/// только подходящие услуги с ценами), и на экране деталей исполнителя.
class ExecutorServiceOffer {
  const ExecutorServiceOffer({
    required this.equipment,
    required this.title,
    required this.description,
    required this.pricePerHour,
    required this.pricePerDay,
    required this.minHours,
    this.categories = const <String>[],
  });
  final String equipment;
  final String title;
  final String description;
  final int pricePerHour;
  final int pricePerDay;
  final int minHours;
  final List<String> categories;
}

class ExecutorMock {
  const ExecutorMock({
    required this.id,
    required this.name,
    required this.rating,
    required this.experience,
    required this.legalStatus,
    required this.equipment,
    required this.categories,
    required this.pricePerHour,
    required this.pricePerDay,
    this.services = const <ExecutorServiceOffer>[],
    this.about = '',
  });
  final String id;
  final String name;
  final double rating;
  final String experience;
  final String legalStatus;
  final List<String> equipment;
  final List<String> categories;
  final int pricePerHour;
  final int pricePerDay;
  final List<ExecutorServiceOffer> services;
  final String about;

  static const List<ExecutorMock> all = <ExecutorMock>[
    ExecutorMock(
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
      pricePerHour: 2000,
      pricePerDay: 14000,
      services: <ExecutorServiceOffer>[
        ExecutorServiceOffer(
          equipment: 'Экскаватор',
          title: 'Экскаватор для копки траншеи',
          description:
              'Экскаватор для земляных работ. Копка траншей, разработка котлованов, выравнивание участка. Работаю аккуратно, соблюдаю сроки. Возможен выезд в ближайшие районы.',
          pricePerHour: 3500,
          pricePerDay: 17000,
          minHours: 4,
          categories: <String>['Земляные работы', 'Погрузочно-разгрузочные работы'],
        ),
        ExecutorServiceOffer(
          equipment: 'Автокран',
          title: 'Автокран для подъёма материалов',
          description:
              'Автокран грузоподъёмностью 25 тонн. Подъём и перемещение материалов на стройплощадке, монтажные работы. Оператор с допуском.',
          pricePerHour: 4000,
          pricePerDay: 18000,
          minHours: 3,
          categories: <String>['Строительные работы', 'Погрузочно-разгрузочные работы'],
        ),
        ExecutorServiceOffer(
          equipment: 'Эвакуатор',
          title: 'Эвакуатор для легковых и коммерческих авто',
          description:
              'Эвакуация автомобилей массой до 3.5 тонн. Работаю круглосуточно, выезжаю по городу и области.',
          pricePerHour: 2000,
          pricePerDay: 14000,
          minHours: 2,
          categories: <String>['Перевозка материалов'],
        ),
        ExecutorServiceOffer(
          equipment: 'Автовышка',
          title: 'Автовышка для работ на высоте',
          description:
              'Работы на высоте до 18 метров: монтаж, обслуживание, обрезка деревьев. Техника исправна, работаю аккуратно.',
          pricePerHour: 2500,
          pricePerDay: 15000,
          minHours: 2,
          categories: <String>['Высотные работы'],
        ),
      ],
      about:
          'Опыт работы более 5 лет. Своя техника в хорошем состоянии, работаю без простоев. Готов выезжать в ближайшие районы.',
    ),
    ExecutorMock(
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
      pricePerHour: 3500,
      pricePerDay: 17000,
      services: <ExecutorServiceOffer>[
        ExecutorServiceOffer(
          equipment: 'Автокран',
          title: 'Автокран 40 тонн',
          description:
              'Автокран грузоподъёмностью 40 тонн, стрела до 34 метров. Монтаж тяжёлых конструкций, разгрузка фур. Опытный оператор.',
          pricePerHour: 4000,
          pricePerDay: 18000,
          minHours: 4,
          categories: <String>['Строительные работы', 'Погрузочно-разгрузочные работы'],
        ),
        ExecutorServiceOffer(
          equipment: 'Экскаватор',
          title: 'Экскаватор гусеничный',
          description:
              'Гусеничный экскаватор для тяжёлых земляных работ. Разработка котлованов, снятие плодородного слоя, обратная засыпка.',
          pricePerHour: 3500,
          pricePerDay: 17000,
          minHours: 4,
          categories: <String>['Строительные работы', 'Земляные работы'],
        ),
      ],
    ),
    ExecutorMock(
      id: '3',
      name: 'Дмитрий Сидоров',
      rating: 4.2,
      experience: '3 года',
      legalStatus: 'Самозанятый',
      equipment: <String>['Экскаватор', 'Автокран', 'Манипулятор'],
      categories: <String>['Земляные работы', 'Строительные работы'],
      pricePerHour: 2500,
      pricePerDay: 15000,
      services: <ExecutorServiceOffer>[
        ExecutorServiceOffer(
          equipment: 'Экскаватор',
          title: 'Миниэкскаватор для небольших участков',
          description:
              'Миниэкскаватор на узких участках: дачи, огороды, узкие проезды. Копка траншей под коммуникации, ямы под столбы.',
          pricePerHour: 2500,
          pricePerDay: 15000,
          minHours: 3,
          categories: <String>['Земляные работы'],
        ),
        ExecutorServiceOffer(
          equipment: 'Автокран',
          title: 'Автокран 14 тонн',
          description:
              'Автокран 14 тонн, компактный, подходит для городских условий. Разгрузка материалов, монтаж небольших конструкций.',
          pricePerHour: 3000,
          pricePerDay: 16000,
          minHours: 3,
          categories: <String>['Строительные работы'],
        ),
        ExecutorServiceOffer(
          equipment: 'Манипулятор',
          title: 'Манипулятор 5 тонн',
          description:
              'Манипулятор грузоподъёмностью 5 тонн со стрелой. Доставка и разгрузка стройматериалов: плиты, кирпич, поддоны.',
          pricePerHour: 3000,
          pricePerDay: 16000,
          minHours: 2,
          categories: <String>['Строительные работы', 'Перевозка материалов'],
        ),
      ],
    ),
    ExecutorMock(
      id: '4',
      name: 'Андрей Козлов',
      rating: 4.9,
      experience: '12 лет',
      legalStatus: 'Юр. лицо',
      equipment: <String>['Самосвал', 'Погрузчик'],
      categories: <String>['Перевозка материалов', 'Земляные работы'],
      pricePerHour: 3000,
      pricePerDay: 16000,
      services: <ExecutorServiceOffer>[
        ExecutorServiceOffer(
          equipment: 'Самосвал',
          title: 'Самосвал для вывоза грунта',
          description:
              'Вывоз грунта, мусора и сыпучих материалов. Работаю быстро, без задержек. Возможен выезд в ближайшие районы.',
          pricePerHour: 3500,
          pricePerDay: 17000,
          minHours: 3,
          categories: <String>['Перевозка материалов', 'Земляные работы'],
        ),
        ExecutorServiceOffer(
          equipment: 'Погрузчик',
          title: 'Фронтальный погрузчик',
          description:
              'Погрузка сыпучих материалов, перемещение грузов по стройплощадке, уборка снега. Ковш 2 м³.',
          pricePerHour: 3000,
          pricePerDay: 16000,
          minHours: 3,
          categories: <String>['Погрузочно-разгрузочные работы'],
        ),
      ],
    ),
  ];

  static ExecutorMock? byId(String id) {
    for (final ExecutorMock e in all) {
      if (e.id == id) return e;
    }
    return null;
  }
}
