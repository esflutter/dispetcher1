import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/ai/ai_navigation.dart';
import 'package:dispatcher_1/core/customer_orders/customer_orders_service.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/utils/phone_dial.dart';
import 'package:dispatcher_1/core/utils/photo_source.dart';
import 'package:dispatcher_1/core/utils/plural.dart';
import 'package:dispatcher_1/core/widgets/avatar_circle.dart';
import 'package:dispatcher_1/core/widgets/clickable_address.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/dialog_close_button.dart';
import 'package:dispatcher_1/features/orders/orders_store.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/executor_card_view_screen.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';
import 'package:dispatcher_1/features/orders/widgets/order_alerts.dart';
import 'package:dispatcher_1/features/orders/widgets/order_status_pill.dart';
import 'package:dispatcher_1/features/profile/reviews_screen.dart';

/// Данные черновика заказа, которые передаются в предварительный
/// просмотр перед публикацией. Все поля отформатированы для показа.
/// Необязательные поля передаются в виде пустых коллекций/строк —
/// preview сам скроет блок, если он пуст.
class OrderDraft {
  const OrderDraft({
    required this.number,
    required this.title,
    required this.description,
    required this.rentDate,
    required this.address,
    required this.machinery,
    required this.categories,
    required this.works,
    required this.photos,
  });

  /// Номер заказа вида `№123456`.
  final String number;
  final String title;

  /// Текст описания. Может быть пустым — тогда блок не показывается.
  final String description;

  /// Готовая строка «15 июня · 09:00–18:00».
  final String rentDate;
  final String address;

  final List<String> machinery;
  final List<String> categories;

  /// Строки вида «Разработка грунта — 40 м³».
  final List<String> works;

  /// Пути ассетов к приложенным фото.
  final List<String> photos;
}

