import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/cropped_avatar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/catalog_service_detail_screen.dart';
import 'package:dispatcher_1/features/catalog/select_order_for_executor_screen.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';
import 'package:dispatcher_1/features/orders/create_order_screen.dart';
import 'package:dispatcher_1/features/orders/orders_store.dart';
import 'package:dispatcher_1/features/profile/account_block.dart';

/// Карточка исполнителя (детали). По Figma — заголовок исполнителя сверху,
/// далее «техника → местоположение → категории → описание → стоимость».
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.multipleEquipment = false,
    this.price = '80 000 – 100 000 ₽',
    this.selectMode = false,
    this.onSelectExecutor,
  });

  final String orderId;
  final bool multipleEquipment;
  final String price;

  /// Режим «выбор исполнителя из откликнувшихся». При `true` нижняя
  /// кнопка меняет смысл: вместо «Предложить заказ» — «Выбрать
  /// исполнителя», и по нажатию вызывается [onSelectExecutor].
  final bool selectMode;

  /// Колбэк при нажатии на «Выбрать исполнителя» (только при
  /// [selectMode] `== true`).
  final VoidCallback? onSelectExecutor;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  static const List<String> _multiEquipment = <String>[
    'Экскаватор',
    'Автокран',
    'Манипулятор',
    'Погрузчик',
    'Автовышка',
  ];

  @override
  void initState() {
    super.initState();
    AccountBlock.notifier.addListener(_onBlockChange);
    OfferSubmissions.revision.addListener(_onBlockChange);
  }

  @override
  void dispose() {
    AccountBlock.notifier.removeListener(_onBlockChange);
    OfferSubmissions.revision.removeListener(_onBlockChange);
    super.dispose();
  }

  void _onBlockChange() {
    if (mounted) setState(() {});
  }

  bool get _alreadyOffered => OfferSubmissions.isOffered(widget.orderId);

  // Моковый список техники из заказа.
  List<String> get _orderEquipment => widget.multipleEquipment
      ? _multiEquipment
      : const <String>['Экскаватор', 'Автокран', 'Манипулятор', 'Погрузчик', 'Автовышка'];

  Future<void> _onRespondTap() async {
    if (MyOrdersStore.offerable.isEmpty) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (_) => NoOrderDialog(
          onCreateOrder: () => DailyOrderLimit.openCreateOrAlert(context),
        ),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SelectOrderForExecutorScreen(
          executorOrderId: widget.orderId,
        ),
      ),
    );
  }

  void _openServiceDetail(
    BuildContext context, {
    required String title,
    required String description,
    required String priceHour,
    required String priceDay,
    required int minOrderHours,
    required List<String> machinery,
    required List<String> categories,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogServiceDetailScreen(
          executorOrderId: widget.orderId,
          title: title,
          description: description,
          priceHour: priceHour,
          priceDay: priceDay,
          minOrderHours: minOrderHours,
          machinery: machinery,
          categories: categories,
          // Пробрасываем selectMode/колбэк — если карточку исполнителя
          // открыли из потока «Выбрать исполнителя», то на экране
          // услуги тоже должна быть «Выбрать исполнителя».
          selectMode: widget.selectMode,
          onSelectExecutor: widget.onSelectExecutor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> equipment = _orderEquipment;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navBarDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 48.h,
        leading: Padding(
          padding: EdgeInsets.only(top: 2.h),
          child: IconButton(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            icon: Padding(
              padding: EdgeInsets.only(left: 8.w),
              child: Image.asset(
                'assets/icons/ui/back_arrow.webp',
                width: 24.r,
                height: 24.r,
                fit: BoxFit.contain,
              ),
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Padding(
          padding: EdgeInsets.only(top: 2.h),
          child: Text(
            'Карточка исполнителя',
            style: AppTextStyles.bodyL.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: const <Widget>[],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: _alreadyOffered ? 24.h : 88.h),
        child: AiAssistantFab(
          onTap: () => context.push('/assistant/chat'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16.w,
                16.h,
                16.w,
                // Нижний отступ: если кнопки нет — сами добавляем safe-area,
                // если кнопка есть — оставляем 16.h, чтобы последняя
                // карточка услуги не прилипала к кнопке.
                (widget.selectMode || !_alreadyOffered)
                    ? 16.h
                    : 16.h + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _CustomerHeader(),
                      SizedBox(height: 20.h),
                      _SectionTitle('Местоположение'),
                      SizedBox(height: 4.h),
                      Text('Московская область, Москва',
                          style: AppTextStyles.body),
                      SizedBox(height: 16.h),
                      _SectionTitle('Спецтехника'),
                      SizedBox(height: 8.h),
                      _FilledChipWrap(items: equipment),
                      SizedBox(height: 16.h),
                      _SectionTitle('Категории услуг'),
                      SizedBox(height: 8.h),
                      const _FilledChipWrap(items: <String>[
                        'Земляные работы',
                        'Погрузочно-разгрузочные работы',
                      ]),
                      SizedBox(height: 16.h),
                      _SectionTitle('Опыт работы'),
                      SizedBox(height: 4.h),
                      Text('5 лет', style: AppTextStyles.body),
                      SizedBox(height: 16.h),
                      _SectionTitle('Статус'),
                      SizedBox(height: 4.h),
                      Text('Физ. лицо', style: AppTextStyles.body),
                      SizedBox(height: 16.h),
                      _SectionTitle('О себе'),
                      SizedBox(height: 4.h),
                      Text(
                          'Опыт работы более 5 лет. Своя техника в хорошем состоянии, работаю без простоев. Готов выезжать в ближайшие районы.',
                          style: AppTextStyles.body),
                      SizedBox(height: 16.h),
                      const _AvailabilitySection(),
                      SizedBox(height: 16.h),
                      _SectionTitle('Услуги'),
                      SizedBox(height: 8.h),
                      _ServiceTile(
                        child: _ServiceItem(
                          equipment: 'Экскаватор',
                          title: 'Экскаватор для копки траншеи',
                          description:
                              'Экскаватор для земляных работ. Копка траншей, разработка котлованов, выравнивание участка. Работаю аккуратно, соблюдаю сроки. Возможен выезд в ближайшие районы.',
                          priceHour: '1 000 ₽',
                          priceDay: '14 000 ₽',
                          onTap: () => _openServiceDetail(
                            context,
                            title: 'Экскаватор для копки траншеи',
                            description:
                                'Экскаватор для земляных работ. Копка траншей, разработка котлованов, выравнивание участка. Работаю аккуратно, соблюдаю сроки. Возможен выезд в ближайшие районы.',
                            priceHour: '1 000 ₽',
                            priceDay: '14 000 ₽',
                            minOrderHours: 4,
                            machinery: const <String>['Экскаватор'],
                            categories: const <String>[
                              'Земляные работы',
                              'Погрузочно-разгрузочные работы',
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _ServiceTile(
                        child: _ServiceItem(
                          equipment: 'Самосвал',
                          title: 'Самосвал для вывоза грунта',
                          description:
                              'Вывоз грунта, мусора и сыпучих материалов. Работаю быстро, без задержек. Возможен выезд в ближайшие районы.',
                          priceHour: '1 500 ₽',
                          priceDay: '18 000 ₽',
                          onTap: () => _openServiceDetail(
                            context,
                            title: 'Самосвал для вывоза грунта',
                            description:
                                'Вывоз грунта, мусора и сыпучих материалов. Работаю быстро, без задержек. Возможен выезд в ближайшие районы.',
                            priceHour: '1 500 ₽',
                            priceDay: '18 000 ₽',
                            minOrderHours: 3,
                            machinery: const <String>['Самосвал'],
                            categories: const <String>[
                              'Погрузочно-разгрузочные работы',
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _ServiceTile(
                        child: _ServiceItem(
                          equipment: 'Автовышка',
                          title: 'Работы на высоте',
                          description:
                              'Работы на высоте: монтаж, обслуживание, обрезка деревьев. Техника исправна, работаю аккуратно.',
                          priceHour: '2 000 ₽',
                          priceDay: '20 000 ₽',
                          onTap: () => _openServiceDetail(
                            context,
                            title: 'Работы на высоте',
                            description:
                                'Работы на высоте: монтаж, обслуживание, обрезка деревьев. Техника исправна, работаю аккуратно.',
                            priceHour: '2 000 ₽',
                            priceDay: '20 000 ₽',
                            minOrderHours: 2,
                            machinery: const <String>['Автовышка'],
                            categories: const <String>['Высотные работы'],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (widget.selectMode || !_alreadyOffered)
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                  16.w,
                  12.h,
                  16.w,
                  16.h + MediaQuery.of(context).padding.bottom),
              child: PrimaryButton(
                label: widget.selectMode
                    ? 'Выбрать исполнителя'
                    : 'Предложить заказ',
                enabled: widget.selectMode || !AccountBlock.isBlocked,
                onPressed: widget.selectMode
                    ? widget.onSelectExecutor
                    : (AccountBlock.isBlocked ? null : _onRespondTap),
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
          CroppedAvatar(size: 72.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Александр Иванов', style: AppTextStyles.titleS),
                SizedBox(height: 4.h),
                Row(
                  children: <Widget>[
                    Image.asset('assets/images/catalog/star.webp',
                        width: 20.r, height: 20.r),
                    SizedBox(width: 4.w),
                    Text('4,5', style: AppTextStyles.body),
                    SizedBox(width: 16.w),
                    Text('15 отзывов',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textPrimary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.textPrimary,
                        )),
                  ],
                ),
              ],
            ),
          ),
        ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.bodyL.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

/// Чип с обводкой (outlined): белая заливка, оранжевая рамка.
class _FilledChipWrap extends StatelessWidget {
  const _FilledChipWrap({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: items
          .map((String label) => Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.primary, width: 1),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  label,
                  style: AppTextStyles.chip.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

/// Блок «Занятость»: неделя + информация о графике на выбранный день.
/// Данные моковые; в проде придут из графика исполнителя.
class _AvailabilitySection extends StatefulWidget {
  const _AvailabilitySection();

  @override
  State<_AvailabilitySection> createState() => _AvailabilitySectionState();
}

class _AvailabilityDay {
  const _AvailabilityDay({
    required this.equipment,
    required this.timeRange,
    required this.radiusKm,
  });
  final List<String> equipment;
  final String timeRange;
  final int radiusKm;
}

class _AvailabilitySectionState extends State<_AvailabilitySection> {
  // Начинаем с сегодняшней даты — как календарь в приложении исполнителя
  // (Профиль → Мой график).
  late DateTime _selected;

  // Моковый график: на этих датах у исполнителя заданы параметры.
  // Остальные дни — «свободен для заказов» без конкретики.
  // Нерабочие дни — в [_dayOffs].
  late final Map<DateTime, _AvailabilityDay> _schedule;
  late final Set<DateTime> _dayOffs;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);

    DateTime off(int days) => _selected.add(Duration(days: days));

    _schedule = <DateTime, _AvailabilityDay>{
      _selected: const _AvailabilityDay(
        equipment: <String>['Экскаватор', 'Автокран', 'Манипулятор'],
        timeRange: 'С 9:00 до 18:00',
        radiusKm: 10,
      ),
      off(1): const _AvailabilityDay(
        equipment: <String>['Экскаватор'],
        timeRange: 'С 9:00 до 17:00',
        radiusKm: 10,
      ),
      off(3): const _AvailabilityDay(
        equipment: <String>['Экскаватор', 'Автокран'],
        timeRange: 'С 10:00 до 19:00',
        radiusKm: 15,
      ),
      off(5): const _AvailabilityDay(
        equipment: <String>['Автокран', 'Манипулятор'],
        timeRange: 'С 8:00 до 17:00',
        radiusKm: 20,
      ),
      off(8): const _AvailabilityDay(
        equipment: <String>['Экскаватор'],
        timeRange: 'С 9:00 до 18:00',
        radiusKm: 10,
      ),
      off(12): const _AvailabilityDay(
        equipment: <String>['Манипулятор'],
        timeRange: 'С 9:00 до 18:00',
        radiusKm: 15,
      ),
    };

    // «Случайно» разбросанные нерабочие дни на месяц вперёд.
    _dayOffs = <DateTime>{
      off(2),
      off(4),
      off(6),
      off(7),
      off(10),
      off(13),
      off(15),
      off(16),
      off(18),
      off(21),
      off(23),
      off(26),
      off(28),
      off(30),
    };
  }

  static const List<String> _monthsGenitive = <String>[
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];

  static const List<String> _monthsNominative = <String>[
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
  ];

  static const List<String> _weekLetters = <String>['п', 'в', 'с', 'ч', 'п', 'с', 'в'];

  // Понедельник недели, содержащей [_selected].
  DateTime get _weekStart {
    final int weekday = _selected.weekday; // 1..7 (пн..вс)
    return DateTime(_selected.year, _selected.month, _selected.day)
        .subtract(Duration(days: weekday - 1));
  }

  void _shiftWeek(int delta) {
    setState(() {
      _selected = _selected.add(Duration(days: 7 * delta));
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  _AvailabilityDay? _dayInfo(DateTime d) {
    final DateTime key = DateTime(d.year, d.month, d.day);
    return _schedule[key];
  }

  bool _isDayOff(DateTime d) =>
      _dayOffs.contains(DateTime(d.year, d.month, d.day));

  @override
  Widget build(BuildContext context) {
    final DateTime start = _weekStart;
    final _AvailabilityDay? info = _dayInfo(_selected);
    final bool selectedDayOff = _isDayOff(_selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _SectionTitle('Занятость'),
            const Spacer(),
            Text(
              '${_monthsNominative[_selected.month - 1]}, ${_selected.year}',
              style: AppTextStyles.body,
            ),
            SizedBox(width: 8.w),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _shiftWeek(-1),
              child: Padding(
                padding: EdgeInsets.all(4.r),
                child: Image.asset(
                    'assets/icons/ui/arrow_left.webp',
                    width: 17.r,
                    height: 17.r),
              ),
            ),
            SizedBox(width: 4.w),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _shiftWeek(1),
              child: Padding(
                padding: EdgeInsets.all(4.r),
                child: Image.asset(
                    'assets/icons/ui/arrow_right.webp',
                    width: 17.r,
                    height: 17.r),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        // Буквы дней недели — раздвинуты до боковых отступов.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            for (int i = 0; i < 7; i++)
              SizedBox(
                width: 36.r,
                child: Center(
                  child: Text(
                    _weekLetters[i],
                    style: AppTextStyles.subBody.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 6.h),
        // Числа недели: выбранный — оранжевый, выходной — F2F2F2, иначе обычный.
        SizedBox(
          height: 44.h,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (int i = 0; i < 7; i++)
                _DayCell(
                  date: start.add(Duration(days: i)),
                  selected: _sameDay(start.add(Duration(days: i)), _selected),
                  dayOff: _isDayOff(start.add(Duration(days: i))),
                  onTap: (DateTime d) => setState(() => _selected = d),
                ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        // Информация по выбранному дню.
        if (selectedDayOff)
          Text(
            'Нерабочий день',
            style: AppTextStyles.body,
          )
        else if (info != null) ...<Widget>[
          _FilledChipWrap(items: info.equipment),
          SizedBox(height: 10.h),
          Text(info.timeRange,
              style: AppTextStyles.body.copyWith(fontSize: 14.sp)),
          SizedBox(height: 10.h),
          Text('Заказы в радиусе ${info.radiusKm} км',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary)),
        ] else
          Text(
            '${_selected.day} ${_monthsGenitive[_selected.month - 1]} — исполнитель свободен для заказов',
            style: AppTextStyles.body,
          ),
      ],
    );
  }
}

/// Ячейка дня в недельном календаре.
/// Выбранный — оранжевый кружок, нерабочий — серый F2F2F2.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.dayOff,
    required this.onTap,
  });
  final DateTime date;
  final bool selected;
  final bool dayOff;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final Color? bg = selected ? AppColors.primary : null;
    final Color textColor = selected
        ? Colors.white
        : dayOff
            ? const Color(0xFFF2F2F2)
            : AppColors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(date),
      child: Center(
        child: Container(
          width: 36.r,
          height: 36.r,
          alignment: Alignment.center,
          decoration: bg != null
              ? BoxDecoration(color: bg, shape: BoxShape.circle)
              : null,
          child: Text('${date.day}',
              style: AppTextStyles.bodyL.copyWith(color: textColor)),
        ),
      ),
    );
  }
}

/// Контейнер-обёртка вокруг [_ServiceItem] с мягкой оранжевой заливкой
/// (`AppColors.fieldFill`). Объединяет карточки услуг в отдельные блоки
/// с закруглёнными углами — так же, как и карточки исполнителей
/// в [SelectExecutorScreen].
class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(14.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Карточка услуги в блоке «Услуги». Стиль — как в `ServiceCard`
/// приложения исполнителя на экране «Мои услуги»: без заливки, тэг
/// техники → заголовок → описание → цены.
class _ServiceItem extends StatelessWidget {
  const _ServiceItem({
    required this.title,
    required this.description,
    this.equipment,
    this.priceHour,
    this.priceDay,
    this.onTap,
  });
  final String title;
  final String description;
  final String? equipment;
  final String? priceHour;
  final String? priceDay;
  final VoidCallback? onTap;

  bool get _hasHour => priceHour != null && priceHour!.isNotEmpty;
  bool get _hasDay => priceDay != null && priceDay!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = AppTextStyles.body.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
    final TextStyle valueStyle = AppTextStyles.bodyMedium.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.primary,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (equipment != null) ...<Widget>[
            Text(
              equipment!,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textTertiary,
                height: 1.78,
              ),
            ),
            SizedBox(height: 4.h),
          ],
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 17.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6.h),
          Text(
            description,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (_hasHour || _hasDay) ...<Widget>[
            SizedBox(height: 10.h),
            Row(
              children: <Widget>[
                if (_hasHour) ...<Widget>[
                  Text('₽ / час', style: labelStyle),
                  SizedBox(width: 6.w),
                  Text(priceHour!, style: valueStyle),
                ],
                if (_hasHour && _hasDay) SizedBox(width: 24.w),
                if (_hasDay) ...<Widget>[
                  Text('₽ / день', style: labelStyle),
                  SizedBox(width: 6.w),
                  Text(priceDay!, style: valueStyle),
                ],
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }
}


