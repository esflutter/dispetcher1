import 'package:flutter/foundation.dart';

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
    required this.publishedAgo,
    required this.publishedAt,
    this.price,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.number,
    this.description = '',
    this.categories = const <String>[],
    this.works = const <String>[],
    this.photos = const <String>[],
    this.reviewLeft = false,
    this.respondersCount,
    this.prevStatus,
  });

  final String id;
  final MyOrderStatus status;
  final String title;
  final List<String> equipment;
  final String rentDate;
  final String address;
  final String publishedAgo;

  /// Момент публикации заказа — используется для сортировки списка
  /// «от новых к старым». Отображаемый человеку текст лежит отдельно
  /// в [publishedAgo], чтобы не перевычислять форматирование на каждую
  /// перерисовку.
  final DateTime publishedAt;

  /// Отформатированная стоимость, например «80 000 – 100 000 ₽»,
  /// «От 80 000 ₽» или «50 000 ₽» для точной цены. Если null — берётся
  /// дефолтное значение из [MyOrderCard].
  final String? price;
  final String? customerName;
  final String? customerPhone;

  /// Email партнёра по «мэтчу» (исполнителя со стороны заказчика или
  /// заказчика со стороны исполнителя). Показывается в карточках с
  /// контактами только если заполнен — email опциональное поле.
  final String? customerEmail;

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
    bool clearContacts = false,
  }) {
    return OrderMock(
      id: id,
      status: status ?? this.status,
      title: title,
      equipment: equipment,
      rentDate: rentDate,
      address: address,
      publishedAgo: publishedAgo,
      publishedAt: publishedAt,
      price: price,
      // [clearContacts] принудительно обнуляет контактные поля,
      // независимо от того, что передали в customerName/phone/email.
      // Нужен, когда заказ возвращается в «Откликов пока нет» — чтобы
      // данные ранее предложенного исполнителя не тянулись за заказом.
      customerName:
          clearContacts ? null : (customerName ?? this.customerName),
      customerPhone:
          clearContacts ? null : (customerPhone ?? this.customerPhone),
      customerEmail:
          clearContacts ? null : (customerEmail ?? this.customerEmail),
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

  /// База отсчёта для моковых дат публикации. Захватывается один раз
  /// при первом обращении к стору, чтобы относительные метки
  /// («2 часа назад», «Вчера в 14:30») не разъезжались.
  static final DateTime _now = DateTime.now();
  static DateTime _today(int h, int m) =>
      DateTime(_now.year, _now.month, _now.day, h, m);
  static DateTime _yesterday(int h, int m) =>
      DateTime(_now.year, _now.month, _now.day - 1, h, m);
  static DateTime _hoursAgo(int h) => _now.subtract(Duration(hours: h));
  static DateTime _daysAgo(int d) => _now.subtract(Duration(days: d));

  /// «Ожидает»: заказ опубликован, исполнитель ещё не выбран.
  static final List<OrderMock> newOrders = <OrderMock>[
    OrderMock(
      id: 'n1',
      status: MyOrderStatus.waiting,
      title: 'Нужен экскаватор для копки траншеи',
      equipment: const <String>['Экскаватор'],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: '2 часа назад',
      publishedAt: _hoursAgo(2),
      description:
          'Нужно проложить траншею под кабель связи на частном участке. '
          'Глубина примерно 0,8 м, длина около 30 м. Грунт суглинок, '
          'без корней. Подъезд свободный.',
    ),
    OrderMock(
      id: 'n2',
      status: MyOrderStatus.waitingChoose,
      title: 'Земляные работы',
      equipment: const <String>['Автокран', 'Экскаватор'],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: 'Сегодня в 11:30',
      publishedAt: _today(11, 30),
      respondersCount: 3,
      description:
          'Требуется разработать площадку под стройку складского ангара. '
          'Снятие растительного слоя и планировка, нужна помощь автокрана '
          'для разгрузки ЖБИ-плит.',
    ),
    OrderMock(
      id: 'n3',
      status: MyOrderStatus.waitingChoose,
      title: 'Разработка котлована под фундамент',
      equipment: const <String>[
        'Экскаватор',
        'Автокран',
        'Эвакуатор',
        'Манипулятор',
        'Автовышка',
      ],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: 'Сегодня в 11:30',
      publishedAt: _today(11, 30),
      respondersCount: 1,
      description:
          'Котлован под ленточный фундамент дома 10×12 м, глубина 1,5 м. '
          'Вывоз грунта на площадку в 5 км. Рядом трасса, подъезд '
          'технике свободный.',
    ),
    OrderMock(
      id: 'n4',
      status: MyOrderStatus.executorDeclined,
      title: 'Демонтаж строения',
      equipment: const <String>['Экскаватор', 'Самосвал'],
      rentDate: '20 июня · 08:00–17:00',
      address: 'Московская область, Красногорск, ул. Ленина, 10',
      publishedAgo: 'Вчера в 09:00',
      publishedAt: _yesterday(9, 0),
      respondersCount: 2,
      description:
          'Снос старого кирпичного гаража 6×4 м с последующим вывозом '
          'строительного мусора. Электричество отключено, газа нет.',
    ),
    OrderMock(
      id: 'n5',
      status: MyOrderStatus.awaitingExecutor,
      title: 'Бурение скважин',
      equipment: const <String>['Буровая установка'],
      rentDate: '25 июня · 10:00–16:00',
      address: 'Московская область, Химки, ул. Строителей, 5',
      publishedAgo: 'Сегодня в 08:15',
      publishedAt: _today(8, 15),
      description:
          'Нужно пробурить 4 скважины диаметром 300 мм под винтовые сваи, '
          'глубина до 2 м. Грунт — глина с небольшими вкраплениями '
          'щебня.',
    ),
    OrderMock(
      id: 'n6',
      status: MyOrderStatus.executorDeclinedWaiting,
      title: 'Устройство ограждения территории',
      equipment: const <String>['Манипулятор'],
      rentDate: '28 июня · 08:00–20:00',
      address: 'Московская область, Балашиха, ул. Заречная, 12',
      publishedAgo: 'Сегодня в 07:40',
      publishedAt: _today(7, 40),
      description:
          'Установка бетонного забора по периметру участка — 80 погонных '
          'метров, 20 секций. Нужна помощь манипулятора для монтажа плит.',
    ),
  ];

  /// «В работе» + «Архив» после completed.
  static final List<OrderMock> accepted = <OrderMock>[
    OrderMock(
      id: 'a1',
      status: MyOrderStatus.accepted,
      title: 'Нужен экскаватор для копки траншеи',
      equipment: const <String>['Экскаватор'],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: '2 часа назад',
      publishedAt: _hoursAgo(2),
      customerName: 'Иванов Александр',
      customerPhone: '+7 999 123-45-67',
      customerEmail: 'ivanov.a@example.ru',
      description:
          'Копка траншеи под водопровод длиной 25 м, глубина 1,2 м. '
          'Грунт — суглинок, без камней. Въезд техники со стороны улицы.',
    ),
    OrderMock(
      id: 'a2',
      status: MyOrderStatus.accepted,
      title: 'Разработка котлована под фундамент',
      equipment: const <String>[
        'Экскаватор',
        'Автокран',
        'Эвакуатор',
        'Манипулятор',
        'Автовышка',
      ],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: 'Сегодня в 11:30',
      publishedAt: _today(11, 30),
      customerName: 'Петров Сергей',
      customerPhone: '+7 999 765-43-21',
      customerEmail: 'petrov.s@example.ru',
      description:
          'Подготовка котлована 8×10 м под ленточный фундамент. Дополнительно '
          'нужен автокран на 1–2 часа для разгрузки арматурных каркасов.',
    ),
    OrderMock(
      id: 'a3',
      status: MyOrderStatus.completed,
      title: 'Нужен экскаватор для копки траншеи',
      equipment: const <String>['Экскаватор'],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: 'Вчера в 14:30',
      publishedAt: _yesterday(14, 30),
      customerName: 'Иванов Александр',
      customerPhone: '+7 999 123-45-67',
      description:
          'Траншея под дренаж вдоль забора, длина 18 м, глубина 0,7 м. '
          'Отвал грунта рядом с траншеей — вывоз не требуется.',
    ),
  ];

  /// «Архив» (отклонённые/отменённые/не нашёлся).
  static final List<OrderMock> rejected = <OrderMock>[
    OrderMock(
      id: 'r1',
      status: MyOrderStatus.rejectedOther,
      title: 'Земляные работы',
      equipment: const <String>['Автокран', 'Экскаватор'],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: '2 часа назад',
      publishedAt: _hoursAgo(2),
      description:
          'Подготовка площадки под склад: снятие плодородного слоя, '
          'планировка, монтаж водоотвода. Автокран для разгрузки труб.',
    ),
    OrderMock(
      id: 'r2',
      status: MyOrderStatus.rejectedDeclined,
      title: 'Разработка котлована под фундамент',
      equipment: const <String>[
        'Экскаватор',
        'Автокран',
        'Эвакуатор',
        'Манипулятор',
        'Автовышка',
      ],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: 'Вчера в 14:30',
      publishedAt: _yesterday(14, 30),
      description:
          'Котлован 12×15 м под фундамент двухэтажного коттеджа. '
          'Глубина 2,0 м. Вывоз грунта — 30 м³ на полигон в 10 км.',
    ),
    OrderMock(
      id: 'r3',
      status: MyOrderStatus.rejectedDeclined,
      title: 'Разработка котлована под фундамент',
      equipment: const <String>[
        'Экскаватор',
        'Автокран',
        'Эвакуатор',
        'Манипулятор',
        'Автовышка',
      ],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: '3 дня назад',
      publishedAt: _daysAgo(3),
      description:
          'Разработка котлована под пристройку к жилому дому, '
          'размеры 6×8 м, глубина 1,4 м. Доступ ограничен — узкие ворота.',
    ),
  ];

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

  /// Заказы, которые можно предложить исполнителю из каталога. Только
  /// статус `waiting` («Откликов пока нет»). Исключены:
  ///   * `awaitingExecutor` — уже предложен конкретному исполнителю;
  ///   * `waitingChoose` / `executorDeclined` — там есть отклики,
  ///     заказчик должен выбрать из откликнувшихся, а не звать ещё;
  ///   * `executorDeclinedWaiting` — это отдельный «пост-отказ»
  ///     поток, заказчик возвращается в каталог сам, а не предлагает
  ///     этот заказ другому исполнителю через экран «Предложить».
  static List<OrderMock> get offerable => newOrders
      .where((OrderMock o) => o.status == MyOrderStatus.waiting)
      .toList();

  /// Добавляет только что созданный пользователем заказ в начало
  /// списка «Ожидает».
  static void addCreated(OrderMock order) {
    newOrders.insert(0, order);
    _bump();
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
  }) {
    newOrders.remove(o);
    accepted.remove(o);
    accepted.insert(
      0,
      o.copyWith(
        status: MyOrderStatus.accepted,
        customerName: name,
        customerPhone: phone,
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
  }) {
    final int idx = newOrders.indexWhere((OrderMock x) => x.id == o.id);
    if (idx < 0) return;
    newOrders[idx] = newOrders[idx].copyWith(
      status: MyOrderStatus.awaitingExecutor,
      customerName: name,
      customerPhone: phone,
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
