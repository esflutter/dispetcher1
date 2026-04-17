import 'package:flutter/foundation.dart';

import 'package:dispatcher_1/features/orders/widgets/order_status_pill.dart';

/// Данные карточки заказа заказчика. Внутренний публичный тип,
/// используется и экраном «Мои заказы», и in-memory стором созданных
/// заказчиком заказов [CreatedOrdersStore].
class OrderMock {
  const OrderMock({
    required this.id,
    required this.status,
    required this.title,
    required this.equipment,
    required this.rentDate,
    required this.address,
    required this.publishedAgo,
    this.price,
    this.customerName,
    this.customerPhone,
    this.number,
    this.description = '',
    this.categories = const <String>[],
    this.works = const <String>[],
    this.photos = const <String>[],
  });

  final String id;
  final MyOrderStatus status;
  final String title;
  final List<String> equipment;
  final String rentDate;
  final String address;
  final String publishedAgo;

  /// Отформатированная стоимость, например «80 000 – 100 000 ₽»,
  /// «От 80 000 ₽» или «50 000 ₽» для точной цены. Если null — берётся
  /// дефолтное значение из [MyOrderCard].
  final String? price;
  final String? customerName;
  final String? customerPhone;

  /// Дополнительные поля, заполняемые из формы создания заказа заказчиком.
  /// У моковых заказов в списке «Мои заказы» они остаются пустыми — экран
  /// подробностей тогда скроет соответствующие блоки.
  final String? number;
  final String description;
  final List<String> categories;
  final List<String> works;
  final List<String> photos;

  OrderMock copyWith({MyOrderStatus? status}) {
    return OrderMock(
      id: id,
      status: status ?? this.status,
      title: title,
      equipment: equipment,
      rentDate: rentDate,
      address: address,
      publishedAgo: publishedAgo,
      price: price,
      customerName: customerName,
      customerPhone: customerPhone,
      number: number,
      description: description,
      categories: categories,
      works: works,
      photos: photos,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is OrderMock && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// In-memory стор заказов, созданных заказчиком из экрана «Создание
/// заказа». Живёт только в памяти — после перезапуска приложения
/// список очищается. Новые заказы добавляются в начало (самые свежие
/// сверху).
class CreatedOrdersStore {
  CreatedOrdersStore._();

  static final List<OrderMock> _items = <OrderMock>[];

  /// Слушатели подписываются сюда, чтобы перерисовать UI при появлении
  /// новых заказов. Числовая ревизия меняется при каждом изменении.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static List<OrderMock> get items => List<OrderMock>.unmodifiable(_items);

  /// Добавляет новый заказ в начало списка.
  static void add(OrderMock order) {
    _items.insert(0, order);
    revision.value++;
  }
}
