// =====================================================================
// ai_client.dart — клиент для Edge Functions ИИ-ассистента.
//
// Обёртка над Supabase Functions client. Хранит session_id для каждого
// типа чата (chat / search / slot_fill), чтобы история сохранялась
// между сообщениями.
//
// Используется из chat_screen.dart и других UI-точек, где есть
// взаимодействие с ассистентом.
// =====================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dispatcher_1/core/config/env.dart';
import 'package:dispatcher_1/core/user_location.dart';

/// Тип чата с ассистентом — определяет какая Edge Function вызывается.
enum AiChatKind { chat, search, slotFillOrder, slotFillService }

/// Результат одного обмена с ассистентом.
@immutable
class AiReply {
  const AiReply({
    required this.sessionId,
    required this.text,
    this.data,
    this.error,
    this.quota,
    this.cached = false,
    this.nav,
  });

  final String sessionId;
  final String text;
  final Map<String, dynamic>? data;
  final String? error;
  final AiQuota? quota;
  final bool cached;
  /// Подсказка перехода в раздел (кнопка «Перейти» под ответом).
  final AiNav? nav;

  /// Поле data.kind показывает, как клиент должен отрисовать ответ:
  ///   - null / "" — обычный текст
  ///   - "order_cards"     — массив заказов в data.items
  ///   - "executor_cards"  — массив исполнителей
  ///   - "order_draft"     — готовый черновик заказа (handoff)
  ///   - "service_draft"   — готовый черновик услуги (handoff)
  ///   - "slot_progress"   — slot-fill ещё не закончен
  ///   - "error"           — текст содержит дружелюбное сообщение
  String? get dataKind => data?['kind'] as String?;

  List<String> get itemIds {
    final ids = data?['ids'];
    if (ids is List) return ids.whereType<String>().toList(growable: false);
    return const <String>[];
  }

  bool get isDraftReady => (data?['ready'] as bool?) ?? false;

  Map<String, dynamic>? get draft {
    final d = data?['draft'];
    if (d is Map<String, dynamic>) return d;
    return null;
  }

  List<Map<String, dynamic>> get items {
    final raw = data?['items'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }
}

/// Подсказка перехода в раздел приложения — кнопка «Перейти» под ответом.
/// action — стабильный ключ от сервера; UI сам сопоставляет его с экраном.
@immutable
class AiNav {
  const AiNav({required this.action, required this.label});
  final String action;
  final String label;

  static AiNav? fromJson(dynamic j) {
    if (j is Map && j['action'] is String && j['label'] is String) {
      return AiNav(action: j['action'] as String, label: j['label'] as String);
    }
    return null;
  }
}

/// Один chunk потока ответа ассистента в стриминговом режиме.
@immutable
class AiChatChunk {
  const AiChatChunk({
    required this.text,
    required this.delta,
    required this.done,
    this.quota,
    this.nav,
  });

  final String text;
  final String delta;
  final bool done;
  final AiQuota? quota;
  /// Подсказка перехода (приходит только на done-chunk'е, если сервер прислал).
  final AiNav? nav;
}

@immutable
class AiQuota {
  const AiQuota({required this.used, required this.total});
  final int used;
  final int total;
  int get left => (total - used).clamp(0, total);
}

class AiQuotaExceeded implements Exception {
  AiQuotaExceeded(this.message);
  final String message;
  @override
  String toString() => 'AiQuotaExceeded: $message';
}

class AiContentFilterError implements Exception {
  AiContentFilterError(this.message);
  final String message;
  @override
  String toString() => 'AiContentFilterError: $message';
}

class AiClient {
  AiClient._({required this.app});
  /// В приложении заказчика — app='customer'.
  static final AiClient instance = AiClient._(app: 'customer');

  final String app;

  SupabaseClient get _sb => Supabase.instance.client;

  // Беседа и поиск — ОДИН разговор с общей памятью (корзина chat); slot-fill
  // держит свою сессию. Без этого переключение чат↔поиск теряло историю, и
  // ассистент здоровался заново, будто видит сообщение впервые.
  final Map<AiChatKind, String?> _sessionIds = <AiChatKind, String?>{};

