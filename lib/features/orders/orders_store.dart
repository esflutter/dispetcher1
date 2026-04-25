import 'package:flutter/foundation.dart';

import 'package:dispatcher_1/core/catalog/format.dart';
import 'package:dispatcher_1/core/customer_orders/customer_orders_service.dart';
import 'package:dispatcher_1/core/customer_orders/models.dart';

import 'package:dispatcher_1/features/orders/widgets/order_status_pill.dart';

/// Данные карточки заказа заказчика. Внутренний публичный тип,
/// используется экраном «Мои заказы», экраном «Выбор заказа для
/// исполнителя» и общим стором заказов [MyOrdersStore].
class OrderMock {
  OrderMock({
    required this.id,
    required this.status,
    required this.title,
    required this.equipment,
    required this.rentDate,
    required this.address,
    required this.publishedAt,
    DateTime? statusUpdatedAt,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.matchId,
    this.executorId,
    this.number,
    this.description = '',
    this.categories = const <String>[],
    this.works = const <String>[],
    this.photos = const <String>[],
    this.reviewLeft = false,
    this.respondersCount,
    this.prevStatus,
  }) : statusUpdatedAt = statusUpdatedAt ?? publishedAt;

  final String id;
  final MyOrderStatus status;
  final String title;
  final List<String> equipment;
  final String rentDate;
  final String address;
  final DateTime publishedAt;

  /// Момент последнего изменения статуса заказа. При каждом изменении
  /// статуса через [copyWith] сбрасывается в [DateTime.now()]. Именно
  /// это поле используется в [timeAgo], чтобы отсчёт «сколько времени
  /// назад» шёл не от публикации, а от последнего действия.
  final DateTime statusUpdatedAt;

  String get timeAgo {
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(statusUpdatedAt);
    if (diff.inSeconds < 60) return 'Только что';
    if (diff.inMinutes < 60) {
      final int m = diff.inMinutes;
      return '$m ${_pluralMin(m)} назад';
    }
    if (diff.inHours < 24) {
      final int h = diff.inHours;
      return '$h ${_pluralH(h)} назад';
    }
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime upDay =
        DateTime(statusUpdatedAt.year, statusUpdatedAt.month, statusUpdatedAt.day);
    if (upDay == today.subtract(const Duration(days: 1))) {
      final String hh = statusUpdatedAt.hour.toString().padLeft(2, '0');
      final String mm = statusUpdatedAt.minute.toString().padLeft(2, '0');
      return 'Вчера в $hh:$mm';
    }
    final int d = today.difference(upDay).inDays;
    return '$d ${_pluralD(d)} назад';
  }

  /// Номер заказа для отображения. Для заказов, созданных пользователем,
  /// возвращает [number]. Для моковых генерирует номер из [id]-префикса,
  /// чтобы каждый мок имел уникальный и реалистичный номер.
  String get displayNumber {
    if (number != null) return number!;
    final String pfx = id.isNotEmpty ? id[0] : 'n';
    final String digits = id.replaceAll(RegExp(r'\D'), '');
    final int base =
        pfx == 'a' ? 81220000 : pfx == 'r' ? 81210000 : 81230000;
    final int n = base + (int.tryParse(digits) ?? 0);
    return '№$n';
  }

