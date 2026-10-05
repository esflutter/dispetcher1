import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Терпимый разбор булева флага из таблицы настроек.
///
/// Одно и то же значение приходит в разных видах, и все они реальны:
/// админ-панель пишет переключатели числом `1`/`0`, миграции — настоящим
/// булевым `true`/`false`, а через REST значение может прийти строкой.
/// Разбор одинаковый на сервере (SQL, edge-функции) и в обоих приложениях —
/// иначе приложение и сервер по-разному поймут, включено ли что-то:
///   • булево — как есть;
///   • число — всё, что не ноль, это «включено»;
///   • строка (регистр и пробелы по краям не важны): '1', 'true', 't',
///     'yes', 'on' — «включено»; '0', 'false', 'f', 'no', 'off' — «выключено»;
///   • всё прочее (ключа нет, мусор) — [fallback].
bool parseSettingsFlag(Object? raw, {required bool fallback}) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) {
    final String s = raw.trim().toLowerCase();
    if (_kFlagTrueWords.contains(s)) return true;
    if (_kFlagFalseWords.contains(s)) return false;
  }
  return fallback;
}

const Set<String> _kFlagTrueWords = <String>{'1', 'true', 't', 'yes', 'on'};
const Set<String> _kFlagFalseWords = <String>{'0', 'false', 'f', 'no', 'off'};

/// Включён ли график работы исполнителей. Приоритет: свежее значение с
/// сервера → последнее известное значение с устройства → «включён».
/// По умолчанию график включён — это прежнее поведение приложения.
bool resolveScheduleEnabled({Object? serverValue, bool? rememberedValue}) {
  if (serverValue != null) {
    return parseSettingsFlag(serverValue, fallback: true);
  }
  return rememberedValue ?? true;
}

/// Глобальные настройки из таблицы `public.settings`. Загружаются один
/// раз при первом обращении и держатся в памяти; перечитываются после входа
/// и при возврате приложения из фона. RLS пропускает чтение до-логиновых
/// ключей (цены, ссылки, график) и анониму, запись — service_role.
class SettingsService with WidgetsBindingObserver {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  bool _observing = false;
  DateTime? _lastResumeReload;