  AiChatKind _sessionBucket(AiChatKind kind) =>
      (kind == AiChatKind.chat || kind == AiChatKind.search)
          ? AiChatKind.chat
          : kind;

  void resetSessions() {
    _sessionIds.clear();
    _lastSlotSessionId = null;
    unawaited(_clearPersistedSession());
  }

  // --- Персистентность разговора: чтобы история чата пережила перезапуск
  // приложения. Храним только session_id; сами сообщения берём из БД
  // (ai_messages, доступ по RLS «только свои сессии»). ---
  static const String _kChatSessionKey = 'ai_chat_session_id';
  // Сессия пошагового создания заказа (slot-fill) отдельная от чата. Храним её
  // id, чтобы при перезапуске показать в истории и эту часть разговора (а не
  // только обычный чат). Используется ТОЛЬКО для показа истории — в активную
  // «корзину» не кладём, иначе «Новый заказ» продолжил бы старый черновик.
  static const String _kSlotSessionKey = 'ai_slot_session_id';
  String? _lastSlotSessionId;

  void _persistChatSession() {
    final String? sid = _sessionIds[AiChatKind.chat];
    if (sid == null || sid.isEmpty) return;
    unawaited(SharedPreferences.getInstance()
        .then((SharedPreferences p) => p.setString(_kChatSessionKey, sid)));
  }

  void _persistSlotSession(String sid) {
    if (sid.isEmpty) return;
    _lastSlotSessionId = sid;
    unawaited(SharedPreferences.getInstance()
        .then((SharedPreferences p) => p.setString(_kSlotSessionKey, sid)));
  }

  /// Сбрасывает сессию пошагового сбора указанного типа — чтобы «Новый заказ»
  /// начинался с ЧИСТОГО черновика, а не продолжал предыдущий (иначе поля
  /// прошлого заказа протекали бы в новый в рамках одного запуска приложения).
  void startFreshSlot(AiChatKind kind) {
    _sessionIds[kind] = null;
  }

