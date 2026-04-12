import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';

/// Состояние подписки.
enum SubscriptionStatus { active, paused, inactive }

/// Экран «Информация о подписке».
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({
    super.key,
    this.status = SubscriptionStatus.active,
  });

  final SubscriptionStatus status;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late SubscriptionStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
  }

  Future<void> _onToggle(bool value) async {
    if (!value && _status == SubscriptionStatus.active) {
      final bool? ok = await _showDisableDialog();
      if (ok != true) return;
      setState(() => _status = SubscriptionStatus.paused);
    } else if (value && _status == SubscriptionStatus.paused) {
      setState(() => _status = SubscriptionStatus.active);
    }
  }

  Future<bool?> _showDisableDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        ),
        insetPadding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(false),
                  child: Icon(Icons.close_rounded,
                      size: 22.r, color: AppColors.textSecondary),
                ),
              ),
              Text('Отключить подписку?',
                  style: AppTextStyles.h3
                      .copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Доступ к заказам будет закрыт, а ваши\n'
                'услуги не будут отображаться в каталоге',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Отключить',
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
              SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Отмена',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary)),
              ),
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
      appBar: const DarkSubAppBar(title: 'Информация о подписке'),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
            bottom: _status == SubscriptionStatus.inactive ? 88.h : 24.h),
        child: AiAssistantFab(onTap: () => context.push('/assistant/chat')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenH, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Подписка',
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700)),
                  ),
                  Switch(
                    value: _status == SubscriptionStatus.active,
                    onChanged: _status == SubscriptionStatus.inactive
                        ? null
                        : _onToggle,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF34C759),
                  ),
                ],
              ),
            ),
            Divider(height: 1.h, color: AppColors.divider),
            Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.screenH,
                  AppSpacing.md, AppSpacing.screenH, 0),
              child: _StatusCard(status: _status),
            ),
            const Spacer(),
            if (_status == SubscriptionStatus.inactive)
              Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
                    AppSpacing.screenH, AppSpacing.md),
                child: PrimaryButton(
                  label: 'Оплатить подписку',
                  onPressed: () => context.push('/subscription/tariffs'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});
  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    switch (status) {
      case SubscriptionStatus.active:
        title = 'Подписка активна';
        subtitle = 'Бесплатный период до 15 июля';
      case SubscriptionStatus.paused:
        title = 'Подписка приостановлена';
        subtitle = 'Оплачено до 15 июля';
      case SubscriptionStatus.inactive:
        title = 'Подписка неактивна';
        subtitle =
            'Оплатите подписку, чтобы откликаться на заказы и заказчики видели ваш профиль';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700)),
        SizedBox(height: AppSpacing.xs),
        Text(subtitle,
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
      ],
    );
  }
}
