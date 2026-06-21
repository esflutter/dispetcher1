import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Управление FCM-токеном текущего пользователя.
///
/// - После OTP-логина: запросить разрешение на пуши (Android 13+, iOS),
///   получить FCM-токен и записать в `device_tokens`.
/// - На `onTokenRefresh` — обновить запись.
/// - При logout — пометить токен как `invalidated_at` и удалить локально.
///
/// Защита от шторма параллельных вызовов:
/// - single-flight: одновременная регистрация ждёт первую.
/// - дедуп 5 минут: повторный вызов в этом окне — no-op.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _initialized = false;
  Future<void>? _inFlight;
  DateTime? _lastRegisteredAt;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Подписаться на `onTokenRefresh` один раз при старте приложения,
  /// после `Firebase.initializeApp`. Любая ошибка `_upsertToken` гасится
  /// — токен подтянется на следующей попытке.
  void initTokenRefreshListener() {
    if (_initialized) return;
    _initialized = true;
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (String token) async {
        try {
          await _upsertToken(token);
        } catch (e) {
          if (kDebugMode) debugPrint('[push] tokenRefresh upsert failed: $e');
        }
      },
    );
  }

  /// Регистрация для текущего пользователя — после OTP-логина или при
  /// холодном старте с валидной сессией.
  Future<void> registerForCurrentUser() async {
    final DateTime? last = _lastRegisteredAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 5)) {
      return;
    }
    final Future<void>? existing = _inFlight;
    if (existing != null) {
      await existing;
      return;
    }
    final Completer<void> done = Completer<void>();
    _inFlight = done.future;
    try {
      await _doRegister();
      _lastRegisteredAt = DateTime.now();
    } catch (e) {
      if (kDebugMode) debugPrint('[push] registerForCurrentUser failed: $e');
    } finally {
      _inFlight = null;
      done.complete();
    }
  }

  Future<void> _doRegister() async {
    final SupabaseClient sb = Supabase.instance.client;
    if (sb.auth.currentSession == null) return;

    NotificationSettings? settings;
    try {
      settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true)
          // 60с: системный диалог разрешения читает ЧЕЛОВЕК — 5с обрывали
          // future до его ответа, и токен терялся до следующего запуска.
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      if (kDebugMode) debugPrint('[push] requestPermission failed: $e');
      return;
    }

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    String? token;
    try {
      token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      if (kDebugMode) debugPrint('[push] getToken failed: $e');
      return;
    }
    if (token == null || token.isEmpty) return;

    await _upsertToken(token);
  }

  Future<void> _upsertToken(String token) async {
    final SupabaseClient sb = Supabase.instance.client;
    final String? userId = sb.auth.currentUser?.id;
    if (userId == null) return;

    await sb.from('device_tokens').upsert({
      'user_id': userId,
      'token': token,
      // Платформу определяем по факту — на iPhone токен помечаем 'ios'.
      'platform': Platform.isIOS ? 'ios' : 'android',
      // Это приложение заказчика — пуши с target_app='customer' идут сюда,
      // с target_app='executor' — отсекаются на сервере. Пуши без target_app
      // (отзывы, блокировка аккаунта) идут в оба.
      'app': 'customer',
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      'invalidated_at': null,
    }, onConflict: 'token');
  }

  /// При logout: пометить текущий токен этого устройства как `invalidated`,
  /// чтобы сервер не слал пуши предыдущему юзеру. Локально — удалить
  /// токен FCM, чтобы при следующем входе пришёл свежий.
  Future<void> clearForCurrentUser() async {
    _lastRegisteredAt = null;

    String? token;
    try {
      token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 5));
    } catch (_) {}

    if (token != null && token.isNotEmpty) {
      try {
        final SupabaseClient sb = Supabase.instance.client;
        await sb
            .from('device_tokens')
            .update(<String, dynamic>{
              'invalidated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('token', token)
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        if (kDebugMode) debugPrint('[push] clear (update) failed: $e');
      }
    }

    try {
      await FirebaseMessaging.instance
          .deleteToken()
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _initialized = false;
  }
}
