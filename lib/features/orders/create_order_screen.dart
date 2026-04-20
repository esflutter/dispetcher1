import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/utils/photo_source.dart';
import 'package:dispatcher_1/core/utils/thousand_separator_formatter.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/catalog_filter_screen.dart';
import 'package:dispatcher_1/features/orders/orders_store.dart';
import 'package:dispatcher_1/features/orders/preview_order_screen.dart';
import 'package:dispatcher_1/features/orders/widgets/order_status_pill.dart';
import 'package:dispatcher_1/features/support/chat_screen.dart';

/// Антиспам-лимит: не более [maxPerDay] заказов в сутки на пользователя.
/// Счётчик сбрасывается автоматически при смене календарной даты.
/// Состояние только в памяти — достаточно для клиентской валидации в моке.
class DailyOrderLimit {
  DailyOrderLimit._();

  static const int maxPerDay = 30;

  static int _count = 0;
  static DateTime? _date;

  static void _rolloverIfNeeded() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    if (_date != today) {
      _date = today;
      _count = 0;
    }
  }

  /// true, если сегодня ещё можно создать хотя бы один заказ.
  static bool get canCreate {
    _rolloverIfNeeded();
    return _count < maxPerDay;
  }

  /// Вызывается после успешного создания заказа.
  static void increment() {
    _rolloverIfNeeded();
    _count++;
  }

  /// Сбрасывает дневной счётчик вне зависимости от календаря. Нужен
  /// при разблокировке аккаунта: заблокированный пользователь не мог
  /// создавать заказы, и после восстановления он должен получить
  /// полную суточную квоту, а не остаток от прерванного дня.
  static void resetToday() {
    final DateTime now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _count = 0;
  }

  /// Диалог «Лимит заказов на сегодня исчерпан».
  static Future<void> showLimitDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => const _OrderLimitDialog(),
    );
  }

  /// Если лимит исчерпан — показать диалог и вернуть false.
  /// Иначе — открыть [CreateOrderScreen] и вернуть true.
  static Future<bool> openCreateOrAlert(BuildContext context) async {
    if (!canCreate) {
      await showLimitDialog(context);
      return false;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const CreateOrderScreen()),
    );
    return true;
  }
}

