import 'package:flutter_test/flutter_test.dart';
import 'package:dispatcher_1/core/ai/ai_client.dart';

/// Unit-тесты для value-классов AiClient. Сам клиент завязан на Supabase
/// singleton и стрим-эндпоинт — здесь покрываем только чистую логику.
void main() {
  group('AiQuota', () {
    test('left возвращает оставшийся лимит', () {
      const q = AiQuota(used: 10, total: 50);
      expect(q.left, 40);
    });

    test('left не уходит в минус если used > total', () {
      const q = AiQuota(used: 100, total: 50);
      expect(q.left, 0);
    });
  });

  group('AiReply', () {
    test('dataKind читает kind из data', () {
      const r = AiReply(
        sessionId: 'sid',
        text: 'hi',
        data: <String, dynamic>{'kind': 'executor_cards', 'ids': <dynamic>['a']},
      );
      expect(r.dataKind, 'executor_cards');
    });

    test('itemIds фильтрует только строки', () {
      const r = AiReply(
        sessionId: 'sid',
        text: '',
        data: <String, dynamic>{'ids': <dynamic>['a', 1, 'b', null]},
      );
      expect(r.itemIds, <String>['a', 'b']);
    });

    test('isDraftReady=true для готового черновика', () {
      const r = AiReply(
        sessionId: 'sid',
        text: '',
        data: <String, dynamic>{'ready': true, 'kind': 'order_draft'},
      );
      expect(r.isDraftReady, isTrue);
    });

    test('items берёт только map-объекты', () {
      const r = AiReply(
        sessionId: 'sid',
        text: '',
        data: <String, dynamic>{
          'items': <dynamic>[
            <String, dynamic>{'id': '1'},
            'not-a-map',
            <String, dynamic>{'id': '2'},
          ],
        },
      );
      expect(r.items.length, 2);
    });
  });

  group('AiChatChunk', () {
    test('done=true несёт квоту', () {
      const c = AiChatChunk(
        text: 'hello',
        delta: '',
        done: true,
        quota: AiQuota(used: 5, total: 50),
      );
      expect(c.quota!.left, 45);
    });

    test('done=false по умолчанию без квоты', () {
      const c = AiChatChunk(text: 'h', delta: 'h', done: false);
      expect(c.quota, isNull);
    });
  });
}
