import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';

/// Empty state «нет интернета».
class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.wifi_off,
                  size: 96.r, color: AppColors.textTertiary),
              SizedBox(height: AppSpacing.lg),
              Text('Нет доступа к интернету',
                  style: AppTextStyles.h3, textAlign: TextAlign.center),
              SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Обновить',
                onPressed: onRetry ?? () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
