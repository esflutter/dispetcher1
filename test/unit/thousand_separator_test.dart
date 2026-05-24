import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatcher_1/core/utils/thousand_separator_formatter.dart';

TextEditingValue _val(String s) =>
    TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));

void main() {
  group('ThousandSeparatorFormatter', () {
    test('пусто → пусто', () {
      const f = ThousandSeparatorFormatter();
      expect(f.formatEditUpdate(_val(''), _val('')).text, '');
    });
    test('до 3 цифр — без пробелов', () {
      const f = ThousandSeparatorFormatter();
      expect(f.formatEditUpdate(_val(''), _val('1')).text, '1');
      expect(f.formatEditUpdate(_val(''), _val('123')).text, '123');
    });
    test('4 цифры — пробел', () {
      const f = ThousandSeparatorFormatter();
      expect(f.formatEditUpdate(_val(''), _val('1000')).text, '1 000');
      expect(f.formatEditUpdate(_val(''), _val('9999')).text, '9 999');
    });
    test('большие числа', () {
      const f = ThousandSeparatorFormatter();
      expect(f.formatEditUpdate(_val(''), _val('10000')).text, '10 000');
      expect(f.formatEditUpdate(_val(''), _val('1000000')).text, '1 000 000');
    });
    test('обрезка по maxDigits', () {
      const f = ThousandSeparatorFormatter(maxDigits: 5);
      expect(f.formatEditUpdate(_val(''), _val('123456')).text, '12 345');
    });
    test('нецифры выкидываются', () {
      const f = ThousandSeparatorFormatter();
      expect(f.formatEditUpdate(_val(''), _val('1a2b3c4')).text, '1 234');
      expect(f.formatEditUpdate(_val(''), _val('-1000')).text, '1 000');
    });
    test('selection в конце', () {
      const f = ThousandSeparatorFormatter();
      final TextEditingValue out = f.formatEditUpdate(_val(''), _val('10000'));
      expect(out.selection.baseOffset, '10 000'.length);
    });
  });
}
