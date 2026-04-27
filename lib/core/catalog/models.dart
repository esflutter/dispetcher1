// DTO для справочников и сущностей каталога. Имена полей совпадают с
// колонками PostgreSQL, преобразование из `Map<String, dynamic>` живёт в
// фабриках `fromRow`.

class MachineryRef {
  const MachineryRef({required this.id, required this.title});
  final int id;
  final String title;

  factory MachineryRef.fromRow(Map<String, dynamic> r) => MachineryRef(
        id: r['id'] as int,
        title: r['title'] as String,
      );
}

class CategoryRef {
  const CategoryRef({required this.id, required this.title});
  final int id;
  final String title;

  factory CategoryRef.fromRow(Map<String, dynamic> r) => CategoryRef(
        id: r['id'] as int,
        title: r['title'] as String,
      );
}

/// Мини-профиль заказчика для карточек ленты.
class CustomerSummary {
  const CustomerSummary({
    required this.id,
    required this.name,
    required this.ratingAsCustomer,
    required this.reviewCountAsCustomer,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final double ratingAsCustomer;
  final int reviewCountAsCustomer;

  factory CustomerSummary.fromRow(Map<String, dynamic> r) => CustomerSummary(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? 'Пользователь',
        avatarUrl: r['avatar_url'] as String?,
        ratingAsCustomer: _num(r['rating_as_customer']),
        reviewCountAsCustomer: (r['review_count_as_customer'] as int?) ?? 0,
      );
}

/// Запись заказа для списка. Названия техники уже разрезолвлены
/// в сервисе, UI их просто показывает.
class OrderListItem {
  const OrderListItem({
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
    required this.customer,
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
  final CustomerSummary customer;
}

/// Один элемент спецификации работ заказа (например, "Выемка грунта: 40 м³").
/// Хранится в `orders.works` как jsonb-массив; схема фиксируется в БД
/// (CHECK с `jsonb_matches_schema`): `{name, volume(number), unit(m|m2|m3)}`.
class WorkItem {
  const WorkItem({required this.name, this.volume, this.unit});
  final String name;
  final double? volume;
  final String? unit; // 'm' / 'm2' / 'm3'

  factory WorkItem.fromJson(Map<String, dynamic> j) => WorkItem(
        name: (j['name'] as String?) ?? '',
        volume: (j['volume'] as num?)?.toDouble(),
        unit: j['unit'] as String?,
      );
}

/// Полные детали одного заказа.
class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.displayNumber,
    required this.title,
    required this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.dateFrom,
    required this.dateTo,
    required this.timeFrom,
    required this.timeTo,
    required this.exactDate,
    required this.wholeDay,
    required this.machineryTitles,
    required this.categoryTitles,
    required this.works,
    required this.photos,
    required this.publishedAt,
    required this.customer,
  });

  final String id;
  final int displayNumber;
  final String title;
  final String? description;
  final String address;
  final double? latitude;
  final double? longitude;
  final DateTime dateFrom;
  final DateTime? dateTo;
  final String? timeFrom;
  final String? timeTo;
  final bool exactDate;
  final bool wholeDay;
  final List<String> machineryTitles;
  final List<String> categoryTitles;
  final List<WorkItem> works;
  final List<String> photos;
  final DateTime publishedAt;
  final CustomerSummary customer;
}

/// Публичный профиль заказчика + его юридический статус (для карточки).
class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.legalStatus,
    required this.ratingAsCustomer,
    required this.reviewCountAsCustomer,
    required this.about,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final String? legalStatus; // individual / self_employed / ip / legal_entity
  final double ratingAsCustomer;
  final int reviewCountAsCustomer;
  final String? about;

  factory CustomerProfile.fromRow(Map<String, dynamic> r) => CustomerProfile(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? 'Пользователь',
        avatarUrl: r['avatar_url'] as String?,
        legalStatus: r['legal_status'] as String?,
        ratingAsCustomer: _num(r['rating_as_customer']),
        reviewCountAsCustomer: (r['review_count_as_customer'] as int?) ?? 0,
        about: r['about'] as String?,
      );
}

/// Услуга исполнителя, попадающая под фильтр по технике в каталоге.
/// Используется на карточке исполнителя, чтобы показать конкретную
/// строку прайса вместо обобщённого списка «Спецтехника / Категории».
class MatchingService {
  const MatchingService({
    required this.machineryTitle,
    required this.pricePerHour,
    required this.pricePerDay,
    required this.minHours,
  });

  final String machineryTitle;
  final double? pricePerHour;
  final double? pricePerDay;
  final int? minHours;
}