  static String _pluralH(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'час';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'часа';
    }
    return 'часов';
  }

  static String _pluralD(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'день';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'дня';
    }
    return 'дней';
  }

  static String _pluralMin(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'минуту';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'минуты';
    }
    return 'минут';
  }

  final String? customerName;
  final String? customerPhone;

  /// Email партнёра по «мэтчу» (исполнителя со стороны заказчика или
  /// заказчика со стороны исполнителя). Показывается в карточках с
  /// контактами только если заполнен — email опциональное поле.
  final String? customerEmail;

  /// `order_matches.id` выбранного мэтча. Нужен экрану деталей, чтобы
  /// проверить актуальный статус в БД и подгрузить контакты, когда
  /// исполнитель подтвердит.
  final String? matchId;

  /// `profiles.id` выбранного исполнителя. Используется как ключ для
  /// SELECT-а из `profiles_private` (RLS пропустит только после
  /// `accepted`).
  final String? executorId;

  /// Дополнительные поля, заполняемые из формы создания заказа заказчиком.
  /// У моковых заказов в списке «Мои заказы» они остаются пустыми — экран
  /// подробностей тогда скроет соответствующие блоки.
  final String? number;
  final String description;
  final List<String> categories;
  final List<String> works;
  final List<String> photos;

  /// Был ли оставлен отзыв по завершённому заказу. После оставления
  /// отзыва кнопка «Оставить отзыв» больше не показывается — отзыв
  /// можно оставить только один раз.
  final bool reviewLeft;

  /// Количество откликнувшихся исполнителей. Показывается рядом со
  /// статусом «Выберите исполнителя» как счётчик: «Выберите
  /// исполнителя (3)». `null` — не показывать счётчик.
  final int? respondersCount;

  /// Статус заказа до блокировки аккаунта. Заполняется, когда активные
  /// заказы автоматически уезжают в «Архив» при блокировке, чтобы при
  /// разблокировке можно было вернуть заказ в его исходную вкладку
  /// («Ожидает» или «В работе»). `null` — значит в архиве «по обычной
  /// причине» (отменён, просрочен и т. п.), возвращать некуда.
  final MyOrderStatus? prevStatus;

  /// Сентинел для [copyWith], чтобы отличить «не передавать» от
  /// «установить в null». Общий трюк для nullable-полей в copyWith.
  static const Object _unset = Object();

  OrderMock copyWith({
    MyOrderStatus? status,
    bool? reviewLeft,
    Object? prevStatus = _unset,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? matchId,
    String? executorId,
    bool clearContacts = false,
  }) {
    return OrderMock(
      id: id,
      status: status ?? this.status,
      title: title,
      equipment: equipment,
      rentDate: rentDate,
      address: address,
      publishedAt: publishedAt,
      // Сбрасываем таймер при каждой реальной смене статуса — чтобы
      // timeAgo отсчитывался от последнего действия, а не от публикации.
      statusUpdatedAt: (status != null && status != this.status)
          ? DateTime.now()
          : statusUpdatedAt,
      // [clearContacts] принудительно обнуляет контактные поля.
      customerName:
          clearContacts ? null : (customerName ?? this.customerName),
      customerPhone:
          clearContacts ? null : (customerPhone ?? this.customerPhone),
      customerEmail:
          clearContacts ? null : (customerEmail ?? this.customerEmail),
      matchId: clearContacts ? null : (matchId ?? this.matchId),
      executorId: clearContacts ? null : (executorId ?? this.executorId),
      number: number,
      description: description,
      categories: categories,
      works: works,
      photos: photos,
      reviewLeft: reviewLeft ?? this.reviewLeft,
      respondersCount: respondersCount,
      prevStatus: identical(prevStatus, _unset)
          ? this.prevStatus
          : prevStatus as MyOrderStatus?,
    );
  }

  /// Пытается распарсить дату начала аренды из [rentDate] формата
  /// «15 июня · 09:00–18:00». Возвращает `null`, если формат не
  /// соответствует — тогда считаем, что определить «истёк ли заказ»
  /// нельзя, и по умолчанию возвращаем заказ из архива.
  DateTime? get rentStart {
    final List<String> parts = rentDate.split('·');
    if (parts.length < 2) return null;
    final List<String> dateParts = parts[0].trim().split(' ');
    if (dateParts.length < 2) return null;
    final int? day = int.tryParse(dateParts[0]);
    final int monthIdx = _monthsGenitive.indexOf(dateParts[1]);
    if (day == null || monthIdx < 0) return null;
    final List<String> timeRange = parts[1].trim().split('–');
    if (timeRange.isEmpty) return null;
    final List<String> hm = timeRange[0].trim().split(':');
    if (hm.length < 2) return null;
    final int hour = int.tryParse(hm[0]) ?? 0;
    final int minute = int.tryParse(hm[1]) ?? 0;
    final DateTime now = DateTime.now();
    DateTime candidate =
        DateTime(now.year, monthIdx + 1, day, hour, minute);
    // Если дата в этом году уже прошла и отстоит от сегодня больше чем
    // на полгода — скорее всего, речь о следующем годе. Этот сдвиг
    // нужен, чтобы «15 декабря» не считался прошлогодним, если сейчас
    // январь.
    if (candidate.isBefore(now.subtract(const Duration(days: 180)))) {
      candidate = DateTime(now.year + 1, monthIdx + 1, day, hour, minute);
    }
    return candidate;
  }

  /// Заказ «истёк» — дата и время начала аренды уже в прошлом.
  /// Используется при разблокировке аккаунта, чтобы вернуть из архива
  /// только актуальные заказы. Если дату не удалось распарсить —
  /// считаем заказ не истёкшим (лучше показать, чем потерять).
  bool get isExpired {
    final DateTime? start = rentStart;
    if (start == null) return false;
    return start.isBefore(DateTime.now());
  }

  static const List<String> _monthsGenitive = <String>[
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is OrderMock && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Единый in-memory стор всех заказов заказчика — и «свежих» мок-данных,
/// и созданных пользователем, и перемещённых в архив. Живёт на уровне
/// приложения, чтобы разные экраны («Мои заказы», «Выбор заказа для
/// исполнителя», экран создания) видели один и тот же набор и не
/// рассинхронизировались.
///
/// Состояние сбрасывается при рестарте (без persistence). Слушатели
/// подписываются на [revision], которая увеличивается на каждое
/// изменение.
class MyOrdersStore {
  MyOrdersStore._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Флаг одноразовой подмены initial-моков реальными данными из БД.
  /// Вызов [loadFromDb] первый раз чистит хардкодные списки и подгружает
  /// свои заказы текущего `auth.uid()`. Повторные вызовы просто обновляют
  /// [newOrders] без повторной очистки (initial моков уже нет).
  static bool _dbSeeded = false;

  /// «Ожидает»: заказ опубликован, исполнитель ещё не выбран.
  /// Заполняется из БД через [loadFromDb]; в стартовом состоянии пуст.
  static final List<OrderMock> newOrders = <OrderMock>[];


  /// «В работе» + «Архив» после completed. Заполняется из БД через
  /// [loadFromDb]; в стартовом состоянии пуст.
  static final List<OrderMock> accepted = <OrderMock>[];

  /// «Архив» (отклонённые/отменённые/не нашёлся). Заполняется из БД
  /// через [loadFromDb]; в стартовом состоянии пуст.
  static final List<OrderMock> rejected = <OrderMock>[];

  /// Все заказы во вкладке «В работе»: `accepted` кроме `completed`.
  static List<OrderMock> get inWork => accepted
      .where((OrderMock o) => o.status != MyOrderStatus.completed)
      .toList();

  /// Все заказы во вкладке «Архив»: отменённые/не нашёлся + завершённые.
  static List<OrderMock> get archive => <OrderMock>[
        ...rejected,
        ...accepted
            .where((OrderMock o) => o.status == MyOrderStatus.completed),
      ];

  /// Заказы, которые можно предложить исполнителю из каталога:
  ///   * `waiting` — откликов пока нет;
  ///   * `awaitingExecutor` — уже предложен кому-то, но заказчик
  ///     вправе предложить тому же или другому исполнителю ещё раз;
  ///   * `executorDeclinedWaiting` — предыдущий отказался, снова
  ///     ищем через каталог.
  /// Исключены `waitingChoose` / `executorDeclined` — там есть
  /// отклики, заказчик выбирает из них, а не ищет сам в каталоге.
  static List<OrderMock> get offerable => newOrders
      .where((OrderMock o) =>
          o.status == MyOrderStatus.waiting ||
          o.status == MyOrderStatus.awaitingExecutor ||
          o.status == MyOrderStatus.executorDeclinedWaiting)
      .toList();

  /// Добавляет только что созданный пользователем заказ в начало
  /// списка «Ожидает».
  static void addCreated(OrderMock order) {
    newOrders.insert(0, order);
    _bump();
  }

  /// Полная очистка всех трёх списков — для logout/удаления аккаунта,
  /// чтобы у следующего пользователя на этом устройстве не оставались
  /// заказы прошлого.
  static void clear() {
    newOrders.clear();
    accepted.clear();
    rejected.clear();
    _dbSeeded = false;
    _bump();
  }

  /// Одноразово вычищает initial-моки и подгружает реальные заказы
  /// текущего заказчика из БД. Повторные вызовы просто обновляют
  /// `newOrders` без повторной очистки (initial уже ушли).
  static Future<void> loadFromDb() async {
    if (!_dbSeeded) {
      newOrders.clear();
      accepted.clear();
      rejected.clear();
      _dbSeeded = true;
    }
    try {
      final List<CustomerOrderListItem> rows =
          await CustomerOrdersService.instance.listMine();
      // Оставляем только заказы, которых ещё нет в локальном списке —
      // `addCreated` мог положить туда свежесозданный заказ до того,
      // как экран успел перезапросить БД.
      final Set<String> knownIds = <String>{
        for (final OrderMock o in newOrders) o.id,
        for (final OrderMock o in accepted) o.id,
        for (final OrderMock o in rejected) o.id,
      };
      for (final CustomerOrderListItem r in rows) {
        if (knownIds.contains(r.id)) continue;
        final MyOrderStatus uiStatus;
        if (r.status == 'cancelled') {
          uiStatus = MyOrderStatus.rejectedDeclined;
        } else if (r.respondersCount > 0) {
          uiStatus = MyOrderStatus.waitingChoose;
        } else {
          uiStatus = MyOrderStatus.waiting;
        }
        final OrderMock mock = OrderMock(
          id: r.id,
          status: uiStatus,
          title: r.title,
          equipment: r.machineryTitles,
          rentDate: formatRentDate(r.toFormatAdapter()),
          address: r.address,
          publishedAt: r.publishedAt,
          number: '№${r.displayNumber.toString().padLeft(8, '0')}',
          respondersCount: r.respondersCount,
        );
        if (r.status == 'published') {
          newOrders.add(mock);
        } else {
          rejected.add(mock);
        }
      }
      _bump();
    } catch (_) {
      // БД упала — оставляем то, что есть в памяти.
    }
  }

  /// Переводит заказ в статус `accepted` («Свяжитесь с исполнителем»)
  /// и перекладывает его из `newOrders` в `accepted`. Если переданы
  /// [name]/[phone] — заполняет контакт выбранного исполнителя, чтобы
  /// карточка в списке и экран деталей сразу показывали блок с именем
  /// и кнопкой-телефоном.
  static void moveToAccepted(
    OrderMock o, {
    String? name,
    String? phone,
    String? matchId,
    String? executorId,
  }) {
    newOrders.remove(o);
    accepted.remove(o);
    accepted.insert(
      0,
      o.copyWith(
        status: MyOrderStatus.accepted,
        customerName: name,
        customerPhone: phone,
        matchId: matchId,
        executorId: executorId,
      ),
    );
    _bump();
  }

  /// Переводит заказ в «красный» статус и складывает в архив.
  static void moveToRejected(OrderMock o, MyOrderStatus newStatus) {
    newOrders.remove(o);
    accepted.remove(o);
    rejected.insert(0, o.copyWith(status: newStatus));
    _bump();
  }

  /// «Выбрать другого исполнителя» из статуса `awaitingExecutor`.
  /// Если у заказа есть другие отклики (`respondersCount > 0`) —
  /// переводим в `waitingChoose`, чтобы заказчик выбрал из списка.
  /// Если других откликов нет — возвращаем заказ в `waiting`, чтобы
  /// пользователь сам поискал исполнителя в каталоге.
  /// Возвращает новый статус, чтобы вызывающий экран решил, куда
  /// навигировать (в каталог или в список откликов).
  static MyOrderStatus pickAnotherFromAwaiting(OrderMock o) {
    final bool hasResponders = (o.respondersCount ?? 0) > 0;
    final MyOrderStatus newStatus = hasResponders
        ? MyOrderStatus.waitingChoose
        : MyOrderStatus.waiting;
    final int idx = newOrders.indexWhere((OrderMock x) => x.id == o.id);
    if (idx < 0) return newStatus;
    // Сбрасываем контакты ранее предложенного исполнителя — он больше
    // не ассоциирован с заказом. Иначе его имя и телефон тихо
    // переехали бы в следующий матч.
    newOrders[idx] = newOrders[idx].copyWith(
      status: newStatus,
      clearContacts: true,
    );
    _bump();
    return newStatus;
  }

  /// Предложение заказа конкретному исполнителю из каталога: заказ
  /// переводится из `waiting` (или `executorDeclinedWaiting`) в
  /// `awaitingExecutor` — «Ждёт подтверждения от исполнителя». Сюда же
  /// можно пристегнуть имя и телефон предложенного исполнителя на
  /// случай, если он в итоге подтвердит — данные уже будут в заказе.
  static void proposeToExecutor(
    OrderMock o, {
    String? name,
    String? phone,
    String? matchId,
    String? executorId,
  }) {
    final int idx = newOrders.indexWhere((OrderMock x) => x.id == o.id);
    if (idx < 0) return;
    newOrders[idx] = newOrders[idx].copyWith(
      status: MyOrderStatus.awaitingExecutor,
      customerName: name,
      customerPhone: phone,
      matchId: matchId,
      executorId: executorId,
    );
    _bump();
  }

  /// Помечает заказ как тот, по которому уже оставлен отзыв.
  static void markReviewLeft(String id) {
    void patch(List<OrderMock> list) {
      final int i = list.indexWhere((OrderMock x) => x.id == id);
      if (i >= 0) list[i] = list[i].copyWith(reviewLeft: true);
    }

    patch(newOrders);
    patch(accepted);
    patch(rejected);
    _bump();
  }

  /// Возвращает архивный заказ обратно в «Ожидает» со статусом
  /// `waiting` (после нажатия «Опубликовать заново»).
  static void republish(OrderMock o) {
    rejected.remove(o);
    newOrders.insert(0, o.copyWith(status: MyOrderStatus.waiting));
    _bump();
  }

  /// При блокировке аккаунта переносит активные заказы в архив со
  /// статусом «Отменён», сохраняя исходный статус в `prevStatus` —
  /// чтобы при разблокировке можно было вернуть обратно.
  static void archiveActiveOrdersOnBlock() {
    final List<OrderMock> removed = <OrderMock>[];
    for (final OrderMock o in newOrders) {
      removed.add(o.copyWith(
        status: MyOrderStatus.rejectedDeclined,
        prevStatus: o.status,
      ));
    }
    for (final OrderMock o in accepted) {
      if (o.status == MyOrderStatus.completed) continue;
      removed.add(o.copyWith(
        status: MyOrderStatus.rejectedDeclined,
        prevStatus: o.status,
      ));
    }
    newOrders.clear();
    accepted.removeWhere(
        (OrderMock o) => o.status != MyOrderStatus.completed);
    rejected.insertAll(0, removed);
    _bump();
  }

  /// После разблокировки возвращает из архива заказы, которые туда
  /// положила блокировка (`prevStatus != null`) и дата аренды которых
  /// ещё не прошла. Истёкшие — остаются в архиве со статусом
  /// «Отменён».
  static void restoreActiveOrdersOnUnblock() {
    final List<OrderMock> stillArchived = <OrderMock>[];
    for (final OrderMock o in rejected) {
      if (o.prevStatus == null || o.isExpired) {
        stillArchived.add(o.copyWith(prevStatus: null));
        continue;
      }
      final OrderMock restored = o.copyWith(
        status: o.prevStatus!,
        prevStatus: null,
      );
      if (restored.status == MyOrderStatus.accepted) {
        accepted.insert(0, restored);
      } else {
        newOrders.insert(0, restored);
      }
    }
    rejected
      ..clear()
      ..addAll(stillArchived);
    _bump();
  }

  static void _bump() {
    revision.value++;
  }
}
