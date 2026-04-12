import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/cropped_avatar.dart';
import 'widgets/verification_badge.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    this.status = VerificationStatus.notVerified,
    this.fullName = 'Александр Иванов',
    this.rating = 4.5,
    this.reviewsCount = 15,
    this.photoUrl,
  });

  final VerificationStatus status;
  final String fullName;
  final double rating;
  final int reviewsCount;
  final String? photoUrl;

  bool get _isBlocked => status == VerificationStatus.blocked;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navBarDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16.w,
        toolbarHeight: 64.h,
        title: Text(
          'Профиль',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 28.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        actions: <Widget>[
          if (!_isBlocked)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: IconButton(
                icon: Image.asset('assets/icons/profile/pen.webp',
                    width: 24.r, height: 24.r),
                onPressed: () => context.push('/profile/edit'),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AppSpacing.md),
            _Header(
              fullName: fullName,
              rating: rating,
              reviewsCount: reviewsCount,
              photoUrl: photoUrl,
              onReviewsTap: () => context.push('/profile/reviews'),
            ),
            SizedBox(height: AppSpacing.sm),
            FullWidthVerificationPill(status: status),
            if (status == VerificationStatus.notVerified) ...[
              SizedBox(height: AppSpacing.xs),
              _PrimaryActionButton(
                label: 'Пройти верификацию',
                onPressed: () => context.push('/assistant/chat', extra: <String, Object?>{'initial': 'verify_documents'}),
              ),
            ] else if (status == VerificationStatus.rejected) ...[
              SizedBox(height: AppSpacing.xs),
              _PrimaryActionButton(
                label: 'Пройти ещё раз',
                onPressed: () => context.push('/assistant/chat', extra: <String, Object?>{'initial': 'verify_documents'}),
              ),
            ] else if (_isBlocked) ...[
              SizedBox(height: AppSpacing.xs),
              Text(
                'Ваш рейтинг ниже 2 звёзд, поэтому доступ\n'
                'временно ограничен на 30 дней',
                style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: AppSpacing.md),
            _ProfileMenuItem(
              label: 'Моя карточка исполнителя',
              onTap: () => context.push('/executor-card'),
            ),
            SizedBox(height: 8.h),
            _ProfileMenuItem(
              label: 'Мои услуги',
              onTap: () => context.push('/services'),
            ),
            SizedBox(height: 8.h),
            _ProfileMenuItem(
              label: 'Мой график',
              onTap: () => context.push('/schedule'),
            ),
            SizedBox(height: 8.h),
            _ProfileMenuItem(
              label: 'Информация о подписке',
              onTap: () => context.push('/subscription'),
            ),
            SizedBox(height: 24.h),
            const _SupportFooter(),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.fullName,
    required this.rating,
    required this.reviewsCount,
    required this.photoUrl,
    required this.onReviewsTap,
  });

  final String fullName;
  final double rating;
  final int reviewsCount;
  final String? photoUrl;
  final VoidCallback onReviewsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        CroppedAvatar(size: 72.r),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(fullName,
                  style: AppTextStyles.h3
                      .copyWith(fontWeight: FontWeight.w600)),
              SizedBox(height: 4.h),
              GestureDetector(
                onTap: onReviewsTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: <Widget>[
                    Image.asset('assets/images/catalog/star.webp',
                        width: 20.r, height: 20.r),
                    SizedBox(width: 4.w),
                    Text(rating.toStringAsFixed(1).replaceAll('.', ','),
                        style: AppTextStyles.bodyMedium),
                    SizedBox(width: 8.w),
                    Text(
                      '$reviewsCount отзывов',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.categoryCard,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          height: 48.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(label,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w500)),
              ),
              Image.asset('assets/icons/profile/arrow_right.webp',
                  width: 16.r, height: 16.r),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportFooter extends StatelessWidget {
  const _SupportFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Возникли вопросы? Напишите нам!',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            )),
        SizedBox(height: 12.h),
        Row(
          children: [
            Image.asset('assets/icons/profile/telegram.webp',
                width: 28.r, height: 28.r),
            SizedBox(width: 12.w),
            Image.asset('assets/icons/profile/whatsapp.webp',
                width: 28.r, height: 28.r),
          ],
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: Text(label,
            style: AppTextStyles.button.copyWith(color: Colors.white)),
      ),
    );
  }
}

/// Показать iOS-стиль алерт для подтверждения выхода.
Future<bool?> showLogoutAlert(BuildContext context) {
  return showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Вы уверены, что хотите\nвыйти?'),
      actions: <Widget>[
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Выйти'),
        ),
      ],
    ),
  );
}

/// Показать iOS-стиль алерт для подтверждения удаления аккаунта.
Future<bool?> showDeleteAccountAlert(BuildContext context) {
  return showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Вы уверены, что хотите\nудалить аккаунт?'),
      actions: <Widget>[
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
}
