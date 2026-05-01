import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/customer_orders/customer_orders_service.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/utils/phone_dial.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/orders/create_order_screen.dart';
import 'package:dispatcher_1/features/orders/order_detail_screen.dart';
import 'package:dispatcher_1/features/orders/orders_store.dart';
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
  final ScrollController _waitingScrollCtrl = ScrollController();

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
    copy.sort((OrderMock a, OrderMock b) =>
        b.statusUpdatedAt.compareTo(a.statusUpdatedAt));
    return copy;
  }

  bool get _blocked => AccountBlock.isBlocked;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    AccountBlock.notifier.addListener(_onBlockChanged);
    MyOrdersStore.revision.addListener(_onStoreChanged);
    MyOrdersStore.onError = _onStoreError;
    // Подгружаем свои заказы из БД. Первый вызов также почистит
    // initial-моки; повторные — просто дольют новые записи.
    MyOrdersStore.loadFromDb();
    DailyOrderLimit.primeFromSettings();
    // Сбрасываем локальный счётчик дневного лимита и считаем его
    // заново из БД — иначе после рестарта приложения пользователь
    // мог снова создавать 30 заказов, а серверный триггер отбивал
    // лишь после `INSERT` уже заполненной формы.
    DailyOrderLimit.primeCountFromDb();
    // Авто-снятие просроченного блока. `isBlocked` теперь чистый
    // getter без побочных эффектов, поэтому проверяем срок раз в
    // минуту здесь.
    AccountBlock.tickExpiry();
    _blockExpiryTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => AccountBlock.tickExpiry(),
    );
    if (AccountBlock.isBlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        MyOrdersStore.archiveActiveOrdersOnBlock();
      });
    }
  }

  Timer? _blockExpiryTimer;

  void _onStoreError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Сервер не принял изменение: $e')),
    );
  }

  @override
  void dispose() {
    AccountBlock.notifier.removeListener(_onBlockChanged);
    MyOrdersStore.revision.removeListener(_onStoreChanged);
    if (MyOrdersStore.onError == _onStoreError) {
      MyOrdersStore.onError = null;
    }
    _blockExpiryTimer?.cancel();
    _tab.dispose();
    _waitingScrollCtrl.dispose();
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
      // restoreActiveOrdersOnUnblock теперь возвращает Future (внутри
      // loadFromDb). Запускаем fire-and-forget — UI обновится через
      // `MyOrdersStore.revision` listener.
      unawaited(MyOrdersStore.restoreActiveOrdersOnUnblock());
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
          // Плюсик нужен только когда уже есть хотя бы один заказ —
          // в empty-state создание заказа делается через большую
          // кнопку «Создать заказ» в центре экрана, дублировать её
          // плюсиком в шапке избыточно.
          if (!_isEmpty) ...<Widget>[
            IconButton(
              onPressed: _blocked
                  ? null
                  : () async {
                      final int before = MyOrdersStore.newOrders.length;
                      await DailyOrderLimit.openCreateOrAlert(context);
                      if (!mounted) return;
                      if (MyOrdersStore.newOrders.length > before) {
                        _tab.animateTo(0);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_waitingScrollCtrl.hasClients) {
                            _waitingScrollCtrl.animateTo(
                              0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        });
                      }
                    },
              icon: Icon(Icons.add, size: 32.r, color: Colors.white),
              tooltip: 'Создать заказ',
            ),
            SizedBox(width: 8.w),
          ],
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
              _buildList(_newOrdersList, scrollCtrl: _waitingScrollCtrl),
              _buildList(_inWorkList),
              _buildList(_archiveList),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<OrderMock> items, {ScrollController? scrollCtrl}) {
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
        controller: scrollCtrl,
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
                reviewLeft: o.reviewLeft,
                title: o.title,
                equipment: o.equipment,
                rentDate: o.rentDate,
                address: o.address,
                timeAgo: o.timeAgo,
                customerName: o.customerName,
                customerPhone: o.customerPhone,
                customerAvatar: o.customerAvatarUrl,
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

  /// «Выбрать другого исполнителя» / «Перейти в каталог»: отзываем
  /// текущий awaiting-мэтч в БД, закрываем экран и переключаемся на
  /// каталог. Раньше переход в каталог не сопровождался UPDATE'ом —
  /// старый мэтч оставался в `awaiting_executor` навечно: исполнитель
  /// видел «призрачное» предложение в своих откликах, а заказчик
  /// продолжал считать заказ «выбран другой».
  Future<void> _handlePickAnotherFromAwaiting(
      BuildContext screenCtx, OrderMock o) async {
    final String? matchId = o.matchId;
    if (matchId != null) {
      try {
        await CustomerOrdersService.instance.rejectResponse(matchId);
      } catch (_) {/* пусть UI продолжит — следующая загрузка из БД
        синхронизирует статус */}
    }
    if (!screenCtx.mounted) return;
    Navigator.of(screenCtx).maybePop();
    widget.onGoToCatalog?.call();
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
            onExecutorSelected: (
              String matchId,
              String name,
              String executorId,
              String? avatarUrl,
            ) {
              // Заказчик принял откликнувшегося — БД переводит мэтч
              // в `accepted` (CustomerOrdersService.acceptResponse).
              // Локально сразу ставим тот же статус, чтобы заказ
              // переехал в «В работе» без ожидания следующего
              // `loadFromDb`.
              MyOrdersStore.acceptResponse(o,
                  name: name,
                  phone: '',
                  avatarUrl: avatarUrl,
                  matchId: matchId,
                  executorId: executorId);
              final OrderMock updated = MyOrdersStore.newOrders.firstWhere(
                (OrderMock x) => x.id == o.id,
                orElse: () => o.copyWith(
                  status: MyOrderStatus.accepted,
                  customerName: name,
                  customerPhone: '',
                  matchId: matchId,
                  executorId: executorId,
                ),
              );
              _swapToAcceptedOrderDetail(updated);
            },
          ),
        ),
      );
      return;
    }
    // Все заказы из БД имеют `display_number` → ветка с моковыми
    // заказами без номера давно мертва. Открываем единственный экран
    // деталей.
    final OrderDraft draft = OrderDraft(
      number: o.displayNumber,
      title: o.title,
      description: o.description,
      rentDate: o.rentDate,
      address: o.address,
      machinery: o.equipment,
      categories: o.categories,
      works: o.works,
      photos: o.photos,
    );
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => OrderDetailScreen(
          draft: draft,
          status: o.status,
          reviewLeft: o.reviewLeft,
          executorId: o.executorId,
          executorName: o.customerName,
          executorAvatarUrl: o.customerAvatarUrl,
          executorPhone: o.customerPhone,
          executorEmail: o.customerEmail,
          executorRating: o.executorRating,
          executorReviewCount: o.executorReviewCount,
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
                builder: (_) => ReviewScreen(
                  targetUserId: o.executorId,
                  matchId: o.matchId,
                ),
              ),
            );
            if (submitted == true && mounted) {
              MyOrdersStore.markReviewLeft(o.id);
              // Перезапрашиваем заказы из БД — триггер на reviews уже
              // обновил `profiles.rating_as_executor` и
              // `review_count_as_executor`, и без свежей загрузки в
              // кэше OrderMock останутся старые executorRating=0/
              // reviewCount=0, и шапка отзыва на следующем открытии
              // покажет «0 отзывов» рядом с реально оставленным
              // отзывом.
              await MyOrdersStore.loadFromDb();
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
  }

  /// После выбора исполнителя атомарно снимает всю цепочку экранов
  /// выбора (SelectExecutorScreen → карточка исполнителя → услуги) и
  /// пушит карточку принятого заказа. pushAndRemoveUntil гарантирует,
  /// что состояния «на экране SelectExecutor» нет вообще — «назад» с
  /// карточки принятого заказа ведёт сразу в список «Мои заказы».
  void _swapToAcceptedOrderDetail(OrderMock o) {
    if (!mounted) return;
    final OrderDraft draft = OrderDraft(
      number: o.displayNumber,
      title: o.title,
      description: o.description,
      rentDate: o.rentDate,
      address: o.address,
      machinery: o.equipment,
      categories: o.categories,
      works: o.works,
      photos: o.photos,
    );
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => OrderDetailScreen(
          draft: draft,
          status: o.status,
          reviewLeft: o.reviewLeft,
          executorId: o.executorId,
          executorName: o.customerName,
          executorAvatarUrl: o.customerAvatarUrl,
          executorPhone: o.customerPhone,
          executorEmail: o.customerEmail,
          executorRating: o.executorRating,
          executorReviewCount: o.executorReviewCount,
          onPickAnother: () => _handlePickAnotherFromAwaiting(ctx, o),
          onMoveToArchive: () {
            MyOrdersStore.moveToRejected(o, MyOrderStatus.rejectedDeclined);
            Navigator.of(ctx).maybePop();
          },
          onLeaveReview: () async {
            final bool? submitted = await Navigator.of(ctx).push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => ReviewScreen(
                  targetUserId: o.executorId,
                  matchId: o.matchId,
                ),
              ),
            );
            if (submitted == true && mounted) {
              MyOrdersStore.markReviewLeft(o.id);
              await MyOrdersStore.loadFromDb();
              if (ctx.mounted) Navigator.of(ctx).maybePop();
            }
          },
          onRepublish: () {
            MyOrdersStore.republish(o);
            Navigator.of(ctx).maybePop();
          },
          onOpenCatalog: () {
            Navigator.of(ctx).maybePop();
            widget.onGoToCatalog?.call();
          },
        ),
      ),
      (Route<dynamic> r) => r.isFirst,
    );
  }

  Future<void> _dialPhone(String? phone) => dialPhone(context, phone);
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
