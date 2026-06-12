import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dispatcher_1/core/utils/geo_distance.dart';

import 'models.dart';

/// Чтение каталога из Supabase: справочники, лента заказов,
/// карточка одного заказа и карточка заказчика. Отклик на заказ —
/// отдельный метод [respondToOrder] (INSERT в `order_matches`).
class _ExecAggregate {
  final Set<int> machineryIds = <int>{};
  final Set<int> categoryIds = <int>{};
  double? minPriceHour;
  double? minPriceDay;

  /// Все услуги исполнителя — нужны, чтобы потом сформировать
  /// `matchingServices` для карточки ленты под активный фильтр.
  final List<_ServiceRow> services = <_ServiceRow>[];

  void addMachinery(List<int> ids) => machineryIds.addAll(ids);
  void addCategory(List<int> ids) => categoryIds.addAll(ids);
}

class _ServiceRow {
  const _ServiceRow({
    required this.machineryIds,
    required this.pricePerHour,
    required this.pricePerDay,
    required this.minHours,
  });

  final List<int> machineryIds;
  final double? pricePerHour;
  final double? pricePerDay;
  final int? minHours;
}

class CatalogService {
  CatalogService._();
  static final CatalogService instance = CatalogService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------
  // Справочники + in-memory кэш (живёт до перезапуска приложения)
  // ---------------------------------------------------------------

  List<MachineryRef>? _machineryCache;
  List<CategoryRef>? _categoryCache;

  /// Последний результат [listActiveMachinery] (или null, если ещё не
  /// загружали). Нужен для синхронного резолвинга id→title в моделях.
  List<MachineryRef>? get cachedMachinery => _machineryCache;

  /// То же для категорий.
  List<CategoryRef>? get cachedCategories => _categoryCache;
  // Производные словари id↔title кэшируем: раньше каждый геттер строил Map
  // заново на КАЖДОМ обращении, а обращение стоит внутри .map() по каждому
  // элементу выдачи — тысячи пересборок одинаковых словарей за одну загрузку
  // списка. Перестраиваем только когда сменился сам список-источник.
  List<MachineryRef>? _machMapsFor;
  Map<int, String>? _machIdToTitle;
  Map<String, int>? _machTitleToId;
  List<CategoryRef>? _catMapsFor;
  Map<int, String>? _catIdToTitle;
  Map<String, int>? _catTitleToId;

  void _ensureMachMaps() {
    if (identical(_machMapsFor, _machineryCache)) return;
    final List<MachineryRef> list = _machineryCache ?? const <MachineryRef>[];
    _machIdToTitle = <int, String>{for (final MachineryRef m in list) m.id: m.title};
    _machTitleToId = <String, int>{for (final MachineryRef m in list) m.title: m.id};
    _machMapsFor = _machineryCache;
  }

  void _ensureCatMaps() {
    if (identical(_catMapsFor, _categoryCache)) return;
    final List<CategoryRef> list = _categoryCache ?? const <CategoryRef>[];
    _catIdToTitle = <int, String>{for (final CategoryRef c in list) c.id: c.title};
    _catTitleToId = <String, int>{for (final CategoryRef c in list) c.title: c.id};
    _catMapsFor = _categoryCache;
  }

  Map<int, String> get _machineryIdToTitle { _ensureMachMaps(); return _machIdToTitle!; }
  Map<String, int> get _machineryTitleToId { _ensureMachMaps(); return _machTitleToId!; }
  Map<int, String> get _categoryIdToTitle  { _ensureCatMaps();  return _catIdToTitle!; }
  Map<String, int> get _categoryTitleToId  { _ensureCatMaps();  return _catTitleToId!; }

  /// id техники в порядке справочника (порядок из админки): названия в
  /// карточках и деталях идут единообразно, а не в том порядке, в котором
  /// автор отмечал технику при создании. Неизвестные id — в конец.
  List<int> machineryIdsInCatalogOrder(Iterable<int> ids) {
    final List<MachineryRef> cat = _machineryCache ?? const <MachineryRef>[];
    final Map<int, int> pos = <int, int>{
      for (int i = 0; i < cat.length; i++) cat[i].id: i,
    };
    return ids.toList()
      ..sort((int a, int b) =>
          (pos[a] ?? 1 << 20).compareTo(pos[b] ?? 1 << 20));
  }

  Future<List<MachineryRef>> listActiveMachinery() async {
    if (_machineryCache != null) return _machineryCache!;
    final List<Map<String, dynamic>> rows = await _client
        .from('machinery_types')
        .select('id, title')
        .eq('is_active', true)
        .order('sort_order');
    _machineryCache = rows.map(MachineryRef.fromRow).toList();
    return _machineryCache!;
  }

  Future<List<CategoryRef>> listActiveCategories() async {
    if (_categoryCache != null) return _categoryCache!;
    final List<Map<String, dynamic>> rows = await _client
        .from('categories')
        .select('id, title')
        .eq('is_active', true)
        .order('sort_order');
    _categoryCache = rows.map(CategoryRef.fromRow).toList();
    return _categoryCache!;
  }

