import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/push/pending_deep_link.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/features/shell/main_shell.dart';

/// Обёртка для маршрута `/orders/:id`. Сам экран деталей принимает
/// готовый OrderDraft + executor info + кучу колбэков — поднимать всё
/// это через дублирующий запрос «загрузи заказ по id» хрупко.
///
/// Поэтому маршрут:
///   1. Записывает `orderId` в `pendingOrderDeepLink`.
///   2. Уводит роутер на `/shell` и переключает таб «Заказы».
///   3. MyOrdersScreen в своём store ищет OrderMock с этим id и сам
///      открывает OrderDetailScreen — той же функцией, что и обычный
///      тап карточки.
class OrderDetailRouteScreen extends StatefulWidget {
  const OrderDetailRouteScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailRouteScreen> createState() => _OrderDetailRouteScreenState();
}

class _OrderDetailRouteScreenState extends State<OrderDetailRouteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      pendingOrderDeepLink.value = widget.orderId;
      MainShell.selectedTab.value = 1; // «Заказы»
      try {
        GoRouter.of(context).go('/shell');
      } catch (_) {/* см. комментарий в claude-копии */}
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
