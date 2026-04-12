import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';

import 'widgets/executor_card_alerts.dart';

/// Длинная форма создания / редактирования карточки исполнителя.
/// Поля из Figma: ФИО, телефон, местоположение (радиус), спецтехника,
/// категории услуг, опыт работы, статус, о себе.
class EditExecutorCardScreen extends StatefulWidget {
  const EditExecutorCardScreen({super.key, this.editing = true});

  final bool editing;

  @override
  State<EditExecutorCardScreen> createState() => _EditExecutorCardScreenState();
}

class _EditExecutorCardScreenState extends State<EditExecutorCardScreen> {
  final _location = TextEditingController(text: 'Москва');
  final _experience = TextEditingController(text: '5 лет');
  final _about = TextEditingController(
      text:
          'Опыт работы более 5 лет. Своя техника в хорошем состоянии, работаю без простоев. Готов выезжать в ближайшие районы.');
  String? _selectedStatus = 'Физ. лицо';
  int _radiusIndex = 0;

  static const _radiusOptions = [
    'В радиусе 10 км',
    'В радиусе 20 км',
    'В радиусе 30 км',
  ];

  static const _statusOptions = [
    'Физ. лицо',
    'ИП',
    'Самозанятый',
    'Юр. лицо',
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
  static const _categories = [
    'Земляные работы',
    'Погрузочно-разгрузочные работы',
    'Перевозка материалов',
    'Строительные работы',
    'Дорожные работы',
    'Буровые работы',
    'Высотные работы',
    'Демонтажные работы',
    'Благоустройство территории',
  ];

  final Set<String> _selMach = {'Экскаватор-погрузчик', 'Погрузчик'};
  final Set<String> _selCat = {
    'Земляные работы',
    'Погрузочно-разгрузочные работы',
  };

  @override
  void dispose() {
    _location.dispose();
    _experience.dispose();
    _about.dispose();
    super.dispose();
  }

  void _openStatusPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: AppSpacing.sm),
            Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: const Color(0xFF929292),
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Text('Укажите статус',
                style: AppTextStyles.titleS
                    .copyWith(fontWeight: FontWeight.w700)),
            SizedBox(height: AppSpacing.sm),
            for (final s in _statusOptions)
              ListTile(
                title: Text(s, style: AppTextStyles.body),
                trailing: _selectedStatus == s
                    ? Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 22.r)
                    : null,
                onTap: () => Navigator.of(ctx).pop(s),
              ),
            SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _selectedStatus = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const DarkSubAppBar(title: 'Моя карточка исполнителя'),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 24.h),
        child: AiAssistantFab(onTap: () => context.push('/assistant/chat')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md,
              AppSpacing.screenH, AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderRow(),
              SizedBox(height: AppSpacing.xs),
              Text('+7 999 123-45-67', style: AppTextStyles.body),
              SizedBox(height: AppSpacing.lg),
              _SectionTitle('Местоположение'),
              SizedBox(height: AppSpacing.xs),
              _LocationField(controller: _location),
              SizedBox(height: AppSpacing.sm),
              for (int i = 0; i < _radiusOptions.length; i++) ...[
                _RadiusOption(
                  label: _radiusOptions[i],
                  selected: _radiusIndex == i,
                  onTap: () => setState(() => _radiusIndex = i),
                ),
                if (i != _radiusOptions.length - 1) SizedBox(height: 6.h),
              ],
              SizedBox(height: AppSpacing.lg),
              _SectionTitle('Спецтехника'),
              SizedBox(height: AppSpacing.xs),
              _ChipWrap(
                items: _machinery,
                selected: _selMach,
                onToggle: (v) => setState(() {
                  _selMach.contains(v) ? _selMach.remove(v) : _selMach.add(v);
                }),
              ),
              SizedBox(height: AppSpacing.lg),
              _SectionTitle('Категории услуг'),
              SizedBox(height: AppSpacing.xs),
              _ChipWrap(
                items: _categories,
                selected: _selCat,
                onToggle: (v) => setState(() {
                  _selCat.contains(v) ? _selCat.remove(v) : _selCat.add(v);
                }),
              ),
              SizedBox(height: AppSpacing.lg),
              _SectionTitle('Опыт работы'),
              SizedBox(height: AppSpacing.xs),
              _TintField(
                controller: _experience,
                hint: 'Например: 5 лет',
              ),
              SizedBox(height: AppSpacing.lg),
              _SectionTitle('Статус'),
              SizedBox(height: AppSpacing.xs),
              GestureDetector(
                onTap: _openStatusPicker,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 54.h,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusM),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedStatus ?? 'Укажите статус',
                          style: AppTextStyles.body.copyWith(
                            color: _selectedStatus == null
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 22.r, color: AppColors.textPrimary),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              _SectionTitle('О себе'),
              SizedBox(height: AppSpacing.xs),
              _TintField(
                controller: _about,
                hint: 'Расскажите о себе',
                maxLines: 4,
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Информация о вас помогает другим лучше понять, '
                'с кем они будут работать.',
                style: AppTextStyles.caption
                    .copyWith(color: const Color(0xFF707070)),
              ),
              SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: widget.editing ? 'Сохранить' : 'Создать',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Сохранено'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  Navigator.of(context).maybePop();
                },
              ),
              if (widget.editing) ...[
                SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 54.h,
                  child: TextButton(
                    onPressed: () async {
                      final ok = await showDeleteExecutorCardAlert(context);
                      if (ok == true && context.mounted) {
                        Navigator.of(context).maybePop();
                      }
                    },
                    child: Text(
                      'Удалить карточку',
                      style: AppTextStyles.button
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                ),
              ],
              SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56.r,
          height: 56.r,
          decoration: const BoxDecoration(
            color: AppColors.surfaceVariant,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(Icons.person, size: 32.r, color: AppColors.textTertiary),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Александр Иванов',
                  style: AppTextStyles.titleS
                      .copyWith(fontWeight: FontWeight.w600)),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Icon(Icons.star_rounded,
                      color: AppColors.ratingStar, size: 16.r),
                  SizedBox(width: 4.w),
                  Text('4,5', style: AppTextStyles.caption),
                  SizedBox(width: 6.w),
                  Text('15 отзывов',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary,
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
      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: 'Укажите ваше местоположение',
        hintStyle:
            AppTextStyles.body.copyWith(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _RadiusOption extends StatelessWidget {
  const _RadiusOption({
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
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 22.r,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
            SizedBox(width: AppSpacing.xs),
            Text(label, style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }
}

class _TintField extends StatelessWidget {
  const _TintField({
    required this.controller,
    this.hint,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String? hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({
    required this.items,
    required this.selected,
    required this.onToggle,
  });
  final List<String> items;
  final Set<String> selected;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: items.map((label) {
        final on = selected.contains(label);
        return GestureDetector(
          onTap: () => onToggle(label),
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
    );
  }
}