  Future<void> _primeDirectories() async {
    await Future.wait<void>(<Future<void>>[
      listActiveMachinery(),
      listActiveCategories(),
    ]);
  }

  /// Прогревает in-memory кэш справочников. Вызывается один раз на
  /// старте приложения после `Supabase.initialize`, чтобы экраны
  /// (каталог, фильтр, создание заказа) получали списки техники и
  /// категорий из памяти с первого кадра.
  Future<void> warmup() => _primeDirectories();

  // Заказчик чужие заказы не листает — «исполнительские» методы ленты и
  // деталей чужого заказа (listPublishedOrders / getOrderDetail) были мёртвым
  // наследием копии из приложения исполнителя и удалены. Хелперы ниже живые:
  // ими пользуются listCustomerOrders и график занятости.

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  OrderListItem _orderListItemFromRow(Map<String, dynamic> r) {
    final List<int> machineryIds = List<int>.from(r['machinery_ids'] as List);
    final List<String> titles = machineryIdsInCatalogOrder(machineryIds)
        .map((int id) => _machineryIdToTitle[id] ?? '')
        .where((String t) => t.isNotEmpty)
        .toList();
    final dynamic customerRaw = r['customer'];
    final CustomerSummary cust = customerRaw is Map<String, dynamic>
        ? CustomerSummary.fromRow(customerRaw)
        : const CustomerSummary(
            id: '',
            name: 'Пользователь',
            ratingAsCustomer: 0,
            reviewCountAsCustomer: 0,
          );
    return OrderListItem(
      id: r['id'] as String,
      displayNumber: r['display_number'] as int,
      title: r['title'] as String,
      address: r['address'] as String,
      dateFrom: DateTime.parse(r['date_from'] as String).toLocal(),
      dateTo: r['date_to'] == null
          ? null
          : DateTime.parse(r['date_to'] as String).toLocal(),
      timeFrom: r['time_from'] as String?,
      timeTo: r['time_to'] as String?,
      exactDate: r['exact_date'] as bool,
      wholeDay: r['whole_day'] as bool,
      machineryTitles: titles,
      publishedAt: DateTime.parse(r['published_at'] as String).toLocal(),
      customer: cust,
    );
  }

  // ---------------------------------------------------------------
  // Каталог исполнителей (видит заказчик)
  // ---------------------------------------------------------------

