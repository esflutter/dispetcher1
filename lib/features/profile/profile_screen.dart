import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'widgets/verification_badge.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    this.status = VerificationStatus.verified,
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
        foregroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.screenH,
        title: Text('Профиль',
            style: AppTextStyles.h1.copyWith(color: AppColors.surface)),
        actions: <Widget>[
          if (!_isBlocked)
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  color: AppColors.primary, size: 24.r),
              onPressed: () => context.push('/profile/edit'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AppSpacing.sm),
            _Header(
              fullName: fullName,
              status: status,
              rating: rating,
              reviewsCount: reviewsCount,
              photoUrl: photoUrl,
              onReviewsTap: () => context.push('/profile/reviews'),
            ),
            SizedBox(height: AppSpacing.lg),
            if (_isBlocked) ...[
              _BlockedNotice(),
              SizedBox(height: AppSpacing.lg),
            ] else if (status == VerificationStatus.inProgress)
              _InfoCard(
                icon: Icons.hourglass_top_rounded,
                color: AppColors.primary,
                title: 'Документы на проверке',
                text:
                    'Обычно проверка занимает до 24 часов. Мы пришлём уведомление о результате.',
              )
            else if (status == VerificationStatus.rejected)
              _InfoCard(
                icon: Icons.error_outline_rounded,
                color: AppColors.error,
                title: 'Верификация не пройдена',
                text:
                    'Документы не прошли проверку. Загрузите их повторно, чтобы получить доступ к заказам.',
                actionLabel: 'Пройти ещё раз',
              )
            else if (status == VerificationStatus.notVerified)
              _InfoCard(
                icon: Icons.shield_outlined,
                color: AppColors.textTertiary,
                title: 'Пройдите верификацию',
                text:
                    'Подтвердите личность, чтобы откликаться на заказы и получать выплаты.',
                actionLabel: 'Пройти верификацию',
              ),
            if (status == VerificationStatus.inProgress ||
                status == VerificationStatus.rejected ||
                status == VerificationStatus.notVerified)
              SizedBox(height: AppSpacing.lg),
            _ProfileMenuItem(
              icon: Icons.badge_outlined,
              label: 'Моя карточка исполнителя',
              onTap: () => context.push('/executor-card'),
            ),
            SizedBox(height: AppSpacing.md),
            _ProfileMenuItem(
              icon: Icons.list_alt_outlined,
              label: 'Мои услуги',
              onTap: () => context.push('/services'),
            ),
            SizedBox(height: AppSpacing.md),
            _ProfileMenuItem(
              icon: Icons.calendar_today_outlined,
              label: 'Мой график',
              onTap: () => context.push('/schedule'),
            ),
            SizedBox(height: AppSpacing.md),
            _ProfileMenuItem(
              icon: Icons.workspace_premium_outlined,
              label: 'Информация о подписке',
              onTap: () => context.push('/subscription'),
            ),
            SizedBox(height: AppSpacing.xl),
            _SupportFooter(),
            SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.fullName,
    required this.status,
    required this.rating,
    required this.reviewsCount,
    required this.photoUrl,
    required this.onReviewsTap,
  });

  final String fullName;
  final VerificationStatus status;
  final double rating;
  final int reviewsCount;
  final String? photoUrl;
  final VoidCallback onReviewsTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 72.r,
          height: 72.r,
          child: CircleAvatar(
            radius: 36.r,
            backgroundColor: AppColors.surfaceVariant,
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? Icon(Icons.person,
                    size: 56.r, color: AppColors.textTertiary)
                : null,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Text(fullName,
            style: AppTextStyles.h3, textAlign: TextAlign.center),
        SizedBox(height: AppSpacing.xs),
        VerificationBadge(status: status),
        SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: onReviewsTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusS),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded,
                    color: AppColors.primary, size: 20.r),
                SizedBox(width: 4.w),
                Text(rating.toStringAsFixed(1),
                    style: AppTextStyles.bodyMedium),
                SizedBox(width: 6.w),
                Text('($reviewsCount отзывов)',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textTertiary)),
                SizedBox(width: 4.w),
                Icon(Icons.chevron_right_rounded,
                    size: 20.r, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.categoryCard,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          height: 56.h,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 24.r, color: AppColors.textSecondary),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(label, style: AppTextStyles.body),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 22.r, color: AppColors.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Text('Возникли вопросы? Напишите нам!',
              style: AppTextStyles.linkBold
                  .copyWith(color: AppColors.textPrimary)),
        ),
        Icon(Icons.telegram, color: AppColors.telegramBlue, size: 32.r),
        SizedBox(width: AppSpacing.xs),
        Icon(Icons.chat, color: AppColors.whatsappGreen, size: 32.r),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    this.actionLabel,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24.r),
              SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(title, style: AppTextStyles.titleS)),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(text,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary)),
          if (actionLabel != null) ...[
            SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => context.push('/executor-card/verification'),
                child: Text(actionLabel!, style: AppTextStyles.linkBold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BlockedNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.block_rounded,
                  color: AppColors.error, size: 24.r),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text('Ваш профиль заблокирован',
                    style: AppTextStyles.titleS
                        .copyWith(color: AppColors.error)),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Ваш рейтинг ниже 2 звёзд, поэтому доступ временно ограничен на 30 дней',
            style: AppTextStyles.body
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