/// Запись каталога исполнителей (видит заказчик при поиске).
/// Для каждой публичной карточки в `executor_cards` плюс данные из
/// `profiles` и aggregate по `services` (техника/категории/мин. цена).
class ExecutorCardListItem {
  const ExecutorCardListItem({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.ratingAsExecutor,
    required this.reviewCountAsExecutor,
    required this.legalStatus,
    required this.experienceYears,
    required this.about,
    required this.locationAddress,
    required this.locationLat,
    required this.locationLng,
    required this.radiusKm,
    required this.machineryTitles,
    required this.categoryTitles,
    required this.minPricePerHour,
    required this.minPricePerDay,
    this.matchingServices = const <MatchingService>[],
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final double ratingAsExecutor;
  final int reviewCountAsExecutor;
  final String? legalStatus;
  final int? experienceYears;
  final String? about;
  final String? locationAddress;
  /// Координаты адреса карточки. Заполняются при выборе адреса в форме
  /// `EditExecutorCardScreen`; null для старых карточек, созданных до
  /// подключения DaData. На карте каталога такой исполнитель попадает
  /// под mock-fallback, в фильтре по радиусу — отсекается.
  final double? locationLat;
  final double? locationLng;
  final int? radiusKm;
  final List<String> machineryTitles;
  final List<String> categoryTitles;
  final double? minPricePerHour;
  final double? minPricePerDay;

  /// Услуги исполнителя по выбранной в фильтре технике. Заполняется
  /// только когда `machineryTitles` фильтр непустой — тогда карточка
  /// в ленте показывает «Экскаватор — 3 500 ₽/час, от 4 часов» вместо
  /// обобщённых блоков «Спецтехника / Категории услуг».
  final List<MatchingService> matchingServices;
}

/// Услуга исполнителя для блока «Услуги» в его карточке. Полные поля
/// из таблицы `services`, плюс резолвнутые названия техники.
class ExecutorService {
  const ExecutorService({
    required this.id,
    required this.title,
    required this.description,
    required this.machineryTitles,
    required this.categoryTitles,
    required this.pricePerHour,
    required this.pricePerDay,
    required this.minHours,
    this.photos = const <String>[],
  });

  final String id;
  final String title;
  final String? description;
  final List<String> machineryTitles;
  final List<String> categoryTitles;
  final double? pricePerHour;
  final double? pricePerDay;
  final int? minHours;

  /// Фото услуги — публичные URL из storage-бакета `service-photos`.
  /// До 8 шт. (CHECK в БД). Пустой список — фото не загружены.
  final List<String> photos;
}

/// Override по конкретному дню в расписании исполнителя
/// (`schedule_day_overrides`). По соглашению default — рабочий день,
/// поэтому в БД хранятся только дни-исключения.
class ExecutorScheduleDay {
  const ExecutorScheduleDay({
    required this.day,
    required this.accepting,
    required this.wholeDay,
    required this.timeFrom,
    required this.timeTo,
    required this.machineryTitles,
    required this.radiusKm,
  });

  final DateTime day;

  /// `true` — исполнитель работает в этот день; `false` — выходной.
  final bool accepting;

  /// Если `true` — время не задано (24/7 на этот день).
  final bool wholeDay;

  /// Локальное время «c», формат `HH:MM` или null.
  final String? timeFrom;
  final String? timeTo;
  final List<String> machineryTitles;
  final int? radiusKm;
}

/// Полная карточка исполнителя для экрана просмотра. Включает всё
/// из [ExecutorCardListItem] + список услуг + расписание (overrides).
class ExecutorCardFull {
  const ExecutorCardFull({
    required this.summary,
    required this.services,
    required this.scheduleOverrides,
  });

  final ExecutorCardListItem summary;
  final List<ExecutorService> services;

  /// Дни-исключения расписания. Ключ — дата без времени (UTC date).
  final Map<DateTime, ExecutorScheduleDay> scheduleOverrides;
}

/// Один отзыв для отображения на карточке заказчика/исполнителя.
class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.rating,
    required this.text,
    required this.authorName,
    required this.createdAt,
  });

  final String id;
  final int rating;
  final String? text;
  final String authorName;
  final DateTime createdAt;

  factory ReviewItem.fromRow(Map<String, dynamic> r) {
    final dynamic authorRaw = r['author'];
    final String authorName = authorRaw is Map<String, dynamic>
        ? (authorRaw['name'] as String?) ?? 'Пользователь'
        : 'Пользователь';
    return ReviewItem(
      id: r['id'] as String,
      rating: r['rating'] as int,
      text: r['text'] as String?,
      authorName: authorName,
      createdAt: DateTime.parse(r['created_at'] as String),
    );
  }
}

double _num(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
