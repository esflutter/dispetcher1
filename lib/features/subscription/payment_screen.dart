import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';

/// Экран оплаты подписки.
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({
    super.key,
    this.tariffTitle = '3 месяца',
    this.amount = '2 490 ₽',
    this.cardLast4 = '4242',
  });

  final String tariffTitle;
  final String amount;
  final String? cardLast4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Способ оплаты', style: AppTextStyles.titleS),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md,
                    AppSpacing.screenH, AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Резюме платежа', style: AppTextStyles.h3),
                    SizedBox(height: AppSpacing.md),
                    Container(
                      padding: EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusL),
                      ),
                      child: Column(
                        children: <Widget>[
                          _Row(label: 'Тариф', value: tariffTitle),
                          SizedBox(height: AppSpacing.sm),
                          const Divider(color: AppColors.divider, height: 1),
                          SizedBox(height: AppSpacing.sm),
                          _Row(label: 'К оплате', value: amount, accent: true),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.lg),
                    _CardRow(
                      cardLast4: cardLast4,
                      onTap: () => Navigator.of(context)
                          .pushNamed('/subscription/card'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
                  AppSpacing.screenH, AppSpacing.lg),
              child: PrimaryButton(
                label: 'Оплатить $amount',
                onPressed: () => Navigator.of(context).pushReplacementNamed(
                    '/subscription/payment/result'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.accent = false});
  final String label;
  final String value;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label,
            style: AppTextStyles.bodyMRegular
                .copyWith(color: AppColors.textSecondary)),
        Text(value,
            style: accent ? AppTextStyles.titleL : AppTextStyles.titleS),
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.cardLast4, required this.onTap});
  final String? cardLast4;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final bool has = cardLast4 != null;
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppSpacing.radiusL),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusS),
                ),
                child: const Icon(Icons.credit_card_rounded,
                    color: AppColors.textPrimary),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  has ? 'Карта •••• $cardLast4' : 'Привязать карту',
                  style: AppTextStyles.bodyMMedium,
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
