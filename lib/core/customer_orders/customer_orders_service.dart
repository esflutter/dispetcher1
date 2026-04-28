import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dispatcher_1/core/catalog/catalog_service.dart';
import 'package:dispatcher_1/core/catalog/models.dart';
import 'package:dispatcher_1/core/storage/storage_service.dart';

import 'models.dart';

/// Результат публикации заказа: id новой записи + сколько фото из
/// заявленных реально залилось в Storage. UI показывает снэкбар, если
/// `photosUploaded < photosTotal`.
class CreateOrderResult {
  const CreateOrderResult({
    required this.id,
    required this.photosUploaded,
    required this.photosTotal,
  });

  final String id;
  final int photosUploaded;
  final int photosTotal;

  bool get hasPhotoFailures => photosUploaded < photosTotal;
  int get photosFailed => photosTotal - photosUploaded;
}

/// Заказы, созданные текущим заказчиком (`orders.customer_id = me`),
/// и входящие отклики исполнителей на них (`order_matches`).
class CustomerOrdersService {
  CustomerOrdersService._();
  static final CustomerOrdersService instance = CustomerOrdersService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// INSERT в `public.orders` + загрузка фото + публикация одним актом.
  /// Возвращает [CreateOrderResult]: id заказа и инфо о том, сколько
  /// фото из ожидаемых реально залилось.
  ///
  /// Поток специально draft → upload → published, чтобы исполнители не
  /// видели заказ в каталоге, пока к нему не подтянутся фото:
  ///
  /// 1. INSERT со `status='draft'` (заказ в БД есть, но в `listPublishedOrders`
  ///    не выбирается — фильтр `is_published`).
  /// 2. Заливаем фото в `order-photos/<user_id>/<order_id>/...` —
  ///    путь обязан содержать `order_id` из-за RLS-политики чтения.
  /// 3. UPDATE одним запросом: `photos = uploaded` + `status='published'`.
  ///    Триггер `set_published_at` поставит `published_at=now()` на
  ///    переходе в `published`.
  ///
  /// Если все фото не залились — заказ всё равно публикуем (оставлять его
  /// застрявшим в `draft` без UI-управления черновиками было бы хуже).
  /// UI вызывающего экрана узнаёт о частичной потере по
  /// [CreateOrderResult.photosUploaded] / [CreateOrderResult.photosTotal]
  /// и показывает снэкбар.
  Future<CreateOrderResult> createOrder(
    OrderDraft d, {
    bool publishNow = true,
    List<File> photoFiles = const <File>[],
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Нет активной сессии');
    }
    final List<MachineryRef> machinery =
        await CatalogService.instance.listActiveMachinery();
    final List<CategoryRef> categories =
        await CatalogService.instance.listActiveCategories();

    final Map<String, int> mById = <String, int>{
      for (final MachineryRef m in machinery) m.title: m.id,
    };
    final Map<String, int> cById = <String, int>{
      for (final CategoryRef c in categories) c.title: c.id,
    };

    final List<int> machineryIds = d.machineryTitles
        .map((String t) => mById[t])
        .whereType<int>()
        .toList();
    final List<int> categoryIds = d.categoryTitles
        .map((String t) => cById[t])
        .whereType<int>()
        .toList();

    // Если пользователь ввёл адрес вручную (не выбрал из подсказок DaData)
    // или DaData вернул адрес без координат — детерминированно вычисляем
    // координаты из хэша адреса, чтобы заказ всё равно появился на карте
    // у исполнителей. Один и тот же адрес → одна и та же точка
    // (без «прыжков» между сессиями).
    final ({double lat, double lng}) coords =
        (d.latitude != null && d.longitude != null)
            ? (lat: d.latitude!, lng: d.longitude!)
            : _stableMoscowCoordsForAddress(d.address);

    final Map<String, dynamic> payload = <String, dynamic>{
      'customer_id': user.id,
      'title': d.title,
      'description': d.description,
      'category_ids': categoryIds,
      'machinery_ids': machineryIds,
      'works': d.works.map((WorkDraft w) => w.toJson()).toList(),
      'photos': const <String>[],
      'address': d.address,
      'latitude': coords.lat,
      'longitude': coords.lng,
      'date_from': _dateIso(d.dateFrom),
      'date_to': d.dateTo == null ? null : _dateIso(d.dateTo!),
      'exact_date': d.exactDate,
      'time_from': d.timeFrom == null ? null : '${d.timeFrom!}:00',
      'time_to': d.timeTo == null ? null : '${d.timeTo!}:00',
      'whole_day': d.wholeDay,
      // Намеренно draft, даже если publishNow=true: финальный статус
      // переключим в UPDATE ниже, после того как фото загрузятся.
      'status': 'draft',
    };

    final Map<String, dynamic> row = await _client
        .from('orders')
        .insert(payload)
        .select('id')
        .single();
    final String orderId = row['id'] as String;

    final List<String> uploaded = <String>[];
    for (final File f in photoFiles) {
      try {
        final String path = await StorageService.instance
            .uploadOrderPhoto(f, orderId: orderId);
        uploaded.add(path);
      } catch (_) {
        // Конкретное фото не залилось — пропускаем; остальные пробуем.
        // UI узнает о потере по photosUploaded < photosTotal.
      }
    }

    final Map<String, dynamic> finalize = <String, dynamic>{
      'photos': uploaded,
      if (publishNow) 'status': 'published',
    };
    await _client
        .from('orders')
        .update(finalize)
        .eq('id', orderId);

    return CreateOrderResult(
      id: orderId,
      photosUploaded: uploaded.length,
      photosTotal: photoFiles.length,
    );
  }

