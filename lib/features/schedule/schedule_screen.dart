import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';
import 'package:dispatcher_1/features/orders/widgets/order_status_pill.dart';
import 'package:dispatcher_1/features/orders/order_detail_screen.dart';
import 'package:dispatcher_1/features/schedule/day_settings_screen.dart';

/// Состояние конкретного дня графика.
enum DayState { noOrders, hasOrders, dayOff }

class _ScheduledOrder {
  const _ScheduledOrder({
    required this.status,
    required this.machinery,
    required this.title,
    required this.rentDate,
    required this.address,
    required this.price,
  });
  final MyOrderStatus status;
  final List<String> machinery;
  final String title;
  final String rentDate;
  final String address;
  final String price;
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _selectedDate;
  late DateTime _weekStart;
  late PageController _pageCtrl;

  /// Начальная неделя (для расчёта индекса страницы).
  late DateTime _originWeek;

  final Map<DateTime, DayState> _dayStates = {};

  bool _acceptingOrders = true;

  /// Заказы по дню недели (1=пн..7=вс). Повторяется каждую неделю.
  static const Map<int, List<_ScheduledOrder>> _ordersByWeekday = {
    1: [ // понедельник — 3 заказа
      _ScheduledOrder(
        status: MyOrderStatus.waiting,
        machinery: ['Автокран', 'Экскаватор'],
        title: 'Земляные работы',
        rentDate: '09:00–12:00',
        address: 'Московская область, Москва, Улица1, д.144',
        price: '40 000 – 60 000 ₽',
      ),
      _ScheduledOrder(
        status: MyOrderStatus.accepted,
        machinery: ['Погрузчик'],
        title: 'Погрузка строительного мусора',
        rentDate: '13:00–16:00',
        address: 'Московская область, Москва, Проспект Мира, д.12',
        price: '25 000 ₽',
      ),
      _ScheduledOrder(
        status: MyOrderStatus.waiting,
        machinery: ['Манипулятор'],
        title: 'Доставка бетонных плит',
        rentDate: '17:00–19:00',
        address: 'Московская область, Химки, ул. Ленина, д.5',
        price: '35 000 ₽',
      ),
    ],
    2: [ // вторник — 1 заказ
      _ScheduledOrder(
        status: MyOrderStatus.accepted,
        machinery: ['Экскаватор', 'Самосвал'],
        title: 'Копка траншеи под фундамент',
        rentDate: '08:00–17:00',
        address: 'Московская область, Подольск, ул. Кирова, д.88',
        price: '80 000 ₽',
      ),
    ],
    3: [], // среда — 0 заказов
    4: [ // четверг — 2 заказа
      _ScheduledOrder(
        status: MyOrderStatus.waiting,
        machinery: ['Автокран', 'Экскаватор'],
        title: 'Земляные работы',
        rentDate: '09:00–14:00',
        address: 'Московская область, Москва, Улица1, д.144',
        price: '40 000 – 60 000 ₽',
      ),
      _ScheduledOrder(
        status: MyOrderStatus.accepted,
        machinery: ['Экскаватор', 'Автокран', 'Эвакуатор', 'Манипулятор', 'Автовышка'],
        title: 'Разработка котлована под фундамент',
        rentDate: '15:00–18:00',
        address: 'Московская область, Москва, Улица1, д.144',
        price: '120 000 ₽',
      ),
    ],
    5: [ // пятница — 1 заказ
      _ScheduledOrder(
        status: MyOrderStatus.waiting,
        machinery: ['Автовышка'],
        title: 'Монтаж рекламного баннера',
        rentDate: '10:00–13:00',
        address: 'Москва, ул. Тверская, д.22',
        price: '18 000 ₽',
      ),
    ],
    // 6 суббота, 7 воскресенье — 0 заказов
  };

  static const _monthNames = [
    '', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
  ];

  static const int _initialPage = 5000;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _weekStart = _mondayOf(_selectedDate);
    _originWeek = _weekStart;
    _pageCtrl = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  DateTime _weekFromPage(int page) =>
      _originWeek.add(Duration(days: (page - _initialPage) * 7));

  List<DateTime> _weekDaysFor(DateTime monday) =>
      List.generate(7, (i) => monday.add(Duration(days: i)));

