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
  final double? volume;
  final String? unit; // 'm' | 'm2' | 'm3'

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        if (volume != null) 'volume': volume,
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
    required this.address,
    required this.dateFrom,
    required this.dateTo,
    required this.timeFrom,
    required this.timeTo,
    required this.exactDate,
    required this.wholeDay,
    required this.machineryTitles,
    required this.publishedAt,
    required this.status,
    required this.respondersCount,
  });

  final String id;
  final int displayNumber;
  final String title;
  final String address;
  final DateTime dateFrom;
  final DateTime? dateTo;
  final String? timeFrom;
  final String? timeTo;
  final bool exactDate;
  final bool wholeDay;
  final List<String> machineryTitles;
  final DateTime publishedAt;
  final String status; // 'published' | 'archived' | 'cancelled' | 'draft'
  final int respondersCount;

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
  final double executorRating;
  final int executorReviewCount;
  final String? serviceId;
  final List<String> serviceMachineryTitles;
}
