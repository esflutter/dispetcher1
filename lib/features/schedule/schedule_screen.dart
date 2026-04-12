import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';
import 'package:dispatcher_1/features/schedule/day_settings_screen.dart';
import 'package:dispatcher_1/features/schedule/widgets/schedule_alerts.dart';

/// Состояние конкретного дня графика.
enum DayState { noOrders, hasOrders, dayOff }

/// Заказ в выбранном дне графика (mock).
class _ScheduledOrder {
  const _ScheduledOrder({
    required this.status,
    required this.machinery,
    required this.category,
    required this.title,
    required this.rentDate,
    required this.address,
    required this.price,
  });

  final _OrderStatus status;
  final List<String> machinery;
  final String category;
  final String title;
  final String rentDate;
  final String address;
  final String price;
}

enum _OrderStatus { pending, contact }

/// Главный экран «Мой график» — календарь месяца с днями.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // Контекст Figma: Февраль 2026. 21 февраля — выбранный день.
  int _year = 2026;
  int _month = 2;
  int _selectedDay = 21;

  // Mock-состояния для дат. Ключ — день месяца.
  final Map<int, DayState> _dayStates = <int, DayState>{
    17: DayState.dayOff,
  };

  bool _acceptingOrders = true;

  // Mock-заказы для 21 февраля (демонстрация «день с заказами»).
  static const List<_ScheduledOrder> _mockOrders = [
    _ScheduledOrder(
      status: _OrderStatus.pending,
      machinery: ['Автокран', 'Экскаватор'],
      category: 'Земляные работы',
      title: 'Земляные работы',
      rentDate: '21 февраля · 09:00–14:00',
      address: 'Московская область, Москва, Улица1, д.144',
      price: '40 000 – 60 000 ₽',
    ),
    _ScheduledOrder(
      status: _OrderStatus.contact,
      machinery: ['Экскаватор', 'Автокран', 'Эвакуатор', 'Манипулятор', 'Автовышка'],
      category: 'Разработка котлована под фундамент',
      title: 'Разработка котлована под фундамент',
      rentDate: '21 февраля · 15:00–18:00',
      address: 'Московская область, Москва, Улица1, д.144',
      price: '120 000 ₽',
    ),
  ];

  static const _monthNames = [
    '',
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  int get _firstWeekday {
    // Monday = 1 .. Sunday = 7, Figma шапка п в с ч п с в.
    final int w = DateTime(_year, _month, 1).weekday;
    return w;
  }

  DayState _stateFor(int day) {
    if (_dayStates.containsKey(day)) return _dayStates[day]!;
    if (day == _selectedDay) {
      return _acceptingOrders ? DayState.hasOrders : DayState.noOrders;
    }
    return DayState.noOrders;
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year--;
      } else {
        _month--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year++;
      } else {
        _month++;
      }
    });
  }

  Future<void> _openDaySettings() async {
    final DayState? updated = await Navigator.of(context).push<DayState>(
      MaterialPageRoute<DayState>(
        builder: (_) => DaySettingsScreen(
          dayLabel:
              '$_selectedDay ${_monthNames[_month]}, $_year',
          initialState: _stateFor(_selectedDay),
        ),
      ),
    );
    if (updated != null) {
      setState(() {
        _dayStates[_selectedDay] = updated;
        if (_selectedDay == _selectedDay) {
          _acceptingOrders = updated != DayState.dayOff && updated != DayState.noOrders;
        }
      });
    }
  }

  Future<void> _toggleAcceptance(bool value) async {
    if (!value) {
      final bool? ok = await ScheduleAlerts.showCloseAcceptance(context);
      if (ok != true) return;
    }
    setState(() {
      _acceptingOrders = value;
      if (!value) {
        _dayStates[_selectedDay] = DayState.noOrders;
      } else {
        _dayStates.remove(_selectedDay);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final DayState state = _stateFor(_selectedDay);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: DarkSubAppBar(
        title: 'Мой график',
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: IconButton(
              icon: Icon(Icons.edit_outlined,
                  color: AppColors.primary, size: 24.r),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: AppSpacing.md),
          _MonthHeader(
            label: '${_monthNames[_month]}, $_year',
            onPrev: _prevMonth,
            onNext: _nextMonth,
          ),
          SizedBox(height: AppSpacing.sm),
          _WeekdayRow(),
          SizedBox(height: AppSpacing.xs),
          _MonthGrid(
            daysInMonth: _daysInMonth,
            firstWeekday: _firstWeekday,
            selectedDay: _selectedDay,
            stateFor: _stateFor,
            onSelect: (d) => setState(() {
              _selectedDay = d;
              _acceptingOrders = _stateFor(d) != DayState.dayOff &&
                  _stateFor(d) != DayState.noOrders;
            }),
          ),
          SizedBox(height: AppSpacing.md),
          Divider(height: 1.h, color: AppColors.divider),
          if (state != DayState.dayOff) ...[
            _AcceptanceToggle(
              value: _acceptingOrders,
              onChanged: _toggleAcceptance,
            ),
            Divider(height: 1.h, color: AppColors.divider),
          ],
          Expanded(child: _buildDayBody(state)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.md),
          child: PrimaryButton(
            label: state == DayState.dayOff
                ? 'Отметить рабочим'
                : 'Отметить нерабочим',
            onPressed: () {
              setState(() {
                if (state == DayState.dayOff) {
                  _dayStates.remove(_selectedDay);
                  _acceptingOrders = true;
                } else {
                  _dayStates[_selectedDay] = DayState.dayOff;
                }
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDayBody(DayState state) {
    switch (state) {
      case DayState.hasOrders:
        return ListView.separated(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH, vertical: AppSpacing.md),
          itemCount: _mockOrders.length,
          separatorBuilder: (_, _) => SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) => _OrderCard(order: _mockOrders[i]),
        );
      case DayState.dayOff:
        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              'Вы отметили этот день\nвыходным — заказы на него не\nпринимаются',
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
        );
      case DayState.noOrders:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icons/profile/no_orders.webp',
                  width: 80.r, height: 80.r),
              SizedBox(height: AppSpacing.sm),
              Text('Нет заказов',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textPrimary)),
            ],
          ),
        );
    }
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          GestureDetector(
            onTap: onPrev,
            child: Padding(
              padding: EdgeInsets.all(4.r),
              child: Icon(Icons.chevron_left_rounded,
                  size: 28.r, color: AppColors.textPrimary),
            ),
          ),
          SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: onNext,
            child: Padding(
              padding: EdgeInsets.all(4.r),
              child: Icon(Icons.chevron_right_rounded,
                  size: 28.r, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  static const _weekdays = ['п', 'в', 'с', 'ч', 'п', 'с', 'в'];
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Row(
        children: _weekdays
            .map((w) => Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textTertiary),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.daysInMonth,
    required this.firstWeekday,
    required this.selectedDay,
    required this.stateFor,
    required this.onSelect,
  });

  final int daysInMonth;
  final int firstWeekday;
  final int selectedDay;
  final DayState Function(int day) stateFor;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final int leading = firstWeekday - 1; // дней до 1-го
    final int total = leading + daysInMonth;
    final int rows = (total / 7).ceil();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Column(
        children: List.generate(rows, (r) {
          return Row(
            children: List.generate(7, (c) {
              final int cell = r * 7 + c;
              final int day = cell - leading + 1;
              if (day < 1 || day > daysInMonth) {
                return const Expanded(child: SizedBox(height: 44));
              }
              final DayState s = stateFor(day);
              final bool selected = day == selectedDay;
              Color? bg;
              Color textColor = AppColors.textPrimary;
              if (selected) {
                bg = AppColors.primary;
                textColor = Colors.white;
              } else if (s == DayState.dayOff) {
                bg = AppColors.error;
                textColor = Colors.white;
              }
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(day),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 44.h,
                    alignment: Alignment.center,
                    child: Container(
                      width: 36.r,
                      height: 36.r,
                      decoration: BoxDecoration(
                        color: bg,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$day',
                        style: AppTextStyles.body.copyWith(color: textColor),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}

class _AcceptanceToggle extends StatelessWidget {
  const _AcceptanceToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH, vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text('Приём заказов',
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF34C759),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final _ScheduledOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding:
                EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: order.status == _OrderStatus.pending
                  ? const Color(0xFFD7F6CB)
                  : const Color(0xFFDCECFA),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusL),
              ),
            ),
            child: Text(
              order.status == _OrderStatus.pending
                  ? 'Ждёт подтверждения'
                  : 'Свяжитесь с заказчиком',
              style: AppTextStyles.captionBold.copyWith(
                color: order.status == _OrderStatus.pending
                    ? const Color(0xFF1F8A2D)
                    : const Color(0xFF1976D2),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8.w,
                  runSpacing: 4.h,
                  children: order.machinery
                      .map((m) => Text(
                            m,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary),
                          ))
                      .toList(),
                ),
                SizedBox(height: 4.h),
                Text(order.title,
                    style: AppTextStyles.titleS
                        .copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: 4.h),
                _MetaRow(label: 'Дата аренды:', value: order.rentDate),
                SizedBox(height: 2.h),
                _MetaRow(label: 'Адрес:', value: order.address, link: true),
                SizedBox(height: AppSpacing.xs),
                Text(order.price,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.link = false,
  });
  final String label;
  final String value;
  final bool link;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: AppTextStyles.caption.copyWith(
              color: link ? AppColors.primary : AppColors.textPrimary,
              decoration: link ? TextDecoration.underline : null,
              decorationColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
