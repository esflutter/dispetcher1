import 'package:dispatcher_1/core/catalog/models.dart' as catalog;

// DTO для заказов заказчика (его собственные записи в `public.orders`)
// и входящих откликов исполнителей (`order_matches`).

/// Черновик для INSERT в `orders`. Поля соответствуют колонкам таблицы;
/// `status` ставим из вызывающего (published при "Опубликовать" или
/// draft если добавим "Сохранить в черновики").
class OrderDraft {
  const OrderDraft({
    required this.title,
    required this.description,
    required this.categoryTitles,
    required this.machineryTitles,
    required this.works,
    required this.address,
    this.latitude,
    this.longitude,
    required this.dateFrom,
    required this.dateTo,
    required this.exactDate,
    required this.timeFrom,
    required this.timeTo,
    required this.wholeDay,
    required this.photos,
  });

  final String title;
  final String? description;
  final List<String> categoryTitles;
  final List<String> machineryTitles;
  final List<WorkDraft> works;
  final String address;
  final double? latitude;
  final double? longitude;
  final DateTime dateFrom;
  final DateTime? dateTo;
  final bool exactDate;
  final String? timeFrom; // 'HH:mm'
  final String? timeTo;
  final bool wholeDay;
  final List<String> photos;
}

class WorkDraft {
  const WorkDraft({required this.name, this.volume, this.unit});
  final String name;
  /// Свободный текст до 10 символов — туда юзер пишет «22» или
  /// «10x30x5» (габариты в метрах). DB CHECK гарантирует maxLength=10.
  final String? volume;
  final String? unit; // 'm' | 'm2' | 'm3'

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        if (volume != null && volume!.isNotEmpty) 'volume': volume,
        if (unit != null) 'unit': unit,
      };
}

/// Один опубликованный заказ со сводкой откликов. Для списка "Мои заказы"
/// заказчика.
class CustomerOrderListItem {
  const CustomerOrderListItem({
    required this.id,
    required this.displayNumber,
    required this.title,
    this.description = '',
    required this.address,
    required this.dateFrom,
    required this.dateTo,
    required this.timeFrom,
    required this.timeTo,
    required this.exactDate,
    required this.wholeDay,
    required this.machineryTitles,
    this.categoryTitles = const <String>[],
    this.works = const <String>[],
    this.photos = const <String>[],
    required this.publishedAt,
    required this.status,
    required this.respondersCount,
    this.bestMatchId,
    this.bestMatchStatus,
    this.bestMatchExecutorId,
    this.bestMatchExecutorName,
    this.bestMatchExecutorRating = 0,
    this.bestMatchExecutorReviewCount = 0,
    this.bestMatchExecutorPhone,
    this.bestMatchExecutorEmail,
    this.bestMatchExecutorAvatarUrl,
    this.reviewLeft = false,
  });

  final String id;
  final int displayNumber;
  final String title;
  final String description;
  final String address;
  final DateTime dateFrom;
  final DateTime? dateTo;
  final String? timeFrom;
  final String? timeTo;
  final bool exactDate;
  final bool wholeDay;
  final List<String> machineryTitles;
  /// Категории работ (резолвлены title из `categories`). Раньше не
  /// подгружались из БД — на детальной карточке заказа блок «Категории
  /// работ» был пустым у всех заказов из БД.
  final List<String> categoryTitles;
  /// Готовые к отображению строки работ («Демонтаж — 5 м³»). Берём из
  /// `orders.works` jsonb-массива при чтении.
  final List<String> works;
  /// Пути к фото в приватном бакете `order-photos`. Для отображения
  /// нужен `getSignedUrl` — см. `SignedStorageImage`.
  final List<String> photos;
  final DateTime publishedAt;
  final String status; // 'published' | 'archived' | 'cancelled' | 'draft'
  final int respondersCount;