  void _onPageChanged(int page) {
    final newWeek = _weekFromPage(page);
    setState(() {
      _weekStart = newWeek;
      _selectedDate = newWeek;
      _acceptingOrders = _stateFor(_selectedDate) != DayState.dayOff;
    });
  }

  DateTime _mondayOf(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1));

  String get _headerLabel {
    final days = _weekDaysFor(_weekStart);
    final first = days.first;
    final last = days.last;
    if (first.month == last.month) {
      return '${_monthNames[first.month]}, ${first.year}';
    }
    if (first.year == last.year) {
      return '${_monthNames[first.month]}–${_monthNames[last.month]}, ${first.year}';
    }
    return '${_monthNames[first.month]}, ${first.year} – ${_monthNames[last.month]}, ${last.year}';
  }

  DateTime _dateKey(DateTime d) => DateTime(d.year, d.month, d.day);

  DayState _stateFor(DateTime d) {
    final key = _dateKey(d);
    if (_dayStates.containsKey(key)) return _dayStates[key]!;
    final orders = _ordersByWeekday[d.weekday] ?? [];
    return orders.isNotEmpty ? DayState.hasOrders : DayState.noOrders;
  }

  void _prevWeek() {
    _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _nextWeek() {
    _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _openDaySettings() async {
    final key = _dateKey(_selectedDate);
    final DayState? updated = await Navigator.of(context).push<DayState>(
      MaterialPageRoute<DayState>(
        builder: (_) => DaySettingsScreen(
          dayLabel: '${_selectedDate.day} ${_monthNames[_selectedDate.month]}, ${_selectedDate.year}',
          initialState: _stateFor(_selectedDate),
        ),
      ),
    );
    if (updated != null) {
      setState(() {
        _dayStates[key] = updated;
        _acceptingOrders = updated != DayState.dayOff && updated != DayState.noOrders;
      });
    }
  }

  Future<void> _toggleAcceptance(bool value) async {
    if (!value) {
      final bool? ok = await _showCloseDialog();
      if (ok != true) return;
    }
    setState(() => _acceptingOrders = value);
  }

  Future<bool?> _showCloseDialog() {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 16.w),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 22.r),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(false),
                  child: Icon(Icons.close_rounded,
                      size: 22.r, color: AppColors.textTertiary),
                ),
              ),
              SizedBox(height: 16.h),
              Text('Закрыть приём заказов?',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleL.copyWith(fontWeight: FontWeight.w700)),
              SizedBox(height: 8.h),
              Text('Новые заказы на этот день поступать не будут',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
              SizedBox(height: 18.h),
              PrimaryButton(
                label: 'Закрыть',
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
              SizedBox(height: 12.h),
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(false),
                child: Center(
                  child: Text('Вернуться',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textPrimary)),
                ),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DayState state = _stateFor(_selectedDate);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: DarkSubAppBar(
        title: 'Мой график',
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: IconButton(
              icon: Image.asset('assets/icons/profile/pen.webp',
                  width: 24.r, height: 24.r),
              onPressed: _openDaySettings,
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 88.h),
        child: AiAssistantFab(onTap: () => context.push('/assistant/chat')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 16.h),
            // Заголовок месяца
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _headerLabel,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _prevWeek,
                    child: Padding(
                      padding: EdgeInsets.all(4.r),
                      child: Image.asset('assets/icons/profile/arrow_left_calendar.webp',
                          width: 24.r, height: 24.r),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  GestureDetector(
                    onTap: _nextWeek,
                    child: Padding(
                      padding: EdgeInsets.all(4.r),
                      child: Image.asset('assets/icons/profile/arrow_right_calendar.webp',
                          width: 24.r, height: 24.r),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            // Дни недели
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: ['п', 'в', 'с', 'ч', 'п', 'с', 'в']
                    .map((w) => Expanded(
                          child: Center(
                            child: Text(w,
                                style: AppTextStyles.subBody
                                    .copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w400)),
                          ),
                        ))
                    .toList(),
              ),
            ),
            SizedBox(height: 6.h),
            // Одна неделя — свайпаемая
            SizedBox(
              height: 44.h,
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: _onPageChanged,
                itemBuilder: (_, page) {
                  final monday = _weekFromPage(page);
                  final days = _weekDaysFor(monday);
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: days.map((day) {
                        final bool selected = _dateKey(day) == _dateKey(_selectedDate);
                        final DayState s = _stateFor(day);
                        Color? bg;
                        Color textColor = AppColors.textPrimary;
                        if (selected) {
                          bg = AppColors.primary;
                          textColor = Colors.white;
                        } else if (s == DayState.dayOff) {
                          bg = const Color(0xFFEB4E3D);
                          textColor = Colors.white;
                        }
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedDate = day;
                              _acceptingOrders = _stateFor(day) != DayState.dayOff;
                            }),
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: Container(
                                width: 36.r,
                                height: 36.r,
                                decoration: BoxDecoration(
                                  color: bg,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text('${day.day}',
                                    style: AppTextStyles.bodyL.copyWith(color: textColor)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12.h),
            // Тоггл приёма заказов
            if (state != DayState.dayOff) ...[
              Divider(height: 1, thickness: 0.5, color: Colors.grey.shade300),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Приём заказов',
                          style: AppTextStyles.button),  // 16sp w600
                    ),
                    ScheduleToggle(
                      value: _acceptingOrders,
                      onChanged: _toggleAcceptance,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 0.5, color: Colors.grey.shade300),
            ],
            // Контент дня
            Expanded(child: _buildDayBody(state)),
            // Кнопка с тенью
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    offset: const Offset(0, -1),
                    blurRadius: 8,
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
              child: PrimaryButton(
                label: state == DayState.dayOff
                    ? 'Отметить рабочим'
                    : 'Отметить нерабочим',
                onPressed: () {
                  final key = _dateKey(_selectedDate);
                  setState(() {
                    if (state == DayState.dayOff) {
                      _dayStates.remove(key);
                      _acceptingOrders = true;
                    } else {
                      _dayStates[key] = DayState.dayOff;
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayBody(DayState state) {
    if (state == DayState.dayOff) {
      return Padding(
        padding: EdgeInsets.only(bottom: 40.h),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              'Вы отметили этот день выходным — заказы на него не принимаются',
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, height: 1.3),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final orders = _ordersByWeekday[_selectedDate.weekday] ?? [];
    if (orders.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: 40.h),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icons/profile/no_orders.webp',
                  width: 80.r, height: 80.r),
                SizedBox(height: 12.h),
                Text('Нет заказов',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
        );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemCount: orders.length,
      separatorBuilder: (_, _) => Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Divider(height: 1, thickness: 1, color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      itemBuilder: (_, i) => _OrderCard(order: orders[i]),
    );
  }
}

class ScheduleToggle extends StatelessWidget {
  const ScheduleToggle({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final double w = 52.r;
    final double h = 32.r;
    final double thumb = 28.r;
    final double pad = 2.r;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(h / 2),
          color: value ? const Color(0xFF34C759) : const Color(0xFFE0E0E0),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: thumb,
            height: thumb,
            margin: EdgeInsets.all(pad),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final _ScheduledOrder order;

  @override
  Widget build(BuildContext context) {
    final TextStyle tagStyle = TextStyle(
      fontFamily: 'Roboto',
      fontSize: 12.sp,
      fontWeight: FontWeight.w400,
      color: AppColors.textTertiary,
      height: 1.78,
    );
    final detailState = order.status == MyOrderStatus.waiting
        ? MyOrderDetailState.waitingConfirm
        : MyOrderDetailState.confirmed;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MyOrderDetailScreen(
            title: order.title,
            equipment: order.machinery,
            rentDate: order.rentDate,
            address: order.address,
            price: order.price,
            state: detailState,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderStatusPill(status: order.status),
        SizedBox(height: 6.h),
        Text(
          order.machinery.join('   '),
          style: tagStyle,
        ),
        SizedBox(height: 8.h),
        Text(
          order.title,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 8.h),
        _LabelLine(label: 'Дата аренды:', value: order.rentDate),
        SizedBox(height: 5.h),
        _LabelLine(label: 'Адрес:', value: order.address, underlined: true),
        SizedBox(height: 8.h),
        Text(order.price,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            )),
        ],
      ),
    );
  }
}

class _LabelLine extends StatelessWidget {
  const _LabelLine({
    required this.label,
    required this.value,
    this.underlined = false,
  });
  final String label;
  final String value;
  final bool underlined;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13.sp,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
        children: <TextSpan>[
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              decoration: underlined ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
