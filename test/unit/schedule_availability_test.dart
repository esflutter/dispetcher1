import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:dispatcher_1/core/catalog/models.dart';
import 'package:dispatcher_1/core/catalog/schedule_availability.dart';

/// График исполнителей в приложении заказчика: «доступен ли исполнитель на
/// диапазон дат» (фильтр каталога) и «нерабочий ли день» (блок «Занятость»).
/// Три режима: график выключен в админ-панели / легаси (день без отметки
/// рабочий) / строгий (день без отметки нерабочий, как на проде).

Map<String, dynamic> _row({
  String uid = 'a',
  required String day,
  bool? accepting = true,
  bool wholeDay = false,
  String? from,
  String? to,
}) =>
    <String, dynamic>{
      'user_id': uid,
      'day': day,
      'accepting': accepting,
      'whole_day': wholeDay,
      'time_from': from,
      'time_to': to,
    };

ExecutorScheduleDay _mark({required bool accepting}) => ExecutorScheduleDay(
      day: DateTime(2026, 10, 10),
      accepting: accepting,
      wholeDay: true,
      timeFrom: null,
      timeTo: null,
      machineryTitles: const <String>[],
      radiusKm: null,
    );

final DateTime _d10 = DateTime(2026, 10, 10);
final DateTime _d11 = DateTime(2026, 10, 11);

/// Короткая обёртка: доступен ли исполнитель на 10–11 октября (или на один
/// день, если [oneDay]).
bool _available(
  List<Map<String, dynamic>> rows, {
  required bool enabled,
  required bool unmarked,
  bool oneDay = false,
  bool wholeDay = false,
  String? timeFrom,
  String? timeTo,
}) =>
    ScheduleAvailability.isExecutorAvailable(
      rows: rows,
      dateFrom: _d10,
      dateTo: oneDay ? _d10 : _d11,
      timeFrom: timeFrom,
      timeTo: timeTo,
      wholeDay: wholeDay,
      scheduleEnabled: enabled,
      unmarkedDayAvailable: unmarked,
    );