  Future<List<ExecutorCardListItem>> listPublishedExecutors({
    Set<String> machineryTitles = const <String>{},
    Set<String> categoryTitles = const <String>{},
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? timeFrom,
    String? timeTo,
    bool? wholeDay,
    double? originLat,
    double? originLng,
    int? radiusKm,
    String? addressContains,
    // Точка отсчёта ТОЛЬКО для сортировки «ближе — выше» (адрес из фильтра
    // без радиуса либо тихий GPS). В отличие от originLat/Lng с radiusKm,
    // НИКОГО не отсекает — лишь влияет на порядок и заполняет distanceKm.
    double? sortOriginLat,
    double? sortOriginLng,
    // Цена и сортировка по цене считаются на клиенте ПОСЛЕ выборки (у карточек
    // нет колонки цены — она в услугах). Чтобы лимит не отрезал самых дешёвых
    // ещё до фильтра/сортировки, держим большой запас. Опубликованных
    // карточек естественно немного (по одной на проверенного исполнителя).
    // На большом масштабе это место заменит серверный RPC с сортировкой по
    // агрегату цены — пока запас 500 покрывает обозримый рост.
    int limit = 500,
  }) async {
    await _primeDirectories();

    final List<int> machineryIds = machineryTitles
        .map((String t) => _machineryTitleToId[t])
        .whereType<int>()
        .toList();
    final List<int> categoryIds = categoryTitles
        .map((String t) => _categoryTitleToId[t])
        .whereType<int>()
        .toList();

    // PostgREST `ilike('profile.name'...)` фильтрует только embedded
    // ресурс, а не родительские строки — на родительский набор это
    // не влияет, и в выдачу попадают все опубликованные карточки.
    // Поэтому при поиске резолвим список подходящих user_id'ов
    // несколькими источниками (имя, «о себе», адрес карточки,
    // название/описание услуги, попадание в название техники или
    // категории работ из справочника), объединяем в одно множество
    // и уже по нему фильтруем карточки.
    Set<String>? searchUserIds;
    final String? s = search?.trim();
    if (s != null && s.isNotEmpty) {
      // Один серверный RPC вместо 5-7 последовательных запросов: объединяет
      // поиск по профилю (имя / о себе), адресу карточки и услугам
      // (название / описание / техника / категория) — см. миграцию
      // 041_search_rpc. Экранирование ILIKE — внутри функции.
      final dynamic resp = await _client.rpc(
        'search_executor_ids',
        params: <String, dynamic>{'q': s},
      );
      final List<dynamic> found =
          (resp as List<dynamic>?) ?? const <dynamic>[];
      final Set<String> userIds = <String>{
        for (final dynamic r in found)
          if (r is Map && r['user_id'] != null) r['user_id'].toString(),
      };
      if (userIds.isEmpty) {
        return <ExecutorCardListItem>[];
      }
      searchUserIds = userIds;
    }

    PostgrestFilterBuilder<List<Map<String, dynamic>>> q = _client
        .from('executor_cards')
        .select(
          'user_id, location_address, location_lat, location_lng, '
          'radius_km, '
          'profile:profiles!executor_cards_user_id_fkey('
          'id, name, avatar_url, legal_status, experience_years, about, '
          'rating_as_executor, review_count_as_executor, '
          'verification_status, blocked_until)',
        )
        .eq('is_published', true);

    if (searchUserIds != null) {
      q = q.inFilter('user_id', searchUserIds.toList());
    }

    // Фильтр по строке адреса карточки (`location_address`). Нужен,
    // когда заказчик выбрал адрес в фильтре, но не задал радиус —
    // в этом случае haversine не работает (нет origin), и без ilike
    // по адресу карточки выдача не сужается совсем (показывались все
    // регионы). При активном radius этот фильтр не применяется —
    // отбор делает haversine по координатам.
    final bool radiusActive =
        radiusKm != null && originLat != null && originLng != null;
    if (!radiusActive &&
        addressContains != null &&
        addressContains.trim().isNotEmpty) {
      final String esc =
          _escapeLike(addressContains.trim()).replaceAll(',', ' ');
      q = q.ilike('location_address', '%$esc%');
    }

    List<Map<String, dynamic>> cards =
        await q.order('updated_at', ascending: false).limit(limit);

    // В каталоге показываем только верифицированных и не заблокированных
    // исполнителей. PostgREST не умеет фильтровать по полям embedded
    // ресурса в одном запросе так же, как по основному, — фильтруем
    // на клиенте. Карточек в одной выдаче мало (обычно ≤ limit=50).
    final DateTime now = DateTime.now().toUtc();
    cards = cards.where((Map<String, dynamic> c) {
      final Map<String, dynamic>? p =
          c['profile'] as Map<String, dynamic>?;
      if (p == null) return false;
      if ((p['verification_status'] as String?) != 'approved') return false;
      final String? blockedRaw = p['blocked_until'] as String?;
      if (blockedRaw != null) {
        final DateTime? until = DateTime.tryParse(blockedRaw);
        if (until != null && until.isAfter(now)) return false;
      }
      return true;
    }).toList();

    if (cards.isEmpty) return <ExecutorCardListItem>[];

    final List<String> userIds =
        cards.map((Map<String, dynamic> r) => r['user_id'] as String).toList();

    // Если задан фильтр по дате — собираем список user_id, у которых
    // расписание (`schedule_day_overrides`) на эти даты конфликтует с
    // запросом, и исключаем их. Без override считаем, что исполнитель
    // доступен по умолчанию.
    Set<String> excludedByDate = const <String>{};
    if (dateFrom != null) {
      excludedByDate = await _findUnavailableExecutors(
        userIds: userIds,
        dateFrom: dateFrom,
        dateTo: dateTo ?? dateFrom,
        timeFrom: timeFrom,
        timeTo: timeTo,
        wholeDay: wholeDay ?? false,
      );
    }

    final List<Map<String, dynamic>> services = await _client
        .from('services')
        .select(
          'executor_id, machinery_ids, category_ids, '
          'price_per_hour, price_per_day, min_hours',
        )
        .inFilter('executor_id', userIds)
        .eq('is_paid', true)
        .eq('is_archived', false);

    // Aggregate by executor.
    final Map<String, _ExecAggregate> byUser =
        <String, _ExecAggregate>{};
    for (final Map<String, dynamic> s in services) {
      final String uid = s['executor_id'] as String;
      final _ExecAggregate agg =
          byUser.putIfAbsent(uid, _ExecAggregate.new);
      final List<int> mIds = List<int>.from(s['machinery_ids'] as List);
      final List<int> cIds = List<int>.from(s['category_ids'] as List);
      final double? pricePerHour = _toDouble(s['price_per_hour']);
      final double? pricePerDay = _toDouble(s['price_per_day']);
      final int? minHours = s['min_hours'] as int?;
      agg.addMachinery(mIds);
      agg.addCategory(cIds);
      agg.minPriceHour = _min(agg.minPriceHour, pricePerHour);
      agg.minPriceDay = _min(agg.minPriceDay, pricePerDay);
      agg.services.add(_ServiceRow(
        machineryIds: mIds,
        pricePerHour: pricePerHour,
        pricePerDay: pricePerDay,
        minHours: minHours,
      ));
    }

    final List<ExecutorCardListItem> out = <ExecutorCardListItem>[];
    for (final Map<String, dynamic> c in cards) {
      final String uid = c['user_id'] as String;
      final Map<String, dynamic> p =
          c['profile'] as Map<String, dynamic>;
      final _ExecAggregate agg =
          byUser[uid] ?? _ExecAggregate();
      // Если задан фильтр по технике/категориям — отсекаем тех, у кого
      // нет ни одной услуги, попадающей под фильтр.
      if (machineryIds.isNotEmpty &&
          !machineryIds.any(agg.machineryIds.contains)) {
        continue;
      }
      if (categoryIds.isNotEmpty &&
          !categoryIds.any(agg.categoryIds.contains)) {
        continue;
      }
      if (excludedByDate.contains(uid)) {
        continue;
      }
      // Если активен фильтр по технике — собираем для карточки конкретные
      // услуги по выбранной технике (одна машина → одна строка прайса).
      // Без фильтра карточка показывает обобщённые блоки.
      final List<MatchingService> matching = <MatchingService>[];
      if (machineryIds.isNotEmpty) {
        for (final _ServiceRow s in agg.services) {
          for (final int mId in s.machineryIds) {
            if (!machineryIds.contains(mId)) continue;
            final String title = _machineryIdToTitle[mId] ?? '';
            if (title.isEmpty) continue;
            matching.add(MatchingService(
              machineryTitle: title,
              pricePerHour: s.pricePerHour,
              pricePerDay: s.pricePerDay,
              minHours: s.minHours,
            ));
          }
        }
        // Дешёвые услуги — выше: верхняя строка карточки совпадает с ценой,
        // по которой карточка стоит в отсортированном по цене списке. Ключ
        // строки — видимая цена (часовая, иначе дневная), как в _ServiceLine.
        matching.sort((MatchingService a, MatchingService b) {
          final double pa = a.pricePerHour ?? a.pricePerDay ?? double.infinity;
          final double pb = b.pricePerHour ?? b.pricePerDay ?? double.infinity;
          return pa.compareTo(pb);
        });
      }

      // Цена карточки: при активном фильтре по технике считаем минимум по
      // услугам ИМЕННО под выбранную технику (matching), а не по всем услугам
      // исполнителя. Иначе карточка под фильтром «экскаватор» показывала бы
      // дешёвую цену, например, от крана, и сортировка/фильтр по цене врали бы.
      double? cardMinHour = agg.minPriceHour;
      double? cardMinDay = agg.minPriceDay;
      if (machineryIds.isNotEmpty) {
        cardMinHour = null;
        cardMinDay = null;
        for (final MatchingService m in matching) {
          cardMinHour = _min(cardMinHour, m.pricePerHour);
          cardMinDay = _min(cardMinDay, m.pricePerDay);
        }
      }

      final double? cardLat = (c['location_lat'] as num?)?.toDouble();
      final double? cardLng = (c['location_lng'] as num?)?.toDouble();

      // Расстояние до карточки — для сортировки «ближе — выше». Точка
      // отсчёта: адрес фильтра при активном радиусе, иначе sortOrigin
      // (адрес без радиуса / тихий GPS). Нет точки или координат — null.
      final double? refLat =
          (radiusKm != null && originLat != null) ? originLat : sortOriginLat;
      final double? refLng =
          (radiusKm != null && originLng != null) ? originLng : sortOriginLng;
      double? distKm;
      if (refLat != null && refLng != null &&
          cardLat != null && cardLng != null) {
        distKm = haversineKm(refLat, refLng, cardLat, cardLng);
      }

      // Клиентский фильтр радиуса (haversine). Без PostGIS на сервере
      // считаем расстояние от точки фильтра до адреса карточки, и
      // пропускаем только тех, кто в радиусе. Карточки без координат
      // (старые, созданы до подключения DaData) при активном фильтре
      // отсекаем — иначе они «всплывали» бы из-за пропущенной проверки.
      if (radiusKm != null && originLat != null && originLng != null) {
        if (distKm == null) continue;
        if (distKm > radiusKm) continue;
      }

      out.add(ExecutorCardListItem(
        userId: uid,
        name: (p['name'] as String?) ?? 'Пользователь',
        avatarUrl: p['avatar_url'] as String?,
        ratingAsExecutor: _toDouble(p['rating_as_executor']) ?? 0,
        reviewCountAsExecutor:
            (p['review_count_as_executor'] as int?) ?? 0,
        legalStatus: p['legal_status'] as String?,
        experienceYears: p['experience_years'] as int?,
        about: p['about'] as String?,
        locationAddress: c['location_address'] as String?,
        locationLat: cardLat,
        locationLng: cardLng,
        radiusKm: c['radius_km'] as int?,
        machineryTitles: machineryIdsInCatalogOrder(agg.machineryIds)
            .map((int id) => _machineryIdToTitle[id] ?? '')
            .where((String t) => t.isNotEmpty)
            .toList(),
        categoryTitles: agg.categoryIds
            .map((int id) => _categoryIdToTitle[id] ?? '')
            .where((String t) => t.isNotEmpty)
            .toList(),
        minPricePerHour: cardMinHour,
        minPricePerDay: cardMinDay,
        matchingServices: matching,
        distanceKm: distKm,
      ));
    }
    sortByProximityThenRating(out);
    return out;
  }

