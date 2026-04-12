import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';

import 'widgets/service_alerts.dart';

/// Экран «Создание / редактирование услуги».
/// При передаче [serviceId] работает в режиме редактирования.
class CreateServiceScreen extends StatefulWidget {
  const CreateServiceScreen({super.key, this.serviceId});

  final String? serviceId;

  @override
  State<CreateServiceScreen> createState() => _CreateServiceScreenState();
}

class _CreateServiceScreenState extends State<CreateServiceScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _priceHour = TextEditingController();
  final _priceDay = TextEditingController();
  final _minHours = TextEditingController();
  final _aiPrompt = TextEditingController();

  bool _aiMode = false;
  int _radiusIndex = 0;

  final Set<String> _selCat = {
    'Земляные работы',
    'Погрузочно-разгрузочные работы',
  };
  final Set<String> _selMach = {'Экскаватор', 'Погрузчик'};

  static const _radiusOptions = [
    'В радиусе 10 км',
    'В радиусе 20 км',
    'В радиусе 30 км',
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

  bool get _isEdit => widget.serviceId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _title.text = 'Разработка котлована под фундамент';
      _desc.text =
          'Экскаватор для земляных работ. Копка траншей, разработка котлованов.';
      _priceHour.text = '1000';
      _priceDay.text = '14000';
      _minHours.text = '4';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _priceHour.dispose();
    _priceDay.dispose();
    _minHours.dispose();
    _aiPrompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _isEdit
          ? const DarkSubAppBar(title: 'Редактирование услуги')
          : _CreateAppBar(onClose: () => Navigator.of(context).maybePop()),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 88.h),
        child: AiAssistantFab(onTap: () => context.push('/assistant/chat')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: _aiMode && !_isEdit ? _buildAiMode() : _buildManualMode(),
      ),
    );
  }

  Widget _buildManualMode() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md,
                AppSpacing.screenH, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Категория услуг'),
                SizedBox(height: AppSpacing.xs),
                _ChipWrap(
                  items: _categories,
                  selected: _selCat,
                  onToggle: (v) => setState(() {
                    _selCat.contains(v) ? _selCat.remove(v) : _selCat.add(v);
                  }),
                ),
                SizedBox(height: AppSpacing.md),
                _SectionTitle('Спецтехника'),
                SizedBox(height: AppSpacing.xs),
                _ChipWrap(
                  items: _machinery,
                  selected: _selMach,
                  onToggle: (v) => setState(() {
                    _selMach.contains(v) ? _selMach.remove(v) : _selMach.add(v);
                  }),
                ),
                SizedBox(height: AppSpacing.md),
                _SectionTitle('Название услуги'),
                SizedBox(height: AppSpacing.xs),
                _TintField(
                  controller: _title,
                  hint: 'Например: Экскаватор для земляных работ',
                ),
                SizedBox(height: AppSpacing.md),
                _SectionTitle('Описание услуги'),
                SizedBox(height: AppSpacing.xs),
                _TintField(
                  controller: _desc,
                  hint: 'Опишите, какие работы вы\nвыполняете и условия работы',
                  maxLines: 4,
                ),
                SizedBox(height: AppSpacing.md),
                _SectionTitle('Фото'),
                SizedBox(height: 2.h),
                Text(
                  'По желанию добавьте к услуге фото, до 8 шт.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                SizedBox(height: AppSpacing.xs),
                _PhotosPicker(),
                SizedBox(height: AppSpacing.md),
                _SectionTitle('Стоимость'),
                SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: _TintField(
                        controller: _priceHour,
                        hint: '₽ / час',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _TintField(
                        controller: _priceDay,
                        hint: '₽ / день',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                _SectionTitle('Минимальный заказ'),
                SizedBox(height: AppSpacing.xs),
                _TintField(
                  controller: _minHours,
                  hint: 'ч',
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 4.h),
                Text(
                  'Укажите минимальное количество часов для заказа',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                SizedBox(height: AppSpacing.md),
                _SectionTitle('Местоположение'),
                SizedBox(height: AppSpacing.xs),
                _TintField(
                  controller: TextEditingController(text: 'Москва'),
                  hint: 'Москва',
                ),
                SizedBox(height: AppSpacing.sm),
                for (int i = 0; i < _radiusOptions.length; i++) ...[
                  _RadiusOption(
                    label: _radiusOptions[i],
                    selected: _radiusIndex == i,
                    onTap: () => setState(() => _radiusIndex = i),
                  ),
                  if (i != _radiusOptions.length - 1) SizedBox(height: 4.h),
                ],
                SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
              AppSpacing.screenH, AppSpacing.md),
          child: _isEdit ? _editButtons() : _createButtons(),
        ),
      ],
    );
  }

  Widget _createButtons() {
    return Column(
      children: [
        PrimaryButton(
          label: 'Создать',
          onPressed: () => context.push('/subscription/tariffs'),
        ),
        SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          height: 54.h,
          child: TextButton(
            onPressed: () => setState(() => _aiMode = true),
            child: Text('Заполнить автоматически',
                style: AppTextStyles.button
                    .copyWith(color: AppColors.primary)),
          ),
        ),
      ],
    );
  }

  Widget _editButtons() {
    return Column(
      children: [
        PrimaryButton(
          label: 'Сохранить',
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
        SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          height: 54.h,
          child: TextButton(
            onPressed: () async {
              final ok = await showDeleteServiceSheet(context,
                  serviceTitle: _title.text);
              if (!mounted) return;
              if (ok == true) {
                Navigator.of(context).maybePop();
              }
            },
            child: Text('Удалить услугу',
                style: AppTextStyles.button.copyWith(color: AppColors.error)),
          ),
        ),
      ],
    );
  }

  Widget _buildAiMode() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, 0),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(AppSpacing.radiusM),
            ),
            child: Text(
              'Опишите услугу — текстом или голосом, я заполню всё за вас',
              style: AppTextStyles.body,
            ),
          ),
        ),
        const Spacer(),
        _AiInputBar(
          controller: _aiPrompt,
          onSend: () {
            setState(() => _aiMode = false);
          },
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

class _TintField extends StatelessWidget {
  const _TintField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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
    );
  }
}

