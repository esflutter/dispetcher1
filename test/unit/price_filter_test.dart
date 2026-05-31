import 'package:flutter_test/flutter_test.dart';
import 'package:dispatcher_1/core/catalog/catalog_service.dart';
import 'package:dispatcher_1/core/catalog/models.dart';

/// Общий помощник фильтра/сортировки по цене для каталога исполнителей.
/// Используется и в ленте, и в поиске по категориям — поведение должно быть
/// одинаковым. Здесь проверяем именно эту чистую функцию.
ExecutorCardListItem _card({double? hour, double? day, String name = 'x'}) =>
    ExecutorCardListItem(
      userId: name,
      name: name,
      avatarUrl: null,
      ratingAsExecutor: 0,
      reviewCountAsExecutor: 0,
      legalStatus: null,
      experienceYears: null,
      about: null,
      locationAddress: null,
      locationLat: null,
      locationLng: null,
      radiusKm: null,
      machineryTitles: const <String>[],
      categoryTitles: const <String>[],
      minPricePerHour: hour,
      minPricePerDay: day,
    );

void main() {
  group('applyPriceFilterAndSort', () {
    test('фильтр по максимальной цене за час (дорогие и без цены отсеиваются)',
        () {
      final list = <ExecutorCardListItem>[
        _card(hour: 1000, name: 'a'),
        _card(hour: 3000, name: 'b'),
        _card(hour: null, name: 'c'),
      ];
      final res = CatalogService.applyPriceFilterAndSort(list,
          maxPricePerHour: 2000);
      expect(res.map((ExecutorCardListItem e) => e.name), <String>['a']);
    });

    test('фильтр по максимальной цене за день', () {
      final list = <ExecutorCardListItem>[
        _card(day: 10000, name: 'a'),
        _card(day: 30000, name: 'b'),
      ];
      final res = CatalogService.applyPriceFilterAndSort(list,
          maxPricePerDay: 15000);
      expect(res.map((ExecutorCardListItem e) => e.name), <String>['a']);
    });

    test('сортировка по возрастанию цены за час, без цены — в конец', () {
      final list = <ExecutorCardListItem>[
        _card(hour: 3000, name: 'b'),
        _card(hour: null, name: 'c'),
        _card(hour: 1000, name: 'a'),
      ];
      final res =
          CatalogService.applyPriceFilterAndSort(list, sortByPriceAsc: true);
      expect(res.map((ExecutorCardListItem e) => e.name),
          <String>['a', 'b', 'c']);
    });

    test('без параметров — порядок не меняется', () {
      final list = <ExecutorCardListItem>[
        _card(hour: 3000, name: 'b'),
        _card(hour: 1000, name: 'a'),
      ];
      final res = CatalogService.applyPriceFilterAndSort(list);
      expect(res.map((ExecutorCardListItem e) => e.name), <String>['b', 'a']);
    });

    test('фильтр и сортировка вместе', () {
      final list = <ExecutorCardListItem>[
        _card(hour: 500, name: 'a'),
        _card(hour: 2500, name: 'b'),
        _card(hour: 1500, name: 'c'),
      ];
      final res = CatalogService.applyPriceFilterAndSort(list,
          maxPricePerHour: 2000, sortByPriceAsc: true);
      expect(res.map((ExecutorCardListItem e) => e.name), <String>['a', 'c']);
    });
  });
}
