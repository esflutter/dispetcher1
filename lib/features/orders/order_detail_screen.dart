import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dispatcher_1/core/catalog/catalog_service.dart';
import 'package:dispatcher_1/core/catalog/models.dart';
import 'package:dispatcher_1/core/customer_orders/customer_orders_service.dart';
import 'package:dispatcher_1/core/customer_orders/models.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/utils/photo_source.dart';
import 'package:dispatcher_1/core/utils/plural.dart';
import 'package:dispatcher_1/core/widgets/avatar_circle.dart';
import 'package:dispatcher_1/core/widgets/clickable_address.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/auth/photo_crop_screen.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';
import 'package:dispatcher_1/features/catalog/widgets/order_card.dart';
import 'package:dispatcher_1/features/orders/review_screen.dart';
import 'package:dispatcher_1/features/orders/widgets/order_alerts.dart';
import 'package:dispatcher_1/features/orders/widgets/order_status_pill.dart';
import 'package:dispatcher_1/features/profile/reviews_screen.dart';

/// Состояние экрана деталей «моего» заказа (для заказчика).
enum MyOrderDetailState {
  /// Заказ на рассмотрении — ожидаем откликов от исполнителей.
  /// Можно «Отменить заказ».
  waitingConfirm,

  /// Исполнитель выбран — показываем телефон исполнителя
  /// и кнопку «Отменить заказ».
  confirmed,

  /// Заказ выполнен. Виден телефон, кнопка «Оставить отзыв».
  completed,

  /// Заказ отменён / завершён. Без телефона и кнопок.
  rejected,
}

/// Детали моего заказа для заказчика (НЕ путать с карточкой исполнителя из features/catalog).
class MyOrderDetailScreen extends StatefulWidget {
  const MyOrderDetailScreen({
    super.key,
    required this.state,
    this.title = '',
    this.equipment = const <String>[],
    this.workCategories = const <String>[],
    this.rentDate = '',
    this.address = '',
    this.customerName = '',
    this.customerPhone = '',
    this.customerEmail,
    this.timeAgo = '',
    this.orderNumber = '',
    this.workDescription = const <String>[],
    this.description = '',
    this.photos = const <String>[],
    this.rejectedStatus = MyOrderStatus.rejectedOther,
    this.waitingStatus = MyOrderStatus.waiting,
    this.onDecline,
    this.onRefuse,
    this.onConfirm,
    this.isBlocked = false,
    this.reviewLeft = false,
    this.onReviewLeft,
    this.onPickAnother,
    this.onOpenCatalog,
    this.matchId,
    this.executorId,
    this.executorRating = 0,
    this.executorReviewCount = 0,
    this.agreedPricePerHour,
    this.agreedPricePerDay,
    this.serviceMachineryTitle,
  });

  final MyOrderDetailState state;
  final String title;
  final List<String> equipment;
  final List<String> workCategories;
  final String rentDate;
  final String address;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String timeAgo;
  final String orderNumber;
  final List<String> workDescription;

  /// Общее описание заказа — текстовый блок, который заказчик ввёл
  /// при создании. Пустая строка → блок не показывается.
  final String description;

  /// Прикреплённые фото — пути ассетов или файлов на устройстве.
  /// Если список пуст, блок «Фото» целиком скрыт (даже заголовок).
  final List<String> photos;

  /// Какой именно красный статус показывать в state == rejected.
  final MyOrderStatus rejectedStatus;

  /// Какой именно «ожидающий» статус показывать в state == waitingConfirm.
  /// `waiting` — «Ждёт подтверждения», `waitingChoose` — «Выберите
  /// исполнителя». Другие значения используются только для rejected/*.
  final MyOrderStatus waitingStatus;

  /// Колбэк «Отклонить заказ» (исполнитель не подтвердил) — обычно
  /// здесь parent перемещает заказ из «Новые» в «Не принятые» со
  /// статусом `rejectedDeclined` и закрывает экран.
  final VoidCallback? onDecline;

  /// Колбэк «Отказаться от заказа» (исполнитель уже подтвердил).
  final VoidCallback? onRefuse;