  /// Порядок каталога по умолчанию. До этого список наследовал порядок
  /// запроса — `updated_at DESC` карточки, т.е. «кто позже редактировал
  /// профиль, тот выше»: для пользователя это выглядело случайной
  /// перетасовкой (находка тестировщицы).
  ///
  /// Теперь два уровня:
  ///   1. Зона удалённости шагом 10 км (когда расстояние известно): среди
  ///      ближних — лучшие, потом среди подальше — лучшие. Чистое «по
  ///      километрам» ставило бы исполнителя 2,0 в километре выше отличника
  ///      в пяти — для спецтехники это неправильный размен. Карточки без
  ///      расстояния (нет GPS/адреса или координат карточки) — в конец.
  ///   2. Внутри зоны: выше рейтинг → при равном рейтинге больше отзывов
  ///      (4,6 по 50 отзывам надёжнее, чем 4,6 по одному) → имя → id
  ///      (детерминированный хвост, чтобы порядок не прыгал между
  ///      перерисовками).
  ///
  /// Выбранная в фильтре сортировка «сначала дешевле» применяется ПОВЕРХ
  /// дальше по конвейеру (applyPriceFilterAndSort) и переопределяет это.
  /// Статическая чистая функция — покрыта юнит-тестами.
  static void sortByProximityThenRating(List<ExecutorCardListItem> items) {
    int zone(ExecutorCardListItem e) =>
        e.distanceKm == null ? 1 << 30 : (e.distanceKm! / 10).floor();
    items.sort((ExecutorCardListItem a, ExecutorCardListItem b) {
      final int z = zone(a).compareTo(zone(b));
      if (z != 0) return z;
      final int r = b.ratingAsExecutor.compareTo(a.ratingAsExecutor);
      if (r != 0) return r;
      final int c = b.reviewCountAsExecutor.compareTo(a.reviewCountAsExecutor);
      if (c != 0) return c;
      final int n = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (n != 0) return n;
      return a.userId.compareTo(b.userId);
    });
  }

