import 'package:flutter/foundation.dart';

/// Глобальный буфер deep-link «открыть конкретный заказ».
///
/// Поток:
///  1. Юзер тапает пуш (новый отклик / accept / отзыв). PushHandler
///     читает `order_id` из payload и кладёт сюда.
///  2. PushHandler переводит router на `/shell` и переключает таб
///     «Мои заказы».
///  3. MyOrdersScreen слушает `pendingOrderDeepLink` и при появлении
///     значения находит запись в своём store, открывает экран деталей,
///     сбрасывает значение обратно в `null`.
final ValueNotifier<String?> pendingOrderDeepLink =
    ValueNotifier<String?>(null);
