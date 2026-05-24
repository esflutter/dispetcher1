import 'package:flutter_test/flutter_test.dart';
import 'package:dispatcher_1/features/orders/widgets/order_status_pill.dart';

/// Тесты `MyOrderStatusX.label` — подписи пилюль статуса заказа в
/// списке «Мои заказы». Они отображаются клиенту, расхождения с
/// дизайном/ТЗ — заметный UX-баг.

void main() {
  group('MyOrderStatusX.label', () {
    test('каждый статус имеет непустой человекочитаемый label', () {
      for (final MyOrderStatus s in MyOrderStatus.values) {
        expect(s.label.trim().isNotEmpty, isTrue,
            reason: 'label статуса $s пустой');
        expect(s.label, isNot(contains('null')),
            reason: 'label для $s = "${s.label}" содержит "null"');
      }
    });

    test('тексты пилюль точно как утвердил продукт (защита от опечаток)',
        () {
      // Чтобы при случайной правке в .dart файле не превратили
      // «Откликов пока нет» в «Откликов нет пока», что заметно глазу
      // юзера и сразу нарушает консистентность.
      expect(MyOrderStatus.waiting.label, 'Откликов пока нет');
      expect(MyOrderStatus.awaitingExecutor.label,
          'Ждёт подтверждения от исполнителя');
      expect(MyOrderStatus.waitingChoose.label, 'Выберите исполнителя');
      expect(MyOrderStatus.accepted.label, 'Свяжитесь с исполнителем');
      expect(MyOrderStatus.executorDeclined.label,
          'Исполнитель отказался. Выберите другого');
    });

    test('completed без отзыва — стандартный label', () {
      expect(MyOrderStatus.completed.label.toLowerCase(), contains('завершён'));
    });
  });
}
