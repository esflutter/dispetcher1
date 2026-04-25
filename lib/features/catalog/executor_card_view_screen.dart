import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/catalog/catalog_service.dart';
import 'package:dispatcher_1/core/catalog/models.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/utils/plural.dart';
import 'package:dispatcher_1/core/widgets/clickable_address.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/select_order_for_executor_screen.dart';
import 'package:dispatcher_1/features/executor_card/executor_card_screen.dart';
import 'package:dispatcher_1/features/orders/create_order_screen.dart';
import 'package:dispatcher_1/features/orders/orders_store.dart';
import 'package:dispatcher_1/features/profile/account_block.dart';
import 'package:dispatcher_1/features/profile/reviews_screen.dart';

/// Просмотр чужой карточки исполнителя (открывается заказчиком из
/// каталога). Данные — из `executor_cards` + `profiles` + aggregate
/// по `services`. Контакты не показываем — они в `profiles_private`
/// под RLS, доступны только участнику accepted-мэтча.
class ExecutorCardViewScreen extends StatefulWidget {
  const ExecutorCardViewScreen({super.key, required this.executorId});

  final String executorId;

  @override
  State<ExecutorCardViewScreen> createState() =>
      _ExecutorCardViewScreenState();
}

class _ExecutorCardViewScreenState extends State<ExecutorCardViewScreen> {
  late Future<ExecutorCardListItem?> _future;

  @override
  void initState() {
    super.initState();
    _future = CatalogService.instance.getExecutorById(widget.executorId);
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
        return 'ООО';
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

  String _fmtRating(double v) =>
      v.toStringAsFixed(1).replaceAll('.', ',');

  String _fmtPrice(double v) {
    final int i = v.round();
    final String s = i.toString();
    final StringBuffer b = StringBuffer();
    for (int k = 0; k < s.length; k++) {
      if (k > 0 && (s.length - k) % 3 == 0) b.write(' ');
      b.write(s[k]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const DarkSubAppBar(title: 'Исполнитель'),
      body: FutureBuilder<ExecutorCardListItem?>(
        future: _future,
        builder: (BuildContext context,
            AsyncSnapshot<ExecutorCardListItem?> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final ExecutorCardListItem? e = snap.data;
          if (e == null) {
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
          final bool alreadyOffered =
              OfferSubmissions.isOffered(e.userId);
          return SafeArea(
            top: false,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: _buildContent(e),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        offset: const Offset(0, -1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                  child: PrimaryButton(
                    label: alreadyOffered ? 'Заказ уже предложен' : 'Предложить заказ',
                    enabled: !alreadyOffered,
                    onPressed:
                        alreadyOffered ? null : () => _onPropose(e),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(ExecutorCardListItem e) {
    return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 36.r,
                        backgroundColor: AppColors.primaryTint,
                        backgroundImage: (e.avatarUrl != null &&
                                e.avatarUrl!.trim().isNotEmpty)
                            ? NetworkImage(e.avatarUrl!) as ImageProvider
                            : const AssetImage(
                                'assets/images/catalog/avatar_placeholder.webp'),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(e.name, style: AppTextStyles.titleS),
                            SizedBox(height: 4.h),
                            Row(
                              children: <Widget>[
                                Icon(Icons.star_rounded,
                                    size: 20.r,
                                    color: AppColors.ratingStar),
                                SizedBox(width: 4.w),
                                Text(_fmtRating(e.ratingAsExecutor),
                                    style: AppTextStyles.body),
                                SizedBox(width: 16.w),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const ReviewsScreen(),
                                    ),
                                  ),
                                  child: Text(
                                    '${e.reviewCountAsExecutor} ${reviewsWord(e.reviewCountAsExecutor)}',
                                    style: AppTextStyles.body.copyWith(
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
                  SizedBox(height: 20.h),
                  _Field(
                    label: 'Статус',
                    value: _legalStatusLabel(e.legalStatus),
                  ),
                  if (e.experienceYears != null) ...<Widget>[
                    SizedBox(height: 16.h),
                    _Field(
                      label: 'Опыт работы',
                      value:
                          '${e.experienceYears} ${_yearsWord(e.experienceYears!)}',
                    ),
                  ],
                  if (e.locationAddress != null &&
                      e.locationAddress!.trim().isNotEmpty) ...<Widget>[
                    SizedBox(height: 16.h),
                    Text('Адрес',
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700)),
                    SizedBox(height: 4.h),
                    ClickableAddress(e.locationAddress!,
                        baseStyle: AppTextStyles.body),
                  ],
                  if (e.radiusKm != null) ...<Widget>[
                    SizedBox(height: 16.h),
                    _Field(label: 'Радиус выезда',
                        value: 'до ${e.radiusKm} км'),
                  ],
                  if (e.machineryTitles.isNotEmpty) ...<Widget>[
                    SizedBox(height: 20.h),
                    Text('Спецтехника',
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700)),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: e.machineryTitles
                          .map((String t) => _Pill(label: t))
                          .toList(),
                    ),
                  ],
                  if (e.categoryTitles.isNotEmpty) ...<Widget>[
                    SizedBox(height: 16.h),
                    Text('Категории работ',
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700)),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: e.categoryTitles
                          .map((String t) => _Pill(label: t))
                          .toList(),
                    ),
                  ],
                  if (e.minPricePerHour != null ||
                      e.minPricePerDay != null) ...<Widget>[
                    SizedBox(height: 16.h),
                    Text('Стоимость от',
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700)),
                    SizedBox(height: 8.h),
                    Row(
                      children: <Widget>[
                        if (e.minPricePerHour != null) ...<Widget>[
                          Text('${_fmtPrice(e.minPricePerHour!)} ₽/час',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(width: 16.w),
                        ],
                        if (e.minPricePerDay != null)
                          Text('${_fmtPrice(e.minPricePerDay!)} ₽/день',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ],
              ),
            );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label,
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w700)),
        SizedBox(height: 4.h),
        Text(value, style: AppTextStyles.body),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
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
