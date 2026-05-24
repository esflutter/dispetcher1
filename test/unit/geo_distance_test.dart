import 'package:flutter_test/flutter_test.dart';
import 'package:dispatcher_1/core/utils/geo_distance.dart';

void main() {
  group('haversineKm', () {
    test('точка сама с собой → 0', () {
      expect(haversineKm(55.7558, 37.6173, 55.7558, 37.6173), 0.0);
    });
    test('Москва — СПб ≈ 635 км', () {
      final double d = haversineKm(55.7520, 37.6175, 59.9398, 30.3146);
      expect(d, closeTo(634, 5));
    });
    test('1° по широте ≈ 111 км', () {
      expect(haversineKm(0, 0, 1, 0), closeTo(111.19, 0.1));
    });
    test('1° по долготе на широте 60° ≈ 55.6 км', () {
      expect(haversineKm(60, 0, 60, 1), closeTo(55.6, 0.5));
    });
    test('симметрия d(A, B) == d(B, A)', () {
      final double ab = haversineKm(55.7558, 37.6173, 59.9398, 30.3146);
      final double ba = haversineKm(59.9398, 30.3146, 55.7558, 37.6173);
      expect(ab, closeTo(ba, 0.01));
    });
    test('маленькие расстояния (Москва, ~2.5 км)', () {
      expect(
        haversineKm(55.7520, 37.6175, 55.7307, 37.6014),
        closeTo(2.57, 0.05),
      );
    });
  });
}
