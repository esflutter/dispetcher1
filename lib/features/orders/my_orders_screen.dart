import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/auth/photo_crop_screen.dart';
import 'package:dispatcher_1/features/orders/create_order_screen.dart';
import 'package:dispatcher_1/features/orders/order_detail_screen.dart';
import 'package:dispatcher_1/features/orders/orders_store.dart';
import 'package:dispatcher_1/features/orders/preview_order_screen.dart';
import 'package:dispatcher_1/features/orders/review_screen.dart';
import 'package:dispatcher_1/features/orders/select_executor_screen.dart';
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

  // Все моки и мутации теперь живут в [MyOrdersStore]. Экран просто
  // подписывается на его revision и перерисовывается при изменении.
  // Это нужно, чтобы данные были общими со «Выбор заказа для
  // исполнителя» и другими местами, которые должны видеть те же
  // заказы.

  bool get _isEmpty =>
      MyOrdersStore.newOrders.isEmpty &&
      MyOrdersStore.accepted.isEmpty &&
      MyOrdersStore.rejected.isEmpty;

  /// «В работе» — принятые исполнителем заказы, ещё не завершённые.
  List<OrderMock> get _inWorkList => _sortedByDate(MyOrdersStore.inWork);

  /// «Архив» — отклонённые/снятые заказы + все завершённые.
  List<OrderMock> get _archiveList => _sortedByDate(MyOrdersStore.archive);

  /// «Ожидает» — все неактивные заказы из стора, от новых к старым.
  List<OrderMock> get _newOrdersList =>
      _sortedByDate(MyOrdersStore.newOrders);

  /// Сортирует список заказов от новых к старым по [OrderMock.publishedAt].
  /// Возвращает копию — исходный список не мутируется.
  List<OrderMock> _sortedByDate(List<OrderMock> list) {
    final List<OrderMock> copy = List<OrderMock>.of(list);
    copy.sort(
        (OrderMock a, OrderMock b) => b.publishedAt.compareTo(a.publishedAt));
    return copy;
  }

  bool get _blocked => AccountBlock.isBlocked;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    AccountBlock.notifier.addListener(_onBlockChanged);
    MyOrdersStore.revision.addListener(_onStoreChanged);
    // Если профиль уже заблокирован к моменту открытия экрана — сразу
    // убираем активные заказы в архив, чтобы состояние было согласованным.
    if (AccountBlock.isBlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        MyOrdersStore.archiveActiveOrdersOnBlock();
      });
    }
  }

  @override
  void dispose() {
    AccountBlock.notifier.removeListener(_onBlockChanged);
    MyOrdersStore.revision.removeListener(_onStoreChanged);
    _tab.dispose();
    super.dispose();
  }

  /// На любые изменения в сторе — просто перерисовываем. Списки
  /// отдаются через геттеры, которые каждый раз читают актуальное
  /// состояние стора.
  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _onBlockChanged() {
    if (!mounted) return;
    if (AccountBlock.isBlocked) {
      MyOrdersStore.archiveActiveOrdersOnBlock();
    } else {
      DailyOrderLimit.resetToday();
      MyOrdersStore.restoreActiveOrdersOnUnblock();
    }
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
              _buildList(_newOrdersList),
              _buildList(_inWorkList),
              _buildList(_archiveList),
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
      removeBottom: true,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (BuildContext context, int i) {
          final OrderMock o = items[i];
          final bool isLast = i == items.length - 1;
          return Column(
            children: <Widget>[
              MyOrderCard(
                status: o.status,
                // Счётчик откликов показываем в статусах, где заказчик
                // выбирает/перевыбирает исполнителя из списка откликов.
                // В «accepted» и остальных статусах исполнитель уже
                // один — (N) не имеет смысла.
                statusCount: (o.status == MyOrderStatus.waitingChoose ||
                        o.status == MyOrderStatus.executorDeclined)
                    ? o.respondersCount
                    : null,
                title: o.title,
                equipment: o.equipment,
                rentDate: o.rentDate,
                address: o.address,
                publishedAgo: o.publishedAgo,
                customerName: o.customerName,
                customerPhone: o.customerPhone,
                price: o.price ?? '80 000 – 100 000 ₽',
                onTap: () => _openOrderDetail(context, o),
                onContact: () => _dialPhone(o.customerPhone),
              ),
              if (!isLast)
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

  /// Обработчик «Выбрать другого исполнителя» для статуса
  /// `awaitingExecutor`. Сначала закрываем открытый экран (превью или
  /// детали), затем дергаем стор: если есть другие отклики — открываем
  /// список откликнувшихся; если нет — переключаемся на вкладку
  /// «Каталог», чтобы заказчик сам нашёл исполнителя.
  void _handlePickAnotherFromAwaiting(
    BuildContext screenCtx,
    OrderMock o,
  ) {
    Navigator.of(screenCtx).maybePop();
    final MyOrderStatus newStatus =
        MyOrdersStore.pickAnotherFromAwaiting(o);
    final OrderMock updated = MyOrdersStore.newOrders.firstWhere(
      (OrderMock x) => x.id == o.id,
      orElse: () => o.copyWith(status: newStatus),
    );
    if (newStatus == MyOrderStatus.waiting) {
      widget.onGoToCatalog?.call();
    } else {
      _openOrderDetail(context, updated);
    }
  }

  /// Открывает подробности заказа. Для заказов, созданных заказчиком
  /// из формы, показывается превью в стиле опубликованной карточки
  /// со статусной пилюлей и действиями, подходящими текущему статусу.
  /// Для моковых заказов сохраняется старый экран с логикой
  /// подтверждения/отказа.
  void _openOrderDetail(BuildContext context, OrderMock o) {
    // Статусы, в которых заказчик должен выбрать исполнителя («пришли
    // отклики» и «предыдущий исполнитель отказался»), всегда ведут на
    // экран со списком откликнувшихся — вне зависимости от того, создан
    // ли заказ пользователем или взят из мока.
    if (o.status == MyOrderStatus.waitingChoose ||
        o.status == MyOrderStatus.executorDeclined) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext ctx) => SelectExecutorScreen(
            order: o,
            onMoveToArchive: () {
              MyOrdersStore.moveToRejected(
                  o, MyOrderStatus.rejectedDeclined);
              Navigator.of(ctx).maybePop();
            },
            onExecutorSelected: (String _, String name, String phone) {
              // Закрываем экран выбора исполнителя, переводим заказ
              // в «accepted» с контактами выбранного исполнителя и
              // сразу открываем его детали в новом статусе. Берём
              // объект из `_accepted` (куда его только что положил
              // _moveToAccepted), а не локальную copyWith — иначе
              // дальнейшие обновления (reviewLeft через callback)
              // уходили бы в отвязанную копию.
              Navigator.of(ctx).maybePop();
              MyOrdersStore.moveToAccepted(o, name: name, phone: phone);
              final OrderMock updated = MyOrdersStore.accepted.firstWhere(
                (OrderMock x) => x.id == o.id,
                orElse: () => o.copyWith(
                  status: MyOrderStatus.accepted,
                  customerName: name,
                  customerPhone: phone,
                ),
              );
              _openOrderDetail(context, updated);
            },
          ),
        ),
      );
      return;
    }
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
            reviewLeft: o.reviewLeft,
            onOpenCatalog: () {
              Navigator.of(ctx).maybePop();
              widget.onGoToCatalog?.call();
            },
            onPickAnother: () => _handlePickAnotherFromAwaiting(ctx, o),
            onMoveToArchive: () {
              MyOrdersStore.moveToRejected(o, MyOrderStatus.rejectedDeclined);
              Navigator.of(ctx).maybePop();
            },
            onLeaveReview: () async {
              final bool? submitted =
                  await Navigator.of(ctx).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => const ReviewScreen(),
                ),
              );
              if (submitted == true && mounted) {
                MyOrdersStore.markReviewLeft(o.id);
                // Закрываем превью, чтобы при следующем открытии экран
                // сразу собрался уже без кнопки «Оставить отзыв».
                if (ctx.mounted) Navigator.of(ctx).maybePop();
              }
            },
            onRepublish: () {
              MyOrdersStore.republish(o);
              Navigator.of(ctx).maybePop();
            },
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => MyOrderDetailScreen(
          title: o.title,
          equipment: o.equipment,
          rentDate: o.rentDate,
          address: o.address,
          publishedAgo: o.publishedAgo,
          customerName: o.customerName ?? CropResult.namePlaceholder,
          customerPhone: o.customerPhone ?? '+7 999 123-45-67',
          customerEmail: o.customerEmail,
          state: _detailStateForCard(o.status),
          rejectedStatus: o.status,
          waitingStatus: o.status,
          onDecline: () => MyOrdersStore.moveToRejected(
              o, MyOrderStatus.rejectedDeclined),
          onRefuse: () => MyOrdersStore.moveToRejected(
              o, MyOrderStatus.rejectedDeclined),
          onConfirm: () => MyOrdersStore.moveToAccepted(o),
          isBlocked: widget.isBlocked,
          reviewLeft: o.reviewLeft,
          onReviewLeft: () => MyOrdersStore.markReviewLeft(o.id),
          onPickAnother: () => _handlePickAnotherFromAwaiting(ctx, o),
        ),
      ),
    );
  }

  /// Открывает системный номеронабиратель с предзаполненным номером.
  /// Не звонит автоматически — пользователю нужно нажать кнопку вызова
  /// в самом приложении телефона. Используется `tel:`-схема, это
  /// стандартное поведение и на iOS, и на Android.
  Future<void> _dialPhone(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    // Оставляем только цифры и плюс — пробелы и дефисы номеронабиратель
    // не портят, но некоторые лаунчеры капризничают.
    final String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri uri = Uri.parse('tel:$cleaned');
    final bool ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть приложение телефона'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  MyOrderDetailState _detailStateForCard(MyOrderStatus s) {
    switch (s) {
      case MyOrderStatus.waiting:
      case MyOrderStatus.awaitingExecutor:
      case MyOrderStatus.waitingChoose:
      case MyOrderStatus.executorDeclined:
      case MyOrderStatus.executorDeclinedWaiting:
        return MyOrderDetailState.waitingConfirm;
      case MyOrderStatus.accepted:
        return MyOrderDetailState.confirmed;
      case MyOrderStatus.completed:
        return MyOrderDetailState.completed;
      case MyOrderStatus.rejectedOther:
      case MyOrderStatus.rejectedDeclined:
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