class _PhotosPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80.r,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Container(
            width: 80.r,
            height: 80.r,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(AppSpacing.radiusM),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.add_photo_alternate_outlined,
                color: AppColors.primary, size: 28.r),
          ),
          SizedBox(width: AppSpacing.xs),
          for (int i = 0; i < 3; i++) ...[
            Container(
              width: 80.r,
              height: 80.r,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusM),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.image_outlined,
                  size: 28.r, color: AppColors.textTertiary),
            ),
            if (i < 2) SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _AiInputBar extends StatelessWidget {
  const _AiInputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.navBarDark,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              width: 44.r,
              height: 44.r,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusM),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.image_outlined,
                  color: Colors.white, size: 22.r),
            ),
            SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Container(
                height: 44.r,
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Написать...',
                          hintStyle: AppTextStyles.body
                              .copyWith(color: AppColors.textTertiary),
                          isCollapsed: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    Icon(Icons.mic_none_rounded,
                        size: 22.r, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 22.r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AppBar режима создания услуги: тёмный фон, крестик вместо стрелки
/// назад, по высоте совпадает с `DarkSubAppBar`.
class _CreateAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CreateAppBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Size get preferredSize => Size.fromHeight(48.h);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.navBarDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 48.h,
      automaticallyImplyLeading: false,
      title: Padding(
        padding: EdgeInsets.only(top: 2.h),
        child: Text(
          'Создание услуги',
          style: AppTextStyles.titleS.copyWith(color: Colors.white),
        ),
      ),
      actions: <Widget>[
        Padding(
          padding: EdgeInsets.only(right: 8.w, top: 2.h),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.close_rounded, size: 24.r, color: Colors.white),
            onPressed: onClose,
          ),
        ),
      ],
    );
  }
}
