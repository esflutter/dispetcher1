import 'package:flutter_test/flutter_test.dart';
import 'package:dispatcher_1/core/catalog/catalog_service.dart';
import 'package:dispatcher_1/core/catalog/models.dart';

/// Порядок каталога исполнителей по умолчанию: зона удалённости шагом
/// 10 км → рейтинг → число отзывов → имя. Появился после находки
/// тестировщицы (раньше список шёл по времени правки карточки и выглядел
/// случайным). Проверяем чистую функцию sortByProximityThenRating.
ExecutorCardListItem _card({
  required String name,
  double rating = 0,
  int reviews = 0,
  double? distanceKm,
}) =>
    ExecutorCardListItem(
      userId: name,
      name: name,
      avatarUrl: null,
      ratingAsExecutor: rating,
      reviewCountAsExecutor: reviews,
      legalStatus: null,
      experienceYears: null,
      about: null,
      locationAddress: null,
      locationLat: null,
      locationLng: null,
      radiusKm: null,
      machineryTitles: const <String>[],
      categoryTitles: const <String>[],
      minPricePerHour: null,
      minPricePerDay: null,
      distanceKm: distanceKm,
    );

List<String> _names(List<ExecutorCardListItem> l) =>
    l.map((ExecutorCardListItem e) => e.name).toList();

void main() {
  group('sortByProximityThenRating', () {
    test('без расстояний — чисто по рейтингу', () {
      final list = <ExecutorCardListItem>[
        _card(name: 'a', rating: 4.1),
        _card(name: 'b', rating: 4.8),
        _card(name: 'c', rating: 4.6),
      ];
      CatalogService.sortByProximityThenRating(list);
      expect(_names(list), <String>['b', 'c', 'a']);
    });

    test('равный рейтинг — выше тот, у кого больше отзывов', () {
      final list = <ExecutorCardListItem>[
        _card(name: 'a', rating: 4.6, reviews: 1),
        _card(name: 'b', rating: 4.6, reviews: 50),
      ];
      CatalogService.sortByProximityThenRating(list);
      expect(_names(list), <String>['b', 'a']);
    });

    test('зона 10 км важнее рейтинга: ближний середняк выше дальнего отличника',
        () {
      final list = <ExecutorCardListItem>[
        _card(name: 'далёкий отличник', rating: 5.0, distanceKm: 35),
        _card(name: 'ближний середняк', rating: 4.2, distanceKm: 4),
      ];
      CatalogService.sortByProximityThenRating(list);
      expect(_names(list), <String>['ближний середняк', 'далёкий отличник']);
    });

    test('внутри одной зоны 10 км решает рейтинг, а не метры', () {
      final list = <ExecutorCardListItem>[
        _card(name: 'ближе но хуже', rating: 4.0, distanceKm: 2),
        _card(name: 'чуть дальше но лучше', rating: 4.9, distanceKm: 8),
      ];
      CatalogService.sortByProximityThenRating(list);
      expect(_names(list), <String>['чуть дальше но лучше', 'ближе но хуже']);
    });

    test('карточки без расстояния — в конец, даже с высоким рейтингом', () {
      final list = <ExecutorCardListItem>[
        _card(name: 'без координат', rating: 5.0),
        _card(name: 'в 20 км', rating: 4.0, distanceKm: 20),
      ];
      CatalogService.sortByProximityThenRating(list);
      expect(_names(list), <String>['в 20 км', 'без координат']);
    });

    test('полный детерминизм: зона → рейтинг → отзывы → имя', () {
      final list = <ExecutorCardListItem>[
        _card(name: 'в', rating: 4.6, reviews: 5, distanceKm: 3),
        _card(name: 'б', rating: 4.6, reviews: 5, distanceKm: 7),
        _card(name: 'а', rating: 4.6, reviews: 5, distanceKm: 9),
      ];
      CatalogService.sortByProximityThenRating(list);
      // Все в одной зоне (0-10 км), рейтинг и отзывы равны — по алфавиту.
      expect(_names(list), <String>['а', 'б', 'в']);
    });
  });
}
