import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dispatcher_1/core/push/push_service.dart';
import 'package:dispatcher_1/core/realtime/realtime_service.dart';
import 'package:dispatcher_1/core/utils/photo_source.dart' show clearSignedUrlCache;
import 'package:dispatcher_1/features/auth/photo_crop_screen.dart';
import 'package:dispatcher_1/features/catalog/catalog_filter_screen.dart';
import 'package:dispatcher_1/features/catalog/select_order_for_executor_screen.dart';
import 'package:dispatcher_1/features/executor_card/executor_card_screen.dart';
import 'package:dispatcher_1/features/orders/create_order_screen.dart';
import 'package:dispatcher_1/features/orders/orders_store.dart';
import 'package:dispatcher_1/features/profile/account_block.dart';
import 'package:dispatcher_1/features/shell/main_shell.dart';
import 'package:dispatcher_1/features/support/chat_screen.dart';

/// Выход из аккаунта. Закрываем сессию Supabase (иначе RLS будет
/// пропускать запросы как от прошлого пользователя) и чистим все
/// статические сторы. При повторном входе профиль/заказы подтянутся
/// из БД заново.
Future<void> signOut() async {
  // Сначала останавливаем realtime — иначе подписки продолжат держать
  // WebSocket-соединение от имени прошлого юзера. Делаем до signOut,
  // чтобы Supabase сам не успел кинуть auth-error в наш callback.
  await RealtimeService.instance.stop();
  // Инвалидируем push-токен ПОКА сессия жива. Если сделать это после
  // signOut (как раньше — в listener onAuthStateChange), запрос к БД уйдёт
  // без авторизации, RLS его отклонит, и токен останется привязан к
  // вышедшему пользователю — следующий человек на устройстве получал бы
  // его пуши. clearForCurrentUser сам безопасен, даже если Firebase не готов.
  await PushService.instance.clearForCurrentUser();
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (_) {/* всё равно чистим локально */}
  _clearAll();
}

/// Удаление аккаунта. Закрываем сессию Supabase и делаем тот же сброс
/// всех сторов, что и при выходе. Сами данные удаляются на сервере
/// отдельным RPC, который дёргает экран профиля до вызова этой функции.
Future<void> deleteAccount() async {
  await RealtimeService.instance.stop();
  // То же, что в signOut: снимаем push-токен до закрытия сессии.
  await PushService.instance.clearForCurrentUser();
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (_) {/* всё равно чистим локально */}
  _clearAll();
}

/// Полная очистка всех глобальных статических хранилищ. Каждый новый
/// «стор» с пользовательскими данными обязан чиститься здесь — иначе
/// на устройстве у следующего пользователя останутся старые данные.
void _clearAll() {
  // Профиль: имя/телефон/почта/аватар.
  CropResult.clearAuthData();

  // Блокировка аккаунта и история отзывов о пользователе.
  AccountBlock.forceLift();
  ReviewsData.resetToDefault();

  // Карточка заказчика.
  ExecutorCardData.clear();
  ExecutorCardScreen.cardCreated = false;

  // Применённые фильтры каталога.
  AppliedFilter.clear();

  // История предложенных исполнителям заказов.
  OfferSubmissions.clear();

  // Счётчик дневного лимита создания заказов.
  DailyOrderLimit.resetToday();

  // Заказы пользователя (новые/принятые/отклонённые).
  MyOrdersStore.clear();

  // История чата с ассистентом — иначе у следующего пользователя
  // на устройстве осталась бы переписка предыдущего.
  ChatScreen.resetHistory();

  // Активная вкладка нижней навигации.
  MainShell.selectedTab.value = 0;

  // Кэш подписанных URL приватных файлов. Без сброса следующий юзер
  // мог теоретически получить живой URL от чужой записи storage.
  clearSignedUrlCache();
}