  /// Свои заказы + счётчик активных (не-терминальных) откликов.
  /// Счётчик считается на клиенте через отдельный запрос — PostgREST
  /// считает всегда-из-одного-места дорого, но для экрана "Мои заказы"
  /// это один список в несколько десятков строк.
  Future<List<CustomerOrderListItem>> listMine({int limit = 100}) async {
    final User? user = _client.auth.currentUser;
    if (user == null) return <CustomerOrderListItem>[];

    await CatalogService.instance.listActiveMachinery();
    await CatalogService.instance.listActiveCategories();

    final List<Map<String, dynamic>> rows = await _client
        .from('orders')
        .select(
          'id, display_number, title, description, address, '
          'date_from, date_to, time_from, time_to, exact_date, whole_day, '
          'machinery_ids, category_ids, works, photos, '
          'published_at, created_at, status',
        )
        .eq('customer_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);

    if (rows.isEmpty) return <CustomerOrderListItem>[];

    final Map<int, String> machineryById = <int, String>{
      for (final MachineryRef m
          in CatalogService.instance.cachedMachinery ??
              const <MachineryRef>[])
        m.id: m.title,
    };
    final Map<int, String> categoryById = <int, String>{
      for (final CategoryRef c
          in CatalogService.instance.cachedCategories ??
              const <CategoryRef>[])
        c.id: c.title,
    };

    // По всем заказам одним запросом тянем мэтчи с инфой об исполнителе —
    // отсюда и счётчик активных откликов, и «лучший» статус для маппинга
    // в UI-вкладку (waiting/waitingChoose/accepted/completed/...).
    final List<String> ids = rows.map((r) => r['id'] as String).toList();
    final Map<String, int> activeCounts = <String, int>{
      for (final String id in ids) id: 0,
    };
    final Map<String, _BestMatch> bestByOrder = <String, _BestMatch>{};
    final List<Map<String, dynamic>> matchRows = await _client
        .from('order_matches')
        .select(
          'id, order_id, status, '
          'executor:profiles!order_matches_executor_id_fkey('
          'id, name, rating_as_executor, review_count_as_executor)',
        )
        .inFilter('order_id', ids);
    for (final Map<String, dynamic> m in matchRows) {
      final String orderId = m['order_id'] as String;
      final String mStatus = m['status'] as String;
      // Активные = всё, кроме терминальных. Считаем для счётчика откликов
      // (он показывается на статусе "Выберите исполнителя (N)").
      const Set<String> terminal = <String>{
        'completed',
        'rejected_by_customer',
        'rejected_by_executor',
        'expired',
      };
      if (!terminal.contains(mStatus)) {
        activeCounts[orderId] = (activeCounts[orderId] ?? 0) + 1;
      }
      final int rank = _matchPriority(mStatus);
      final _BestMatch? prev = bestByOrder[orderId];
      if (prev == null || rank > prev.rank) {
        final Map<String, dynamic>? executor =
            m['executor'] as Map<String, dynamic>?;
        bestByOrder[orderId] = _BestMatch(
          rank: rank,
          matchId: m['id'] as String,
          status: mStatus,
          executorId: executor?['id'] as String?,
          executorName: executor?['name'] as String?,
          executorRating: _toDouble(executor?['rating_as_executor']) ?? 0,
          executorReviewCount:
              (executor?['review_count_as_executor'] as int?) ?? 0,
        );
      }
    }

    // Какие best-мэтчи уже получили отзыв от этого заказчика — нужно,
    // чтобы UI не показывал «Оставить отзыв» дважды (после рестарта
    // локальный `reviewLeft`-флаг терялся и кнопка возвращалась).
    final List<String> bestMatchIds = <String>[
      for (final _BestMatch b in bestByOrder.values) b.matchId,
    ];
    final Set<String> reviewedMatchIds = <String>{};
    if (bestMatchIds.isNotEmpty) {
      try {
        final List<Map<String, dynamic>> rev = await _client
            .from('reviews')
            .select('match_id')
            .eq('author_id', user.id)
            .inFilter('match_id', bestMatchIds);
        for (final Map<String, dynamic> r in rev) {
          final String? mid = r['match_id'] as String?;
          if (mid != null) reviewedMatchIds.add(mid);
        }
      } catch (_) {/* silent — на ошибке UI просто покажет кнопку */}
    }

    return rows.map((Map<String, dynamic> r) {
      final List<int> mIds = List<int>.from(r['machinery_ids'] as List);
      final List<int> cIds =
          List<int>.from((r['category_ids'] as List?) ?? const <dynamic>[]);
      final DateTime published = r['published_at'] == null
          ? DateTime.parse(r['created_at'] as String)
          : DateTime.parse(r['published_at'] as String);
      final _BestMatch? best = bestByOrder[r['id']];
      final List<dynamic>? worksRaw = r['works'] as List<dynamic>?;
      final List<String> worksList = worksRaw == null
          ? const <String>[]
          : worksRaw
              .map((dynamic w) => _formatWorkLine(w as Map<String, dynamic>))
              .where((String s) => s.isNotEmpty)
              .toList();
      final List<dynamic>? photosRaw = r['photos'] as List<dynamic>?;
      final List<String> photos = photosRaw == null
          ? const <String>[]
          : photosRaw.map((dynamic p) => p as String).toList();
      return CustomerOrderListItem(
        id: r['id'] as String,
        displayNumber: r['display_number'] as int,
        title: r['title'] as String,
        description: (r['description'] as String?) ?? '',
        address: r['address'] as String,
        dateFrom: DateTime.parse(r['date_from'] as String),
        dateTo: r['date_to'] == null
            ? null
            : DateTime.parse(r['date_to'] as String),
        timeFrom: r['time_from'] as String?,
        timeTo: r['time_to'] as String?,
        exactDate: r['exact_date'] as bool,
        wholeDay: r['whole_day'] as bool,
        machineryTitles: mIds
            .map((int id) => machineryById[id] ?? '')
            .where((String t) => t.isNotEmpty)
            .toList(),
        categoryTitles: cIds
            .map((int id) => categoryById[id] ?? '')
            .where((String t) => t.isNotEmpty)
            .toList(),
        reviewLeft: best != null && reviewedMatchIds.contains(best.matchId),
        works: worksList,
        photos: photos,
        publishedAt: published,
        status: r['status'] as String,
        respondersCount: activeCounts[r['id']] ?? 0,
        bestMatchId: best?.matchId,
        bestMatchStatus: best?.status,
        bestMatchExecutorId: best?.executorId,
        bestMatchExecutorName: best?.executorName,
        bestMatchExecutorRating: best?.executorRating ?? 0,
        bestMatchExecutorReviewCount: best?.executorReviewCount ?? 0,
      );
    }).toList();
  }

  /// Превращает один элемент `orders.works` (`{name, volume?, unit?}`)
  /// в строку для отображения. Юниты из БД хранятся как ASCII (`m`/`m2`/
  /// `m3`), на UI показываем кириллические эквиваленты.
  static String _formatWorkLine(Map<String, dynamic> w) {
    final String name = (w['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return '';
    final num? volume = w['volume'] as num?;
    final String? unit = w['unit'] as String?;
    if (volume == null) return name;
    final String unitUi = switch (unit) {
      'm' => 'м',
      'm2' => 'м²',
      'm3' => 'м³',
      _ => '',
    };
    final String volStr = volume == volume.toInt()
        ? volume.toInt().toString()
        : volume.toString();
    return '$name — $volStr $unitUi'.trim();
  }

  // Чем больше число — тем «важнее» статус для UI-вкладки.
  // completed (заказ выполнен) > accepted (в работе) > awaiting_executor
  // (ждёт подтверждения) > awaiting_customer (есть отклики) > terminal-rejected.
  static int _matchPriority(String status) {
    switch (status) {
      case 'completed':
        return 5;
      case 'accepted':
        return 4;
      case 'awaiting_executor':
        return 3;
      case 'awaiting_customer':
        return 2;
      case 'rejected_by_executor':
        return 1;
      default:
        return 0;
    }
  }

  /// Отклики на конкретный заказ.
  Future<List<IncomingResponse>> listResponsesForOrder(String orderId) async {
    await CatalogService.instance.listActiveMachinery();
    final List<Map<String, dynamic>> rows = await _client
        .from('order_matches')
        .select(
          'id, status, created_at, '
          'agreed_price_per_hour, agreed_price_per_day, agreed_min_hours, '
          'executor:profiles!order_matches_executor_id_fkey('
          'id, name, avatar_url, rating_as_executor, review_count_as_executor), '
          'service:services!order_matches_service_id_fkey(id, machinery_ids)',
        )
        .eq('order_id', orderId)
        .order('created_at', ascending: false);

    final Map<int, String> machineryById = <int, String>{
      for (final MachineryRef m
          in CatalogService.instance.cachedMachinery ??
              const <MachineryRef>[])
        m.id: m.title,
    };

    return rows.map((Map<String, dynamic> r) {
      final Map<String, dynamic>? executor =
          r['executor'] as Map<String, dynamic>?;
      final Map<String, dynamic>? service =
          r['service'] as Map<String, dynamic>?;
      final List<int> machineryIds = service == null
          ? const <int>[]
          : List<int>.from(service['machinery_ids'] as List);
      return IncomingResponse(
        matchId: r['id'] as String,
        status: r['status'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
        agreedPricePerHour: _toDouble(r['agreed_price_per_hour']),
        agreedPricePerDay: _toDouble(r['agreed_price_per_day']),
        agreedMinHours: r['agreed_min_hours'] as int?,
        executorId: (executor?['id'] as String?) ?? '',
        executorName: (executor?['name'] as String?) ?? 'Пользователь',
        executorAvatarUrl: executor?['avatar_url'] as String?,
        executorRating: _toDouble(executor?['rating_as_executor']) ?? 0,
        executorReviewCount:
            (executor?['review_count_as_executor'] as int?) ?? 0,
        serviceId: service?['id'] as String?,
        serviceMachineryTitles: machineryIds
            .map((int id) => machineryById[id] ?? '')
            .where((String t) => t.isNotEmpty)
            .toList(),
      );
    }).toList();
  }

  /// Выбор конкретного отклика: `awaiting_customer` → `awaiting_executor`.
  /// Остальные отклики на тот же заказ триггер БД автоматически не
  /// закрывает — клиент может это сделать отдельным UPDATE либо
  /// дождаться, пока исполнитель подтвердит.
  ///
  /// `.select().single()` обязательная: если строка не нашлась
  /// (RLS отказал, мэтч удалён, или его статус уже терминальный
  /// и FSM-триггер откатил UPDATE) — `single()` бросит исключение,
  /// и UI не «съест» молчаливый no-op.
  Future<void> proposeToExecutor(String matchId) async {
    await _client
        .from('order_matches')
        .update(<String, dynamic>{'status': 'awaiting_executor'})
        .eq('id', matchId)
        .select('id')
        .single();
  }

  /// Заказчик отклонил отклик (`awaiting_customer` → `rejected_by_customer`).
  Future<void> rejectResponse(String matchId) async {
    await _client
        .from('order_matches')
        .update(<String, dynamic>{'status': 'rejected_by_customer'})
        .eq('id', matchId)
        .select('id')
        .single();
  }

  /// Предложить заказ конкретному исполнителю из каталога.
  /// INSERT в `order_matches` с `initiated_by='customer'`, status
  /// сразу `awaiting_executor` (заказчик уже выбрал, ждём подтверждения
  /// исполнителя). Триггер `snapshot_match_price` зафиксирует цену
  /// услуги, которую мы подобрали по совпадению техники с заказом.
  /// Возвращает id созданного мэтча.
  ///
  /// Бросает [Exception], если у исполнителя нет ни одной услуги,
  /// которая покрывает требуемую в заказе технику.
  Future<({String matchId, String serviceId})> proposeOrderToExecutor({
    required String orderId,
    required String executorId,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Нет активной сессии');
    }
    final Map<String, dynamic>? order = await _client
        .from('orders')
        .select('machinery_ids')
        .eq('id', orderId)
        .eq('customer_id', user.id)
        .maybeSingle();
    if (order == null) {
      throw Exception('Заказ не найден');
    }
    final List<int> orderMachinery =
        List<int>.from(order['machinery_ids'] as List);

    final List<Map<String, dynamic>> services = await _client
        .from('services')
        .select('id, machinery_ids')
        .eq('executor_id', executorId)
        .eq('is_paid', true)
        .eq('is_archived', false);
    String? serviceId;
    for (final Map<String, dynamic> s in services) {
      final List<int> m = List<int>.from(s['machinery_ids'] as List);
      if (m.any(orderMachinery.contains)) {
        serviceId = s['id'] as String;
        break;
      }
    }
    if (serviceId == null) {
      throw Exception('У исполнителя нет услуги под технику этого заказа');
    }

    final Map<String, dynamic> row = await _client
        .from('order_matches')
        .insert(<String, dynamic>{
          'order_id': orderId,
          'executor_id': executorId,
          'service_id': serviceId,
          'initiated_by': 'customer',
          'status': 'awaiting_executor',
        })
        .select('id')
        .single();
    return (matchId: row['id'] as String, serviceId: serviceId);
  }

  /// Снять заказ с публикации (status → `cancelled`). RLS-политика
  /// уже проверяет владельца, но `.eq('customer_id', user.id)` дублирует
  /// её на стороне клиента — defense-in-depth: если RLS однажды
  /// сломается миграцией, без этой проверки любой авторизованный
  /// пользователь смог бы отменить чужой заказ, отправив orderId.
  Future<void> cancelOrder(String orderId) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Нет активной сессии');
    }
    await _client
        .from('orders')
        .update(<String, dynamic>{'status': 'cancelled'})
        .eq('id', orderId)
        .eq('customer_id', user.id);
  }

  /// Опубликовать заново ранее отменённый заказ (cancelled → published).
  /// Триггер `set_published_at` обновит `published_at=now()`. Тоже с
  /// явной фильтрацией по `customer_id` (см. [cancelOrder]).
  Future<void> republishOrder(String orderId) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Нет активной сессии');
    }
    await _client
        .from('orders')
        .update(<String, dynamic>{'status': 'published'})
        .eq('id', orderId)
        .eq('customer_id', user.id);
  }

