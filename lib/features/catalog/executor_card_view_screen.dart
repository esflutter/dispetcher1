import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/catalog/catalog_service.dart';
import 'package:dispatcher_1/core/catalog/models.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/utils/plural.dart';
import 'package:dispatcher_1/core/widgets/avatar_circle.dart';
import 'package:dispatcher_1/core/widgets/clickable_address.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/catalog_service_detail_screen.dart';
import 'package:dispatcher_1/features/catalog/select_order_for_executor_screen.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';
import 'package:dispatcher_1/features/executor_card/executor_card_screen.dart';
import 'package:dispatcher_1/features/orders/create_order_screen.dart';
import 'package:dispatcher_1/features/orders/orders_store.dart';
import 'package:dispatcher_1/features/profile/account_block.dart';
import 'package:dispatcher_1/features/profile/reviews_screen.dart';

/// Форматирует число с разделителем тысяч: 12500 → «12 500».
String _fmtThousands(int value) {
  final String s = value.toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final int rest = s.length - i;
    if (i > 0 && rest % 3 == 0) out.write(' ');
    out.write(s[i]);
  }
  return out.toString();
}

/// Просмотр чужой карточки исполнителя (открывается заказчиком из
/// каталога). Данные — из `executor_cards` + `profiles` + список
/// `services` + `schedule_day_overrides`. Контакты не показываем —
/// они в `profiles_private` под RLS, доступны только участнику
/// accepted-мэтча.
class ExecutorCardViewScreen extends StatefulWidget {
  const ExecutorCardViewScreen({
    super.key,
    required this.executorId,
    this.selectMode = false,
    this.onSelectExecutor,
  });

  final String executorId;

  /// Открыто из потока «Выбор исполнителя из откликнувшихся». В этом
  /// режиме нижняя кнопка показывает «Выбрать исполнителя», а не
  /// «Предложить заказ»; по нажатию вызывается [onSelectExecutor].
  final bool selectMode;

  /// Колбэк при «Выбрать исполнителя» в [selectMode]. Родитель должен
  /// сделать UPDATE в `order_matches` и закрыть экран выбора.
  final VoidCallback? onSelectExecutor;

  @override
  State<ExecutorCardViewScreen> createState() =>
      _ExecutorCardViewScreenState();
}

class _ExecutorCardViewScreenState extends State<ExecutorCardViewScreen> {
  late Future<ExecutorCardFull?> _future;

  @override
  void initState() {
    super.initState();
    _future = CatalogService.instance.getExecutorFull(widget.executorId);
    OfferSubmissions.revision.addListener(_onRevision);
    AccountBlock.notifier.addListener(_onRevision);
    MyOrdersStore.revision.addListener(_onRevision);
  }

  @override
  void dispose() {
    OfferSubmissions.revision.removeListener(_onRevision);
    AccountBlock.notifier.removeListener(_onRevision);
    MyOrdersStore.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    if (mounted) setState(() {});
  }

