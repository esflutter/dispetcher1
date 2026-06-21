import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Открывает системный номеронабиратель с подставленным номером.
/// Звонок не запускается автоматически — пользователю нужно тапнуть
/// кнопку вызова в приложении телефона. Используется стандартная
/// `tel:`-схема, работает одинаково на iOS и Android.
Future<void> dialPhone(BuildContext context, String? phone) async {
  if (phone == null || phone.trim().isEmpty) return;
  // Чистим до цифр и плюса — некоторые лаунчеры капризничают
  // на пробелах/дефисах.
  final String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
  final Uri uri = Uri.parse('tel:$cleaned');
  // launchUrl на отказ может ВЕРНУТЬ false ИЛИ БРОСИТЬ PlatformException
  // (например, на устройстве вообще нет звонилки). Сводим оба исхода к одному:
  // показываем снекбар, а не оставляем кнопку «молча мёртвой».
  bool ok = false;
  try {
    ok = await launchUrl(uri);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Не удалось открыть приложение телефона'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
