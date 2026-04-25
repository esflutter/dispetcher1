import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dispatcher_1/core/catalog/catalog_service.dart';
import 'package:dispatcher_1/core/catalog/models.dart';

import 'models.dart';

/// Заказы, созданные текущим заказчиком (`orders.customer_id = me`),
/// и входящие отклики исполнителей на них (`order_matches`).
class CustomerOrdersService {
  CustomerOrdersService._();
  static final CustomerOrdersService instance = CustomerOrdersService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// INSERT в `public.orders`. Триггер `set_published_at` проставит
  /// `published_at=now()` на статусе `published`. Возвращает id нового
  /// заказа.
  Future<String> createOrder(
    OrderDraft d, {
    bool publishNow = true,
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

    final Map<String, dynamic> payload = <String, dynamic>{
      'customer_id': user.id,
      'title': d.title,
      'description': d.description,
      'category_ids': categoryIds,
      'machinery_ids': machineryIds,
      'works': d.works.map((WorkDraft w) => w.toJson()).toList(),
      // Загрузка фото в Storage — отдельная задача. Пока отправляем пустой
      // массив, даже если пользователь выбрал локальные файлы.
      'photos': <String>[],
      'address': d.address,
      'date_from': _dateIso(d.dateFrom),
      'date_to': d.dateTo == null ? null : _dateIso(d.dateTo!),
      'exact_date': d.exactDate,
      'time_from': d.timeFrom == null ? null : '${d.timeFrom!}:00',
      'time_to': d.timeTo == null ? null : '${d.timeTo!}:00',
      'whole_day': d.wholeDay,
      'status': publishNow ? 'published' : 'draft',
    };

    final Map<String, dynamic> row = await _client
        .from('orders')
        .insert(payload)
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Свои заказы + счётчик активных (не-терминальных) откликов.
  /// Счётчик считается на клиенте через отдельный запрос — PostgREST
  /// считает всегда-из-одного-места дорого, но для экрана "Мои заказы"
  /// это один список в несколько десятков строк.
  Future<List<CustomerOrderListItem>> listMine({int limit = 100}) async {
    final User? user = _client.auth.currentUser;
    if (user == null) return <CustomerOrderListItem>[];

    await CatalogService.instance.listActiveMachinery();

    final List<Map<String, dynamic>> rows = await _client
        .from('orders')
        .select(
          'id, display_number, title, address, date_from, date_to, '
          'time_from, time_to, exact_date, whole_day, machinery_ids, '
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

    // Считаем отклики по всем заказам одним запросом с group-by эмуляцией.
    final List<String> ids = rows.map((r) => r['id'] as String).toList();
    final Map<String, int> counts = <String, int>{
      for (final String id in ids) id: 0,
    };
    final List<Map<String, dynamic>> matchRows = await _client
        .from('order_matches')
        .select('order_id')
        .inFilter('order_id', ids)
        .not('status', 'in',
            '(completed,rejected_by_customer,rejected_by_executor,expired)');
    for (final Map<String, dynamic> m in matchRows) {
      final String id = m['order_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }

    return rows.map((Map<String, dynamic> r) {
      final List<int> mIds = List<int>.from(r['machinery_ids'] as List);
      final DateTime published = r['published_at'] == null
          ? DateTime.parse(r['created_at'] as String)
          : DateTime.parse(r['published_at'] as String);
      return CustomerOrderListItem(
        id: r['id'] as String,
        displayNumber: r['display_number'] as int,
        title: r['title'] as String,
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
        publishedAt: published,
        status: r['status'] as String,
        respondersCount: counts[r['id']] ?? 0,
      );
    }).toList();
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
          'id, name, rating_as_executor, review_count_as_executor), '
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
  Future<void> proposeToExecutor(String matchId) async {
    await _client
        .from('order_matches')
        .update(<String, dynamic>{'status': 'awaiting_executor'})
        .eq('id', matchId);
  }

  /// Заказчик отклонил отклик (`awaiting_customer` → `rejected_by_customer`).
  Future<void> rejectResponse(String matchId) async {
    await _client
        .from('order_matches')
        .update(<String, dynamic>{'status': 'rejected_by_customer'})
        .eq('id', matchId);
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

  /// Снять заказ с публикации (status → `cancelled`).
  Future<void> cancelOrder(String orderId) async {
    await _client
        .from('orders')
        .update(<String, dynamic>{'status': 'cancelled'})
        .eq('id', orderId);
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

  // ---------------------------------------------------------------

  String _dateIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
