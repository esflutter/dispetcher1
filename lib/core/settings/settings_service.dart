import 'package:supabase_flutter/supabase_flutter.dart';

/// Глобальные настройки из таблицы `public.settings`. Загружаются один
/// раз при первом обращении и держатся в памяти. RLS пропускает чтение
/// до-логиновых ключей (цены, ссылки) и анониму, запись — service_role.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  SupabaseClient get _client => Supabase.instance.client;

  Map<String, dynamic>? _cache;

  // Дедуп параллельных загрузок: несколько геттеров, дёрнутых одновременно,
  // ждут один сетевой вызов, а не шлют каждый свой.
  Future<void>? _inFlight;

  Future<void> _load() {
    if (_cache != null) return Future<void>.value();
    final Future<void> f = _inFlight ??= _doLoad();
    return f;
  }

  Future<void> _doLoad() async {
    try {
      final List<Map<String, dynamic>> rows =
          await _client.from('settings').select('key, value');
      _cache = <String, dynamic>{
        for (final Map<String, dynamic> r in rows) r['key'] as String: r['value'],
      };
    } catch (_) {
      // Кэш НЕ фиксируем пустым: офлайн-старт раньше навсегда (до перезапуска)
      // оставлял приложение на зашитых фолбэках. Оставляем null — следующий
      // геттер повторит запрос, когда сеть появится.
    } finally {
      _inFlight = null;
    }
  }

  /// Снимок кэша для геттеров: после неудачной загрузки кэш остаётся null —
  /// геттеры работают по фолбэкам, следующий вызов снова попробует сеть.
  Map<String, dynamic> get _values => _cache ?? const <String, dynamic>{};

  Future<int> subscriptionMonthlyPriceRub() async {
    await _load();
    return (_values['subscription.monthly_price_rub'] as num?)?.toInt() ?? 490;
  }

  Future<int> serviceSlotPriceRub() async {
    await _load();
    return (_values['service_slot.price_rub'] as num?)?.toInt() ?? 99;
  }

  Future<int> orderDailyLimit() async {
    await _load();
    return (_values['order.daily_limit'] as num?)?.toInt() ?? 30;
  }

  Future<String> termsCurrentVersion() async {
    await _load();
    return (_values['terms.current_version'] as String?) ?? '1.0';
  }

  /// Ссылка на мессенджер поддержки (МАХ). Пусто — UI покажет мягкую заглушку.
  /// Берётся из настроек, чтобы админ задал её без пересборки приложения.
  Future<String> supportMessengerUrl() async {
    await _load();
    return ((_values['support.messenger_url'] as String?) ?? '').trim();
  }

  /// Ссылка на пользовательское соглашение (оферту). Пусто — не показываем.
  Future<String> legalTermsUrl() async {
    await _load();
    return ((_values['legal.terms_url'] as String?) ?? '').trim();
  }

  /// Ссылка на политику конфиденциальности. Пусто — не показываем.
  Future<String> legalPrivacyUrl() async {
    await _load();
    return ((_values['legal.privacy_url'] as String?) ?? '').trim();
  }

  /// Настройки проверки обновлений: минимально допустимая версия (ниже неё —
  /// настойчивое окно), последняя версия и переключатель «рекомендуем
  /// обновить». Мягкое окно показывается ТОЛЬКО когда переключатель включён
  /// И версия ниже последней. Дефолты («0.0.0» / выключено) — окно не
  /// появляется, пока админ не задаст значения. Парсинг терпим к хранению
  /// значения как строки и как числа.
  Future<({String min, String latest, bool recommend})> appVersions() async {
    await _load();
    final String min =
        (_values['app.customer_min_version']?.toString() ?? '0.0.0').trim();
    final String latest =
        (_values['app.customer_latest_version']?.toString() ?? '0.0.0').trim();
    final bool recommend =
        (num.tryParse('${_values['app.customer_recommend_update'] ?? 0}') ?? 0) !=
            0;
    return (min: min, latest: latest, recommend: recommend);
  }

  /// Прогревает кэш настроек на старте приложения. Вызывается из `main()`
  /// fire-and-forget вместе с CatalogService.warmup() — после этого все
  /// геттеры возвращают значения мгновенно, без сетевого запроса.
  Future<void> warmup() => _load();
}