void main() {
  group('доступность на диапазон — график ВЫКЛЮЧЕН', () {
    test('без отметок исполнитель доступен даже при строгом режиме', () {
      expect(_available(const <Map<String, dynamic>>[],
          enabled: false, unmarked: false), isTrue);
    });

    test('отметка «не работаю» не мешает', () {
      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
        _row(day: '2026-10-10', accepting: false),
      ];
      expect(_available(rows, enabled: false, unmarked: false), isTrue);
      expect(_available(rows, enabled: false, unmarked: true), isTrue);
    });

    test('время и «весь день» не мешают', () {
      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
        _row(day: '2026-10-10', from: '10:00:00', to: '12:00:00'),
      ];
      expect(
          _available(rows,
              enabled: false, unmarked: false, wholeDay: true),
          isTrue);
      expect(
          _available(rows,
              enabled: false,
              unmarked: true,
              timeFrom: '08:00',
              timeTo: '20:00'),
          isTrue);
    });

    test('список недоступных пуст', () {
      final Set<String> out = ScheduleAvailability.unavailableExecutors(
        userIds: const <String>['a', 'b'],
        rows: <Map<String, dynamic>>[
          _row(uid: 'a', day: '2026-10-10', accepting: false),
        ],
        dateFrom: _d10,
        dateTo: _d11,
        wholeDay: false,
        scheduleEnabled: false,
        unmarkedDayAvailable: false,
      );
      expect(out, isEmpty);
    });
  });

  group('доступность на диапазон — ЛЕГАСИ (день без отметки рабочий)', () {
    test('без отметок — доступен', () {
      expect(_available(const <Map<String, dynamic>>[],
          enabled: true, unmarked: true), isTrue);
    });

    test('одна отметка «не работаю» в диапазоне — недоступен', () {
      expect(
          _available(<Map<String, dynamic>>[
            _row(day: '2026-10-11', accepting: false),
          ], enabled: true, unmarked: true),
          isFalse);
    });

    test('рабочая отметка на часть дней — доступен', () {
      expect(
          _available(<Map<String, dynamic>>[
            _row(day: '2026-10-10'),
          ], enabled: true, unmarked: true),
          isTrue);
    });

    test('accepting не пришёл — считается рабочим', () {
      expect(
          _available(<Map<String, dynamic>>[
            _row(day: '2026-10-10', accepting: null),
          ], enabled: true, unmarked: true),
          isTrue);
    });

    test('запрос «весь день», а у отметки время — недоступен', () {
      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
        _row(day: '2026-10-10', from: '09:00:00', to: '18:00:00'),
      ];
      expect(_available(rows, enabled: true, unmarked: true, wholeDay: true),
          isFalse);
    });

    test('запрос со временем: внутри окна — да, за окном — нет', () {
      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
        _row(day: '2026-10-10', from: '08:00:00', to: '20:00:00'),
      ];
      expect(
          _available(rows,
              enabled: true, unmarked: true, timeFrom: '09:00', timeTo: '18:00'),
          isTrue);
      expect(
          _available(rows,
              enabled: true, unmarked: true, timeFrom: '07:00', timeTo: '18:00'),
          isFalse);
      expect(
          _available(rows,
              enabled: true, unmarked: true, timeFrom: '09:00', timeTo: '21:00'),
          isFalse);
    });

    test('у отметки нет времени — запрос со временем не проходит', () {
      expect(
          _available(<Map<String, dynamic>>[
            _row(day: '2026-10-10'),
          ], enabled: true, unmarked: true, timeFrom: '09:00', timeTo: '18:00'),
          isFalse);
    });

    test('отметка «весь день» покрывает любое время', () {
      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
        _row(day: '2026-10-10', wholeDay: true),
      ];
      expect(
          _available(rows,
              enabled: true, unmarked: true, timeFrom: '06:00', timeTo: '23:00'),
          isTrue);
      expect(_available(rows, enabled: true, unmarked: true, wholeDay: true),
          isTrue);
    });
  });

  group('доступность на диапазон — СТРОГИЙ (день без отметки нерабочий)', () {
    test('без отметок — недоступен', () {
      expect(_available(const <Map<String, dynamic>>[],
          enabled: true, unmarked: false), isFalse);
    });

    test('все дни диапазона отмечены рабочими — доступен', () {
      expect(
          _available(<Map<String, dynamic>>[
            _row(day: '2026-10-10'),
            _row(day: '2026-10-11'),
          ], enabled: true, unmarked: false),
          isTrue);
    });

    test('отмечен только один из двух дней — недоступен', () {
      expect(
          _available(<Map<String, dynamic>>[
            _row(day: '2026-10-10'),
          ], enabled: true, unmarked: false),
          isFalse);
    });

    test('один день — одна рабочая отметка — доступен', () {
      expect(
          _available(<Map<String, dynamic>>[
            _row(day: '2026-10-10'),
          ], enabled: true, unmarked: false, oneDay: true),
          isTrue);
    });

    test('любая отметка «не работаю» — недоступен сразу', () {
      expect(
          _available(<Map<String, dynamic>>[
            _row(day: '2026-10-10'),
            _row(day: '2026-10-11', accepting: false),
          ], enabled: true, unmarked: false),
          isFalse);
    });

    test('день отмечен, но время не подходит — не засчитывается', () {
      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
        _row(day: '2026-10-10', from: '08:00:00', to: '20:00:00'),
        _row(day: '2026-10-11', from: '12:00:00', to: '20:00:00'),
      ];
      expect(
          _available(rows,
              enabled: true,
              unmarked: false,
              timeFrom: '09:00',
              timeTo: '18:00'),
          isFalse);
      expect(
          _available(rows,
              enabled: true,
              unmarked: false,
              timeFrom: '13:00',
              timeTo: '18:00'),
          isTrue);
    });
  });

  group('список недоступных исполнителей', () {
    // a — оба дня рабочие, b — второй день «не работаю», c — без отметок.
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
      _row(uid: 'a', day: '2026-10-10'),
      _row(uid: 'a', day: '2026-10-11'),
      _row(uid: 'b', day: '2026-10-10'),
      _row(uid: 'b', day: '2026-10-11', accepting: false),
    ];
    Set<String> run({required bool enabled, required bool unmarked}) =>
        ScheduleAvailability.unavailableExecutors(
          userIds: const <String>['a', 'b', 'c'],
          rows: rows,
          dateFrom: _d10,
          dateTo: _d11,
          wholeDay: false,
          scheduleEnabled: enabled,
          unmarkedDayAvailable: unmarked,
        );

    test('выключен — все доступны',
        () => expect(run(enabled: false, unmarked: false), isEmpty));
    test('легаси — исключён только b',
        () => expect(run(enabled: true, unmarked: true), <String>{'b'}));
    test('строгий — исключены b и c (у c нет отметок)',
        () => expect(run(enabled: true, unmarked: false), <String>{'b', 'c'}));
  });

  group('нерабочий ли день (блок «Занятость»)', () {
    bool off(ExecutorScheduleDay? m,
            {required bool enabled, required bool unmarked}) =>
        ScheduleAvailability.isDayOff(
          mark: m,
          scheduleEnabled: enabled,
          unmarkedDayAvailable: unmarked,
        );

    test('график выключен — нерабочих дней нет', () {
      for (final bool unmarked in <bool>[true, false]) {
        expect(off(null, enabled: false, unmarked: unmarked), isFalse);
        expect(off(_mark(accepting: false), enabled: false, unmarked: unmarked),
            isFalse);
        expect(off(_mark(accepting: true), enabled: false, unmarked: unmarked),
            isFalse);
      }
    });

    test('легаси — нерабочий только отмеченный «не работаю»', () {
      expect(off(null, enabled: true, unmarked: true), isFalse);
      expect(off(_mark(accepting: true), enabled: true, unmarked: true),
          isFalse);
      expect(off(_mark(accepting: false), enabled: true, unmarked: true),
          isTrue);
    });

    test('строгий — нерабочий и день без отметки', () {
      expect(off(null, enabled: true, unmarked: false), isTrue);
      expect(off(_mark(accepting: true), enabled: true, unmarked: false),
          isFalse);
      expect(off(_mark(accepting: false), enabled: true, unmarked: false),
          isTrue);
    });
  });

  // Логику вынесли из сервиса каталога в чистые функции. Сверяем со старой
  // реализацией (скопирована ниже без изменений) на тысячах случайных
  // наборов: при включённом графике результат обязан совпадать один в один.
  test('при включённом графике совпадает с прежней логикой каталога', () {
    final Random rnd = Random(20261005);
    const List<String> users = <String>['u1', 'u2', 'u3', 'u4'];
    const List<String?> times = <String?>[
      null, '07:00:00', '08:00:00', '09:00:00', '12:00:00', '18:00:00',
      '20:00:00',
    ];
    const List<String?> reqTimes = <String?>[
      null, '07:00', '09:00', '12:00', '18:00', '21:00',
    ];
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    for (int i = 0; i < 3000; i++) {
      final DateTime from = DateTime(2026, 10, 1 + rnd.nextInt(5));
      final DateTime to = from.add(Duration(days: rnd.nextInt(3)));
      final int span = to.difference(from).inDays + 1;
      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
      for (final String u in users) {
        for (int k = 0; k < span; k++) {
          if (rnd.nextInt(3) == 0) continue; // день без отметки
          final int acc = rnd.nextInt(5);
          rows.add(_row(
            uid: u,
            day: iso(from.add(Duration(days: k))),
            accepting: acc == 0 ? false : (acc == 1 ? null : true),
            wholeDay: rnd.nextBool(),
            from: times[rnd.nextInt(times.length)],
            to: times[rnd.nextInt(times.length)],
          ));
        }
      }
      rows.shuffle(rnd);
      final bool wholeDay = rnd.nextInt(3) == 0;
      final String? tf = reqTimes[rnd.nextInt(reqTimes.length)];
      final String? tt = reqTimes[rnd.nextInt(reqTimes.length)];
      for (final bool unmarked in <bool>[true, false]) {
        final Set<String> expected = _legacyFindUnavailable(
          userIds: users,
          rows: rows,
          dateFrom: from,
          dateTo: to,
          timeFrom: tf,
          timeTo: tt,
          wholeDay: wholeDay,
          unmarkedOk: unmarked,
        );
        final Set<String> actual = ScheduleAvailability.unavailableExecutors(
          userIds: users,
          rows: rows,
          dateFrom: from,
          dateTo: to,
          timeFrom: tf,
          timeTo: tt,
          wholeDay: wholeDay,
          scheduleEnabled: true,
          unmarkedDayAvailable: unmarked,
        );
        expect(actual, expected, reason: 'набор #$i, легаси=$unmarked');
      }
    }
  });
}