  /// Перечитывать настройки при возврате приложения из фона.
  ///
  /// Без этого переключатели из админ-панели (например, «График работы»)
  /// доезжали до уже открытого приложения только после полного перезапуска:
  /// человек продолжал видеть блок «Занятость» и фильтр по дате, которых
  /// уже нет. Образец — приложение исполнителя.
  ///
  /// Чаще раза в минуту не дёргаем: возврат из фона бывает частым.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final DateTime now = DateTime.now();
    if (_lastResumeReload != null &&
        now.difference(_lastResumeReload!) < const Duration(minutes: 1)) {
      return;
    }
    _lastResumeReload = now;
    reload().catchError((Object _) {/* офлайн — останемся на прежних значениях */});
  }

  SupabaseClient get _client => Supabase.instance.client;

  Map<String, dynamic>? _cache;

  /// Когда настройки последний раз успешно загрузились с сервера.
  DateTime? _loadedAt;

  /// Сигнал «настройки перечитаны»: меняется после КАЖДОЙ успешной загрузки
  /// (и когда с устройства подняли запомненное значение до первой загрузки).
  /// Открытые экраны слушают его, чтобы переключатель из админ-панели
  /// доехал до них после возврата из фона, а не после перезапуска.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

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
      _loadedAt = DateTime.now();
      _rememberScheduleEnabled(
        parseSettingsFlag(_cache![_kScheduleEnabledKey], fallback: true),
      );
      revision.value = revision.value + 1;
    } catch (_) {
      // Кэш НЕ фиксируем пустым: офлайн-старт раньше навсегда (до перезапуска)
      // оставлял приложение на зашитых фолбэках. Оставляем как было — при
      // первой загрузке это null, и следующий геттер повторит запрос, когда
      // сеть появится; при перечитывании остаются прежние значения.
    } finally {
      _inFlight = null;
    }
  }

  /// Сбросить и перечитать настройки. Зовётся после входа и при возврате из
  /// фона. Сначала дожидаемся уже летящей загрузки (если есть) — иначе её
  /// поздний ответ перетёр бы свежий. Прежние значения до прихода новых НЕ
  /// стираем: экраны, которые читают настройки в этот момент, получают
  /// последние известные, а не зашитые запасные (у графика это был бы
  /// легаси-режим вместо строгого). При сбое сети прежние значения остаются.
  Future<void> reload() async {
    final Future<void>? inflight = _inFlight;
    if (inflight != null) {
      try {
        await inflight;
      } catch (_) {
        /* неудача старой загрузки не мешает новой */
      }
    }
    await (_inFlight ??= _doLoad());
  }

  /// Перечитать настройки, если они старше [maxAge], но ждать не дольше
  /// [timeout]. Зовётся перед решениями, которые зависят от графика (поиск по
  /// дате, блок «Занятость»): если админ переключил график, пока приложение
  /// было открыто и не уходило в фон, по устаревшему «строгому режиму» поиск
  /// по дате никого бы не нашёл (сервер уже прячет чужие отметки). Сеть не
  /// отвечает — работаем по последним известным значениям.
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(minutes: 1),
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final DateTime? at = _loadedAt;
    if (at != null && DateTime.now().difference(at) < maxAge) return;
    try {
      // Уже идёт загрузка — присоединяемся к ней, а не запускаем после неё
      // ещё одну: свежая загрузка и так отражает текущее состояние сервера.
      await (_inFlight ?? reload()).timeout(timeout);
    } catch (_) {/* офлайн или долго — остаёмся на прежних значениях */}
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

  // ---------------------------------------------------------------
  // График работы исполнителей (`schedule.enabled` в таблице настроек).
  //
  // Один серверный переключатель в админ-панели: пока он выключен, графика
  // в приложении нет вообще — блок «Занятость» в карточке исполнителя
  // скрыт, в фильтре каталога нет даты и времени, проверок доступности по
  // графику нет, любой день считается рабочим. Включение возвращает прежнее
  // поведение — код графика никуда не удалён, он просто спрятан за флагом.
  // ---------------------------------------------------------------

  static const String _kScheduleEnabledKey = 'schedule.enabled';
  static const String _kScheduleEnabledPrefsKey = 'schedule_enabled_v1';

  /// Последнее известное значение, поднятое с устройства. `null` — ещё не
  /// читали. Нужно только для первых мгновений холодного старта и для
  /// работы без сети: иначе при выключенном графике первый кадр карточки
  /// исполнителя мигал бы блоком «Занятость».
  bool? _stickyScheduleEnabled;

  Future<void> _restoreScheduleEnabled() async {
    if (_stickyScheduleEnabled != null) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool? v = prefs.getBool(_kScheduleEnabledPrefsKey);
      // Пока ждали хранилище, могла прийти свежая загрузка — её не перетираем.
      if (v == null || _stickyScheduleEnabled != null) return;
      _stickyScheduleEnabled = v;
      // С сервера ещё ничего нет — экраны, уже нарисованные по умолчанию,
      // должны перерисоваться по запомненному значению.
      if (_cache == null) revision.value = revision.value + 1;
    } catch (_) {
      /* нет доступа к хранилищу — останемся на серверном значении */
    }
  }

  void _rememberScheduleEnabled(bool value) {
    if (_stickyScheduleEnabled == value) return;
    _stickyScheduleEnabled = value;
    SharedPreferences.getInstance()
        .then((SharedPreferences p) =>
            p.setBool(_kScheduleEnabledPrefsKey, value))
        .catchError((Object _) => false);
  }

  /// Включён ли график работы исполнителей. Ждёт загрузку настроек.
  Future<bool> scheduleEnabled() async {
    await _load();
    return scheduleEnabledCached;
  }

  /// Синхронная версия по уже прогретому кэшу — нужна там, где решение
  /// принимается прямо во время отрисовки (первый кадр карточки исполнителя,
  /// фильтр каталога). Приоритет: свежие настройки с сервера → последнее
  /// известное значение с устройства → график включён.
  bool get scheduleEnabledCached => resolveScheduleEnabled(
        serverValue: _values[_kScheduleEnabledKey],
        rememberedValue: _stickyScheduleEnabled,
      );

  /// Режим графика исполнителей: считается ли день БЕЗ отметки в расписании
  /// рабочим. true (легаси, по умолчанию) — исполнитель без отметки доступен
  /// на любую дату. false (новый режим «нерабочие по умолчанию») — доступен
  /// только на явно отмеченные рабочие дни. Флаг серверный
  /// (schedule.unmarked_day_available, миграция 107) — фильтр каталога по
  /// дате обязан трактовать «нет записи» так же, как сервер.
  /// Работает только при включённом графике ([scheduleEnabled]); при
  /// выключенном любой день рабочий независимо от этого флага.
  Future<bool> unmarkedDayAvailable() async {
    await _load();
    return unmarkedDayAvailableCached;
  }

  /// Синхронная версия по УЖЕ ПРОГРЕТОМУ кэшу (warmup в main). Нужна там,
  /// где значение требуется в первый же кадр отрисовки. Без неё экран
  /// занятости сначала рисовался в легаси-режиме и писал «исполнитель
  /// свободен для заказов», а через мгновение переключался на «не принимает
  /// заказы». При медленной сети человек успевал прочитать неправду.
  /// Разбор — общий терпимый, как на сервере (строка '0' — это false).
  bool get unmarkedDayAvailableCached => parseSettingsFlag(
        _values['schedule.unmarked_day_available'],
        fallback: true,
      );

  /// Прогревает кэш настроек на старте приложения. Вызывается из `main()`
  /// fire-and-forget вместе с CatalogService.warmup() — после этого все
  /// геттеры возвращают значения мгновенно, без сетевого запроса.
  ///
  /// Здесь же подписываемся на возврат приложения из фона (перечитывание
  /// настроек) и до сети поднимаем с устройства последнее известное значение
  /// переключателя графика: иначе на холодном старте без сети приложение
  /// считало бы график включённым, даже если его выключили.
  Future<void> warmup() async {
    if (!_observing) {
      _observing = true;
      WidgetsFlutterBinding.ensureInitialized();
      WidgetsBinding.instance.addObserver(this);
    }
    await _restoreScheduleEnabled();
    await _load();
  }
}