  /// «Предложить заказ» — основной флоу для заказчика. Сначала проверки:
  /// 1) есть ли своя карточка заказчика; 2) есть ли хотя бы один
  /// заказ, который можно предлагать. Затем — экран выбора заказа,
  /// который пишет в БД через [CustomerOrdersService.proposeOrderToExecutor].
  Future<void> _onPropose(ExecutorCardListItem e) async {
    if (AccountBlock.isBlocked) {
      await showBlockedProfileDialog(context);
      return;
    }
    if (!ExecutorCardScreen.cardCreated) {
      await showCreateCustomerCardDialog(context);
      return;
    }
    if (MyOrdersStore.offerable.isEmpty) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (_) => NoOrderDialog(
          onCreateOrder: () => DailyOrderLimit.openCreateOrAlert(context),
        ),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SelectOrderForExecutorScreen(
          executorId: e.userId,
          executorName: e.name,
          executorAvatarUrl: e.avatarUrl,
          executorMachinery: e.machineryTitles,
        ),
      ),
    );
  }

  String _legalStatusLabel(String? code) {
    switch (code) {
      case 'individual':
        return 'Физ. лицо';
      case 'self_employed':
        return 'Самозанятый';
      case 'ip':
        return 'ИП';
      case 'legal_entity':
        return 'Юр. лицо';
      default:
        return '—';
    }
  }

  String _yearsWord(int n) {
    final int n10 = n % 10;
    final int n100 = n % 100;
    if (n100 >= 11 && n100 <= 14) return 'лет';
    if (n10 == 1) return 'год';
    if (n10 >= 2 && n10 <= 4) return 'года';
    return 'лет';
  }

  /// «4.5» → «4,5»; «4.0» → «4». Целое число рейтинга показываем без
  /// дробной части — как в дореволюционной версии экрана (и как
  /// карточка заказчика).
  String _fmtRating(double v) {
    final String s = (v == v.roundToDouble())
        ? v.toInt().toString()
        : v.toStringAsFixed(1);
    return s.replaceAll('.', ',');
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
            'Карточка исполнителя',
            style: AppTextStyles.bodyL.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 88.h),
        child: AiAssistantFab(
          onTap: () => context.push('/assistant/chat'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: FutureBuilder<ExecutorCardFull?>(
        future: _future,
        builder: (BuildContext context,
            AsyncSnapshot<ExecutorCardFull?> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final ExecutorCardFull? full = snap.data;
          if (full == null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Text(
                  'Карточка не найдена или не опубликована',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMRegular
                      .copyWith(color: AppColors.textTertiary),
                ),
              ),
            );
          }
          final ExecutorCardListItem e = full.summary;
          final bool alreadyOffered =
              OfferSubmissions.isOffered(e.userId);
          final bool selectMode = widget.selectMode;
          return Column(
            children: <Widget>[
              Expanded(child: _buildContent(full)),
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
                    16.h + MediaQuery.of(context).padding.bottom),
                child: PrimaryButton(
                  label: selectMode
                      ? 'Выбрать исполнителя'
                      : (alreadyOffered
                          ? 'Отклик уже отправлен'
                          : 'Предложить заказ'),
                  enabled: selectMode
                      ? widget.onSelectExecutor != null
                      : (!AccountBlock.isBlocked && !alreadyOffered),
                  onPressed: selectMode
                      ? widget.onSelectExecutor
                      : ((AccountBlock.isBlocked || alreadyOffered)
                          ? null
                          : () => _onPropose(e)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(ExecutorCardFull full) {
    final ExecutorCardListItem e = full.summary;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CustomerHeader(
            name: e.name,
            avatarUrl: e.avatarUrl,
            rating: e.ratingAsExecutor,
            reviewsCount: e.reviewCountAsExecutor,
            onReviewsTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReviewsScreen(
                  subject: ReviewSubject.executor,
                  targetUserId: e.userId,
                  initialRating: e.ratingAsExecutor,
                  initialCount: e.reviewCountAsExecutor,
                ),
              ),
            ),
            ratingText: _fmtRating(e.ratingAsExecutor),
          ),
          SizedBox(height: 20.h),
          if (e.locationAddress != null &&
              e.locationAddress!.trim().isNotEmpty) ...<Widget>[
            const _SectionTitle('Местоположение'),
            SizedBox(height: 4.h),
            ClickableAddress(
              e.locationAddress!,
              baseStyle: AppTextStyles.body,
            ),
            SizedBox(height: 16.h),
          ],
          if (e.machineryTitles.isNotEmpty) ...<Widget>[
            const _SectionTitle('Спецтехника'),
            SizedBox(height: 8.h),
            _FilledChipWrap(items: e.machineryTitles),
            SizedBox(height: 16.h),
          ],
          if (e.categoryTitles.isNotEmpty) ...<Widget>[
            const _SectionTitle('Категории услуг'),
            SizedBox(height: 8.h),
            _FilledChipWrap(items: e.categoryTitles),
            SizedBox(height: 16.h),
          ],
          if (e.experienceYears != null && e.experienceYears! > 0) ...<Widget>[
            const _SectionTitle('Опыт работы'),
            SizedBox(height: 4.h),
            Text(
              '${e.experienceYears} ${_yearsWord(e.experienceYears!)}',
              style: AppTextStyles.body,
            ),
            SizedBox(height: 16.h),
          ],
          if (e.legalStatus != null && e.legalStatus!.isNotEmpty) ...<Widget>[
            const _SectionTitle('Статус'),
            SizedBox(height: 4.h),
            Text(_legalStatusLabel(e.legalStatus), style: AppTextStyles.body),
            SizedBox(height: 16.h),
          ],
          if (e.about != null && e.about!.trim().isNotEmpty) ...<Widget>[
            const _SectionTitle('О себе'),
            SizedBox(height: 4.h),
            Text(e.about!, style: AppTextStyles.body),
            SizedBox(height: 16.h),
          ],
          _AvailabilitySection(
            overrides: full.scheduleOverrides,
            defaultRadiusKm: e.radiusKm,
          ),
          if (full.services.isNotEmpty) ...<Widget>[
            SizedBox(height: 16.h),
            const _SectionTitle('Услуги'),
            SizedBox(height: 8.h),
            for (int i = 0; i < full.services.length; i++) ...<Widget>[
              if (i > 0) SizedBox(height: 16.h),
              _ServiceTile(
                child: _ServiceItem(
                  service: full.services[i],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CatalogServiceDetailScreen(
                        service: full.services[i],
                        executorId: e.userId,
                        executorName: e.name,
                        executorAvatarUrl: e.avatarUrl,
                        executorMachinery: e.machineryTitles,
                        selectMode: widget.selectMode,
                        onSelectExecutor: widget.onSelectExecutor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({
    required this.name,
    required this.avatarUrl,
    required this.rating,
    required this.reviewsCount,
    required this.onReviewsTap,
    required this.ratingText,
  });

  final String name;
  final String? avatarUrl;
  final double rating;
  final int reviewsCount;
  final VoidCallback onReviewsTap;
  final String ratingText;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        AvatarCircle(size: 72.r, avatarUrl: avatarUrl),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(name, style: AppTextStyles.titleS),
              SizedBox(height: 4.h),
              Row(
                children: <Widget>[
                  if (reviewsCount > 0) ...<Widget>[
                    Image.asset('assets/images/catalog/star.webp',
                        width: 20.r, height: 20.r),
                    SizedBox(width: 4.w),
                    Text(ratingText, style: AppTextStyles.body),
                    SizedBox(width: 16.w),
                  ],
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onReviewsTap,
                    child: Text(
                      '$reviewsCount ${reviewsWord(reviewsCount)}',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.bodyL.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

/// Чип с обводкой (outlined): белая заливка, оранжевая рамка.
class _FilledChipWrap extends StatelessWidget {
  const _FilledChipWrap({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: items
          .map((String label) => Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.primary, width: 1),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  label,
                  style: AppTextStyles.chip.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

/// Блок «Занятость»: неделя + информация о графике на выбранный день.
/// Источник — `schedule_day_overrides` (sparse). Default = «свободен
/// для заказов» без конкретики; явные overrides могут быть с временем,
/// техникой и индивидуальным радиусом, либо `accepting=false`
/// (выходной).
class _AvailabilitySection extends StatefulWidget {
  const _AvailabilitySection({
    required this.overrides,
    required this.defaultRadiusKm,
  });

  final Map<DateTime, ExecutorScheduleDay> overrides;
  final int? defaultRadiusKm;

  @override
  State<_AvailabilitySection> createState() => _AvailabilitySectionState();
}

class _AvailabilitySectionState extends State<_AvailabilitySection> {
  late DateTime _selected;
  late PageController _pageCtrl;
  late DateTime _originWeek;
  static const int _initialPage = 0;
  static const int _maxPage = 52;

  static const List<String> _monthsGenitive = <String>[
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];

  static const List<String> _monthsNominative = <String>[
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
  ];

  static const List<String> _weekLetters = <String>['п', 'в', 'с', 'ч', 'п', 'с', 'в'];

  DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  DateTime _weekFromPage(int page) =>
      _originWeek.add(Duration(days: (page - _initialPage) * 7));

  List<DateTime> _weekDaysFor(DateTime monday) =>
      List<DateTime>.generate(7, (int i) => monday.add(Duration(days: i)));

  void _onPageChanged(int page) {
    // На текущей неделе выделяем именно сегодня — пользователь свайпает
    // вперёд, потом возвращается обратно и ожидает увидеть кружок на
    // сегодня, а не на понедельник. На остальных неделях по умолчанию
    // выделяем понедельник этой недели — там «сегодняшнего» дня нет.
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime monday = _weekFromPage(page);
    final DateTime newSelected =
        _sameDay(monday, _mondayOf(today)) ? today : monday;
    setState(() => _selected = newSelected);
  }

  int get _currentPage {
    final double p = _pageCtrl.hasClients
        ? (_pageCtrl.page ?? _initialPage.toDouble())
        : _initialPage.toDouble();
    return p.round();
  }

  void _shiftWeek(int delta) {
    if (delta < 0) {
      if (_currentPage <= _initialPage) return;
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    } else {
      if (_currentPage >= _maxPage) return;
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    }
  }

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _originWeek = _mondayOf(_selected);
    _pageCtrl = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  ExecutorScheduleDay? _override(DateTime d) =>
      widget.overrides[DateTime(d.year, d.month, d.day)];

  bool _isDayOff(DateTime d) {
    final ExecutorScheduleDay? o = _override(d);
    return o != null && !o.accepting;
  }

  String _formatTimeRange(ExecutorScheduleDay o) {
    if (o.wholeDay) return 'Весь день';
    if (o.timeFrom == null || o.timeTo == null) return '';
    return 'С ${o.timeFrom} до ${o.timeTo}';
  }

  @override
  Widget build(BuildContext context) {
    final ExecutorScheduleDay? info = _override(_selected);
    final bool selectedDayOff = info != null && !info.accepting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const _SectionTitle('Занятость'),
            const Spacer(),
            Text(
              '${_monthsNominative[_selected.month - 1]}, ${_selected.year}',
              style: AppTextStyles.body,
            ),
            SizedBox(width: 8.w),
            Opacity(
              opacity: _currentPage <= _initialPage ? 0.35 : 1.0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _shiftWeek(-1),
                child: Padding(
                  padding: EdgeInsets.all(4.r),
                  child: Image.asset(
                      'assets/icons/ui/arrow_left.webp',
                      width: 17.r,
                      height: 17.r),
                ),
              ),
            ),
            SizedBox(width: 4.w),
            Opacity(
              opacity: _currentPage >= _maxPage ? 0.35 : 1.0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _shiftWeek(1),
                child: Padding(
                  padding: EdgeInsets.all(4.r),
                  child: Image.asset(
                      'assets/icons/ui/arrow_right.webp',
                      width: 17.r,
                      height: 17.r),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            for (int i = 0; i < 7; i++)
              SizedBox(
                width: 36.r,
                child: Center(
                  child: Text(
                    _weekLetters[i],
                    style: AppTextStyles.subBody.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 6.h),
        SizedBox(
          height: 44.h,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: _onPageChanged,
            itemCount: _maxPage + 1,
            itemBuilder: (BuildContext _, int page) {
              final DateTime monday = _weekFromPage(page);
              final List<DateTime> days = _weekDaysFor(monday);
              final DateTime now = DateTime.now();
              final DateTime today = DateTime(now.year, now.month, now.day);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (final DateTime d in days)
                    _DayCell(
                      date: d,
                      selected: _sameDay(d, _selected),
                      dayOff: _isDayOff(d),
                      // Прошлые дни — серые и без onTap. Раньше клик на
                      // вчерашний/позавчерашний день показывал «исполнитель
                      // свободен для заказов», что вводило в заблуждение —
                      // расписание для прошлого не имеет смысла.
                      isPast: d.isBefore(today),
                      onTap: (DateTime tapped) =>
                          setState(() => _selected = tapped),
                    ),
                ],
              );
            },
          ),
        ),
        SizedBox(height: 12.h),
        if (selectedDayOff)
          Text('Нерабочий день', style: AppTextStyles.body)
        else if (info != null) ...<Widget>[
          if (info.machineryTitles.isNotEmpty) ...<Widget>[
            _FilledChipWrap(items: info.machineryTitles),
            SizedBox(height: 10.h),
          ],
          if (_formatTimeRange(info).isNotEmpty) ...<Widget>[
            Text(_formatTimeRange(info),
                style: AppTextStyles.body.copyWith(fontSize: 14.sp)),
            SizedBox(height: 10.h),
          ],
          if ((info.radiusKm ?? widget.defaultRadiusKm) != null)
            Text(
              'Заказы в радиусе ${info.radiusKm ?? widget.defaultRadiusKm} км',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary),
            ),
        ] else
          Text(
            '${_selected.day} ${_monthsGenitive[_selected.month - 1]} — исполнитель свободен для заказов',
            style: AppTextStyles.body,
          ),
      ],
    );
  }
}

/// Ячейка дня в недельном календаре.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.dayOff,
    required this.onTap,
    this.isPast = false,
  });
  final DateTime date;
  final bool selected;
  final bool dayOff;
  final bool isPast;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final Color? bg = selected ? AppColors.primary : null;
    final Color textColor = selected
        ? Colors.white
        : isPast
            ? AppColors.textTertiary
            : dayOff
                ? const Color(0xFFF2F2F2)
                : AppColors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isPast ? null : () => onTap(date),
      child: Center(
        child: Container(
          width: 36.r,
          height: 36.r,
          alignment: Alignment.center,
          decoration: bg != null
              ? BoxDecoration(color: bg, shape: BoxShape.circle)
              : null,
          child: Text('${date.day}',
              style: AppTextStyles.bodyL.copyWith(color: textColor)),
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(14.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _ServiceItem extends StatelessWidget {
  const _ServiceItem({required this.service, this.onTap});
  final ExecutorService service;
  final VoidCallback? onTap;

  String? get _equipmentTag => service.machineryTitles.isEmpty
      ? null
      : service.machineryTitles.first;

  String? _fmtPrice(double? v) {
    if (v == null) return null;
    return '${_fmtThousands(v.round())} ₽';
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = AppTextStyles.body.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
    final TextStyle valueStyle = AppTextStyles.bodyMedium.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.primary,
    );
    final String? priceHour = _fmtPrice(service.pricePerHour);
    final String? priceDay = _fmtPrice(service.pricePerDay);
    final bool hasHour = priceHour != null;
    final bool hasDay = priceDay != null;
    return InkWell(
      onTap: onTap,
      child: Padding(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_equipmentTag != null) ...<Widget>[
            Text(
              _equipmentTag!,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textTertiary,
                height: 1.78,
              ),
            ),
            SizedBox(height: 4.h),
          ],
          Text(
            service.title,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 17.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (service.description != null &&
              service.description!.trim().isNotEmpty) ...<Widget>[
            SizedBox(height: 6.h),
            Text(
              service.description!,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (hasHour || hasDay) ...<Widget>[
            SizedBox(height: 10.h),
            Row(
              children: <Widget>[
                if (hasHour) ...<Widget>[
                  Text('₽ / час', style: labelStyle),
                  SizedBox(width: 6.w),
                  Text(priceHour, style: valueStyle),
                ],
                if (hasHour && hasDay) SizedBox(width: 24.w),
                if (hasDay) ...<Widget>[
                  Text('₽ / день', style: labelStyle),
                  SizedBox(width: 6.w),
                  Text(priceDay, style: valueStyle),
                ],
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }
}
