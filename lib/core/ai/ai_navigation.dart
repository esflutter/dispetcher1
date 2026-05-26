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
