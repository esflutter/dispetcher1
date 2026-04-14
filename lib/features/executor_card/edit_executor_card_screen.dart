import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/cropped_avatar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/auth/photo_crop_screen.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';

import 'executor_card_screen.dart';

/// Форма создания / редактирования карточки заказчика.
/// Поля: ФИО, телефон, местоположение, статус, о себе.
class EditExecutorCardScreen extends StatefulWidget {
  const EditExecutorCardScreen({super.key, this.editing = true});

  final bool editing;

  @override
  State<EditExecutorCardScreen> createState() => _EditExecutorCardScreenState();
}

class _EditExecutorCardScreenState extends State<EditExecutorCardScreen> {
  late final TextEditingController _about;
  String? _selectedStatus;

  bool _statusExpanded = false;

  static const _statusOptions = [
    'Физ. лицо',
    'Самозанятый',
    'ИП',
    'Юр. лицо',
  ];

  @override
  void initState() {
    super.initState();
    _about = TextEditingController(text: ExecutorCardData.about ?? '');
    _selectedStatus = ExecutorCardData.status;
  }

  @override
  void dispose() {
    _about.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const DarkSubAppBar(title: 'Моя карточка заказчика'),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 88.h),
        child: AiAssistantFab(onTap: () => context.push('/assistant/chat')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md,
                    AppSpacing.screenH, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              _HeaderRow(),
              SizedBox(height: 16.h),
              Container(
                height: 56.h,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                alignment: Alignment.centerLeft,
                child: Text('Александр Иванов', style: AppTextStyles.body),
              ),
              SizedBox(height: 8.h),
              Container(
                height: 56.h,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                alignment: Alignment.centerLeft,
                child: Text('+7 999 123-45-67', style: AppTextStyles.body),
              ),
              SizedBox(height: AppSpacing.lg),
              _SectionTitle('Статус'),
              SizedBox(height: AppSpacing.xs),
              GestureDetector(
                onTap: () => setState(() => _statusExpanded = !_statusExpanded),
                child: Container(
                  height: 54.h,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: _statusExpanded
                        ? BorderRadius.vertical(top: Radius.circular(12.r))
                        : BorderRadius.circular(AppSpacing.radiusM),
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
                      Image.asset(
                        _statusExpanded
                            ? 'assets/icons/ui/arrow_up.webp'
                            : 'assets/icons/ui/arrow_down.webp',
                        width: 22.r,
                        height: 22.r,
                      ),
                    ],
                  ),
                ),
              ),
              if (_statusExpanded)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(12.r)),
                  ),
                  child: Column(
                    children: [
                      Divider(height: 1, thickness: 0.5, color: Colors.grey.shade300),
                      for (final s in _statusOptions)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() {
                            _selectedStatus = s;
                            _statusExpanded = false;
                          }),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.md, vertical: 12.h),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(s, style: AppTextStyles.body),
                                ),
                                if (_selectedStatus == s)
                                  Image.asset('assets/icons/ui/check_black.webp',
                                      width: 22.r, height: 22.r),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              SizedBox(height: AppSpacing.lg),
              _SectionTitle('О себе'),
              SizedBox(height: AppSpacing.xs),
              _TintField(
                controller: _about,
                hint: 'Расскажите о себе',
                minLines: 1,
                maxLength: 500,
                maxLines: 5,
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Информация о вас помогает другим лучше понять, '
                'с кем они будут работать.',
                style: AppTextStyles.caption
                    .copyWith(color: const Color(0xFF707070)),
              ),
                  SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
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
                label: 'Сохранить',
                onPressed: () {
                  ExecutorCardData.status = _selectedStatus;
                  ExecutorCardData.about = _about.text;
                  ExecutorCardScreen.cardCreated = true;
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatefulWidget {
  @override
  State<_HeaderRow> createState() => _HeaderRowState();
}

class _HeaderRowState extends State<_HeaderRow> {
  Future<void> _openCrop() async {
    final result = await Navigator.of(context).push<CropResult>(
      MaterialPageRoute(builder: (_) => const PhotoCropScreen()),
    );
    if (result != null && mounted) {
      setState(() => CropResult.saved = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _openCrop,
          child: SizedBox(
            width: 80.r,
            height: 80.r,
            child: Stack(
              children: [
                CroppedAvatar(size: 80.r),
                Positioned(
                  right: -1.w,
                  bottom: 0,
                  child: Image.asset(
                    'assets/icons/ui/edit.webp',
                    width: 21.r,
                    height: 21.r,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Александр Иванов',
                  style: AppTextStyles.titleS),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Image.asset('assets/images/catalog/star.webp',
                      width: 20.r, height: 20.r),
                  SizedBox(width: 4.w),
                  Text('4,5', style: AppTextStyles.body),
                  SizedBox(width: 16.w),
                  GestureDetector(
                    onTap: () => context.push('/profile/reviews'),
                    child: Text('10 отзывов',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textPrimary,
                          decoration: TextDecoration.underline,
                        )),
                  ),
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

class _TintField extends StatelessWidget {
  const _TintField({
    required this.controller,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
  });
  final TextEditingController controller;
  final String? hint;
  final int minLines;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      buildCounter: maxLength != null ? (_, {required currentLength, required isFocused, required maxLength}) => null : null,
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