  /// Колбэк «Подтвердить» (исполнитель принимает заказ) — обычно
  /// parent переносит заказ из «Новые» в «Принятые» со статусом
  /// `accepted` и закрывает экран.
  final VoidCallback? onConfirm;

  final bool isBlocked;

  /// Был ли уже оставлен отзыв по этому заказу. Источник правды —
  /// родительский список `OrderMock.reviewLeft`, который передаёт
  /// актуальное значение сюда; экран локально не хранит статический
  /// «Set пройденных заказов», чтобы не было расхождения между
  /// открытием через список и открытием из превью.
  final bool reviewLeft;

  /// Колбэк «отзыв оставлен». Родитель должен пометить свой
  /// `OrderMock.reviewLeft = true`, чтобы при следующем открытии
  /// кнопка «Оставить отзыв» больше не показывалась.
  final VoidCallback? onReviewLeft;

  /// Колбэк «Выбрать другого исполнителя» на статусе
  /// `awaitingExecutor`. Родитель должен вызвать
  /// [MyOrdersStore.pickAnotherFromAwaiting], закрыть текущий экран
  /// и при отсутствии других откликов — переключиться на вкладку
  /// «Каталог», а при наличии — открыть список откликнувшихся.
  final VoidCallback? onPickAnother;

  /// «Перейти в каталог» для статусов `waiting` и
  /// `executorDeclinedWaiting` — когда откликов нет и выбирать некого.
  /// Родитель закрывает экран и переключает bottom-nav на «Каталог».
  final VoidCallback? onOpenCatalog;

  /// id мэтча в `order_matches`. Нужен чтобы при открытии экрана
  /// проверить актуальный статус и перейти в `confirmed`, если
  /// исполнитель уже подтвердил.
  final String? matchId;

  /// id исполнителя в `profiles`. По нему делается SELECT из
  /// `profiles_private` (RLS пропустит только при `accepted`/`completed`).
  final String? executorId;

  /// Снапшот цены, зафиксированный триггером в `order_matches.agreed_*`
  /// при создании мэтча. Та цена, которая была у услуги исполнителя в
  /// момент отклика/предложения. Последующие правки услуги её не меняют.
  final double? agreedPricePerHour;
  final double? agreedPricePerDay;

  /// Техника услуги, по которой шёл мэтч. Подпись к строке «Цена».
  final String? serviceMachineryTitle;

  /// Рейтинг исполнителя из `profiles.rating_as_executor`. 0 значит
  /// «отзывов нет» — UI рисует «—».
  final double executorRating;
  final int executorReviewCount;

  @override
  State<MyOrderDetailScreen> createState() => _MyOrderDetailScreenState();
}

class _MyOrderDetailScreenState extends State<MyOrderDetailScreen> {
  late MyOrderDetailState _state;
  late MyOrderStatus _rejectedStatus;
  late bool _reviewLeft;

  /// Подгружаемые из БД контакты исполнителя — RLS на `profiles_private`
  /// пропустит только участника `accepted`/`completed` мэтча. До
  /// загрузки используем то, что пришло в `widget.customerPhone`
  /// (обычно пусто, т.к. контакты появляются именно после accepted).
  String? _dbExecutorPhone;
  String? _dbExecutorEmail;

  /// Snapshot мэтча из БД: цена и список техник услуги. Подгружается
  /// в `_syncFromDb` — нужен для блока «Цена» (одна строка на каждую
  /// технику услуги, попадающую в технику заказа).
  double? _dbAgreedPricePerHour;
  double? _dbAgreedPricePerDay;
  int? _dbAgreedMinHours;
  List<String> _dbServiceMachineryTitles = const <String>[];

  /// Полные данные исполнителя для блока «Ждёт подтверждения». Грузим
  /// один раз в `initState` параллельно со снапшотом мэтча, чтобы
  /// не моргала компактная плашка-fallback во время FutureBuilder
  /// внутри `_AwaitingExecutorCard`.
  ExecutorCardListItem? _awaitingExecutor;
  bool _awaitingLoading = false;