  /// «Лучший» мэтч по заказу — приоритет:
  /// completed > accepted > awaiting_executor > awaiting_customer.
  /// `null`, если активных мэтчей нет.
  final String? bestMatchId;
  final String? bestMatchStatus;
  final String? bestMatchExecutorId;
  final String? bestMatchExecutorName;
  final double bestMatchExecutorRating;
  final int bestMatchExecutorReviewCount;
  /// Телефон исполнителя по best-мэтчу — заполняется только когда мэтч
  /// в `accepted`/`completed` (RLS на `profiles_private` пропускает
  /// заказчика только в этих статусах). Нужен для кнопки-звонка
  /// в карточке «В работе» и в деталях заказа без отдельного запроса.
  final String? bestMatchExecutorPhone;

  /// Email исполнителя по best-мэтчу (`profiles_private.email`).
  /// Тянется тем же SELECT'ом что и `bestMatchExecutorPhone`, по тем
  /// же RLS-условиям (`accepted`/`completed`). `null` — поле пустое
  /// или у заказчика нет доступа.
  final String? bestMatchExecutorEmail;

  /// URL аватара исполнителя по best-мэтчу (`profiles.avatar_url`).
  /// Доступен на любом статусе мэтча (RLS на `profiles` пропускает
  /// чтение этого поля без ограничений). Нужен для шапки заказа в
  /// «В работе»/«Завершён» — без него у исполнителя всегда серый
  /// силуэт.
  final String? bestMatchExecutorAvatarUrl;

  /// True, если текущий заказчик уже оставил отзыв об исполнителе по
  /// best-мэтчу. Берётся одним SELECT по `reviews` в `listMine` и
  /// далее пробрасывается в `OrderMock.reviewLeft`. Без этого флаг
  /// жил только в локальном кэше и сбрасывался при рестарте — после
  /// перезагрузки приложения кнопка «Оставить отзыв» опять появлялась
  /// и второй INSERT падал по unique-constraint (либо плодил дубль).
  final bool reviewLeft;

  /// Удобный адаптер для утилиты `formatRentDate` из каталога исполнителя.
  catalog.OrderListItem toFormatAdapter() => catalog.OrderListItem(
        id: id,
        displayNumber: displayNumber,
        title: title,
        address: address,
        dateFrom: dateFrom,
        dateTo: dateTo,
        timeFrom: timeFrom,
        timeTo: timeTo,
        exactDate: exactDate,
        wholeDay: wholeDay,
        machineryTitles: machineryTitles,
        publishedAt: publishedAt,
        customer: const catalog.CustomerSummary(
          id: '',
          name: '',
          ratingAsCustomer: 0,
          reviewCountAsCustomer: 0,
        ),
      );
}

/// Отклик исполнителя на заказ (для экрана деталей заказа у заказчика).
class IncomingResponse {
  const IncomingResponse({
    required this.matchId,
    required this.status,
    required this.createdAt,
    required this.agreedPricePerHour,
    required this.agreedPricePerDay,
    required this.agreedMinHours,
    required this.executorId,
    required this.executorName,
    required this.executorAvatarUrl,
    required this.executorRating,
    required this.executorReviewCount,
    required this.serviceId,
    required this.serviceMachineryTitles,
  });

  final String matchId;
  final String status; // order_matches.status
  final DateTime createdAt;
  final double? agreedPricePerHour;
  final double? agreedPricePerDay;
  final int? agreedMinHours;
  final String executorId;
  final String executorName;
  final String? executorAvatarUrl;
  final double executorRating;
  final int executorReviewCount;
  final String? serviceId;
  final List<String> serviceMachineryTitles;
}

/// Снапшот мэтча на момент чтения: статус, согласованная цена и список
/// техник услуги. Используется на детальной странице моего заказа,
/// чтобы показать цену и подписи к ней (например «Экскаватор — 3 500
/// ₽/час, от 4 часов»).
class MatchSnapshot {
  const MatchSnapshot({
    required this.status,
    required this.agreedPricePerHour,
    required this.agreedPricePerDay,
    required this.agreedMinHours,
    required this.serviceMachineryTitles,
  });

  final String status;
  final double? agreedPricePerHour;
  final double? agreedPricePerDay;
  final int? agreedMinHours;
  final List<String> serviceMachineryTitles;
}
