import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/orders/create_order_screen.dart';
import 'package:dispatcher_1/features/orders/order_detail_screen.dart';
import 'package:dispatcher_1/features/orders/orders_store.dart';
import 'package:dispatcher_1/features/orders/preview_order_screen.dart';
import 'package:dispatcher_1/features/orders/review_screen.dart';
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
  final List<OrderMock> _newOrders = <OrderMock>[
    OrderMock(
      id: 'n1',
      status: MyOrderStatus.waiting,
      title: 'Нужен экскаватор для копки траншеи',
      equipment: const <String>['Экскаватор'],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: '2 часа назад',
    ),
    OrderMock(
      id: 'n2',
      status: MyOrderStatus.waitingChoose,
      title: 'Земляные работы',
      equipment: const <String>['Автокран', 'Экскаватор'],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: 'Сегодня в 11:30',
    ),
    OrderMock(
      id: 'n3',
      status: MyOrderStatus.waitingChoose,
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
  final List<OrderMock> _accepted = <OrderMock>[
    OrderMock(
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
    OrderMock(
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
    OrderMock(
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

  final List<OrderMock> _rejected = <OrderMock>[
    OrderMock(
      id: 'r1',
      status: MyOrderStatus.rejectedOther,
      title: 'Земляные работы',
      equipment: const <String>['Автокран', 'Экскаватор'],
      rentDate: '15 июня · 09:00–18:00',
      address: 'Московская область, Москва, Улица1, д 144',
      publishedAgo: '2 часа назад',
    ),
    OrderMock(
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
    OrderMock(
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

  int _lastStoreRevision = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    AccountBlock.notifier.addListener(_onBlockChanged);
    _lastStoreRevision = CreatedOrdersStore.revision.value;
    _newOrders.insertAll(0, CreatedOrdersStore.items);
    CreatedOrdersStore.revision.addListener(_onStoreChanged);
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
    CreatedOrdersStore.revision.removeListener(_onStoreChanged);
    _tab.dispose();
    super.dispose();
  }

  /// Забирает из стора только «новые» (ещё не добавленные по id) заказы
  /// и кладёт их в начало списка «Ожидает».
  void _onStoreChanged() {
    if (!mounted) return;
    if (CreatedOrdersStore.revision.value == _lastStoreRevision) return;
    _lastStoreRevision = CreatedOrdersStore.revision.value;
    final Set<String> existing =
        _newOrders.map((OrderMock o) => o.id).toSet();
    final List<OrderMock> fresh = CreatedOrdersStore.items
        .where((OrderMock o) => !existing.contains(o.id))
        .toList();
    if (fresh.isEmpty) return;
    setState(() => _newOrders.insertAll(0, fresh));
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
      final List<OrderMock> removed = <OrderMock>[];
      for (final OrderMock o in _newOrders) {
        removed.add(o.copyWith(status: MyOrderStatus.rejectedRemoved));
      }
      for (final OrderMock o in _accepted) {
        if (o.status == MyOrderStatus.completed) continue;
        removed.add(o.copyWith(status: MyOrderStatus.rejectedRemoved));
      }
      _newOrders.clear();
      _accepted.removeWhere((OrderMock o) => o.status != MyOrderStatus.completed);
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
        actions: <Widget>[
          IconButton(
            onPressed: _blocked
                ? null
                : () => DailyOrderLimit.openCreateOrAlert(context),
            icon: Icon(Icons.add, size: 32.r, color: Colors.white),
            tooltip: 'Создать заказ',
          ),
          SizedBox(width: 8.w),
        ],
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

  Widget _buildList(List<OrderMock> items) {
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
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (BuildContext context, int i) {
          final OrderMock o = items[i];
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
                price: o.price ?? '80 000 – 100 000 ₽',
                onTap: () => _openOrderDetail(context, o),
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

  /// Открывает подробности заказа. Для заказов, созданных заказчиком
  /// из формы, показывается превью в стиле опубликованной карточки
  /// со статусной пилюлей и действиями, подходящими текущему статусу.
  /// Для моковых заказов сохраняется старый экран с логикой
  /// подтверждения/отказа.
  void _openOrderDetail(BuildContext context, OrderMock o) {
    final bool isUserCreated = o.number != null;
    if (isUserCreated) {
      final OrderDraft draft = OrderDraft(
        number: o.number!,
        title: o.title,
        description: o.description,
        budget: o.price ?? '',
        rentDate: o.rentDate,
        address: o.address,
        machinery: o.equipment,
        categories: o.categories,
        works: o.works,
        photos: o.photos,
      );
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext ctx) => CreateOrderPreviewScreen(
            draft: draft,
            status: o.status,
            onPickAnother: () {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Выбор другого исполнителя — скоро'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            onMoveToArchive: () {
              _moveToRejected(o, MyOrderStatus.rejectedRemoved);
              Navigator.of(ctx).maybePop();
            },
            onLeaveReview: () => Navigator.of(ctx).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const ReviewScreen(),
              ),
            ),
            onRepublish: () {
              setState(() {
                _rejected.remove(o);
                _newOrders.insert(
                  0,
                  o.copyWith(status: MyOrderStatus.waiting),
                );
              });
              Navigator.of(ctx).maybePop();
            },
            onEditRemoved: () {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Редактирование заказа — скоро'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push<void>(
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
          waitingStatus: o.status,
          onDecline: () =>
              _moveToRejected(o, MyOrderStatus.rejectedDeclined),
          onRefuse: () => _moveToRejected(o, MyOrderStatus.rejectedDeclined),
          onConfirm: () => _moveToAccepted(o),
          isBlocked: widget.isBlocked,
        ),
      ),
    );
  }

  /// Перемещает заказ из «Новые/Принятые» в «Не принятые» с заданным
  /// красным статусом. Используется при отклонении и при отказе.
  void _moveToRejected(OrderMock o, MyOrderStatus newStatus) {
    setState(() {
      _newOrders.remove(o);
      _accepted.remove(o);
      _rejected.insert(0, o.copyWith(status: newStatus));
    });
  }

  /// Перемещает заказ из «Новые» в «Принятые» со статусом
  /// `accepted` («Свяжитесь с заказчиком»). Используется при
  /// подтверждении заказа исполнителем.
  void _moveToAccepted(OrderMock o) {
    setState(() {
      _newOrders.remove(o);
      _accepted.insert(0, o.copyWith(status: MyOrderStatus.accepted));
    });
  }

  MyOrderDetailState _detailStateForCard(MyOrderStatus s) {
    switch (s) {
      case MyOrderStatus.waiting:
      case MyOrderStatus.waitingChoose:
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
            onPressed: blocked
                ? null
                : () => DailyOrderLimit.openCreateOrAlert(context),
          ),
        ],
      ),
    );
  }
}