  @override
  void initState() {
    super.initState();
    _state = widget.state;
    _rejectedStatus = widget.rejectedStatus;
    _reviewLeft = widget.reviewLeft;
    _dbAgreedPricePerHour = widget.agreedPricePerHour;
    _dbAgreedPricePerDay = widget.agreedPricePerDay;
    if (widget.serviceMachineryTitle != null &&
        widget.serviceMachineryTitle!.isNotEmpty) {
      _dbServiceMachineryTitles = <String>[widget.serviceMachineryTitle!];
    }
    _syncFromDb();
    if (widget.waitingStatus == MyOrderStatus.awaitingExecutor &&
        widget.executorId != null &&
        widget.executorId!.isNotEmpty) {
      _awaitingLoading = true;
      _loadAwaitingExecutor(widget.executorId!);
    }
  }

  Future<void> _loadAwaitingExecutor(String executorId) async {
    try {
      final ExecutorCardListItem? found =
          await CatalogService.instance.getExecutorById(executorId);
      if (!mounted) return;
      setState(() {
        _awaitingExecutor = found;
        _awaitingLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _awaitingLoading = false);
    }
  }

  /// Спрашивает у БД актуальный статус мэтча и при `accepted`/`completed`
  /// переключает экран в соответствующее состояние и тянет контакты +
  /// snapshot цены. Без [matchId] и [executorId] ничего не делает.
  Future<void> _syncFromDb() async {
    final String? matchId = widget.matchId;
    final String? executorId = widget.executorId;
    if (matchId == null || executorId == null) return;
    final MatchSnapshot? snap =
        await CustomerOrdersService.instance.getMatchSnapshot(matchId);
    if (!mounted || snap == null) return;
    setState(() {
      _dbAgreedPricePerHour = snap.agreedPricePerHour;
      _dbAgreedPricePerDay = snap.agreedPricePerDay;
      _dbAgreedMinHours = snap.agreedMinHours;
      _dbServiceMachineryTitles = snap.serviceMachineryTitles;
      if (snap.status == 'accepted') {
        _state = MyOrderDetailState.confirmed;
      } else if (snap.status == 'completed') {
        _state = MyOrderDetailState.completed;
      }
    });
    if (snap.status == 'accepted' || snap.status == 'completed') {
      await _loadContacts(executorId);
    }
  }

  Future<void> _loadContacts(String executorId) async {
    final ({String? phone, String? email})? c = await CustomerOrdersService
        .instance
        .getExecutorContacts(executorId);
    if (c == null || !mounted) return;
    setState(() {
      _dbExecutorPhone = c.phone;
      _dbExecutorEmail = c.email;
    });
  }

  String get _effectivePhone =>
      (_dbExecutorPhone != null && _dbExecutorPhone!.isNotEmpty)
          ? _dbExecutorPhone!
          : widget.customerPhone;

  String? get _effectiveEmail =>
      (_dbExecutorEmail != null && _dbExecutorEmail!.isNotEmpty)
          ? _dbExecutorEmail
          : widget.customerEmail;

  bool get _hasAgreedPrice =>
      (_dbAgreedPricePerHour != null && _dbAgreedPricePerHour! > 0) ||
      (_dbAgreedPricePerDay != null && _dbAgreedPricePerDay! > 0);

  /// Названия техник, под которые показываем строки цены: пересечение
  /// техник услуги исполнителя (`_dbServiceMachineryTitles`) и техник,
  /// которые заказчик указал в заказе (`widget.equipment`). Если
  /// пересечение пустое, возвращаем все техники услуги — иначе блок
  /// «Цена» останется без подписи.
  List<String> get _priceMachineryTitles {
    if (_dbServiceMachineryTitles.isEmpty) return const <String>[];
    if (widget.equipment.isEmpty) return _dbServiceMachineryTitles;
    final Set<String> orderEq = widget.equipment.toSet();
    final List<String> intersect = _dbServiceMachineryTitles
        .where((String t) => orderEq.contains(t))
        .toList();
    return intersect.isEmpty ? _dbServiceMachineryTitles : intersect;
  }

  String _hoursWord(int n) {
    final int mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'часов';
    if (n % 10 == 1) return 'часа';
    return 'часов';
  }

  String _fmtAgreedPrice(double? v) {
    if (v == null || v <= 0) return '';
    final int i = v.round();
    final String s = i.toString();
    final StringBuffer b = StringBuffer();
    final int n = s.length;
    for (int k = 0; k < n; k++) {
      if (k > 0 && (n - k) % 3 == 0) b.write(' ');
      b.write(s[k]);
    }
    return b.toString();
  }

  MyOrderStatus get _pillStatus {
    switch (_state) {
      case MyOrderDetailState.waitingConfirm:
        // «Ожидает»: пилюля «Ждёт подтверждения» либо «Выберите
        // исполнителя» — в зависимости от исходного статуса карточки.
        return widget.waitingStatus;
      case MyOrderDetailState.confirmed:
        // «Принятые»: бирюзовая пилюля «Свяжитесь с заказчиком».
        return MyOrderStatus.accepted;
      case MyOrderDetailState.completed:
        return MyOrderStatus.completed;
      case MyOrderDetailState.rejected:
        return _rejectedStatus;
    }
  }

  /// Показываем контакты и шапку исполнителя только пока заказ
  /// активен (executor выбран, но ещё не закрыт). У завершённых
  /// заказов блок исполнителя не нужен — заказ исторический, звонить
  /// и писать смысла нет.
  bool get _showExecutor =>
      _state == MyOrderDetailState.confirmed ||
      _state == MyOrderDetailState.completed;

  bool get _showPhone => _showExecutor;

  /// Открывает БД-подключённую карточку исполнителя (видна заказчику).
  /// Если у заказа нет [executorId] (мок-данные), кнопка не нажимается.
  void _openExecutorProfile() {
    final String? executorId = widget.executorId;
    if (executorId == null || executorId.isEmpty) return;
    context.push('/catalog/executor/$executorId');
  }

  /// Открывает экран отзывов конкретного исполнителя по тапу «N отзывов».
  /// Без `executorId` ничего не делает — иначе откроется список «отзывы
  /// обо мне» (заказчике), что собьёт пользователя.
  void _openExecutorReviews() {
    final String? executorId = widget.executorId;
    if (executorId == null || executorId.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReviewsScreen(
          subject: ReviewSubject.executor,
          targetUserId: executorId,
          initialRating: widget.executorRating,
          initialCount: widget.executorReviewCount,
        ),
      ),
    );
  }

