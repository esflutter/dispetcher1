import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';

import 'widgets/executor_card_alerts.dart';

/// Состояние верификации карточки исполнителя.
enum ExecutorCardStatus { empty, inReview, rejected, verified }

/// Экран «Моя карточка исполнителя» с разными состояниями верификации.
/// Кнопки и баннер меняются в зависимости от [status].
class ExecutorCardScreen extends StatelessWidget {
  const ExecutorCardScreen({super.key, this.status = ExecutorCardStatus.empty});

  final ExecutorCardStatus status;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Моя карточка исполнителя',
          style: AppTextStyles.titleS,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: AppSpacing.md),
              _StatusBanner(status: status),
              SizedBox(height: AppSpacing.lg),
              if (status != ExecutorCardStatus.empty) ...[
                const _ExecutorCardPreview(),
                SizedBox(height: AppSpacing.lg),
              ] else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 64.r,
                          color: AppColors.textTertiary,
                        ),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'Создайте карточку исполнителя',
                          style: AppTextStyles.titleL,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg),
                          child: Text(
                            'Заказчики смогут посмотреть информацию '
                            'о вас, услугах и связаться с вами.',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (status != ExecutorCardStatus.empty) const Spacer(),
              _StatusActions(status: status),
              SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final ExecutorCardStatus status;

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    switch (status) {
      case ExecutorCardStatus.empty:
        text = 'Подтвердите свои данные';
        bg = AppColors.surfaceVariant;
        fg = AppColors.textSecondary;
        icon = Icons.info_outline;
        break;
      case ExecutorCardStatus.inReview:
        text = 'Ваши документы ещё на проверке';
        bg = AppColors.primaryTint;
        fg = AppColors.primaryDark;
        icon = Icons.hourglass_top;
        break;
      case ExecutorCardStatus.rejected:
        text = 'Документы не прошли проверку';
        bg = const Color(0xFFFDECEA);
        fg = AppColors.error;
        icon = Icons.error_outline;
        break;
      case ExecutorCardStatus.verified:
        text = 'Верификация пройдена';
        bg = const Color(0xFFE8F8E9);
        fg = AppColors.success;
        icon = Icons.verified_outlined;
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20.r),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(text,
                style: AppTextStyles.bodyMedium.copyWith(color: fg)),
          ),
        ],
      ),
    );
  }
}

class _ExecutorCardPreview extends StatelessWidget {
  const _ExecutorCardPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56.r,
                height: 56.r,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                ),
                child: Icon(Icons.person,
                    color: AppColors.textTertiary, size: 32.r),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Иванов Иван Иванович',
                        style: AppTextStyles.titleS),
                    SizedBox(height: 2.h),
                    Text('Экскаватор-погрузчик',
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Divider(color: AppColors.divider, height: 1.h),
          SizedBox(height: AppSpacing.md),
          _InfoRow(label: 'Район работ', value: 'Москва, 30 км'),
          SizedBox(height: AppSpacing.xs),
          _InfoRow(label: 'Паспорт', value: 'Загружен'),
          SizedBox(height: AppSpacing.xs),
          _InfoRow(label: 'Водительское удостоверение', value: 'Загружено'),
          SizedBox(height: AppSpacing.xs),
          _InfoRow(label: 'Удостоверение на технику', value: 'Загружено'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary)),
        ),
        SizedBox(width: AppSpacing.sm),
        Text(value, style: AppTextStyles.bodyMedium),
      ],
    );
  }
}

class _StatusActions extends StatelessWidget {
  const _StatusActions({required this.status});
  final ExecutorCardStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ExecutorCardStatus.empty:
        return PrimaryButton(
          label: 'Создать',
          onPressed: () =>
              context.push('/executor-card/edit'),
        );
      case ExecutorCardStatus.inReview:
        return PrimaryButton(
          label: 'Редактировать',
          onPressed: () =>
              context.push('/executor-card/edit'),
        );
      case ExecutorCardStatus.rejected:
        return Column(
          children: [
            PrimaryButton(
              label: 'Отправить заново',
              onPressed: () => context.push('/executor-card/verification'),
            ),
            SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Редактировать',
              onPressed: () =>
                  context.push('/executor-card/edit'),
            ),
          ],
        );
      case ExecutorCardStatus.verified:
        return Column(
          children: [
            PrimaryButton(
              label: 'Редактировать',
              onPressed: () =>
                  context.push('/executor-card/edit'),
            ),
            SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Удалить карточку',
              onPressed: () => showDeleteExecutorCardAlert(context),
            ),
          ],
        );
    }
  }
}
