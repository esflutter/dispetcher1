import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';
import 'package:dispatcher_1/features/schedule/schedule_screen.dart';
import 'package:dispatcher_1/features/schedule/widgets/schedule_alerts.dart';

/// Экран «Параметры дня» для группы «Мой график».
class DaySettingsScreen extends StatefulWidget {
  const DaySettingsScreen({
    super.key,
    required this.dayLabel,
    required this.initialState,
  });

  final String dayLabel;
  final DayState initialState;

  @override
  State<DaySettingsScreen> createState() => _DaySettingsScreenState();
}

class _DaySettingsScreenState extends State<DaySettingsScreen> {
  late DayState _state;
  late bool _accepting;
  int _fromHour = 18;
  int _toHour = 18;
  bool _allDay = false;
  int _radiusIndex = 0;

  final Set<String> _selMach = {'Экскаватор-погрузчик', 'Погрузчик'};

  static const _radiusOptions = [
    'В радиусе 10 км',
    'В радиусе 20 км',
    'В радиусе 30 км',
  ];
  static const _machinery = [
    'Экскаватор-погрузчик',
    'Погрузчик',
    'Миниэкскаватор',
    'Минипогрузчик',
    'Буроям',
    'Самогруз',
    'Автокран',
    'Самосвалы (до 5тн, 15, 25)',
    'Бетононасос',
    'Эвакуатор',
    'Автовышка',
    'Манипулятор',
    'Минитрактор',
    'Экскаватор',
    'Инертные материалы',
  ];

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _accepting = _state == DayState.hasOrders;
  }

  Future<void> _toggleAccepting(bool value) async {
    if (!value && _state == DayState.hasOrders) {
      final bool? ok = await ScheduleAlerts.showCloseAcceptance(context);
      if (ok != true) return;
    }
    setState(() {
      _accepting = value;
      _state = value ? DayState.hasOrders : DayState.noOrders;
    });
  }

  void _markAsDayOff() {
    setState(() => _state = DayState.dayOff);
    Navigator.of(context).pop(DayState.dayOff);
  }

  void _markAsWorking() {
    setState(() {
      _state = DayState.hasOrders;
      _accepting = true;
    });
    Navigator.of(context).pop(DayState.hasOrders);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const DarkSubAppBar(title: 'Параметры дня'),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 88.h),
        child: AiAssistantFab(onTap: () => context.push('/assistant/chat')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
                  AppSpacing.screenH, AppSpacing.md),
              child: PrimaryButton(
                label: _state == DayState.dayOff
                    ? 'Отметить рабочим'
                    : 'Отметить нерабочим',
                onPressed: _state == DayState.dayOff
                    ? _markAsWorking
                    : _markAsDayOff,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md,
          AppSpacing.screenH, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.dayLabel,
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700)),
          SizedBox(height: AppSpacing.md),
          Divider(height: 1.h, color: AppColors.divider),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text('Приём заказов',
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: _accepting && _state != DayState.dayOff,
                  onChanged:
                      _state == DayState.dayOff ? null : _toggleAccepting,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF34C759),
                ),
              ],
            ),
          ),
          Divider(height: 1.h, color: AppColors.divider),
          SizedBox(height: AppSpacing.md),
          if (_state == DayState.dayOff)
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(
                child: Text(
                  'Вы отметили этот день\nвыходным — заказы на него не\nпринимаются',
                  style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_accepting)
            ..._acceptingBody()
          else
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(
                child: Text(
                  'Приём заказов на этот день\nзакрыт',
                  style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _acceptingBody() {
    return [
      Text('Время работы',
          style: AppTextStyles.bodyMedium
              .copyWith(fontWeight: FontWeight.w700)),
      SizedBox(height: AppSpacing.xs),
      Row(
        children: [
          Expanded(
            child: _HourField(
              label: 'С',
              hour: _fromHour,
              onChanged: (v) => setState(() => _fromHour = v),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _HourField(
              label: 'По',
              hour: _toHour,
              onChanged: (v) => setState(() => _toHour = v),
            ),
          ),
        ],
      ),
      SizedBox(height: AppSpacing.sm),
      GestureDetector(
        onTap: () => setState(() => _allDay = !_allDay),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            SizedBox(
              width: 24.r,
              height: 24.r,
              child: Checkbox(
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v ?? false),
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Text('Весь день', style: AppTextStyles.body),
          ],
        ),
      ),
      SizedBox(height: AppSpacing.lg),
      Text('Спецтехника',
          style: AppTextStyles.bodyMedium
              .copyWith(fontWeight: FontWeight.w700)),
      SizedBox(height: AppSpacing.xs),
      Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: _machinery.map((label) {
          final on = _selMach.contains(label);
          return GestureDetector(
            onTap: () => setState(() {
              on ? _selMach.remove(label) : _selMach.add(label);
            }),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: on ? AppColors.primary : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: AppTextStyles.chip.copyWith(
                        fontSize: 13.sp,
                        color: on ? Colors.white : AppColors.textPrimary,
                      )),
                  if (on) ...[
                    SizedBox(width: 6.w),
                    Icon(Icons.close_rounded, size: 12.r, color: Colors.white),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
      SizedBox(height: AppSpacing.lg),
      Text('Местоположение',
          style: AppTextStyles.bodyMedium
              .copyWith(fontWeight: FontWeight.w700)),
      SizedBox(height: AppSpacing.xs),
      Container(
        height: 52.h,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
        ),
        child: Row(
          children: [
            Expanded(child: Text('Москва', style: AppTextStyles.body)),
          ],
        ),
      ),
      SizedBox(height: AppSpacing.sm),
      for (int i = 0; i < _radiusOptions.length; i++) ...[
        GestureDetector(
          onTap: () => setState(() => _radiusIndex = i),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: Row(
              children: [
                Icon(
                  _radiusIndex == i
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 22.r,
                  color: _radiusIndex == i
                      ? AppColors.primary
                      : AppColors.textTertiary,
                ),
                SizedBox(width: AppSpacing.xs),
                Text(_radiusOptions[i], style: AppTextStyles.body),
              ],
            ),
          ),
        ),
      ],
    ];
  }
}

class _HourField extends StatelessWidget {
  const _HourField({
    required this.label,
    required this.hour,
    required this.onChanged,
  });

  final String label;
  final int hour;
  final ValueChanged<int> onChanged;

  String _f(int v) => '${v.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: 0),
        );
        if (picked != null) onChanged(picked.hour);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52.h,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
        ),
        child: Row(
          children: [
            Text('$label   ', style: AppTextStyles.body),
            Expanded(child: Text(_f(hour), style: AppTextStyles.body)),
            Icon(Icons.access_time_rounded,
                size: 20.r, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
