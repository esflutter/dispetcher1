import 'package:flutter_test/flutter_test.dart';
import 'package:dispatcher_1/core/settings/settings_service.dart';

/// Флаги из таблицы настроек приходят в разных видах, и все они реальны:
///   - числом 1/0 — так пишет переключатель в админ-панели;
///   - булевым true/false — так пишут миграции;
///   - строкой — так значение может прийти через REST.
/// Разбор обязан совпадать с серверным (SQL, edge-функции), иначе приложение
/// и сервер по-разному поймут, включён ли, например, график работы.
void main() {
  group('parseSettingsFlag — «включено»', () {
    test('булево true',
        () => expect(parseSettingsFlag(true, fallback: false), isTrue));
    test('число 1 (так пишет админ-панель)',
        () => expect(parseSettingsFlag(1, fallback: false), isTrue));
    test('любое ненулевое число', () {
      expect(parseSettingsFlag(2, fallback: false), isTrue);
      expect(parseSettingsFlag(-1, fallback: false), isTrue);
      expect(parseSettingsFlag(0.5, fallback: false), isTrue);
    });
    test('строки 1 / true / t / yes / on в любом регистре и с пробелами', () {
      for (final String s in <String>[
        '1', 'true', 'TRUE', 'True', 't', 'T', 'yes', 'YES', 'on', 'On',
        '  true  ', ' 1 ',
      ]) {
        expect(parseSettingsFlag(s, fallback: false), isTrue, reason: s);
      }
    });
  });

  group('parseSettingsFlag — «выключено»', () {
    test('булево false',
        () => expect(parseSettingsFlag(false, fallback: true), isFalse));
    test('число 0 (так пишет админ-панель)', () {
      expect(parseSettingsFlag(0, fallback: true), isFalse);
      expect(parseSettingsFlag(0.0, fallback: true), isFalse);
    });
    test('строки 0 / false / f / no / off в любом регистре и с пробелами', () {
      for (final String s in <String>[
        '0', 'false', 'FALSE', 'f', 'F', 'no', 'No', 'off', 'OFF', ' off ',
        ' 0 ',
      ]) {
        expect(parseSettingsFlag(s, fallback: true), isFalse, reason: s);
      }
    });
  });

  group('parseSettingsFlag — всё прочее даёт значение по умолчанию', () {
    test('ключа нет', () {
      expect(parseSettingsFlag(null, fallback: true), isTrue);
      expect(parseSettingsFlag(null, fallback: false), isFalse);
    });
    test('пустая строка и произвольный текст', () {
      for (final String s in <String>['', '   ', 'да', 'вкл', 'maybe', '2']) {
        expect(parseSettingsFlag(s, fallback: true), isTrue, reason: s);
        expect(parseSettingsFlag(s, fallback: false), isFalse, reason: s);
      }
    });
    test('список и словарь', () {
      expect(parseSettingsFlag(<String>['true'], fallback: false), isFalse);
      expect(
          parseSettingsFlag(<String, Object>{'value': false}, fallback: true),
          isTrue);
    });
  });

  group('resolveScheduleEnabled — сервер → устройство → включён', () {
    test('значение с сервера важнее запомненного на устройстве', () {
      expect(resolveScheduleEnabled(serverValue: 0, rememberedValue: true),
          isFalse);
      expect(resolveScheduleEnabled(serverValue: 1, rememberedValue: false),
          isTrue);
      expect(
          resolveScheduleEnabled(serverValue: false, rememberedValue: true),
          isFalse);
    });
    test('с сервера ничего — берём запомненное на устройстве', () {
      expect(resolveScheduleEnabled(rememberedValue: false), isFalse);
      expect(resolveScheduleEnabled(rememberedValue: true), isTrue);
    });
    test('ничего нет — график включён (прежнее поведение)', () {
      expect(resolveScheduleEnabled(), isTrue);
    });
    test('мусор с сервера — график включён', () {
      expect(
          resolveScheduleEnabled(serverValue: 'abc', rememberedValue: false),
          isTrue);
    });
  });
}