  /// Открывает системный номеронабиратель с подставленным номером.
  /// Звонок не запускается автоматически — нужно нажать кнопку вызова
  /// в приложении телефона. Используется стандартная `tel:`-схема.
  Future<void> _dialPhone(String phone) async {
    if (phone.trim().isEmpty) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navBarDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 48.h,
        leading: Padding(
          padding: EdgeInsets.only(top: 2.h),
          child: IconButton(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            icon: Padding(
              padding: EdgeInsets.only(left: 8.w),
              child: Image.asset(
                'assets/icons/ui/back_arrow.webp',
                width: 24.r,
                height: 24.r,
                fit: BoxFit.contain,
              ),
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Padding(
          padding: EdgeInsets.only(top: 2.h),
          child: Text(
            widget.title,
            style: AppTextStyles.titleS.copyWith(color: Colors.white),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          // 148h — когда снизу две кнопки (все варианты waitingConfirm:
          // waiting/executorDeclinedWaiting → «Перейти в каталог» +
          // «Переместить в архив»; waitingChoose/executorDeclined/
          // awaitingExecutor → «Выбрать [другого] исполнителя» +
          // «Переместить в архив»); 88h — когда одна кнопка (confirmed:
          // только «Переместить в архив», completed: «Оставить отзыв»);
          // 24h — когда нижней панели нет.
          bottom: _state == MyOrderDetailState.waitingConfirm
              ? 148.h
              : _hasBottomBar
                  ? 88.h
                  : 24.h,
        ),
        child: AiAssistantFab(onTap: () => context.push('/assistant/chat')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w,
                  _hasBottomBar ? 16.h : 16.h + MediaQuery.of(context).padding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  OrderStatusPill(status: _pillStatus),
                  if (_showExecutor) ...<Widget>[
                    SizedBox(height: 12.h),
                    _CustomerHeader(
                      name: widget.customerName,
                      rating: widget.executorRating,
                      reviewCount: widget.executorReviewCount,
                      onTap: _openExecutorProfile,
                      onCall: _state == MyOrderDetailState.confirmed
                          ? () => _dialPhone(_effectivePhone)
                          : null,
                      onReviewsTap: _openExecutorReviews,
                    ),
                  ],
                  if (_showPhone) ...<Widget>[
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
                      _effectivePhone,
                      style: AppTextStyles.subBody
                          .copyWith(fontWeight: FontWeight.w400),
                    ),
                    if (_effectiveEmail != null &&
                        _effectiveEmail!.trim().isNotEmpty) ...<Widget>[
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
                        _effectiveEmail!,
                        style: AppTextStyles.subBody
                            .copyWith(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ],
                  SizedBox(height: 11.h),
                  Text(
                    widget.orderNumber,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    widget.title,
                    style: AppTextStyles.titleL.copyWith(height: 1.2),
                  ),
                  SizedBox(height: 7.h),
                  Text(
                    widget.timeAgo,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
                  SizedBox(height: 11.h),
                  _Section(
                    title: 'Дата и время аренды',
                    child: Text(
                      widget.rentDate,
                      style: AppTextStyles.subBody
                          .copyWith(fontWeight: FontWeight.w400),
                    ),
                  ),
                  _Section(
                    title: 'Адрес',
                    child: ClickableAddress(
                      widget.address,
                      baseStyle: AppTextStyles.subBody
                          .copyWith(fontWeight: FontWeight.w400),
                    ),
                  ),
                  if (widget.description.trim().isNotEmpty)
                    _Section(
                      title: 'Описание заказа',
                      child: Text(
                        widget.description,
                        style: AppTextStyles.subBody
                            .copyWith(fontWeight: FontWeight.w400),
                      ),
                    ),
                  _Section(
                    title: 'Требуемая спецтехника',
                    child: Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: widget.equipment
                          .map((String e) => _OutlinedChip(label: e))
                          .toList(),
                    ),
                  ),
                  _Section(
                    title: 'Категория работ',
                    child: Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: widget.workCategories
                          .map((String e) => _OutlinedChip(label: e))
                          .toList(),
                    ),
                  ),
                  _Section(
                    title: 'Характер работ',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final String line in widget.workDescription)
                          Text(
                            line,
                            style: AppTextStyles.subBody
                                .copyWith(fontWeight: FontWeight.w400),
                          ),
                      ],
                    ),
                  ),
                  // Блок «Цена» (снапшот из `order_matches.agreed_*`)
                  // показывается, когда мэтч уже состоялся. Источник
                  // правды — поля [agreedPricePerHour]/[agreedPricePerDay]/
                  // [serviceMachineryTitle], которые передаются сверху
                  // после загрузки матча из БД.
                  if ((_state == MyOrderDetailState.confirmed ||
                          _state == MyOrderDetailState.completed) &&
                      _hasAgreedPrice)
                    _Section(
                      title: 'Цена',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (int i = 0;
                              i < _priceMachineryTitles.length;
                              i++) ...<Widget>[
                            if (i > 0) SizedBox(height: 2.h),
                            _PriceLine(
                              equipment: _priceMachineryTitles[i],
                              pricePerHour:
                                  _fmtAgreedPrice(_dbAgreedPricePerHour),
                              pricePerDay:
                                  _fmtAgreedPrice(_dbAgreedPricePerDay),
                              minHoursLabel: _dbAgreedMinHours != null &&
                                      _dbAgreedMinHours! > 0
                                  ? 'от $_dbAgreedMinHours ${_hoursWord(_dbAgreedMinHours!)}'
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (widget.photos.isNotEmpty)
                    _Section(
                      title: 'Фото',
                      child: _PhotosGrid(photos: widget.photos),
                    ),
                  if (widget.waitingStatus ==
                          MyOrderStatus.awaitingExecutor &&
                      !_awaitingLoading) ...<Widget>[
                    SizedBox(height: 4.h),
                    _AwaitingExecutorCard(
                      executor: _awaitingExecutor,
                      fallbackName: widget.customerName,
                      onTap: _openExecutorProfile,
                      orderEquipment: widget.equipment,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_hasBottomBar) _buildBottomBar(),
        ],
      ),
    );
  }

  bool get _hasBottomBar =>
      _state != MyOrderDetailState.rejected &&
      !(_state == MyOrderDetailState.completed && _reviewLeft);

  Widget _buildBottomBar() {
    return Container(
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
      child: _buildAction(),
    );
  }

  Widget _buildAction() {
    switch (_state) {
      case MyOrderDetailState.waitingConfirm:
        final Widget archiveButton = SecondaryButton(
          label: 'Переместить в архив',
          onPressed: () => showConfirmDeclineDialog(
            context,
            onDecline: () {
              widget.onDecline?.call();
              if (mounted) Navigator.of(context).maybePop();
            },
          ),
        );
        // Если откликов ещё не было (waiting) или выбранный исполнитель
        // отказался, а других откликов нет (executorDeclinedWaiting) —
        // выбирать некого прямо из заказа: первый шаг — отправляем в
        // каталог, чтобы заказчик сам нашёл подрядчика. Набор кнопок
        // намеренно повторяет превью-экран пользовательских заказов
        // (`CreateOrderPreviewScreen`), чтобы поведение между моковой и
        // пользовательской карточкой не расходилось.
        if (widget.waitingStatus == MyOrderStatus.waiting ||
            widget.waitingStatus ==
                MyOrderStatus.executorDeclinedWaiting) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PrimaryButton(
                label: 'Перейти в каталог',
                enabled: !widget.isBlocked,
                onPressed: widget.onOpenCatalog ??
                    () => Navigator.of(context).maybePop(),
              ),
              SizedBox(height: 8.h),
              archiveButton,
            ],
          );
        }
        // Заказ предложен конкретному исполнителю — кнопка «Выбрать
        // другого» уводит либо к списку откликнувшихся (если есть
        // другие), либо в каталог; ветвлением занимается родитель
        // через [onPickAnother].
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PrimaryButton(
              label: 'Выбрать другого исполнителя',
              enabled: !widget.isBlocked,
              onPressed: widget.waitingStatus ==
                      MyOrderStatus.awaitingExecutor
                  ? widget.onPickAnother
                  : () => Navigator.of(context).maybePop(),
            ),
            SizedBox(height: 8.h),
            archiveButton,
          ],
        );
      case MyOrderDetailState.confirmed:
        return SecondaryButton(
          label: 'Переместить в архив',
          onPressed: () => showConfirmRefuseDialog(
            context,
            onRefuse: () {
              widget.onRefuse?.call();
              if (mounted) Navigator.of(context).maybePop();
            },
          ),
        );
      case MyOrderDetailState.completed:
        if (_reviewLeft) return const SizedBox.shrink();
        return PrimaryButton(
          label: 'Оставить отзыв',
          onPressed: () async {
            final bool? submitted = await Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => ReviewScreen(
                  targetUserId: widget.executorId,
                  matchId: widget.matchId,
                ),
              ),
            );
            if (submitted == true && mounted) {
              widget.onReviewLeft?.call();
              setState(() => _reviewLeft = true);
            }
          },
        );
      case MyOrderDetailState.rejected:
        return const SizedBox.shrink();
    }
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({
    required this.name,
    required this.rating,
    required this.reviewCount,
    required this.onTap,
    this.onCall,
    this.onReviewsTap,
  });

  final String name;

  /// Реальный рейтинг исполнителя (`profiles.rating_as_executor`).
  /// 0 = ещё нет ни одного отзыва — UI рисует «—».
  final double rating;
  final int reviewCount;

  final VoidCallback onTap;

  /// Если задан — справа появляется оранжевая кнопка с телефоном.
  /// Видна только когда есть кого звонить (accepted/completed).
  final VoidCallback? onCall;

  /// Тап по «N отзывов» — открывает экран отзывов. Если `null`,
  /// текст остаётся некликабельным (для состояний, где у исполнителя
  /// ещё нет профиля-мэтча).
  final VoidCallback? onReviewsTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          AvatarCircle(size: 56.r),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name.trim().isEmpty ? CropResult.namePlaceholder : name,
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
                    Image.asset(
                      'assets/images/catalog/star.webp',
                      width: 20.r,
                      height: 20.r,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      rating > 0
                          ? rating.toStringAsFixed(1).replaceAll('.', ',')
                          : '—',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onReviewsTap,
                      child: Text(
                        '$reviewCount ${reviewsWord(reviewCount)}',
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
      ),
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
                child: isAssetPath(p)
                    ? Image.asset(
                        p,
                        width: 72.r,
                        height: 72.r,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(p),
                        width: 72.r,
                        height: 72.r,
                        fit: BoxFit.cover,
                      ),
              ))
          .toList(),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          SizedBox(height: 4.h),
          child,
        ],
      ),
    );
  }
}

