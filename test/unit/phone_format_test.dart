import 'package:flutter_test/flutter_test.dart';
import 'package:dispatcher_1/core/auth/phone_format.dart';

/// Нормализация телефонов в E.164 + UI-показ. Идентично исполнителю,
/// потому что одна и та же кодовая база на двух проектах разнесена.

void main() {
  group('PhoneFormat.toE164', () {
    test('10 цифр → +7XXXXXXXXXX', () {
      expect(PhoneFormat.toE164('9991234567'), '+79991234567');
    });

    test('11 цифр с 7/8 в начале', () {
      expect(PhoneFormat.toE164('79991234567'), '+79991234567');
      expect(PhoneFormat.toE164('89991234567'), '+79991234567');
    });

    test('с пробелами/дефисами/скобками', () {
      expect(PhoneFormat.toE164('+7 999 123-45-67'), '+79991234567');
      expect(PhoneFormat.toE164('8 (999) 123-45-67'), '+79991234567');
    });

    test('меньше 10 цифр → FormatException', () {
      expect(() => PhoneFormat.toE164('123'), throwsFormatException);
    });

    test('11 цифр НЕ с 7/8 → FormatException', () {
      expect(() => PhoneFormat.toE164('19991234567'), throwsFormatException);
    });
  });

  group('PhoneFormat.toPretty', () {
    test('+7XXXXXXXXXX → +7 XXX XXX-XX-XX', () {
      expect(PhoneFormat.toPretty('+79991234567'), '+7 999 123-45-67');
    });

    test('неподдерживаемый формат → исходник как есть', () {
      expect(PhoneFormat.toPretty('+1234'), '+1234');
      expect(PhoneFormat.toPretty(''), '');
    });

    test('roundtrip toE164→toPretty стабильный', () {
      const String e164 = '+79991234567';
      expect(PhoneFormat.toE164(PhoneFormat.toPretty(e164)), e164);
    });
  });
}
