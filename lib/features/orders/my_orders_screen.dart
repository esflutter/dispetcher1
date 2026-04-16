import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/orders/order_detail_screen.dart';
import 'package:dispatcher_1/features/orders/widgets/my_order_card.dart';
import 'package:dispatcher_1/features/orders/widgets/order_status_pill.dart';
import 'package:dispatcher_1/features/profile/account_block.dart';

/// Экран «Мои заказы» — три вкладки «На рассмотрении / Принятые / Архив».
/// Когда всех списков пусто — показываем заглушку «Здесь появятся ваши заказы».
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key, this.onGoToCatalog, this.isBlocked = false});

  /// Колбэк переключения нижнего таба на «Каталог».
  /// Передаётся из MainShell, потому что мы уже находимся внутри /shell —
  /// обычным go_router'ом сюда не перейти.
  final VoidCallback? onGoToCatalog;
  final bool isBlocked;

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // Моковые данные. На рассмотрении: заказ ожидает отклика исполнителей.
  final List<_OrderMock> _newOrders = <_OrderMock>[
    _OrderMock(
      id: 'n1',
      status: MyOrderStatus.waiting,
      title: 'Нужен экскаватор для копки траншеи',
      equipment: const <String>['Экскаватор'],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: '2 часа назад',
    ),
    _OrderMock(
      id: 'n2',
      status: MyOrderStatus.waiting,
      title: 'Земляные работы',
      equipment: const <String>['Автокран', 'Экскаватор'],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: 'Сегодня в 11:30',
    ),
    _OrderMock(
      id: 'n3',
      status: MyOrderStatus.waiting,
      title: 'Разработка котлована под фундамент',
      equipment: const <String>[
        'Экскаватор',
        'Автокран',
        'Эвакуатор',
        'Манипулятор',
        'Автовышка',
      ],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: 'Сегодня в 11:30',
    ),
  ];

  // Принятые: «Свяжитесь с исполнителем» + один «Завершён».
  final List<_OrderMock> _accepted = <_OrderMock>[
    _OrderMock(
      id: 'a1',
      status: MyOrderStatus.accepted,
      title: 'Нужен экскаватор для копки траншеи',
      equipment: const <String>['Экскаватор'],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: '2 часа назад',
      customerName: 'Иванов Александр',
      customerPhone: '+7 999 123-45-67',
    ),
    _OrderMock(
      id: 'a2',
      status: MyOrderStatus.accepted,
      title: 'Разработка котлована под фундамент',
      equipment: const <String>[
        'Экскаватор',
        'Автокран',
        'Эвакуатор',
        'Манипулятор',
        'Автовышка',
      ],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: 'Сегодня в 11:30',
      customerName: 'Петров Сергей',
      customerPhone: '+7 999 765-43-21',
    ),
    _OrderMock(
      id: 'a3',
      status: MyOrderStatus.completed,
      title: 'Нужен экскаватор для копки траншеи',
      equipment: const <String>['Экскаватор'],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: 'Вчера в 14:30',
      customerName: 'Иванов Александр',
      customerPhone: '+7 999 123-45-67',
    ),
  ];

  final List<_OrderMock> _rejected = <_OrderMock>[
    _OrderMock(
      id: 'r1',
      status: MyOrderStatus.rejectedOther,
      title: 'Земляные работы',
      equipment: const <String>['Автокран', 'Экскаватор'],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: '2 часа назад',
    ),
    _OrderMock(
      id: 'r2',
      status: MyOrderStatus.rejectedDeclined,
      title: 'Разработка котлована под фундамент',
      equipment: const <String>[
        'Экскаватор',
        'Автокран',
        'Эвакуатор',
        'Манипулятор',
        'Автовышка',
      ],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: 'Вчера в 14:30',
    ),
    _OrderMock(
      id: 'r3',
      status: MyOrderStatus.rejectedRemoved,
      title: 'Разработка котлована под фундамент',
      equipment: const <String>[
        'Экскаватор',
        'Автокран',
        'Эвакуатор',
        'Манипулятор',
        'Автовышка',
      ],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: '3 дня назад',
    ),
  ];

  bool get _isEmpty =>
      _newOrders.isEmpty && _accepted.isEmpty && _rejected.isEmpty;

  bool get _blocked => AccountBlock.isBlocked;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    AccountBlock.notifier.addListener(_onBlockChanged);
    // Если профиль уже заблокирован к моменту открытия экрана — сразу
    // убираем активные заказы в архив, чтобы состояние было согласованным.
    if (AccountBlock.isBlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _archiveActiveOrdersOnBlock();
      });
    }
  }

  @override
  void dispose() {
    AccountBlock.notifier.removeListener(_onBlockChanged);
    _tab.dispose();
    super.dispose();
  }

  void _onBlockChanged() {
    if (!mounted) return;
    if (AccountBlock.isBlocked) {
      _archiveActiveOrdersOnBlock();
    } else {
      setState(() {});
    }
  }

  /// Переносит все активные заказы заказчика («Ожидает» + «В работе»,
  /// кроме уже завершённых) в «Архив» со статусом «Заказ был снят
  /// с публикации». Уже архивные заказы остаются на месте.
  void _archiveActiveOrdersOnBlock() {
    setState(() {
      final List<_OrderMock> removed = <_OrderMock>[];
      for (final _OrderMock o in _newOrders) {
        removed.add(o.copyWith(status: MyOrderStatus.rejectedRemoved));
      }
      for (final _OrderMock o in _accepted) {
        if (o.status == MyOrderStatus.completed) continue;
        removed.add(o.copyWith(status: MyOrderStatus.rejectedRemoved));
      }
      _newOrders.clear();
      _accepted.removeWhere((_OrderMock o) => o.status != MyOrderStatus.completed);
      _rejected.insertAll(0, removed);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navBarDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16.w,
        toolbarHeight: 64.h,
        title: Text(
          'Мои заказы',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 28.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.2,
          ),
        ),
      ),
      body: _isEmpty
          ? _EmptyOrders(
              onGoToCatalog: _blocked ? null : widget.onGoToCatalog,
              blocked: _blocked,
            )
          : _buildWithTabs(),
    );
  }

  Widget _buildWithTabs() {
    return Column(
      children: <Widget>[
        Container(
          color: AppColors.background,
          // Сверху 17.h — на 40% больше предыдущих 12. Снизу 5.h:
          // вместе с собственным 12.h первой карточки даёт те же 17.h
          // под пилюлей, чтобы отступы сверху и снизу были одинаковыми.
          padding: EdgeInsets.fromLTRB(16.w, 17.h, 16.w, 5.h),
          child: _OrdersSegmented(
            controller: _tab,
            items: const <String>['Ожидает', 'В работе', 'Архив'],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: <Widget>[
              _buildList(_newOrders),
              _buildList(_accepted),
              _buildList(_rejected),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<_OrderMock> items) {
    if (items.isEmpty) {
      return _EmptyOrders(
        onGoToCatalog: _blocked ? null : widget.onGoToCatalog,
        blocked: _blocked,
      );
    }
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: 24.h),
        itemCount: items.length,
        itemBuilder: (BuildContext context, int i) {
          final _OrderMock o = items[i];
          return Column(
            children: <Widget>[
              MyOrderCard(
                status: o.status,
                title: o.title,
                equipment: o.equipment,
                rentDate: o.rentDate,
                address: o.address,
                publishedAgo: o.publishedAgo,
                customerName: o.customerName,
                customerPhone: o.customerPhone,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MyOrderDetailScreen(
                      title: o.title,
                      equipment: o.equipment,
                      rentDate: o.rentDate,
                      address: o.address,
                      publishedAgo: o.publishedAgo,
                      customerName: o.customerName ?? 'Александр Иванов',
                      customerPhone: o.customerPhone ?? '+7 999 123-45-67',
                      state: _detailStateForCard(o.status),
                      rejectedStatus: o.status,
                      onDecline: () =>
                          _moveToRejected(o, MyOrderStatus.rejectedDeclined),
                      onRefuse: () =>
                          _moveToRejected(o, MyOrderStatus.rejectedDeclined),
                      onConfirm: () => _moveToAccepted(o),
                      isBlocked: widget.isBlocked,
                    ),
                  ),
                ),
                onContact: () =>
                    ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Звоним: ${o.customerName ?? 'исполнителю'}'),
                    duration: const Duration(seconds: 2),
                  ),
                ),
              ),
              Container(
                height: 1 / MediaQuery.of(context).devicePixelRatio,
                color: AppColors.primary,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Перемещает заказ из «Новые/Принятые» в «Не принятые» с заданным
  /// красным статусом. Используется при отклонении и при отказе.
  void _moveToRejected(_OrderMock o, MyOrderStatus newStatus) {
    setState(() {
      _newOrders.remove(o);
      _accepted.remove(o);
      _rejected.insert(0, o.copyWith(status: newStatus));
    });
  }

  /// Перемещает заказ из «Новые» в «Принятые» со статусом
  /// `accepted` («Свяжитесь с заказчиком»). Используется при
  /// подтверждении заказа исполнителем.
  void _moveToAccepted(_OrderMock o) {
    setState(() {
      _newOrders.remove(o);
      _accepted.insert(0, o.copyWith(status: MyOrderStatus.accepted));
    });
  }

  MyOrderDetailState _detailStateForCard(MyOrderStatus s) {
    switch (s) {
      case MyOrderStatus.waiting:
        return MyOrderDetailState.waitingConfirm;
      case MyOrderStatus.accepted:
        return MyOrderDetailState.confirmed;
      case MyOrderStatus.completed:
        return MyOrderDetailState.completed;
      case MyOrderStatus.rejectedOther:
      case MyOrderStatus.rejectedDeclined:
      case MyOrderStatus.rejectedRemoved:
        return MyOrderDetailState.rejected;
    }
  }
}

class _OrderMock {
  const _OrderMock({
    required this.id,
    required this.status,
    required this.title,
    required this.equipment,
    required this.rentDate,
    required this.address,
    required this.publishedAgo,
    this.customerName,
    this.customerPhone,
  });

  final String id;
  final MyOrderStatus status;
  final String title;
  final List<String> equipment;
  final String rentDate;
  final String address;
  final String publishedAgo;
  final String? customerName;
  final String? customerPhone;

  _OrderMock copyWith({MyOrderStatus? status}) {
    return _OrderMock(
      id: id,
      status: status ?? this.status,
      title: title,
      equipment: equipment,
      rentDate: rentDate,
      address: address,
      publishedAgo: publishedAgo,
      customerName: customerName,
      customerPhone: customerPhone,
    );
  }

  // Сравниваем заказы по id — это нужно, чтобы List.remove корректно
  // находил «тот же» заказ после copyWith (после смены статуса заказ
  // лежит в списке как новая копия с тем же id).
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is _OrderMock && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Pill-сегмент «Новые / Принятые / Не принятые». Оранжевая обводка,
/// активный сегмент заливается оранжевым, неактивные — белые, разделены
/// тонкими оранжевыми вертикальными линиями.
class _OrdersSegmented extends StatelessWidget {
  const _OrdersSegmented({
    required this.controller,
    required this.items,
  });

  final TabController controller;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final int index = controller.index;
        final double radius = 22.r;
        return Container(
          height: 40.h,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.primary, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Row(
              // stretch, чтобы GestureDetector каждого сегмента заполнял
              // всю высоту пилюли — иначе кликабельная область становится
              // по высоте текста и края сегмента «не прокликиваются».
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => controller.animateTo(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        alignment: Alignment.center,
                        color: i == index
                            ? AppColors.primary
                            : AppColors.surface,
                        child: Text(
                          items[i],
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            height: 1.3,
                            color: i == index
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Разделитель между сегментами — рисуем только если оба
                  // соседа неактивные (иначе оранжевая заливка активного
                  // и так сливается с бордером).
                  if (i < items.length - 1 &&
                      i != index &&
                      i + 1 != index)
                    Container(
                      width: 1,
                      color: AppColors.primary,
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({this.onGoToCatalog, this.blocked = false});

  final VoidCallback? onGoToCatalog;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 16 в логических пикселях, без .w — чтобы боковой отступ кнопки
      // совпадал с системным отступом FAB ии-ассистента
      // (FloatingActionButtonLocation.endFloat = 16 dp).
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Здесь появятся ваши заказы',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6.h),
          Text(
            'Создайте заказ, чтобы найти\nисполнителя',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16.sp,
              fontWeight: FontWeight.w400,
              height: 1.3,
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 26.h),
          PrimaryButton(
            label: 'Создать заказ',
            enabled: !blocked,
            onPressed: blocked ? null : onGoToCatalog,
          ),
        ],
      ),
    );
  }
}