class _OutlinedChip extends StatelessWidget {
  const _OutlinedChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

/// Карточка единственного исполнителя в статусе «Ждёт подтверждения».
/// Получает уже загруженного исполнителя сверху — родительский экран
/// грузит его параллельно со снапшотом мэтча. Если executor=null
/// (исполнителя не нашли в выдаче или executorId пуст), показывает
/// компактную fallback-плашку с именем.
class _AwaitingExecutorCard extends StatelessWidget {
  const _AwaitingExecutorCard({
    required this.executor,
    required this.fallbackName,
    required this.onTap,
    required this.orderEquipment,
  });

  final ExecutorCardListItem? executor;
  final String fallbackName;
  final VoidCallback onTap;
  final List<String> orderEquipment;

  @override
  Widget build(BuildContext context) {
    final ExecutorCardListItem? e = executor;
    if (e == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(14.r),
          ),
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: <Widget>[
              AvatarCircle(size: 40.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(fallbackName, style: AppTextStyles.bodyMedium),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 24.r),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(14.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: OrderCard(
        name: e.name,
        rating: e.ratingAsExecutor,
        equipment: e.machineryTitles,
        categories: e.categoryTitles,
        matchingServices: e.matchingServices,
        highlightEquipment: orderEquipment.toSet(),
        avatarUrl: e.avatarUrl,
        onTap: onTap,
      ),
    );
  }
}

/// Строка блока «Цена» на странице заказа после мэтча. Источник —
/// снапшот из `order_matches.agreed_*`: пробрасывается готовыми
/// строками, потому что форматирование уже сделано в _fmtAgreedPrice.
class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.equipment,
    required this.pricePerHour,
    required this.pricePerDay,
    this.minHoursLabel,
  });
  final String equipment;
  final String pricePerHour;
  final String pricePerDay;
  final String? minHoursLabel;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = TextStyle(
      fontFamily: 'Roboto',
      fontSize: 14.sp,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: AppColors.textPrimary,
    );
    final TextStyle priceUnit = base.copyWith(
      fontSize: 16.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.primary,
    );
    final bool hasHour = pricePerHour.isNotEmpty;
    final bool hasDay = pricePerDay.isNotEmpty;
    final List<TextSpan> spans = <TextSpan>[
      if (equipment.isNotEmpty) TextSpan(text: '$equipment — '),
    ];
    if (hasHour) {
      spans.add(TextSpan(text: pricePerHour, style: priceUnit));
      spans.add(TextSpan(text: ' ₽/час', style: priceUnit));
    }
    if (hasHour && hasDay) spans.add(const TextSpan(text: '   '));
    if (hasDay) {
      spans.add(TextSpan(text: pricePerDay, style: priceUnit));
      spans.add(TextSpan(text: ' ₽/день', style: priceUnit));
    }
    if (minHoursLabel != null && minHoursLabel!.isNotEmpty && hasHour) {
      spans.add(TextSpan(text: ', ${minHoursLabel!}'));
    }
    return Text.rich(TextSpan(children: spans), style: base);
  }
}
