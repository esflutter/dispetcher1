import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/ai/ai_navigation.dart';
import 'package:dispatcher_1/core/auth/guest_gate.dart';
import 'package:dispatcher_1/core/network_status.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/update/update_checker.dart';
import 'package:dispatcher_1/core/theme/system_bar_style.dart';
import 'package:dispatcher_1/core/widgets/no_internet_view.dart';
import 'package:dispatcher_1/features/catalog/catalog_categories_screen.dart';
import 'package:dispatcher_1/features/orders/my_orders_screen.dart';
import 'package:dispatcher_1/features/profile/profile_screen.dart';
import 'package:dispatcher_1/features/shell/widgets/main_bottom_nav_bar.dart';
import 'package:dispatcher_1/features/shell/widgets/support_fab.dart';

/// Главный shell приложения. Нижняя навигация на 3 таба
/// (Каталог / Заказы / Профиль) + плавающая оранжевая кнопка
/// поддержки в правом нижнем углу — как в Figma.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Глобальный способ переключить нижний таб изнутри экранов,
  /// запушенных поверх MainShell (например, из `OrderFeedScreen`,
  /// где нижняя панель — это «фейковая» копия shell'овской).
  /// Достаточно выставить нужный индекс и сделать
  /// `Navigator.popUntil(isFirst)`, чтобы вернуться к shell.
  static final ValueNotifier<int> selectedTab = ValueNotifier<int>(0);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Гость видит тот же каталог, что и зарегистрированный пользователь. Действия,
  // для которых нужен аккаунт, показывают компактный диалог регистрации.
  // гостя фиксировано на время жизни shell (после входа открывается новый shell
  // через переход на /shell), поэтому считаем один раз.
  late final bool _guest = isGuest;
  late final List<Widget> _screens = <Widget>[
    const CatalogCategoriesScreen(),
    _guest
        ? const GuestLockedView(
            icon: Icons.assignment_outlined,
            title: 'Начните с первого заказа',
            subtitle:
                'После регистрации здесь появятся ваши заказы и отклики исполнителей.',
            intent: GuestAuthIntent.createOrder,
          )
        : MyOrdersScreen(onGoToCatalog: () => MainShell.selectedTab.value = 0),
    _guest
        ? const GuestLockedView(
            icon: Icons.person_outline,
            title: 'Войдите в аккаунт',
            subtitle: 'Чтобы открыть профиль, войдите или зарегистрируйтесь.',
          )
        : const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    MainShell.selectedTab.addListener(_onTabChanged);
    // Первый реальный экран после сплэша — здесь один раз за запуск
    // проверяем, не пора ли обновиться (тихо, если сеть/настройка недоступны).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateChecker.maybePromptOnce(context);
    });
  }

  @override
  void dispose() {
    MainShell.selectedTab.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  void _openSupport() {
    // Ассистент доступен гостю для общих вопросов. Поиск исполнителей и
    // создание заказа внутри чата гейтятся на вход отдельно.
    // Стартовый экран ассистента («С чего хотите начать?») показывается
    // только один раз — сразу после регистрации (см. registration_screen.dart).
    // По FAB всегда открываем чат напрямую.
    openAssistantChat(context);
  }

  @override
  Widget build(BuildContext context) {
    final int index = MainShell.selectedTab.value;
    // Под shell нав-бар закрашивается AppColors.navBarDark и тянется до
    // системных кнопок навигации. Через AnnotatedRegion сообщаем Android-у
    // что фон тёмный — чтобы Xiaomi/MIUI красила свои 3-button иконки
    // белыми (на тёмном фоне чёрные иконки сливались). Вне shell
    // (splash, OTP, регистрация) остаётся глобальный белый стиль.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dispatcherSystemBarStyle(
        navBarColor: AppColors.navBarDark,
        navIconBrightness: Brightness.light,
        // Шапка каталога — тёмный Container (не AppBar), стиль статус-бара
        // на этой вкладке берётся отсюда. Иконки часов/батареи — светлые.
        statusIconBrightness: Brightness.light,
      ),
      child: _buildScaffold(index),
    );
  }

  Widget _buildScaffold(int index) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: NetworkStatus.instance,
        builder: (BuildContext context, _) {
          if (NetworkStatus.instance.isOffline) {
            return NoInternetView(
              onRetry: () => NetworkStatus.instance.recheck(),
            );
          }
          return IndexedStack(index: index, children: _screens);
        },
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 24.h),
        child: SupportFab(onTap: _openSupport),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: MainBottomNavBar(
        items: _guest ? kGuestMainNavItems : kMainNavItems,
        currentIndex: index,
        onTap: (int i) => MainShell.selectedTab.value = i,
      ),
    );
  }
}
