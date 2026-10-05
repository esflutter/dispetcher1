import 'models.dart';

/// Чистая логика графика исполнителей в приложении заказчика:
///  • «доступен ли исполнитель на диапазон дат» — фильтр каталога по дате
///    и времени ([isExecutorAvailable], [unavailableExecutors]);
///  • «нерабочий ли день» — окраска и текст блока «Занятость» в карточке
///    исполнителя ([isDayOff]).
///
/// Сеть и настройки сюда не ходят — всё приходит параметрами, поэтому логика
/// покрыта юнит-тестами. Три режима:
///  • график выключен в админ-панели (`scheduleEnabled` = false) — графика
///    нет вообще: любой день рабочий, исполнитель доступен на любую дату;
///  • легаси (`schedule.unmarked_day_available` = true) — день без отметки
///    рабочий, мешают только явные отметки «не работаю» и конфликт по
///    времени;
///  • строгий (false, «нерабочие по умолчанию», как на проде) — рабочий
///    только явно отмеченный день; день без записи = недоступен.
/// Трактовка обязана совпадать с серверной (ai_search_executors, миграция 107).
class ScheduleAvailability {
  ScheduleAvailability._();

  /// Доступен ли ОДИН исполнитель на интервале `[dateFrom..dateTo]` по своим
  /// строкам `schedule_day_overrides` за этот интервал ([rows]: day,
  /// accepting, whole_day, time_from, time_to).
  ///
  ///  • легаси: недоступен, если есть строка с accepting=false ИЛИ строка,
  ///    конфликтующая по времени (см. [_conflictsByTime]); дни без строки —
  ///    доступны;
  ///  • строгий: любая строка с accepting=false — сразу недоступен; иначе
  ///    доступен, только если КАЖДЫЙ день интервала отмечен рабочей строкой
  ///    без конфликта по времени.
  /// accepting=null трактуется как true (так было и раньше).
  static bool isExecutorAvailable({
    required Iterable<Map<String, dynamic>> rows,
    required DateTime dateFrom,
    required DateTime dateTo,
    String? timeFrom,
    String? timeTo,
    required bool wholeDay,
    required bool scheduleEnabled,
    required bool unmarkedDayAvailable,
  }) {
    // График выключен — дата и время ни на что не влияют.
    if (!scheduleEnabled) return true;

    if (unmarkedDayAvailable) {
      // Легаси-режим: исключаем только явные конфликты, день без записи
      // доступен — поведение прежних версий.
      for (final Map<String, dynamic> r in rows) {
        final bool accepting = (r['accepting'] as bool?) ?? true;
        if (!accepting ||
            _conflictsByTime(r,
                wholeDay: wholeDay, timeFrom: timeFrom, timeTo: timeTo)) {
          return false;
        }
      }
      return true;
    }

    // Строгий режим: считаем, сколько дней интервала явно отмечены рабочими
    // и подходят по времени; закрытый день (accepting=false) — жёсткое
    // исключение сразу. Не покрыл все дни — недоступен.
    final int daysTotal = dateTo.difference(dateFrom).inDays + 1;
    final Set<String> okDays = <String>{};
    for (final Map<String, dynamic> r in rows) {
      final bool accepting = (r['accepting'] as bool?) ?? true;
      if (!accepting) return false;
      if (_conflictsByTime(r,
          wholeDay: wholeDay, timeFrom: timeFrom, timeTo: timeTo)) {
        continue; // день отмечен, но время не подходит
      }
      okDays.add((r['day'] ?? '').toString());
    }
    return okDays.length >= daysTotal;
  }

  /// Множество `user_id` из [userIds], которые НЕдоступны на интервале
  /// `[dateFrom..dateTo]`. [rows] — строки `schedule_day_overrides` всех этих
  /// исполнителей за интервал (с колонкой user_id). Правила — как в
  /// [isExecutorAvailable]. При выключенном графике — пустое множество.
  static Set<String> unavailableExecutors({
    required Iterable<String> userIds,
    required Iterable<Map<String, dynamic>> rows,
    required DateTime dateFrom,
    required DateTime dateTo,
    String? timeFrom,
    String? timeTo,
    required bool wholeDay,
    required bool scheduleEnabled,
    required bool unmarkedDayAvailable,
  }) {
    if (!scheduleEnabled) return <String>{};
    final Map<String, List<Map<String, dynamic>>> byUser =
        <String, List<Map<String, dynamic>>>{};
    for (final Map<String, dynamic> r in rows) {
      (byUser[r['user_id'] as String] ??= <Map<String, dynamic>>[]).add(r);
    }
    final Set<String> excluded = <String>{};
    for (final String uid in userIds) {
      final bool available = isExecutorAvailable(
        rows: byUser[uid] ?? const <Map<String, dynamic>>[],
        dateFrom: dateFrom,
        dateTo: dateTo,
        timeFrom: timeFrom,
        timeTo: timeTo,
        wholeDay: wholeDay,
        scheduleEnabled: scheduleEnabled,
        unmarkedDayAvailable: unmarkedDayAvailable,
      );
      if (!available) excluded.add(uid);
    }
    return excluded;
  }

  /// Нерабочий ли день в блоке «Занятость». [mark] — отметка исполнителя на
  /// этот день (null — дня нет в графике).
  ///  • график выключен — нерабочих дней нет;
  ///  • легаси — нерабочий только день с отметкой accepting=false;
  ///  • строгий — нерабочий и день без отметки (как фильтр каталога и сервер).
  static bool isDayOff({
    required ExecutorScheduleDay? mark,
    required bool scheduleEnabled,
    required bool unmarkedDayAvailable,
  }) {
    if (!scheduleEnabled) return false;
    if (unmarkedDayAvailable) return mark != null && !mark.accepting;
    return mark == null || !mark.accepting;
  }

  /// Конфликтует ли строка графика с запрошенным временем:
  ///  • запрос «весь день», а у строки не whole_day — конфликт;
  ///  • запрос с временем С/По (оба заданы, не «весь день»): строка whole_day
  ///    подходит, иначе время запроса должно лежать внутри time_from..time_to
  ///    строки (сравнение строк ЧЧ:ММ); пустое время у строки — конфликт;
  ///  • без времени и без «весь день» — любая строка подходит.
  static bool _conflictsByTime(
    Map<String, dynamic> r, {
    required bool wholeDay,
    String? timeFrom,
    String? timeTo,
  }) {
    final bool overrideWholeDay = (r['whole_day'] as bool?) ?? false;
    if (wholeDay && !overrideWholeDay) return true;
    if (!wholeDay && timeFrom != null && timeTo != null) {
      if (overrideWholeDay) return false; // полностью покрывает
      final String? oFrom = _trimTime(r['time_from'] as String?);
      final String? oTo = _trimTime(r['time_to'] as String?);
      if (oFrom == null ||
          oTo == null ||
          timeFrom.compareTo(oFrom) < 0 ||
          timeTo.compareTo(oTo) > 0) {
        return true;
      }
    }
    return false;
  }

  /// Postgres `time` отдаёт `HH:MM:SS`; сравниваем по `HH:MM` (та же обрезка,
  /// что в CatalogService).
  static String? _trimTime(String? t) {
    if (t == null) return null;
    if (t.length >= 5) return t.substring(0, 5);
    return t;
  }
}