  /// Контакты исполнителя (телефон/email) — доступны только после
  /// `accepted`/`completed` через RLS-политику на `profiles_private`.
  /// Возвращает `null`, если RLS не пустила (статус ещё не accepted).
  Future<({String? phone, String? email})?> getExecutorContacts(
      String executorId) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('profiles_private')
          .select('phone, email')
          .eq('id', executorId)
          .maybeSingle();
      if (row == null) return null;
      return (
        phone: row['phone'] as String?,
        email: row['email'] as String?,
      );
    } on PostgrestException {
      return null;
    }
  }

  /// Текущий статус мэтча в БД. Используется при открытии деталей
  /// заказа: если исполнитель уже подтвердил (`accepted`/`completed`) —
  /// заказчик может подтянуть его контакты.
  Future<String?> getMatchStatus(String matchId) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('order_matches')
          .select('status')
          .eq('id', matchId)
          .maybeSingle();
      return row?['status'] as String?;
    } on PostgrestException {
      return null;
    }
  }

  /// Snapshot цены из `order_matches.agreed_*` плюс список техник услуги,
  /// по которой был мэтч. Возвращает null, если мэтча нет.
  Future<MatchSnapshot?> getMatchSnapshot(String matchId) async {
    await CatalogService.instance.listActiveMachinery();
    try {
      final Map<String, dynamic>? row = await _client
          .from('order_matches')
          .select(
            'status, agreed_price_per_hour, agreed_price_per_day, '
            'agreed_min_hours, '
            'service:services!order_matches_service_id_fkey(machinery_ids)',
          )
          .eq('id', matchId)
          .maybeSingle();
      if (row == null) return null;
      final Map<int, String> machineryById = <int, String>{
        for (final MachineryRef m
            in CatalogService.instance.cachedMachinery ??
                const <MachineryRef>[])
          m.id: m.title,
      };
      final Map<String, dynamic>? service =
          row['service'] as Map<String, dynamic>?;
      final List<int> machineryIds = service == null
          ? const <int>[]
          : List<int>.from(service['machinery_ids'] as List);
      return MatchSnapshot(
        status: row['status'] as String,
        agreedPricePerHour: _toDouble(row['agreed_price_per_hour']),
        agreedPricePerDay: _toDouble(row['agreed_price_per_day']),
        agreedMinHours: row['agreed_min_hours'] as int?,
        serviceMachineryTitles: machineryIds
            .map((int id) => machineryById[id] ?? '')
            .where((String t) => t.isNotEmpty)
            .toList(),
      );
    } on PostgrestException {
      return null;
    }
  }

  // ---------------------------------------------------------------

  String _dateIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Детерминированная точка в пределах Москвы (≈ ±11 км по широте,
  /// ±10 км по долготе от центра) из хэша адреса. Используется как
  /// fallback, когда заказ создан без выбора подсказки DaData. Один и
  /// тот же адрес всегда даёт одну и ту же точку — это стабильнее
  /// рандома, который заставлял бы заказ «прыгать» между fetch'ами.
  ({double lat, double lng}) _stableMoscowCoordsForAddress(String address) {
    const double centerLat = 55.7558;
    const double centerLon = 37.6173;
    // FNV-1a 32-bit — быстрый стабильный хэш строки. Берём два независимых
    // байтовых среза для широты и долготы, чтобы они не коррелировали.
    int hash = 0x811c9dc5;
    for (final int code in address.codeUnits) {
      hash = ((hash ^ code) * 0x01000193) & 0xffffffff;
    }
    final int latSeed = hash & 0xffff;
    final int lonSeed = (hash >> 16) & 0xffff;
    final double dLat = ((latSeed / 0xffff) - 0.5) * 0.20;
    final double dLon = ((lonSeed / 0xffff) - 0.5) * 0.36;
    return (lat: centerLat + dLat, lng: centerLon + dLon);
  }

  double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

class _BestMatch {
  const _BestMatch({
    required this.rank,
    required this.matchId,
    required this.status,
    required this.executorId,
    required this.executorName,
    required this.executorRating,
    required this.executorReviewCount,
  });
  final int rank;
  final String matchId;
  final String status;
  final String? executorId;
  final String? executorName;
  final double executorRating;
  final int executorReviewCount;
}