  /// Возвращает множество `user_id`, у которых на интервале
  /// `[dateFrom..dateTo]` расписание конфликтует с запрошенным временем.
  /// Если для дня нет override — считаем, что исполнитель доступен.
  /// Конфликт = override.accepting=false ИЛИ
  /// (заказ wholeDay=true, override.whole_day=false) ИЛИ
  /// (заданы timeFrom/timeTo, override не whole_day и время не покрывает запрос).
  Future<Set<String>> _findUnavailableExecutors({
    required List<String> userIds,
    required DateTime dateFrom,
    required DateTime dateTo,
    String? timeFrom,
    String? timeTo,
    required bool wholeDay,
  }) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('schedule_day_overrides')
        .select('user_id, day, accepting, whole_day, time_from, time_to')
        .inFilter('user_id', userIds)
        .gte('day', _isoDate(dateFrom))
        .lte('day', _isoDate(dateTo));

    final Set<String> excluded = <String>{};
    for (final Map<String, dynamic> r in rows) {
      final String uid = r['user_id'] as String;
      if (excluded.contains(uid)) continue;
      final bool accepting = (r['accepting'] as bool?) ?? true;
      if (!accepting) {
        excluded.add(uid);
        continue;
      }
      final bool overrideWholeDay = (r['whole_day'] as bool?) ?? false;
      if (wholeDay && !overrideWholeDay) {
        excluded.add(uid);
        continue;
      }
      if (!wholeDay && timeFrom != null && timeTo != null) {
        if (overrideWholeDay) continue; // полностью покрывает
        final String? oFrom = _trimTime(r['time_from'] as String?);
        final String? oTo = _trimTime(r['time_to'] as String?);
        if (oFrom == null ||
            oTo == null ||
            timeFrom.compareTo(oFrom) < 0 ||
            timeTo.compareTo(oTo) > 0) {
          excluded.add(uid);
        }
      }
    }
    return excluded;
  }

  /// Прямой SELECT по `user_id` + агрегация услуг этого исполнителя.
  /// Раньше делал `listPublishedExecutors(limit:100)` и линейный поиск
  /// — для исполнителей за пределами топ-100 возвращал null, хотя
  /// карточка существует и опубликована.
  Future<ExecutorCardListItem?> getExecutorById(String userId) async {
    await _primeDirectories();

    final Map<String, dynamic>? card = await _client
        .from('executor_cards')
        .select(
          'user_id, location_address, location_lat, location_lng, '
          'radius_km, '
          'profile:profiles!executor_cards_user_id_fkey('
          'id, name, avatar_url, legal_status, experience_years, about, '
          'rating_as_executor, review_count_as_executor, '
          'verification_status, blocked_until)',
        )
        .eq('user_id', userId)
        .eq('is_published', true)
        .maybeSingle();
    if (card == null) return null;
    final Map<String, dynamic>? prof =
        card['profile'] as Map<String, dynamic>?;
    if (prof == null) return null;
    if ((prof['verification_status'] as String?) != 'approved') return null;
    final String? blockedRaw = prof['blocked_until'] as String?;
    if (blockedRaw != null) {
      final DateTime? until = DateTime.tryParse(blockedRaw);
      if (until != null && until.isAfter(DateTime.now().toUtc())) return null;
    }

    final List<Map<String, dynamic>> services = await _client
        .from('services')
        .select(
          'machinery_ids, category_ids, '
          'price_per_hour, price_per_day, min_hours',
        )
        .eq('executor_id', userId)
        .eq('is_paid', true)
        .eq('is_archived', false);

    final _ExecAggregate agg = _ExecAggregate();
    for (final Map<String, dynamic> s in services) {
      final List<int> mIds = List<int>.from(s['machinery_ids'] as List);
      final List<int> cIds = List<int>.from(s['category_ids'] as List);
      final double? pricePerHour = _toDouble(s['price_per_hour']);
      final double? pricePerDay = _toDouble(s['price_per_day']);
      agg.addMachinery(mIds);
      agg.addCategory(cIds);
      agg.minPriceHour = _min(agg.minPriceHour, pricePerHour);
      agg.minPriceDay = _min(agg.minPriceDay, pricePerDay);
      agg.services.add(_ServiceRow(
        machineryIds: mIds,
        pricePerHour: pricePerHour,
        pricePerDay: pricePerDay,
        minHours: s['min_hours'] as int?,
      ));
    }

    final Map<String, dynamic> p = card['profile'] as Map<String, dynamic>;
    return ExecutorCardListItem(
      userId: userId,
      name: (p['name'] as String?) ?? 'Пользователь',
      avatarUrl: p['avatar_url'] as String?,
      ratingAsExecutor: _toDouble(p['rating_as_executor']) ?? 0,
      reviewCountAsExecutor: (p['review_count_as_executor'] as int?) ?? 0,
      legalStatus: p['legal_status'] as String?,
      experienceYears: p['experience_years'] as int?,
      about: p['about'] as String?,
      locationAddress: card['location_address'] as String?,
      locationLat: (card['location_lat'] as num?)?.toDouble(),
      locationLng: (card['location_lng'] as num?)?.toDouble(),
      radiusKm: card['radius_km'] as int?,
      machineryTitles: machineryIdsInCatalogOrder(agg.machineryIds)
          .map((int id) => _machineryIdToTitle[id] ?? '')
          .where((String t) => t.isNotEmpty)
          .toList(),
      categoryTitles: agg.categoryIds
          .map((int id) => _categoryIdToTitle[id] ?? '')
          .where((String t) => t.isNotEmpty)
          .toList(),
      minPricePerHour: agg.minPriceHour,
      minPricePerDay: agg.minPriceDay,
    );
  }

  /// Полная карточка исполнителя: summary + услуги + расписание.
  /// Делает 3 параллельных запроса. Если карточка не опубликована или
  /// исполнитель не найден — возвращает null.
  Future<ExecutorCardFull?> getExecutorFull(String userId) async {
    await _primeDirectories();

    final ExecutorCardListItem? summary = await getExecutorById(userId);
    if (summary == null) return null;

    final List<List<Map<String, dynamic>>> results =
        await Future.wait<List<Map<String, dynamic>>>(<Future<List<Map<String, dynamic>>>>[
      _client
          .from('services')
          .select(
            'id, title, description, machinery_ids, category_ids, '
            'price_per_hour, price_per_day, min_hours, photos',
          )
          .eq('executor_id', userId)
          .eq('is_paid', true)
          .eq('is_archived', false)
          .order('updated_at', ascending: false),
      _client
          .from('schedule_day_overrides')
          .select(
            'day, accepting, whole_day, time_from, time_to, '
            'machinery_ids, radius_km',
          )
          .eq('user_id', userId),
    ]);

    final List<ExecutorService> services = results[0]
        .map<ExecutorService>(_executorServiceFromRow)
        .toList();

    final Map<DateTime, ExecutorScheduleDay> schedule =
        <DateTime, ExecutorScheduleDay>{};
    for (final Map<String, dynamic> r in results[1]) {
      final ExecutorScheduleDay day = _scheduleDayFromRow(r);
      schedule[day.day] = day;
    }

    return ExecutorCardFull(
      summary: summary,
      services: services,
      scheduleOverrides: schedule,
    );
  }

  ExecutorService _executorServiceFromRow(Map<String, dynamic> r) {
    final List<int> mIds = List<int>.from((r['machinery_ids'] as List?) ?? const <dynamic>[]);
    final List<int> cIds = List<int>.from((r['category_ids'] as List?) ?? const <dynamic>[]);
    final List<String> photos = List<String>.from(
      (r['photos'] as List?) ?? const <String>[],
    );
    return ExecutorService(
      id: r['id'] as String,
      title: (r['title'] as String?) ?? '',
      description: r['description'] as String?,
      machineryTitles: machineryIdsInCatalogOrder(mIds)
          .map((int id) => _machineryIdToTitle[id] ?? '')
          .where((String t) => t.isNotEmpty)
          .toList(),
      categoryTitles: cIds
          .map((int id) => _categoryIdToTitle[id] ?? '')
          .where((String t) => t.isNotEmpty)
          .toList(),
      pricePerHour: _toDouble(r['price_per_hour']),
      pricePerDay: _toDouble(r['price_per_day']),
      minHours: r['min_hours'] as int?,
      photos: photos,
    );
  }

  ExecutorScheduleDay _scheduleDayFromRow(Map<String, dynamic> r) {
    final List<int> mIds = List<int>.from(
        (r['machinery_ids'] as List?) ?? const <int>[]);
    final DateTime day = DateTime.parse(r['day'] as String).toLocal();
    return ExecutorScheduleDay(
      day: DateTime(day.year, day.month, day.day),
      accepting: (r['accepting'] as bool?) ?? true,
      wholeDay: (r['whole_day'] as bool?) ?? false,
      timeFrom: _trimTime(r['time_from'] as String?),
      timeTo: _trimTime(r['time_to'] as String?),
      machineryTitles: machineryIdsInCatalogOrder(mIds)
          .map((int id) => _machineryIdToTitle[id] ?? '')
          .where((String t) => t.isNotEmpty)
          .toList(),
      radiusKm: r['radius_km'] as int?,
    );
  }

  /// Postgres `time` отдаёт `HH:MM:SS`; UI хочет `HH:MM`.
  String? _trimTime(String? t) {
    if (t == null) return null;
    if (t.length >= 5) return t.substring(0, 5);
    return t;
  }

  double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static double? _min(double? a, double? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a < b ? a : b;
  }

  /// Локальный фильтр по максимальной цене + сортировка по возрастанию
  /// минимальной цены за час. Общий для ленты исполнителей и для поиска на
  /// экране категорий, чтобы фильтр цены вёл себя одинаково везде (раньше
  /// поиск по категориям цену вообще игнорировал). Чистая функция — покрыта
  /// юнит-тестами.
  static List<ExecutorCardListItem> applyPriceFilterAndSort(
    List<ExecutorCardListItem> input, {
    int? maxPricePerHour,
    int? maxPricePerDay,
    bool sortByPriceAsc = false,
  }) {
    Iterable<ExecutorCardListItem> res = input;
    if (maxPricePerHour != null) {
      res = res.where((ExecutorCardListItem e) =>
          e.minPricePerHour != null && e.minPricePerHour! <= maxPricePerHour);
    }
    if (maxPricePerDay != null) {
      res = res.where((ExecutorCardListItem e) =>
          e.minPricePerDay != null && e.minPricePerDay! <= maxPricePerDay);
    }
    final List<ExecutorCardListItem> out = res.toList();
    if (sortByPriceAsc) {
      out.sort(_comparePriceAsc);
    }
    return out;
  }

  /// Компаратор «по возрастанию цены» — устойчивый и согласованный с тем,
  /// что видно на карточке.
  ///
  ///   1. Группа по доступной ставке: сперва те, у кого есть ПОЧАСОВАЯ цена,
  ///      затем те, у кого ТОЛЬКО ПОСУТОЧНАЯ, затем «цена по запросу».
  ///      Часовую и дневную ставку нельзя сравнивать напрямую (разные
  ///      единицы), поэтому не мешаем их в один ряд, а разводим по группам —
  ///      иначе «5000 ₽/час» и «8000 ₽/день» встали бы в произвольном порядке.
  ///   2. Внутри группы — по самой цене, по возрастанию.
  ///   3. При равной цене — детерминированный тай-брейк: выше рейтинг, затем
  ///      имя по алфавиту, затем id. Без него порядок одинаково-ценовых
  ///      карточек «прыгал» бы между перерисовками (List.sort нестабилен).
  static int _comparePriceAsc(ExecutorCardListItem a, ExecutorCardListItem b) {
    final int ga = _priceGroup(a);
    final int gb = _priceGroup(b);
    if (ga != gb) return ga.compareTo(gb);
    if (ga == 0) {
      final int c = a.minPricePerHour!.compareTo(b.minPricePerHour!);
      if (c != 0) return c;
    } else if (ga == 1) {
      final int c = a.minPricePerDay!.compareTo(b.minPricePerDay!);
      if (c != 0) return c;
    }
    final int r = b.ratingAsExecutor.compareTo(a.ratingAsExecutor);
    if (r != 0) return r;
    final int n = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (n != 0) return n;
    return a.userId.compareTo(b.userId);
  }

  /// 0 — есть почасовая ставка, 1 — только посуточная, 2 — цены нет вовсе.
  static int _priceGroup(ExecutorCardListItem e) {
    if (e.minPricePerHour != null && e.minPricePerHour! > 0) return 0;
    if (e.minPricePerDay != null && e.minPricePerDay! > 0) return 1;
    return 2;
  }

  // ---------------------------------------------------------------
  // Карточка заказчика
  // ---------------------------------------------------------------

  Future<CustomerProfile?> getCustomer(String userId) async {
    final Map<String, dynamic>? r = await _client
        .from('profiles')
        .select(
          'id, name, avatar_url, legal_status, about, '
          'rating_as_customer, review_count_as_customer',
        )
        .eq('id', userId)
        .maybeSingle();
    if (r == null) return null;
    return CustomerProfile.fromRow(r);
  }

  /// Заказы конкретного заказчика — для списка на его карточке.
  /// По умолчанию только `published` (чтобы не утекали черновики/архив).
  Future<List<OrderListItem>> listCustomerOrders(String userId,
      {int limit = 100}) async {
    await _primeDirectories();
    final List<Map<String, dynamic>> rows = await _client
        .from('orders')
        .select(
          'id, display_number, title, address, date_from, date_to, '
          'time_from, time_to, exact_date, whole_day, machinery_ids, '
          'published_at, '
          'customer:profiles!orders_customer_id_fkey('
          'id, name, avatar_url, rating_as_customer, review_count_as_customer)',
        )
        .eq('customer_id', userId)
        .eq('status', 'published')
        .order('published_at', ascending: false)
        .limit(limit);
    return rows.map(_orderListItemFromRow).toList();
  }

  /// Последние отзывы о заказчике (subject='customer').
  Future<List<ReviewItem>> listCustomerReviews(String userId,
      {int limit = 20}) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('reviews')
        .select(
          'id, rating, text, created_at, '
          'author:profiles!reviews_author_id_fkey(name)',
        )
        .eq('target_id', userId)
        .eq('subject', 'customer')
        .eq('is_hidden', false)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(ReviewItem.fromRow).toList();
  }

  // ---------------------------------------------------------------
  // Отклик на заказ
  // ---------------------------------------------------------------

  /// Мои активные (`is_archived=false`, `is_paid=true`) услуги — маппинг
  /// названия техники → id услуги. Нужно для отклика: по выбранной технике
  /// находим service_id, который уйдёт в `order_matches`.
  Future<Map<String, String>> listMyActiveServicesByMachinery() async {
    await _primeDirectories();
    final User? user = _client.auth.currentUser;
    if (user == null) return <String, String>{};
    final List<Map<String, dynamic>> rows = await _client
        .from('services')
        .select('id, machinery_ids')
        .eq('executor_id', user.id)
        .eq('is_archived', false)
        .eq('is_paid', true);
    final Map<String, String> out = <String, String>{};
    for (final Map<String, dynamic> r in rows) {
      final List<int> ids = List<int>.from(r['machinery_ids'] as List);
      if (ids.isEmpty) continue;
      final String? title = _machineryIdToTitle[ids.first];
      if (title != null) out[title] = r['id'] as String;
    }
    return out;
  }

  /// Есть ли у меня активный (не терминальный) отклик на этот заказ.
  /// Используется, чтобы на экране заказа кнопка сразу стала "Вы уже
  /// откликнулись".
  Future<bool> hasActiveMatchForOrder(String orderId) async {
    final User? user = _client.auth.currentUser;
    if (user == null) return false;
    final Map<String, dynamic>? row = await _client
        .from('order_matches')
        .select('id')
        .eq('order_id', orderId)
        .eq('executor_id', user.id)
        .not(
          'status',
          'in',
          '(completed,rejected_by_customer,rejected_by_executor,expired)',
        )
        .maybeSingle();
    return row != null;
  }

  /// INSERT в `order_matches` (initiated_by='executor', status='awaiting_customer').
  /// Цена автоматически снапшотится триггером из `services(service_id)`.
  /// Возвращает id созданного мэтча.
  Future<String> respondToOrder({
    required String orderId,
    required String serviceId,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Нет активной сессии');
    }
    final Map<String, dynamic> row = await _client
        .from('order_matches')
        .insert(<String, dynamic>{
          'order_id': orderId,
          'executor_id': user.id,
          'service_id': serviceId,
          'initiated_by': 'executor',
          'status': 'awaiting_customer',
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Экранирует wildcard-метасимволы LIKE/ILIKE в пользовательском вводе.
  /// Без этого поиск «50%» матчит любые строки с «50», «и_ан» — «иван»/«иган»/«итан».
  /// Бэкслеш экранируется первым, иначе мы добавим обратные слеши и удвоим их.
  static String _escapeLike(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}