/// Экран предпросмотра заказа. Используется и перед публикацией
/// (`status == null`, режим создания с кнопками «Опубликовать /
/// Редактировать»), и при просмотре уже опубликованного заказа
/// (`status != null`, набор кнопок зависит от статуса).
///
/// Необязательные блоки (Описание, Характер работ, Фото) показываются,
/// только если заполнены.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.draft,
    this.orderId,
    this.status,
    this.reviewLeft = false,
    this.onPickAnother,
    this.onMoveToArchive,
    this.onLeaveReview,
    this.onRepublish,
    this.onOpenCatalog,
    this.executorId,
    this.executorName,
    this.executorAvatarUrl,
    this.executorPhone,
    this.executorEmail,
    this.executorRating = 0,
    this.executorReviewCount = 0,
  });

  final OrderDraft draft;

  /// DB-id заказа (для live-обновления статуса по realtime из стора). Если
  /// null — экран статичен (например, превью до публикации).
  final String? orderId;

  /// Данные исполнителя по best-мэтчу. Если `executorId` непустой —
  /// под пилюлей статуса показывается шапка с аватаром, именем,
  /// рейтингом и кликабельными «N отзывов»; справа — кнопка вызова
  /// (только в `accepted`). Ниже — секции «Номер телефона» и
  /// «Электронная почта», когда соответствующие поля заполнены
  /// (RLS на `profiles_private` пропускает их только для accepted/
  /// completed мэтчей).
  final String? executorId;
  final String? executorName;
  final String? executorAvatarUrl;
  final String? executorPhone;
  final String? executorEmail;
  final double executorRating;
  final int executorReviewCount;

  /// Статус опубликованного заказа. `null` — режим создания заказа
  /// (до публикации), показываются кнопки «Опубликовать / Редактировать».
  final MyOrderStatus? status;

  /// Был ли уже оставлен отзыв по этому заказу. Если `true`, кнопка
  /// «Оставить отзыв» в статусе [MyOrderStatus.completed] не показывается.
  final bool reviewLeft;

  /// Колбэк «Выбрать другого исполнителя» — для waiting/waitingChoose/
  /// accepted.
  final VoidCallback? onPickAnother;

  /// Колбэк «Переместить в архив» — для waiting/waitingChoose/accepted.
  final VoidCallback? onMoveToArchive;

  /// Колбэк «Оставить отзыв» — для completed.
  final VoidCallback? onLeaveReview;

  /// Колбэк «Опубликовать заново» — для rejectedDeclined.
  final VoidCallback? onRepublish;

  /// Колбэк «Перейти в каталог» — для waiting, когда откликов ещё нет
  /// и заказчику предлагается поискать исполнителей самостоятельно.
  final VoidCallback? onOpenCatalog;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  /// Подгруженные из БД контакты исполнителя — RLS-политика
  /// `profiles_private_select_self_or_matched` пропускает их только
  /// заказчику, у которого есть accepted/completed-мэтч с этим
  /// исполнителем. Локальный кэш `OrderMock` после нажатия «Выбрать
  /// исполнителя» содержит только matchId/executorId, телефон/email
  /// заказчику ещё не виден — догружаем здесь.
  String? _dbExecutorPhone;
  String? _dbExecutorEmail;

  /// Live-статус: при realtime-изменении заказа (исполнитель принял/отклонил,
  /// заказ завершился) обновляется из стора, перебивая исходный widget.status.
  MyOrderStatus? _liveStatus;
  MyOrderStatus? get _status => _liveStatus ?? widget.status;

  /// Идёт RPC ручного завершения заказа — блокируем повторные тапы по
  /// «Отметить выполненным», пока запрос летит.
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    final MyOrderStatus? s = widget.status;
    final bool needContacts =
        (s == MyOrderStatus.accepted || s == MyOrderStatus.completed) &&
            (widget.executorPhone == null ||
                widget.executorPhone!.trim().isEmpty);
    if (needContacts &&
        widget.executorId != null &&
        widget.executorId!.isNotEmpty) {
      _loadContacts();
    }
    // Live-обновление ОТКРЫТОГО экрана: стор обновляется по realtime —
    // переискиваем свой заказ и обновляем статус на месте.
    if (widget.orderId != null) {
      MyOrdersStore.revision.addListener(_onStoreRevision);
    }
  }

  @override
  void dispose() {
    MyOrdersStore.revision.removeListener(_onStoreRevision);
    super.dispose();
  }

  /// Актуальный снимок своего заказа из стора (по widget.orderId) — стор
  /// обновляется по realtime, поэтому matchId/даты здесь свежее, чем
  /// параметры, переданные при открытии экрана. `null` — заказ не найден
  /// (например, экран открыт как превью до публикации).
  OrderMock? _findInStore() {
    final String? id = widget.orderId;
    if (id == null) return null;
    for (final List<OrderMock> bucket in <List<OrderMock>>[
      MyOrdersStore.newOrders, MyOrdersStore.accepted, MyOrdersStore.inWork,
      MyOrdersStore.archive, MyOrdersStore.rejected,
    ]) {
      for (final OrderMock o in bucket) {
        if (o.id == id) return o;
      }
    }
    return null;
  }

  /// Realtime поднял revision стора — ищем свой заказ и, если статус сменился,
  /// обновляем экран и догружаем контакты (на случай перехода в «принят»).
  void _onStoreRevision() {
    if (!mounted) return;
    final OrderMock? found = _findInStore();
    if (found == null) return;
    if (found.status == _status) return;
    setState(() => _liveStatus = found.status);
    if ((found.status == MyOrderStatus.accepted ||
            found.status == MyOrderStatus.completed) &&
        (_dbExecutorPhone == null || _dbExecutorPhone!.isEmpty) &&
        widget.executorId != null &&
        widget.executorId!.isNotEmpty) {
      _loadContacts();
    }
  }

  Future<void> _loadContacts() async {
    try {
      final ({String? phone, String? email})? c = await CustomerOrdersService
          .instance
          .getExecutorContacts(widget.executorId!);
      if (!mounted || c == null) return;
      setState(() {
        _dbExecutorPhone = c.phone;
        _dbExecutorEmail = c.email;
      });
    } catch (_) {/* RLS не пустил — UI оставит пустой блок контактов */}
  }

  String? get _effectivePhone {
    final String? db = _dbExecutorPhone;
    if (db != null && db.trim().isNotEmpty) return db;
    return widget.executorPhone;
  }

  String? get _effectiveEmail {
    final String? db = _dbExecutorEmail;
    if (db != null && db.trim().isNotEmpty) return db;
    return widget.executorEmail;
  }

  @override
  Widget build(BuildContext context) {
    // Локальные алиасы — чтобы тело build-метода почти один-в-один
    // совпадало с прежним StatelessWidget. Это убирает шум `widget.X`
    // на каждой строке и облегчает сверку с Figma-эталоном.
    final OrderDraft draft = widget.draft;
    final MyOrderStatus? status = _status;
    final bool reviewLeft = widget.reviewLeft;
    final String? executorId = widget.executorId;
    final String? executorName = widget.executorName;
    final String? executorAvatarUrl = widget.executorAvatarUrl;
    final String? executorPhone = _effectivePhone;
    final String? executorEmail = _effectiveEmail;
    final double executorRating = widget.executorRating;
    final int executorReviewCount = widget.executorReviewCount;

    final List<Widget> sections = <Widget>[];

    void addSection(String title, Widget child) {
      if (sections.isNotEmpty) sections.add(SizedBox(height: 16.h));
      sections.add(_Section(title: title, child: child));
    }

    // Порядок секций совпадает со стандартной карточкой заказа
    // (MyOrderDetailScreen): Дата → Адрес → Описание → Спецтехника →
    // Категория → Характер работ → Фото. Описание и фото опциональные —
    // показываются только если заполнены.
    addSection(
      'Дата и время аренды',
      Text(
        draft.rentDate,
        style: AppTextStyles.body.copyWith(fontSize: 14.sp, height: 1.4),
      ),
    );

    addSection(
      'Адрес',
      ClickableAddress(
        draft.address,
        baseStyle:
            AppTextStyles.body.copyWith(fontSize: 14.sp, height: 1.4),
      ),
    );

    if (draft.description.trim().isNotEmpty) {
      addSection(
        'Описание заказа',
        Text(
          draft.description,
          style: AppTextStyles.body.copyWith(fontSize: 14.sp, height: 1.4),
        ),
      );
    }

    if (draft.machinery.isNotEmpty) {
      addSection('Требуемая спецтехника', _ChipRow(items: draft.machinery));
    }

    if (draft.works.isNotEmpty) {
      addSection(
        'Характер работ',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final String w in draft.works)
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Text(
                  w,
                  style: AppTextStyles.body
                      .copyWith(fontSize: 14.sp, height: 1.4),
                ),
              ),
          ],
        ),
      );
    }

    if (draft.photos.isNotEmpty) {
      addSection('Фото', _PhotosGrid(photos: draft.photos));
    }

    final List<Widget> bottomButtons = _buildBottomButtons(context);
    final bool hasBottomBar = bottomButtons.isNotEmpty;
    final double fabBottom = !hasBottomBar
        ? 24.h
        : (bottomButtons.length == 1 ? 88.h : 148.h);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: DarkSubAppBar(title: draft.title),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: fabBottom),
        child: AiAssistantFab(onTap: () => openAssistantChat(context)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              // Нижний отступ зависит от наличия панели кнопок: если
              // кнопки есть — отбиваемся от их верхнего края (16.h),
              // т.к. сама панель уже учитывает системный safe-area.
              // Если кнопок нет — добавляем safe-area сюда, иначе
              // последняя секция уезжает под жесты/навбар.
              padding: EdgeInsets.fromLTRB(
                16.w,
                16.h,
                16.w,
                hasBottomBar
                    ? 16.h
                    : 16.h + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (status != null) ...<Widget>[
                    Center(
                      child: OrderStatusPill(
                        status: status,
                        reviewLeft: reviewLeft,
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],
                  // Терминальные «негативные» статусы — заказ закрыт без
                  // исполнителя (cron auto-expire или заказчик отменил).
                  // Даже если у best-мэтча есть executor_id (от expired-
                  // отклика), показывать его контакты бессмысленно: RLS
                  // на profiles_private его не пропустит, а в кэше
                  // MyOrdersStore могли остаться старые phone/email
                  // от предыдущего accepted-периода.
                  if (executorId != null &&
                      executorId.isNotEmpty &&
                      status != MyOrderStatus.rejectedOther &&
                      status != MyOrderStatus.rejectedDeclined) ...<Widget>[
                    _ExecutorHeader(
                      name: executorName ?? '',
                      avatarUrl: executorAvatarUrl,
                      rating: executorRating,
                      reviewCount: executorReviewCount,
                      // Тап по аватару/имени открывает полную карточку
                      // исполнителя (та же, что в каталоге) — заказчик
                      // может посмотреть его услуги, отзывы, услуги.
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ExecutorCardViewScreen(executorId: executorId),
                        ),
                      ),
                      onCall: status == MyOrderStatus.accepted &&
                              executorPhone != null &&
                              executorPhone.trim().isNotEmpty
                          ? () => dialPhone(context, executorPhone)
                          : null,
                      onReviewsTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReviewsScreen(
                            subject: ReviewSubject.executor,
                            targetUserId: executorId,
                            initialRating: executorRating,
                            initialCount: executorReviewCount,
                          ),
                        ),
                      ),
                    ),
                    // Контакты исполнителя раскрываем только после
                    // мэтча (accepted/completed). До этого, в т.ч. в
                    // awaitingExecutor / awaitingCustomer, контакты
                    // могут оставаться в локальном кэше от предыдущего
                    // accepted-состояния — и без явной проверки статуса
                    // пользователь видел бы телефон и email уже на
                    // «Ждёт подтверждения», что нарушает RLS-семантику.
                    if ((status == MyOrderStatus.accepted ||
                            status == MyOrderStatus.completed) &&
                        executorPhone != null &&
                        executorPhone.trim().isNotEmpty) ...<Widget>[
                      SizedBox(height: 12.h),
                      Text(
                        'Номер телефона',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        executorPhone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subBody
                            .copyWith(fontWeight: FontWeight.w400),
                      ),
                    ],
                    if ((status == MyOrderStatus.accepted ||
                            status == MyOrderStatus.completed) &&
                        executorEmail != null &&
                        executorEmail.trim().isNotEmpty) ...<Widget>[
                      SizedBox(height: 12.h),
                      Text(
                        'Электронная почта',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        executorEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subBody
                            .copyWith(fontWeight: FontWeight.w400),
                      ),
                    ],
                    SizedBox(height: 12.h),
                  ],
                  Text(
                    draft.number,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    draft.title,
                    textAlign: TextAlign.left,
                    style: AppTextStyles.titleL.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  ...sections,
                ],
              ),
            ),
          ),
          if (hasBottomBar)
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                16.w,
                12.h,
                16.w,
                16.h + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: bottomButtons,
              ),
            ),
        ],
      ),
    );
  }

  /// Обёртка над `onMoveToArchive`: показывает подтверждающий диалог и
  /// только при нажатии «Переместить в архив» вызывает исходный колбэк.
  void _confirmMoveToArchive(BuildContext context) {
    final VoidCallback? cb = widget.onMoveToArchive;
    if (cb == null) return;
    showConfirmRefuseDialog(context, onRefuse: cb);
  }

  /// Обёртка над `onMoveToArchive` для статуса «Свяжитесь с
  /// исполнителем» — показывает диалог «Вы уверены, что хотите
  /// отменить заказ?» с кнопкой «Отменить заказ». Функционально
  /// делает то же самое (заказ уезжает в `cancelled`), просто текст
  /// под смыслом — заказчик отменяет принятый заказ, а не «убирает в
  /// архив».
  void _confirmCancelOrder(BuildContext context) {
    final VoidCallback? cb = widget.onMoveToArchive;
    if (cb == null) return;
    showConfirmCancelDialog(context, onCancel: cb);
  }

  /// Правило видимости «Отметить выполненным»: заказ в работе (accepted,
  /// т.е. best-мэтч принят) И по локальному времени устройства уже
  /// наступил последний день заказа (date_to, без него date_from).
  /// Сервер (миграция 111) сверяет по НОВОСИБИРСКОЙ дате — совпадает с
  /// местным временем стартового рынка, поэтому кнопка видна ровно тогда,
  /// когда сервер уже принимает завершение (без ложного too_early).
  /// Даты и matchId берём из актуального снимка стора — параметры экрана
  /// их не содержат.
  bool get _canMarkCompleted {
    if (_status != MyOrderStatus.accepted) return false;
    final OrderMock? o = _findInStore();
    if (o == null) return false;
    final String? matchId = o.matchId;
    final DateTime? from = o.dateFrom;
    if (matchId == null || matchId.isEmpty || from == null) return false;
    final DateTime finalDay = o.dateTo ?? from;
    final DateTime finalDayStart =
        DateTime(finalDay.year, finalDay.month, finalDay.day);
    return !DateTime.now().isBefore(finalDayStart);
  }

  /// «Отметить выполненным»: подтверждение → RPC → заказ в сторе и на
  /// экране становится «Завершён» (кнопка «Оставить отзыв» появится по
  /// существующей логике completed). `already_completed` — тоже успех:
  /// крон или исполнитель успели завершить раньше.
  Future<void> _markCompleted() async {
    if (_completing) return;
    final OrderMock? o = _findInStore();
    final String? matchId = o?.matchId;
    if (o == null || matchId == null || matchId.isEmpty) return;
    final bool? confirmed = await _showConfirmCompleteDialog(context);
    if (confirmed != true || !mounted) return;
    setState(() => _completing = true);
    try {
      await CustomerOrdersService.instance.completeMatchManually(matchId);
      if (!mounted) return;
      MyOrdersStore.markCompleted(o.id);
      setState(() => _liveStatus = MyOrderStatus.completed);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заказ завершён')),
      );
    } on CompleteMatchException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось завершить заказ. Попробуйте ещё раз.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  /// Диалог подтверждения ручного завершения — «Заказ выполнен?». Тот же
  /// хаус-стайл, что у алертов в order_alerts.dart (голый Dialog +
  /// Container, крестик, оранжевая кнопка, текстовая «Вернуться»), плюс
  /// поясняющий текст под заголовком. Возвращает `true` при подтверждении;
  /// сам RPC вызывается уже ПОСЛЕ закрытия диалога.
  Future<bool?> _showConfirmCompleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (BuildContext ctx) => Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 16.w),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 22.r),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: DialogCloseButton(
                  onTap: () => Navigator.of(ctx).pop(),
                  color: AppColors.textTertiary,
                  iconSize: 22.r,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Заказ выполнен?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Заказ будет завершён у вас и у исполнителя. После этого можно оставить отзыв.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 20.h),
              PrimaryButton(
                label: 'Да, выполнен',
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
              SizedBox(height: 20.h),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
                child: Center(
                  child: Text(
                    'Вернуться',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  /// Набор кнопок нижней панели в зависимости от статуса заказа.
  /// Пустой список означает, что нижней панели нет вообще.
  List<Widget> _buildBottomButtons(BuildContext context) {
    final MyOrderStatus? status = _status;
    if (status == null) {
      return <Widget>[
        PrimaryButton(
          label: 'Опубликовать',
          onPressed: () => Navigator.of(context).pop(true),
        ),
        SizedBox(height: 8.h),
        SecondaryButton(
          label: 'Редактировать',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ];
    }
    switch (status) {
      case MyOrderStatus.waiting:
      case MyOrderStatus.executorDeclinedWaiting:
        return <Widget>[
          PrimaryButton(
            label: 'Перейти в каталог',
            onPressed: widget.onOpenCatalog,
          ),
          SizedBox(height: 8.h),
          SecondaryButton(
            label: 'Переместить в архив',
            onPressed: () => _confirmMoveToArchive(context),
          ),
        ];
      case MyOrderStatus.awaitingExecutor:
        return <Widget>[
          PrimaryButton(
            label: 'Выбрать другого исполнителя',
            onPressed: widget.onPickAnother,
          ),
          SizedBox(height: 8.h),
          SecondaryButton(
            label: 'Переместить в архив',
            onPressed: () => _confirmMoveToArchive(context),
          ),
        ];
      case MyOrderStatus.waitingChoose:
      case MyOrderStatus.executorDeclined:
        return <Widget>[
          PrimaryButton(
            label: 'Выбрать другого исполнителя',
            onPressed: widget.onPickAnother,
          ),
          SizedBox(height: 8.h),
          SecondaryButton(
            label: 'Переместить в архив',
            onPressed: () => _confirmMoveToArchive(context),
          ),
        ];
      case MyOrderStatus.accepted:
        return <Widget>[
          // «Отметить выполненным» — только когда наступил последний
          // день работ заказа (см. _canMarkCompleted). До этого в панели
          // остаётся одна кнопка отмены.
          if (_canMarkCompleted) ...<Widget>[
            PrimaryButton(
              label: 'Отметить выполненным',
              enabled: !_completing,
              onPressed: _markCompleted,
            ),
            SizedBox(height: 8.h),
          ],
          SecondaryButton(
            label: 'Отменить заказ',
            onPressed: _completing
                ? null
                : () => _confirmCancelOrder(context),
          ),
        ];
      case MyOrderStatus.completed:
        if (widget.reviewLeft) return const <Widget>[];
        return <Widget>[
          PrimaryButton(
            label: 'Оставить отзыв',
            onPressed: widget.onLeaveReview,
          ),
        ];
      case MyOrderStatus.rejectedDeclined:
        return <Widget>[
          PrimaryButton(
            label: 'Опубликовать заново',
            onPressed: widget.onRepublish,
          ),
        ];
      case MyOrderStatus.rejectedOther:
        return const <Widget>[];
    }
  }
}

/// Шапка исполнителя на детальном экране заказа: аватар + имя +
/// (звезда+рейтинг, если есть отзывы) + кликабельные «N отзывов».
/// Если задан `onCall`, справа добавляется круглая оранжевая кнопка
/// вызова. Логика отображения скопирована с
/// `MyOrderDetailScreen._CustomerHeader`, чтобы оба экрана выглядели
/// одинаково.
class _ExecutorHeader extends StatelessWidget {
  const _ExecutorHeader({
    required this.name,
    required this.rating,
    required this.reviewCount,
    this.avatarUrl,
    this.onTap,
    this.onCall,
    this.onReviewsTap,
  });

  final String name;
  final double rating;
  final int reviewCount;
  final String? avatarUrl;

  /// Тап по шапке (аватару + имени) — открывает полную карточку
  /// исполнителя. `null` — шапка некликабельна (например, на статусах,
  /// где исполнитель уже не привязан к заказу).
  final VoidCallback? onTap;
  final VoidCallback? onCall;
  final VoidCallback? onReviewsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: Row(
              children: <Widget>[
                AvatarCircle(size: 56.r, avatarUrl: avatarUrl),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name.trim().isEmpty ? 'Пользователь' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: <Widget>[
                          if (reviewCount > 0) ...<Widget>[
                            Image.asset(
                              'assets/images/catalog/star.webp',
                              width: 20.r,
                              height: 20.r,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.star_rounded,
                                size: 20.r,
                                color: AppColors.ratingStar,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              rating.toStringAsFixed(1).replaceAll('.', ','),
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w400,
                                height: 1.3,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(width: 16.w),
                          ],
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onReviewsTap,
                            child: Text(
                              '$reviewCount ${reviewsWord(reviewCount)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w400,
                                height: 1.3,
                                color: AppColors.textPrimary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onCall != null) ...<Widget>[
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: onCall,
            child: Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.phone,
                color: Colors.white,
                size: 22.r,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        child,
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: items
          .map(
            (String label) => Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.primary, width: 1),
                borderRadius: BorderRadius.circular(100.r),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PhotosGrid extends StatelessWidget {
  const _PhotosGrid({required this.photos});
  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: photos
          .map((String p) => ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: photoSmartImage(
                  p,
                  bucket: 'order-photos',
                  width: 72.r,
                  height: 72.r,
                  fit: BoxFit.cover,
                  cacheWidth: 300,
                ),
              ))
          .toList(),
    );
  }
}