  Future<void> _clearPersistedSession() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.remove(_kChatSessionKey);
      await p.remove(_kSlotSessionKey);
    } catch (_) {/* не критично */}
  }

  /// Восстанавливает session_id разговора из прошлого запуска. Вызывать при
  /// открытии экрана чата ДО loadHistory.
  Future<void> restoreChatSession() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      if (_sessionIds[AiChatKind.chat] == null) {
        final String? sid = p.getString(_kChatSessionKey);
        if (sid != null && sid.isNotEmpty) _sessionIds[AiChatKind.chat] = sid;
      }
      _lastSlotSessionId ??= p.getString(_kSlotSessionKey);
    } catch (_) {/* не критично */}
    // Локальный id стирается при ВЫХОДЕ из аккаунта (приватность: следующий
    // пользователь на устройстве не должен видеть чужую переписку). Поэтому
    // после повторного входа того же пользователя восстанавливаем его
    // последнюю беседу из БД по его id (RLS отдаёт только его сессии). Без
    // этого история «терялась» при выходе и повторном входе.
    await _restoreSessionsFromDb();
  }

  /// Достаёт последнюю сессию пользователя из БД, если локального id нет
  /// (после выхода/повторного входа). Беседа (chat/search) — для продолжения
  /// и истории; пошаговое создание (create_*) — только для показа истории.
  Future<void> _restoreSessionsFromDb() async {
    if (_sb.auth.currentUser == null) return;
    try {
      if ((_sessionIds[AiChatKind.chat] ?? '').isEmpty) {
        final List<dynamic> rows = await _sb
            .from('ai_sessions')
            .select('id')
            .eq('app', app)
            .inFilter('kind', const <String>['chat', 'search'])
            .order('updated_at', ascending: false)
            .limit(1);
        if (rows.isNotEmpty) {
          final String? sid = (rows.first as Map)['id'] as String?;
          if (sid != null && sid.isNotEmpty) {
            _sessionIds[AiChatKind.chat] = sid;
            _persistChatSession();
          }
        }
      }
      if ((_lastSlotSessionId ?? '').isEmpty) {
        final List<dynamic> rows = await _sb
            .from('ai_sessions')
            .select('id')
            .eq('app', app)
            .inFilter('kind',
                const <String>['create_order', 'create_service', 'create_card'])
            .order('updated_at', ascending: false)
            .limit(1);
        if (rows.isNotEmpty) {
          final String? sid = (rows.first as Map)['id'] as String?;
          if (sid != null && sid.isNotEmpty) _lastSlotSessionId = sid;
        }
      }
    } catch (_) {/* не критично — просто не восстановим, чат начнётся заново */}
  }

  /// Загружает историю текущего разговора из БД (последние сообщения сессии).
  /// Возвращает «сырые» строки {role, content, data}; экран сам строит из них
  /// сообщения. Пусто, если сессии нет или ошибка.
  Future<List<Map<String, dynamic>>> loadHistory() async {
    // Историю собираем по ДВУМ сессиям — обычный чат/поиск и пошаговое создание
    // заказа — и сливаем в одну ленту по времени. Без этого после перезапуска
    // часть «создание заказа» пропадала (она в отдельной сессии).
    final List<String> ids = <String>[
      if ((_sessionIds[AiChatKind.chat] ?? '').isNotEmpty) _sessionIds[AiChatKind.chat]!,
      if ((_lastSlotSessionId ?? '').isNotEmpty) _lastSlotSessionId!,
    ];
    if (ids.isEmpty) return const <Map<String, dynamic>>[];
    try {
      final List<dynamic> rows = await _sb
          .from('ai_messages')
          .select('role, content, data, created_at')
          .inFilter('session_id', ids)
          .order('created_at', ascending: true)
          .limit(60);
      return rows
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<AiReply> chat(String message) =>
      _invoke('ai-chat', message, AiChatKind.chat, null);

  /// Стрим версия chat — присылает delta-куски по мере генерации.
  /// Эмитит первое событие AiChatChunk(text: '...', done: false) с
  /// частичным текстом, последнее — AiChatChunk(done: true) с полным
  /// текстом и квотой. Используется в UI для эффекта «ассистент печатает».
  Stream<AiChatChunk> chatStream(String message) async* {
    final sb = _sb;
    final session = sb.auth.currentSession;
    if (session == null) {
      throw Exception('unauthorized');
    }
    final url = '${Env.supabaseUrl}/functions/v1/ai-chat-stream';
    final req = http.Request('POST', Uri.parse(url));
    req.headers['Content-Type']  = 'application/json';
    req.headers['Authorization'] = 'Bearer ${session.accessToken}';
    req.headers['apikey']        = Env.supabaseAnonKey;
    req.body = jsonEncode(<String, dynamic>{
      'message': message,
      'app':     app,
      'session_id': ?_sessionIds[AiChatKind.chat],
    });

    // Держим Client в переменной, чтобы закрыть его в finally — иначе
    // на каждое сообщение в чате утекает Client + сокет из пула.
    final client = http.Client();
    try {
      final resp = await client.send(req);
      if (resp.statusCode == 402) {
        throw AiQuotaExceeded('Лимит исчерпан');
      }
      if (resp.statusCode != 200) {
        throw Exception('ai_chat_stream_${resp.statusCode}');
      }

      String buf = '';
      String fullText = '';
      bool sawDone = false;

      Iterable<AiChatChunk> processLine(String line) sync* {
        if (line.isEmpty) return;
        Map<String, dynamic> obj;
        try {
          obj = jsonDecode(line) as Map<String, dynamic>;
        } catch (_) { return; }

        final kind = obj['kind'] as String?;
        if (kind == 'session') {
          final sid = obj['session_id'] as String?;
          if (sid != null && sid.isNotEmpty) {
            _sessionIds[AiChatKind.chat] = sid;
            _persistChatSession();
          }
        } else if (kind == 'delta') {
          final delta = obj['text'] as String? ?? '';
          fullText += delta;
          yield AiChatChunk(text: fullText, delta: delta, done: false);
        } else if (kind == 'done') {
          sawDone = true;
          final quotaMap = obj['quota'] is Map<String, dynamic>
              ? obj['quota'] as Map<String, dynamic> : null;
          yield AiChatChunk(
            text:  fullText,
            delta: '',
            done:  true,
            quota: quotaMap == null
                ? null
                : AiQuota(
                    used:  (quotaMap['used']  as num? ?? 0).toInt(),
                    total: (quotaMap['total'] as num? ?? 0).toInt(),
                  ),
            nav: AiNav.fromJson(obj['nav']),
          );
        } else if (kind == 'error') {
          final code = obj['code'] as String?;
          final msg  = obj['message'] as String? ?? 'Ошибка ассистента';
          if (code == 'content_filter') {
            throw AiContentFilterError(msg);
          }
          throw Exception(code ?? 'stream_error');
        }
      }

      await for (final chunk in resp.stream.transform(utf8.decoder)) {
        buf += chunk;
        int nl;
        while ((nl = buf.indexOf('\n')) >= 0) {
          final line = buf.substring(0, nl).trim();
          buf = buf.substring(nl + 1);
          for (final c in processLine(line)) {
            yield c;
            if (c.done) return;
          }
        }
      }
      // Хвост без финального \n — обрабатываем остаток buf, иначе можем
      // потерять done-событие, если сервер не доставил перенос.
      final tail = buf.trim();
      if (tail.isNotEmpty) {
        for (final c in processLine(tail)) {
          yield c;
        }
      }
      if (!sawDone) {
        yield AiChatChunk(text: fullText, delta: '', done: true);
      }
    } finally {
      client.close();
    }
  }

  Future<AiReply> search(String message) =>
      _invoke('ai-search', message, AiChatKind.search, null);

  Future<AiReply> slotFillOrder(String message) =>
      _invoke('ai-slot-fill', message, AiChatKind.slotFillOrder, 'create_order');

  Future<AiReply> slotFillService(String message) =>
      _invoke('ai-slot-fill', message, AiChatKind.slotFillService, 'create_service');

  Future<AiReply> _invoke(
    String functionName,
    String message,
    AiChatKind kind,
    String? intent,
  ) async {
    final body = <String, dynamic>{
      'message': message,
      'app':     app,
      'session_id': ?_sessionIds[_sessionBucket(kind)],
      'intent':     ?intent,
      // GPS-координаты пользователя (если он разрешил геолокацию): в поиске
      // сервер считает по ним точное расстояние «от вас», а при создании
      // заказа/услуги — сам определяет город/адрес по координатам (обратный
      // геокодер), чтобы не переспрашивать. Ключи опускаются, если координат нет.
      'origin_lat': ?UserLocation.lat,
      'origin_lng': ?UserLocation.lng,
    };

    // supabase_flutter functions_client@2.5.0 бросает FunctionException
    // на не-2xx статусах. Разбор кодов делаем в catch.
    try {
      final FunctionResponse res = await _sb.functions.invoke(
        functionName,
        body: body,
      );
      final data = res.data;
      final Map<String, dynamic> json = data is Map<String, dynamic>
          ? data
          : <String, dynamic>{};

      final reply = _buildReply(json);
      if (reply.sessionId.isNotEmpty) {
        final AiChatKind bucket = _sessionBucket(kind);
        _sessionIds[bucket] = reply.sessionId;
        if (bucket == AiChatKind.chat) {
          _persistChatSession();
        } else {
          _persistSlotSession(reply.sessionId); // slot-fill — сохраняем для истории
        }
      }
      return reply;
    } on FunctionException catch (e) {
      final Map<String, dynamic> json = e.details is Map<String, dynamic>
          ? e.details as Map<String, dynamic>
          : <String, dynamic>{};
      final int status = e.status;

      // Сохраняем session_id даже при ошибке, чтобы не порвать контекст
      // разговора (например, при content_filter).
      final String? newSid = json['session_id'] as String?;
      if (newSid != null && newSid.isNotEmpty) {
        final AiChatKind bucket = _sessionBucket(kind);
        _sessionIds[bucket] = newSid;
        if (bucket == AiChatKind.chat) {
          _persistChatSession();
        } else {
          _persistSlotSession(newSid);
        }
      }

      if (status == 402) {
        throw AiQuotaExceeded(json['message'] as String? ?? 'Лимит исчерпан');
      }
      if (status == 422 && json['error'] == 'content_filter') {
        throw AiContentFilterError(
          json['message'] as String? ?? 'Не удалось обработать запрос',
        );
      }
      if (status == 503) {
        throw AiQuotaExceeded(
          'Ассистент сейчас перегружен. Попробуйте через несколько минут.',
        );
      }
      if (kDebugMode) {
        debugPrint('[ai-client] $functionName status=$status error=${json['error']}');
      }
      rethrow;
    } on AiQuotaExceeded {
      rethrow;
    } on AiContentFilterError {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('[ai-client] $functionName failed: ${e.runtimeType}');
      rethrow;
    }
  }

  AiReply _buildReply(Map<String, dynamic> json) {
    return AiReply(
      sessionId: json['session_id'] as String? ?? '',
      text:      json['reply']      as String? ?? '',
      data:      json['data']       as Map<String, dynamic>?,
      cached:    json['cached']     as bool?   ?? false,
      nav:       AiNav.fromJson(json['nav']),
      quota: json['quota'] is Map<String, dynamic>
          ? AiQuota(
              used:  (json['quota']['used']  as num? ?? 0).toInt(),
              total: (json['quota']['total'] as num? ?? 0).toInt(),
            )
          : null,
    );
  }

  /// Распознавание голоса.
  /// Бросает: [AiQuotaExceeded], [AiAudioTooLargeError], [AiAudioNoSpeechError].
  Future<String> transcribeAudio(File audio, {String format = 'oggopus'}) async {
    final bytes = await audio.readAsBytes();
    final Map<String, dynamic> qp = <String, dynamic>{'format': format};
    // Для сырого PCM (фолбэк без Opus) серверу нужна частота дискретизации.
    if (format == 'lpcm') qp['sample_rate'] = '16000';
    try {
      final FunctionResponse res = await _sb.functions.invoke(
        'stt-yandex',
        method:        HttpMethod.post,
        body:          bytes,
        queryParameters: qp,
      );
      final data = res.data;
      final Map<String, dynamic> json = data is Map<String, dynamic>
          ? data
          : <String, dynamic>{};
      if (json['text'] is String) {
        return (json['text'] as String).trim();
      }
      return '';
    } on FunctionException catch (e) {
      final Map<String, dynamic> json = e.details is Map<String, dynamic>
          ? e.details as Map<String, dynamic>
          : <String, dynamic>{};
      final int status = e.status;
      if (status == 402) {
        throw AiQuotaExceeded(json['message'] as String? ?? 'Лимит исчерпан');
      }
      if (status == 413 || json['error'] == 'audio_too_large') {
        throw AiAudioTooLargeError();
      }
      if (status == 422 && json['error'] == 'invalid_format') {
        throw AiAudioInvalidFormatError();
      }
      if (status == 422) {
        throw AiAudioNoSpeechError();
      }
      if (status == 500 && json['error'] == 'stt_auth_error') {
        throw Exception('Ассистент временно недоступен (auth).');
      }
      if (kDebugMode) debugPrint('[ai-client] transcribe status=$status error=${json['error']}');
      rethrow;
    } on AiQuotaExceeded {
      rethrow;
    } on AiAudioTooLargeError {
      rethrow;
    } on AiAudioNoSpeechError {
      rethrow;
    } on AiAudioInvalidFormatError {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('[ai-client] transcribe failed: ${e.runtimeType}');
      rethrow;
    }
  }
}

class AiAudioTooLargeError implements Exception {
  @override
  String toString() => 'AiAudioTooLargeError';
}

class AiAudioNoSpeechError implements Exception {
  @override
  String toString() => 'AiAudioNoSpeechError';
}

class AiAudioInvalidFormatError implements Exception {
  @override
  String toString() => 'AiAudioInvalidFormatError';
}
