import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _firstNameController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _firstNameController.text.trim().isNotEmpty && _agreed;

  void _openPhotoSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 16.h),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.textPrimary),
                title: Text('Сделать фото', style: AppTextStyles.bodyMMedium),
                onTap: () => Navigator.of(ctx).pop(),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.textPrimary),
                title: Text('Выбрать из галереи', style: AppTextStyles.bodyMMedium),
                onTap: () => Navigator.of(ctx).pop(),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => context.go('/auth/otp'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16.h),
              Text(
                'Введите данные',
                style: AppTextStyles.h1SemiBold.copyWith(color: AppColors.textBlack),
              ),
              SizedBox(height: 24.h),
              Center(child: _AvatarSlot(onTap: _openPhotoSheet)),
              SizedBox(height: 24.h),
              _LabeledField(
                controller: _firstNameController,
                hint: 'Имя',
              ),
              SizedBox(height: 16.h),
              _PolicyCheckbox(
                value: _agreed,
                onChanged: (bool v) => setState(() => _agreed = v),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Готово',
                enabled: _isValid,
                onPressed: _isValid ? () => context.go('/shell') : null,
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarSlot extends StatelessWidget {
  const _AvatarSlot({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: 100.w,
            height: 100.w,
            decoration: const BoxDecoration(
              color: AppColors.border,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.person_outline,
              size: 48.sp,
              color: AppColors.textTertiary,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 32.w,
              height: 32.w,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit, size: 16.r, color: AppColors.surface),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(16.r),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        style: AppTextStyles.body.copyWith(fontSize: 16.sp),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppTextStyles.body.copyWith(
            fontSize: 16.sp,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _PolicyCheckbox extends StatelessWidget {
  const _PolicyCheckbox({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: SizedBox(
              width: 24.r,
              height: 24.r,
              child: Checkbox(
                value: value,
                onChanged: (bool? v) => onChanged(v ?? false),
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Я прочитал(а) и согласен(а) с Правилами обработки персональных данных, Пользовательским соглашением и Политикой конфиденциальности',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
