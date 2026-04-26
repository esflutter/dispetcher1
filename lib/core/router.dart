import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/otp_verification_screen.dart';
import '../features/auth/phone_input_screen.dart';
import '../features/auth/registration_screen.dart';
import '../features/catalog/catalog_categories_screen.dart';
import '../features/catalog/catalog_filter_screen.dart';
import '../features/catalog/executor_card_view_screen.dart';
import '../features/catalog/no_internet_screen.dart';
import '../features/catalog/order_feed_screen.dart';
import '../features/executor_card/edit_executor_card_screen.dart';
import '../features/executor_card/executor_card_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/orders/my_orders_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/reviews_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/support/chat_screen.dart';
import '../features/support/support_home_screen.dart';

/// Главный роутер приложения «Диспетчер №1».
/// Иерархия:
///   /splash → /onboarding → /auth/* → /shell (MainShell с табами)
///   Внутренние страницы (executor-card, services, schedule, profile/edit и т.п.)
///   открываются поверх shell обычным push.
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: <RouteBase>[
    GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),

    // Авторизация
    GoRoute(path: '/auth/phone', builder: (_, _) => const PhoneInputScreen()),
    GoRoute(path: '/auth/otp', builder: (_, _) => const OtpVerificationScreen()),
    GoRoute(path: '/auth/registration', builder: (_, _) => const RegistrationScreen()),

    // Главный shell с нижней навигацией
    GoRoute(path: '/shell', builder: (_, _) => const MainShell()),

    // Каталог
    GoRoute(path: '/catalog', builder: (_, _) => const CatalogCategoriesScreen()),
    GoRoute(
      path: '/catalog/feed/:categoryId',
      builder: (_, state) => OrderFeedScreen(
        categoryId: state.pathParameters['categoryId'] ?? '',
        categoryTitle: (state.extra as String?) ?? 'Категория',
      ),
    ),
    GoRoute(path: '/catalog/filter', builder: (_, _) => const CatalogFilterScreen()),
    GoRoute(
      path: '/catalog/executor/:id',
      builder: (_, state) => ExecutorCardViewScreen(
        executorId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(path: '/catalog/no-internet', builder: (_, _) => const NoInternetScreen()),

    // Заказы. Только список — детали и review открываются через
    // `Navigator.push(MaterialPageRoute)`, чтобы получать конкретные
    // данные заказа через параметры конструктора. Декларативные роуты
    // `/orders/:id` без передачи orderId-параметра не имеют смысла.
    GoRoute(path: '/orders', builder: (_, _) => const MyOrdersScreen()),

    // Профиль
    GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
    GoRoute(path: '/profile/edit', builder: (_, _) => const EditProfileScreen()),
    GoRoute(path: '/profile/reviews', builder: (_, _) => const ReviewsScreen()),

    // Карточка заказчика
    GoRoute(path: '/executor-card', builder: (_, _) => const ExecutorCardScreen()),
    GoRoute(path: '/executor-card/edit', builder: (_, _) => const EditExecutorCardScreen()),

    // Поддержка
    GoRoute(path: '/support', builder: (_, _) => const SupportHomeScreen()),
    GoRoute(path: '/support/chat', builder: (_, _) => const ChatScreen()),
    GoRoute(path: '/assistant', builder: (_, _) => const SupportHomeScreen()),
    GoRoute(
      path: '/assistant/chat',
      builder: (context, state) {
        final extra = state.extra;
        String? initial;
        if (extra is Map && extra['initial'] is String) {
          initial = extra['initial'] as String;
        }
        return ChatScreen(initialMessage: initial);
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Маршрут не найден: ${state.uri}')),
  ),
);
