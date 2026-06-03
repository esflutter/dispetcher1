// =====================================================================
// ai_navigation.dart — единая точка открытия чата с ассистентом.
//
// Раньше каждое место в UI делало context.push('/assistant/chat') —
// если юзер тапал FAB ассистента дважды подряд, в стеке появлялся
// второй экран чата поверх первого.
//
// Этот helper:
//   - если уже на /assistant/chat — ничего не делает;
//   - иначе — push'ит свежий.
// =====================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/utils/support_contact.dart';
import 'package:dispatcher_1/features/shell/main_shell.dart';

const String _kAssistantChat = '/assistant/chat';

/// Открыть чат с ассистентом без дубликатов.
Future<void> openAssistantChat(
  BuildContext context, {
  Object? extra,
}) async {
  final router = GoRouter.maybeOf(context);
  if (router == null) return;

  final String current = router.routerDelegate.currentConfiguration.fullPath;
  if (current == _kAssistantChat) {
    return;
  }
  await router.push(_kAssistantChat, extra: extra);
}

/// Перейти в раздел приложения по ключу действия от ассистента — это
/// обработчик кнопки «Перейти» под ответом. Ключи приходят с сервера
/// (см. _shared/navSuggest.ts). Корневые вкладки открываем переключением
/// таба. Неизвестный ключ — ничего не делаем (молча, без краша).
void navigateAssistantAction(BuildContext context, String action) {
  switch (action) {
    case 'open_create_order':
      // Создание заказа живёт на вкладке «Мои заказы» (там же лимит/проверки).
      MainShell.selectedTab.value = 1;
      context.go('/shell');
    case 'open_my_orders':
      MainShell.selectedTab.value = 1;
      context.go('/shell');
    case 'open_catalog':
      MainShell.selectedTab.value = 0;
      context.go('/shell');
    case 'open_reviews':
      context.push('/profile/reviews');
    case 'contact_support':
      // Живой человек — открываем мессенджер поддержки прямо из чата.
      // Быстрее, чем вести в «Профиль» и искать там иконку. Пока ссылка
      // не задана (kSupportMessengerUrl) — показывается мягкая заглушка.
      openSupportMessenger(context);
    default:
      break;
  }
}
