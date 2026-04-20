import 'package:dispatcher_1/features/auth/photo_crop_screen.dart';
import 'package:dispatcher_1/features/catalog/catalog_filter_screen.dart';
import 'package:dispatcher_1/features/catalog/select_order_for_executor_screen.dart';
import 'package:dispatcher_1/features/executor_card/executor_card_screen.dart';
import 'package:dispatcher_1/features/orders/create_order_screen.dart';
import 'package:dispatcher_1/features/profile/account_block.dart';
import 'package:dispatcher_1/features/shell/main_shell.dart';

/// Единая точка очистки всех глобальных статических хранилищ при
/// выходе из аккаунта или удалении аккаунта. До того как в приложение
/// прикрутят настоящий бэкенд, все «пользовательские» данные хранятся
/// в статических полях классов — и без явного сброса они переживают
/// переход на `/auth/phone` и появляются у следующего, кто
/// зарегистрируется на этом устройстве.
///
/// Добавляя новый статический «стор» с пользовательскими данными,
/// дополняй эту функцию — иначе регрессия.
void resetForLogout() {
  // Профиль: имя/телефон/почта/аватар.
  CropResult.clearAuthData();

  // Блокировка аккаунта и история отзывов о пользователе.
  AccountBlock.forceLift();
  ReviewsData.resetToDefault();

  // Карточка исполнителя (используется и в приложении заказчика как
  // legacy-раздел).
  ExecutorCardData.clear();
  ExecutorCardScreen.cardCreated = false;

  // Применённые фильтры каталога.
  AppliedFilter.clear();

  // История предложенных исполнителям заказов.
  OfferSubmissions.clear();

  // Счётчик дневного лимита создания заказов.
  DailyOrderLimit.resetToday();

  // Активная вкладка нижней навигации.
  MainShell.selectedTab.value = 0;
}
