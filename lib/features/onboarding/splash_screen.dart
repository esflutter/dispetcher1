import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Сплеш-экран приложения «Диспетчер №1».
/// Через 1.5 секунды отправляем пользователя:
/// - на `/shell`, если есть валидная Supabase-сессия (вошедший
///   пользователь не должен снова вводить телефон при рестарте);
/// - иначе на `/onboarding`.
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
    _timer = Timer(const Duration(milliseconds: 1500), _route);
  }

  /// Маршрутизация после сплэша.
  /// 1. Сессии нет → онбординг.
  /// 2. Сессия есть, но `profiles.agreement_accepted_at == null` —
  ///    пользователь убил приложение между OTP-верификацией и
  ///    регистрацией. Отправляем на экран регистрации, иначе он
  ///    попал бы в каталог без имени и принятой оферты.
  /// 3. Иначе — `/shell`.
  Future<void> _route() async {
    if (!mounted) return;
    // Supabase может быть не инициализирован, если запускаем без
    // --dart-define ключей (URL/anonKey). Тогда сессии всё равно
    // нет — отправляем на онбординг, чтобы не зависнуть на сплэше.
    Session? session;
    try {
      session = Supabase.instance.client.auth.currentSession;
    } catch (_) {
      session = null;
    }
    if (session == null) {
      if (mounted) context.go('/onboarding');
      return;
    }
    bool needsRegistration = false;
    try {
      final Map<String, dynamic>? row = await Supabase.instance.client
          .from('profiles')
          .select('agreement_accepted_at')
          .eq('id', session.user.id)
          .maybeSingle();
      // Профиль может ещё не существовать (триггер создания строки в
      // `profiles` отрабатывает асинхронно после первой авторизации) —
      // тогда тоже считаем регистрацию незавершённой.
      needsRegistration =
          row == null || row['agreement_accepted_at'] == null;
    } catch (_) {
      // Сеть/БД упала — лучше пустить в /shell, чем застрять на сплэше:
      // при действительной проблеме шторка ошибок будет уже на каталоге.
    }
    if (!mounted) return;
    context.go(needsRegistration ? '/auth/registration' : '/shell');
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
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/onboarding/splash_logo.webp',
                    width: 130.r,
                    height: 130.r,
                    fit: BoxFit.contain,
                    errorBuilder: (BuildContext _, Object _, StackTrace? _) => Icon(
                      Icons.engineering,
                      size: 80.r,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    'Диспетчер №1',
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 64.h),
                child: SizedBox(
                  width: 44.r,
                  height: 44.r,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 4.r,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
