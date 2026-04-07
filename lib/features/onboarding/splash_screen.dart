import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Сплеш-экран приложения «Диспетчер №1».
/// Показывает лого, через 1.5 секунды переходит на онбординг.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) context.go('/onboarding');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/onboarding/splash_logo.webp',
              width: 100.w,
              height: 100.w,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 16.h),
            Text(
              'Диспетчер №1 PRO',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