class _OrderLimitDialog extends StatelessWidget {
  const _OrderLimitDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(
                  Icons.close_rounded,
                  size: 22.r,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Лимит заказов на сегодня',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'В день можно разместить не более '
              '${DailyOrderLimit.maxPerDay} заказов. '
              'Попробуйте создать новый заказ завтра.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                height: 1.3,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 14.h),
            PrimaryButton(
              label: 'Ок',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Экран «Создание заказа». Структура и вёрстка по аналогии с экраном
/// «Создание услуги» в приложении исполнителя.
class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

/// Одна позиция блока «Характер работ»: название, единица измерения
/// и объём. У каждой позиции свои контроллеры — храним модель вместе
/// с состоянием раскрытого выпадающего списка единиц измерения.
class _WorkItem {
  _WorkItem();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController volumeCtrl = TextEditingController();
  String? unit;
  bool unitOpen = false;

  void dispose() {
    nameCtrl.dispose();
    volumeCtrl.dispose();
  }
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _budgetFromCtrl = TextEditingController();
  final TextEditingController _budgetToCtrl = TextEditingController();

  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _exactDate = false;
  bool _exactBudget = false;
  String? _openDatePicker;
  TimeOfDay? _timeFrom;
  TimeOfDay? _timeTo;
  bool _wholeDay = false;
  String? _openTimePicker;
  String? _address;
  final List<String> _photos = <String>[];
  final Set<String> _selCat = <String>{};
  final Set<String> _selMach = <String>{};
  final List<_WorkItem> _works = <_WorkItem>[_WorkItem()];

  static const List<String> _workUnits = <String>['м', 'м²', 'м³'];
  static const int _maxWorks = 20;

  static const List<String> _categories = <String>[
    'Земляные работы',
    'Погрузочно-разгрузочные работы',
    'Перевозка материалов',
    'Строительные работы',
    'Дорожные работы',
    'Буровые работы',
    'Высотные работы',
    'Демонтажные работы',
    'Благоустройство территории',
  ];

  static const List<String> _machinery = <String>[
    'Экскаватор-погрузчик',
    'Экскаватор',
    'Погрузчик',
    'Миниэкскаватор',
    'Буроям',
    'Самогруз',
    'Автокран',
    'Бетононасос',
    'Эвакуатор',
    'Автовышка',
    'Манипулятор',
    'Минипогрузчик',
    'Самосвал',
    'Минитрактор',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_onFieldChanged);
    _descCtrl.addListener(_onFieldChanged);
    _budgetFromCtrl.addListener(_onFieldChanged);
    _budgetToCtrl.addListener(_onFieldChanged);
    for (final _WorkItem w in _works) {
      _attachWorkListeners(w);
    }
  }

  void _attachWorkListeners(_WorkItem w) {
    w.nameCtrl.addListener(_onFieldChanged);
    w.volumeCtrl.addListener(_onFieldChanged);
  }

  bool _isWorkFilled(_WorkItem w) =>
      w.nameCtrl.text.trim().isNotEmpty &&
      w.unit != null &&
      w.volumeCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _titleCtrl.removeListener(_onFieldChanged);
    _descCtrl.removeListener(_onFieldChanged);
    _budgetFromCtrl.removeListener(_onFieldChanged);
    _budgetToCtrl.removeListener(_onFieldChanged);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _budgetFromCtrl.dispose();
    _budgetToCtrl.dispose();
    for (final _WorkItem w in _works) {
      w.dispose();
    }
    super.dispose();
  }

  void _addWork() {
    if (_works.length >= _maxWorks) return;
    setState(() {
      final _WorkItem w = _WorkItem();
      _attachWorkListeners(w);
      _works.add(w);
    });
  }

  void _removeWork(int i) {
    setState(() {
      _works[i].dispose();
      _works.removeAt(i);
    });
  }

  void _onFieldChanged() => setState(() {});

  Future<void> _addPhoto() async {
    final int remaining = 8 - _photos.length;
    if (remaining <= 0) return;
    final List<String> picked =
        await pickMultipleImagesFromGallery(limit: remaining, context: context);
    if (picked.isEmpty || !mounted) return;
    final List<String> kept =
        picked.length > remaining ? picked.sublist(0, remaining) : picked;
    setState(() => _photos.addAll(kept));
    if (picked.length > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Можно добавить не более 8 фото. Добавлены первые ${kept.length}.',
          ),
        ),
      );
    }
  }

  /// Якоря на раскрываемые пикеры даты и времени — нужны для того,
  /// чтобы после открытия скроллить форму так, что бы пикер встал в
  /// центр вьюпорта. На маленьких экранах он иначе выпадает ниже и
  /// его не видно без ручного доскролла.
  final GlobalKey _datePickerAnchorKey = GlobalKey();
  final GlobalKey _timePickerAnchorKey = GlobalKey();

  void _scrollPickerIntoView(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _toggleDatePicker(String key) {
    final bool willOpen = _openDatePicker != key;
    setState(() => _openDatePicker = willOpen ? key : null);
    if (willOpen) _scrollPickerIntoView(_datePickerAnchorKey);
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    return _formatDateRu(d);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _toggleTimePicker(String key) {
    final bool willOpen = _openTimePicker != key;
    setState(() => _openTimePicker = willOpen ? key : null);
    if (willOpen) _scrollPickerIntoView(_timePickerAnchorKey);
  }

  Future<void> _openAddressSheet() async {
    final String? result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddressBottomSheet(),
    );
    if (result != null && mounted) {
      setState(() => _address = result);
    }
  }

  bool get _canCreate =>
      _selCat.isNotEmpty &&
      _selMach.isNotEmpty &&
      _titleCtrl.text.trim().isNotEmpty &&
      _descCtrl.text.trim().isNotEmpty &&
      _dateFrom != null &&
      (_exactDate || _dateTo != null) &&
      (_wholeDay || (_timeFrom != null && _timeTo != null)) &&
      (_exactBudget
          ? _budgetFromCtrl.text.trim().isNotEmpty
          : (_budgetFromCtrl.text.trim().isNotEmpty ||
              _budgetToCtrl.text.trim().isNotEmpty)) &&
      _address != null;

  Future<void> _onCreateTap() async {
    if (!DailyOrderLimit.canCreate) {
      await DailyOrderLimit.showLimitDialog(context);
      return;
    }
    final OrderDraft draft = _buildDraft();
    final bool? published = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateOrderPreviewScreen(draft: draft),
      ),
    );
    if (!mounted || published != true) return;
    DailyOrderLimit.increment();
    MyOrdersStore.addCreated(_buildOrderMock(draft));
    Navigator.of(context).maybePop();
  }

  void _onAutoFillTap() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ChatScreen(initialMessage: 'create_order'),
      ),
    );
  }

  /// Собирает черновик заказа из всех заполненных полей — для предпросмотра.
  OrderDraft _buildDraft() {
    final int n = DateTime.now().millisecondsSinceEpoch % 1000000;
    return OrderDraft(
      number: '№${n.toString().padLeft(6, '0')}',
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      budget: _formatBudget(),
      rentDate: _formatRentDateTime(),
      address: _address ?? '',
      machinery: _selMach.toList(),
      categories: _selCat.toList(),
      works: _works
          .where(_isWorkFilled)
          .map((_WorkItem w) =>
              '${w.nameCtrl.text.trim()} — ${w.volumeCtrl.text.trim()} ${w.unit ?? ''}'
                  .trim())
          .toList(),
      photos: List<String>.from(_photos),
    );
  }

  String _formatBudget() {
    final String from = _budgetFromCtrl.text.trim();
    final String to = _budgetToCtrl.text.trim();
    if (_exactBudget) return from.isEmpty ? '' : '$from ₽';
    if (from.isEmpty && to.isEmpty) return '';
    if (from.isNotEmpty && to.isNotEmpty) return '$from – $to ₽';
    if (from.isNotEmpty) return 'От $from ₽';
    return 'До $to ₽';
  }

  /// Преобразует черновик в карточку для списка «Мои заказы».
  OrderMock _buildOrderMock(OrderDraft draft) {
    return OrderMock(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      status: MyOrderStatus.waiting,
      title: draft.title,
      equipment: draft.machinery,
      rentDate: draft.rentDate,
      address: draft.address,
      publishedAgo: 'Только что',
      publishedAt: DateTime.now(),
      price: draft.budget.isEmpty ? null : draft.budget,
      number: draft.number,
      description: draft.description,
      categories: draft.categories,
      works: draft.works,
      photos: draft.photos,
    );
  }

  static const List<String> _monthNamesGen = <String>[
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];

  String _formatDateRu(DateTime d) =>
      '${d.day} ${_monthNamesGen[d.month - 1]}';

  String _formatRentDateTime() {
    final String datePart = _dateFrom == null
        ? ''
        : (_exactDate || _dateTo == null
            ? _formatDateRu(_dateFrom!)
            : '${_formatDateRu(_dateFrom!)} — ${_formatDateRu(_dateTo!)}');
    final String timePart = _wholeDay
        ? 'Весь день'
        : (_timeFrom != null && _timeTo != null
            ? '${_fmtTime(_timeFrom!)}–${_fmtTime(_timeTo!)}'
            : '');
    if (datePart.isEmpty) return timePart;
    if (timePart.isEmpty) return datePart;
    return '$datePart · $timePart';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _CreateAppBar(onBack: () => Navigator.of(context).maybePop()),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SectionTitle('Название'),
                  SizedBox(height: 8.h),
                  _TintField(
                    controller: _titleCtrl,
                    hint: 'Например: Автовышка для фасада',
                    maxLength: 50,
                  ),
                  SizedBox(height: 16.h),
                  _SectionTitle('Описание заказа'),
                  SizedBox(height: 8.h),
                  _TintField(
                    controller: _descCtrl,
                    hint: 'Опишите задачу',
                    minLines: 2,
                    maxLines: null,
                    maxLength: 500,
                  ),
                  SizedBox(height: 16.h),
                  _SectionTitle('Стоимость'),
                  SizedBox(height: 8.h),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _TintField(
                          controller: _budgetFromCtrl,
                          hint: _exactBudget ? 'Цена' : 'От',
                          prefix: _exactBudget ? null : 'От ',
                          suffix: ' ₽',
                          keyboardType: TextInputType.number,
                          maxLength: 9,
                          thousandSeparator: true,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: IgnorePointer(
                          ignoring: _exactBudget,
                          child: Opacity(
                            opacity: _exactBudget ? 0.5 : 1.0,
                            child: _TintField(
                              controller: _budgetToCtrl,
                              hint: 'До',
                              prefix: 'До ',
                              suffix: ' ₽',
                              keyboardType: TextInputType.number,
                              maxLength: 9,
                              thousandSeparator: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  CheckRow(
                    label: 'Точная стоимость',
                    value: _exactBudget,
                    onChanged: (bool v) => setState(() {
                      _exactBudget = v;
                      if (v) _budgetToCtrl.clear();
                    }),
                  ),
                  SizedBox(height: 16.h),
                  _SectionTitle('Дата аренды'),
                  SizedBox(height: 8.h),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: PickerField(
                          hint: _exactDate ? '' : 'С',
                          value:
                              _dateFrom == null ? null : _fmtDate(_dateFrom),
                          iconAsset: 'assets/icons/ui/calendar_active.webp',
                          iconAssetInactive:
                              'assets/icons/ui/calendar_inactive.webp',
                          active: _openDatePicker == 'dateFrom',
                          onTap: () => _toggleDatePicker('dateFrom'),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: PickerField(
                          hint: 'По',
                          value: _dateTo == null ? null : _fmtDate(_dateTo),
                          iconAsset: 'assets/icons/ui/calendar_active.webp',
                          iconAssetInactive:
                              'assets/icons/ui/calendar_inactive.webp',
                          active: _openDatePicker == 'dateTo',
                          enabled: !_exactDate,
                          onTap: _exactDate
                              ? null
                              : () => _toggleDatePicker('dateTo'),
                        ),
                      ),
                    ],
                  ),
                  if (_openDatePicker == 'dateFrom' ||
                      _openDatePicker == 'dateTo') ...<Widget>[
                    SizedBox(height: 8.h),
                    InlineCalendar(
                      key: _datePickerAnchorKey,
                      selected: _openDatePicker == 'dateFrom'
                          ? _dateFrom
                          : (_dateTo ?? _dateFrom),
                      minDate: _openDatePicker == 'dateTo' ? _dateFrom : null,
                      onChanged: (DateTime d) {
                        setState(() {
                          if (_openDatePicker == 'dateFrom') {
                            _dateFrom = d;
                            if (_dateTo != null && _dateTo!.isBefore(d)) {
                              _dateTo = null;
                            }
                          } else {
                            _dateTo = d;
                          }
                          _openDatePicker = null;
                        });
                      },
                      onCancel: () =>
                          setState(() => _openDatePicker = null),
                    ),
                  ],
                  SizedBox(height: 8.h),
                  CheckRow(
                    label: 'Точная дата',
                    value: _exactDate,
                    onChanged: (bool v) => setState(() {
                      _exactDate = v;
                      if (v) {
                        _dateTo = null;
                        if (_openDatePicker == 'dateTo') _openDatePicker = null;
                      }
                    }),
                  ),
                  SizedBox(height: 16.h),
                  _SectionTitle('Время работы'),
                  SizedBox(height: 8.h),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: PickerField(
                          hint: 'С',
                          value:
                              _timeFrom == null ? null : _fmtTime(_timeFrom!),
                          iconAsset: 'assets/icons/ui/clock_active.webp',
                          iconAssetInactive:
                              'assets/icons/ui/clock_inactive.webp',
                          active: _openTimePicker == 'timeFrom',
                          enabled: !_wholeDay,
                          onTap: _wholeDay
                              ? null
                              : () => _toggleTimePicker('timeFrom'),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: PickerField(
                          hint: 'По',
                          value: _timeTo == null ? null : _fmtTime(_timeTo!),
                          iconAsset: 'assets/icons/ui/clock_active.webp',
                          iconAssetInactive:
                              'assets/icons/ui/clock_inactive.webp',
                          active: _openTimePicker == 'timeTo',
                          enabled: !_wholeDay,
                          onTap: _wholeDay
                              ? null
                              : () => _toggleTimePicker('timeTo'),
                        ),
                      ),
                    ],
                  ),
                  if (_openTimePicker == 'timeFrom' ||
                      _openTimePicker == 'timeTo') ...<Widget>[
                    SizedBox(height: 8.h),
                    InlineTimePicker(
                      key: _timePickerAnchorKey,
                      selected: _openTimePicker == 'timeFrom'
                          ? _timeFrom
                          : _timeTo,
                      onDone: (TimeOfDay t) {
                        setState(() {
                          if (_openTimePicker == 'timeFrom') {
                            _timeFrom = t;
                          } else {
                            _timeTo = t;
                          }
                          _openTimePicker = null;
                        });
                      },
                      onCancel: () => setState(() => _openTimePicker = null),
                    ),
                  ],
                  SizedBox(height: 8.h),
                  CheckRow(
                    label: 'Весь день',
                    value: _wholeDay,
                    onChanged: (bool v) => setState(() {
                      _wholeDay = v;
                      if (v &&
                          (_openTimePicker == 'timeFrom' ||
                              _openTimePicker == 'timeTo')) {
                        _openTimePicker = null;
                      }
                    }),
                  ),
                  SizedBox(height: 16.h),
                  _SectionTitle('Характер работ'),
                  SizedBox(height: 8.h),
                  for (int i = 0; i < _works.length; i++) ...<Widget>[
                    if (i != 0) SizedBox(height: 16.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: _TintField(
                            controller: _works[i].nameCtrl,
                            hint: 'Название',
                            maxLength: 60,
                            fontSize: 14.sp,
                            height: 40.h,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _removeWork(i),
                          child: SizedBox(
                            width: 28.r,
                            height: 40.h,
                            child: Icon(
                              Icons.close_rounded,
                              size: 22.r,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: _UnitDropdown(
                            units: _workUnits,
                            selected: _works[i].unit,
                            isOpen: _works[i].unitOpen,
                            fontSize: 14.sp,
                            height: 40.h,
                            onToggle: () => setState(() {
                              _works[i].unitOpen = !_works[i].unitOpen;
                            }),
                            onSelect: (String u) => setState(() {
                              _works[i].unit = u;
                              _works[i].unitOpen = false;
                            }),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _TintField(
                            controller: _works[i].volumeCtrl,
                            hint: 'Объём работы',
                            keyboardType: TextInputType.number,
                            maxLength: 9,
                            fontSize: 14.sp,
                            height: 40.h,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_works.length < _maxWorks &&
                      (_works.isEmpty ||
                          _isWorkFilled(_works.last))) ...<Widget>[
                    if (_works.isNotEmpty) SizedBox(height: 8.h),
                    GestureDetector(
                      onTap: _addWork,
                      child: Container(
                        width: double.infinity,
                        height: 40.h,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(
                              color: AppColors.primary, width: 1),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Добавить',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            height: 1.3,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 16.h),
                  _SectionTitle('Фото'),
                  SizedBox(height: 4.h),
                  Text(
                    'По желанию добавьте изображения к заказу, до 8 шт',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  if (_photos.isNotEmpty) ...<Widget>[
                    _PhotosGrid(
                      photos: _photos,
                      onRemove: (int i) =>
                          setState(() => _photos.removeAt(i)),
                    ),
                    SizedBox(height: 8.h),
                  ],
                  _AddPhotosButton(onTap: _addPhoto),
                  SizedBox(height: 16.h),
                  _SectionTitle('Категория услуг'),
                  SizedBox(height: 8.h),
                  _ChipWrap(
                    items: _categories,
                    selected: _selCat,
                    onToggle: (String v) => setState(() {
                      _selCat.contains(v) ? _selCat.remove(v) : _selCat.add(v);
                    }),
                  ),
                  SizedBox(height: 16.h),
                  _SectionTitle('Требуемая спецтехника'),
                  SizedBox(height: 8.h),
                  _ChipWrap(
                    items: _machinery,
                    selected: _selMach,
                    onToggle: (String v) => setState(() {
                      _selMach.contains(v)
                          ? _selMach.remove(v)
                          : _selMach.add(v);
                    }),
                  ),
                  SizedBox(height: 16.h),
                  _SectionTitle('Местоположение'),
                  SizedBox(height: 8.h),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openAddressSheet,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 14.h),
                      decoration: BoxDecoration(
                        color: AppColors.fieldFill,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        _address ?? 'Введите адрес',
                        style: AppTextStyles.body.copyWith(
                          color: _address != null
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
              children: <Widget>[
                PrimaryButton(
                  label: 'Создать',
                  enabled: _canCreate,
                  onPressed: _canCreate ? _onCreateTap : null,
                ),
                SizedBox(height: 8.h),
                SecondaryButton(
                  label: 'Заполнить автоматически',
                  onPressed: _onAutoFillTap,
                  height: 48.h,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Вспомогательные виджеты ──

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 20.sp,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _TintField extends StatelessWidget {
  const _TintField({
    required this.controller,
    required this.hint,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.maxLength,
    this.suffix,
    this.prefix,
    this.thousandSeparator = false,
    this.fontSize,
    this.height,
  });
  final TextEditingController controller;
  final String hint;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final int? maxLength;
  final String? suffix;
  final String? prefix;
  final bool thousandSeparator;
  final double? fontSize;
  final double? height;

  TextStyle get _textStyle => fontSize == null
      ? AppTextStyles.body
      : AppTextStyles.body.copyWith(fontSize: fontSize);

  List<TextInputFormatter>? _buildFormatters() {
    if (thousandSeparator) {
      return <TextInputFormatter>[
        ThousandSeparatorFormatter(maxDigits: maxLength ?? 9),
      ];
    }
    final List<TextInputFormatter> fs = <TextInputFormatter>[];
    if (maxLength != null) fs.add(LengthLimitingTextInputFormatter(maxLength));
    return fs.isEmpty ? null : fs;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAffixDef = suffix != null || prefix != null;

    if (hasAffixDef) {
      final bool hasText = controller.text.isNotEmpty;
      double prefixWidth = 0;
      if (hasText && prefix != null) {
        final TextPainter tp = TextPainter(
          text: TextSpan(text: prefix, style: _textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        prefixWidth = tp.width;
      }
      return Stack(
        children: <Widget>[
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: _buildFormatters(),
            style: hasText
                ? _textStyle.copyWith(color: Colors.transparent)
                : _textStyle,
            decoration: InputDecoration(
              hintText: hasText ? null : hint,
              hintStyle:
                  _textStyle.copyWith(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.fieldFill,
              contentPadding: EdgeInsets.fromLTRB(
                16.w + prefixWidth,
                12.h,
                16.w,
                12.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          if (hasText)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${prefix ?? ''}${controller.text}${suffix ?? ''}',
                    style: _textStyle,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    double? verticalPad;
    if (height != null) {
      final double lineHeight = (fontSize ?? 16) * 1.4;
      verticalPad = ((height! - lineHeight) / 2).clamp(0.0, 20.0);
    }
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: maxLength != null
          ? <TextInputFormatter>[LengthLimitingTextInputFormatter(maxLength)]
          : null,
      style: _textStyle,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _textStyle.copyWith(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.fieldFill,
        isDense: height != null,
        contentPadding: verticalPad != null
            ? EdgeInsets.symmetric(horizontal: 16.w, vertical: verticalPad)
            : EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({
    required this.items,
    required this.selected,
    required this.onToggle,
  });
  final List<String> items;
  final Set<String> selected;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: items.map((String label) {
        final bool on = selected.contains(label);
        return GestureDetector(
          onTap: () => onToggle(label),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: on ? AppColors.primary : AppColors.surface,
              border: Border.all(color: AppColors.primary, width: 1),
              borderRadius: BorderRadius.circular(100.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                    color: on ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                if (on) ...<Widget>[
                  SizedBox(width: 6.w),
                  Icon(Icons.close_rounded, size: 14.r, color: Colors.white),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PhotosGrid extends StatelessWidget {
  const _PhotosGrid({required this.photos, required this.onRemove});
  final List<String> photos;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: List<Widget>.generate(photos.length, (int i) {
        return SizedBox(
          width: 72.r,
          height: 72.r,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: isAssetPath(photos[i])
                    ? Image.asset(
                        photos[i],
                        width: 72.r,
                        height: 72.r,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(photos[i]),
                        width: 72.r,
                        height: 72.r,
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned(
                top: 4.w,
                right: 4.w,
                child: GestureDetector(
                  onTap: () => onRemove(i),
                  child: Image.asset(
                    'assets/icons/ui/close_photo.webp',
                    width: 24.r,
                    height: 24.r,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _AddPhotosButton extends StatelessWidget {
  const _AddPhotosButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 42.h,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              'assets/icons/ui/add_circle.webp',
              width: 24.r,
              height: 24.r,
              fit: BoxFit.contain,
            ),
            SizedBox(width: 8.w),
            Text(
              'Добавить изображения',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AppBar режима создания заказа: тёмный фон, стрелка назад слева.
class _CreateAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CreateAppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Size get preferredSize => Size.fromHeight(48.h);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.navBarDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 48.h,
      automaticallyImplyLeading: false,
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
          onPressed: onBack,
        ),
      ),
      title: Padding(
        padding: EdgeInsets.only(top: 2.h),
        child: Text(
          'Создание заказа',
          style: AppTextStyles.titleS.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

/// Выпадающий список единиц измерения для позиции блока «Характер работ».
/// В закрытом виде — поле-кнопка с плейсхолдером или выбранным значением
/// и шевроном; при открытии разворачивается список опций под кнопкой.
class _UnitDropdown extends StatelessWidget {
  const _UnitDropdown({
    required this.units,
    required this.selected,
    required this.isOpen,
    required this.onToggle,
    required this.onSelect,
    this.fontSize,
    this.height,
  });

  final List<String> units;
  final String? selected;
  final bool isOpen;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;
  final double? fontSize;
  final double? height;

  TextStyle get _textStyle => fontSize == null
      ? AppTextStyles.body
      : AppTextStyles.body.copyWith(fontSize: fontSize);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Container(
            height: height ?? 48.h,
            padding: EdgeInsets.only(left: 20.w, right: 16.w),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: isOpen
                  ? BorderRadius.vertical(top: Radius.circular(12.r))
                  : BorderRadius.circular(12.r),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    selected ?? 'Ед. измерения',
                    style: _textStyle.copyWith(
                      color: selected == null
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 22.r,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (isOpen)
          Container(
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(12.r)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Colors.grey.shade300,
                ),
                for (final String u in units)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(u),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 20.w, vertical: 10.h),
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Text(u, style: _textStyle)),
                          if (selected == u)
                            Image.asset(
                              'assets/icons/ui/check_black.webp',
                              width: 18.r,
                              height: 18.r,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
