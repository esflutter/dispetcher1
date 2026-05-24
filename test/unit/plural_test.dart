import 'package:flutter_test/flutter_test.dart';
import 'package:dispatcher_1/core/utils/plural.dart';

void main() {
  group('reviewsWord', () {
    test('0 → отзывов', () => expect(reviewsWord(0), 'отзывов'));
    test('1/21/101 → отзыв', () {
      expect(reviewsWord(1), 'отзыв');
      expect(reviewsWord(21), 'отзыв');
      expect(reviewsWord(101), 'отзыв');
    });
    test('2-4, 22-24 → отзыва', () {
      expect(reviewsWord(2), 'отзыва');
      expect(reviewsWord(3), 'отзыва');
      expect(reviewsWord(4), 'отзыва');
      expect(reviewsWord(22), 'отзыва');
    });
    test('5-20 → отзывов', () {
      for (int n = 5; n <= 20; n++) {
        expect(reviewsWord(n), 'отзывов', reason: 'n=$n');
      }
    });
    test('11-14 → отзывов (-надцать-форма)', () {
      expect(reviewsWord(11), 'отзывов');
      expect(reviewsWord(12), 'отзывов');
      expect(reviewsWord(13), 'отзывов');
      expect(reviewsWord(14), 'отзывов');
      expect(reviewsWord(111), 'отзывов');
      expect(reviewsWord(112), 'отзывов');
    });
    test('отрицательные — по модулю', () {
      expect(reviewsWord(-1), 'отзыв');
      expect(reviewsWord(-5), 'отзывов');
    });
  });
}
