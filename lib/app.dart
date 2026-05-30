import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/system_bar_style.dart';

class DispatcherApp extends StatelessWidget {
  const DispatcherApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Базовый размер фрейма Figma — 375 × 812 (iPhone X).
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: false,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'Диспетчер №1',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          // Непрерывно держим стиль системных баров (тёмные иконки навигации
          // под светлый фон) на ВСЕХ экранах. Экраны под MainShell и тёмные
          // app-bar'ы перекрывают своим AnnotatedRegion. Без этого на экранах
          // входа/онбординга система оставляла светлые кнопки навигации —
          // невидимые на белом фоне.
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: dispatcherSystemBarStyle(),
            child: child ?? const SizedBox.shrink(),
          ),
          routerConfig: appRouter,
          locale: const Locale('ru', 'RU'),
          supportedLocales: const <Locale>[Locale('ru', 'RU')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}
