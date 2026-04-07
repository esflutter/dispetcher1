import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/schedule/schedule_screen.dart';
import 'package:dispatcher_1/features/schedule/widgets/schedule_alerts.dart';

/// Экран «Параметры дня» для группы «Мой график».
/// Поддерживает три режима: открыт приём заказов, закрыт, выходной.
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
  TimeOfDay _from = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 18, minute: 0);
  bool _repeatRegular = false;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
  }

  Future<void> _pickTime({required bool isFrom}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? _from : _to,
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
    }
  }

  Future<void> _onSave() async {
    if (_state == DayState.dayOff && widget.initialState != DayState.dayOff) {
      // Без подтверждения — выходной просто сохраняется.
    }
    if (_state == DayState.noOrders && widget.initialState != DayState.noOrders) {
      // «Закрыт приём заказов» — спросить подтверждение.
      final bool? ok = await ScheduleAlerts.showCloseAcceptance(context);
      if (ok != true) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(_state);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        title: Text('Параметры дня', style: AppTextStyles.titleS),
        leading: const BackButton(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.dayLabel, style: AppTextStyles.h3),
                    SizedBox(height: AppSpacing.lg),
                    Text('Приём заказов', style: AppTextStyles.bodyMedium),
                    SizedBox(height: AppSpacing.sm),
                    _ModeOption(
                      label: 'Открыт приём заказов',
                      selected: _state == DayState.hasOrders ||
                          _state == DayState.noOrders &&
                              widget.initialState == DayState.hasOrders,
                      onTap: () => setState(() => _state = DayState.hasOrders),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    _ModeOption(
                      label: 'Закрыт приём заказов',
                      selected: _state == DayState.noOrders,
                      onTap: () => setState(() => _state = DayState.noOrders),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    _ModeOption(
                      label: 'Выходной',
                      selected: _state == DayState.dayOff,
                      onTap: () => setState(() => _state = DayState.dayOff),
                    ),
                    if (_state != DayState.dayOff) ...[
                      SizedBox(height: AppSpacing.xl),
                      Text('Время работы', style: AppTextStyles.bodyMedium),
                      SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _TimeField(
                              label: 'С',
                              value: _formatTime(_from),
                              onTap: () => _pickTime(isFrom: true),
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _TimeField(
                              label: 'До',
                              value: _formatTime(_to),
                              onTap: () => _pickTime(isFrom: false),
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: AppSpacing.xl),
                    _RepeatCheckbox(
                      value: _repeatRegular,
                      onChanged: (v) => setState(() => _repeatRegular = v),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: PrimaryButton(label: 'Сохранить', onPressed: _onSave),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusL),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.textTertiary,
              size: 22.sp,
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label, style: AppTextStyles.bodyMMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusL),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            ),
            SizedBox(height: AppSpacing.xxs),
            Text(value, style: AppTextStyles.titleS),
          ],
        ),
      ),
    );
  }
}

class _RepeatCheckbox extends StatelessWidget {
  const _RepeatCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox(
            width: 24.w,
            height: 24.w,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.r),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Повторять регулярно', style: AppTextStyles.bodyMRegular),
          ),
        ],
      ),
    );
  }
}