/// Прежняя реализация CatalogService._findUnavailableExecutors (без запроса к
/// базе) — эталон для сверки. Не менять.
Set<String> _legacyFindUnavailable({
  required List<String> userIds,
  required List<Map<String, dynamic>> rows,
  required DateTime dateFrom,
  required DateTime dateTo,
  String? timeFrom,
  String? timeTo,
  required bool wholeDay,
  required bool unmarkedOk,
}) {
  String? trimTime(String? t) {
    if (t == null) return null;
    if (t.length >= 5) return t.substring(0, 5);
    return t;
  }

  bool conflictsByTime(Map<String, dynamic> r) {
    final bool overrideWholeDay = (r['whole_day'] as bool?) ?? false;
    if (wholeDay && !overrideWholeDay) return true;
    if (!wholeDay && timeFrom != null && timeTo != null) {
      if (overrideWholeDay) return false;
      final String? oFrom = trimTime(r['time_from'] as String?);
      final String? oTo = trimTime(r['time_to'] as String?);
      if (oFrom == null ||
          oTo == null ||
          timeFrom.compareTo(oFrom) < 0 ||
          timeTo.compareTo(oTo) > 0) {
        return true;
      }
    }
    return false;
  }

  final Set<String> excluded = <String>{};

  if (unmarkedOk) {
    for (final Map<String, dynamic> r in rows) {
      final String uid = r['user_id'] as String;
      if (excluded.contains(uid)) continue;
      final bool accepting = (r['accepting'] as bool?) ?? true;
      if (!accepting || conflictsByTime(r)) excluded.add(uid);
    }
    return excluded;
  }

  final int daysTotal = dateTo.difference(dateFrom).inDays + 1;
  final Map<String, Set<String>> okDays = <String, Set<String>>{};
  for (final Map<String, dynamic> r in rows) {
    final String uid = r['user_id'] as String;
    if (excluded.contains(uid)) continue;
    final bool accepting = (r['accepting'] as bool?) ?? true;
    if (!accepting) {
      excluded.add(uid);
      okDays.remove(uid);
      continue;
    }
    if (conflictsByTime(r)) continue;
    (okDays[uid] ??= <String>{}).add((r['day'] ?? '').toString());
  }
  for (final String uid in userIds) {
    if (excluded.contains(uid)) continue;
    if ((okDays[uid]?.length ?? 0) < daysTotal) excluded.add(uid);
  }
  return excluded;
}
