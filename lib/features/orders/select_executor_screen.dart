import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dispatcher_1/core/customer_orders/customer_orders_service.dart';
import 'package:dispatcher_1/core/customer_orders/models.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/utils/plural.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/orders/orders_store.dart';
import 'package:dispatcher_1/features/orders/widgets/order_alerts.dart';
import 'package:dispatcher_1/features/orders/widgets/order_status_pill.dart';

/// Экран выбора исполнителя — открывается по тапу на заказ со статусом
/// «ожидает» с откликами. Источник откликов — таблица `order_matches`
/// через [CustomerOrdersService.listResponsesForOrder].
class SelectExecutorScreen extends StatefulWidget {
  const SelectExecutorScreen({
    super.key,
    required this.order,
    required this.onMoveToArchive,
    required this.onExecutorSelected,
  });

  final OrderMock order;
  final VoidCallback onMoveToArchive;

  /// Вызывается после успешного UPDATE в `order_matches` — сюда
  /// передаются id мэтча, имя и id исполнителя, чтобы родитель показал
  /// его в карточке заказа и впоследствии смог подтянуть контакты из
  /// `profiles_private` (RLS пускает только после `accepted`).
  final void Function(String matchId, String executorName, String executorId)
      onExecutorSelected;

  @override
  State<SelectExecutorScreen> createState() => _SelectExecutorScreenState();
}

class _SelectExecutorScreenState extends State<SelectExecutorScreen> {
  late Future<List<IncomingResponse>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = CustomerOrdersService.instance
        .listResponsesForOrder(widget.order.id);
  }

  Future<void> _pickExecutor(IncomingResponse r) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await CustomerOrdersService.instance.proposeToExecutor(r.matchId);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось выбрать: ${e.message}')),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось выбрать исполнителя.')),
      );
      return;
    }

    MyOrdersStore.proposeToExecutor(widget.order,
        name: r.executorName,
        phone: '',
        matchId: r.matchId,
        executorId: r.executorId);

    if (!mounted) return;
    await showExecutorSelectedDialog(context);
    if (!mounted) return;
    widget.onExecutorSelected(r.matchId, r.executorName, r.executorId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: DarkSubAppBar(title: widget.order.title),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<IncomingResponse>>(
          future: _future,
          builder: (BuildContext context,
              AsyncSnapshot<List<IncomingResponse>> snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _Retry(onRetry: () => setState(() {
                    _future = CustomerOrdersService.instance
                        .listResponsesForOrder(widget.order.id);
                  }));
            }
            final List<IncomingResponse> responses = (snap.data ??
                    const <IncomingResponse>[])
                .where((IncomingResponse r) => r.status == 'awaiting_customer')
                .toList();
            return Column(
              children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                        child: OrderStatusPill(
                          status: widget.order.status,
                          count: responses.length,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(widget.order.displayNumber,
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textTertiary)),
                            SizedBox(height: 4.h),
                            Text(widget.order.title,
                                style:
                                    AppTextStyles.titleL.copyWith(height: 1.2)),
                            SizedBox(height: 12.h),
                            Text('Дата и время аренды',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                  color: AppColors.textPrimary,
                                )),
                            SizedBox(height: 4.h),
                            Text(widget.order.rentDate,
                                style: AppTextStyles.subBody
                                    .copyWith(fontWeight: FontWeight.w400)),
                            SizedBox(height: 16.h),
                            Text('Требуемая спецтехника',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                  color: AppColors.textPrimary,
                                )),
                            SizedBox(height: 8.h),
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 8.h,
                              children: widget.order.equipment
                                  .map((String e) => _Chip(label: e))
                                  .toList(),
                            ),
                            SizedBox(height: 16.h),
                          ],
                        ),
                      ),
                      if (responses.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(24.w),
                          child: Text(
                            'Откликов пока нет',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMRegular
                                .copyWith(color: AppColors.textTertiary),
                          ),
                        )
                      else
                        for (final IncomingResponse r in responses)
                          _ResponseCard(
                            response: r,
                            enabled: !_busy,
                            onPick: () => _pickExecutor(r),
                          ),
                      SizedBox(height: 16.h),
                    ],
                  ),
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
                  child: SecondaryButton(
                    label: 'Переместить в архив',
                    onPressed: _busy
                        ? null
                        : () => showConfirmRefuseDialog(
                              context,
                              onRefuse: widget.onMoveToArchive,
                            ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({
    required this.response,
    required this.enabled,
    required this.onPick,
  });
  final IncomingResponse response;
  final bool enabled;
  final VoidCallback onPick;

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
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(14.r),
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 24.r,
                  backgroundColor: AppColors.primaryTint,
                  child: Text(
                    response.executorName.isEmpty
                        ? '?'
                        : response.executorName[0].toUpperCase(),
                    style: AppTextStyles.titleS,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(response.executorName,
                          style: AppTextStyles.titleS),
                      SizedBox(height: 4.h),
                      Row(
                        children: <Widget>[
                          Icon(Icons.star_rounded,
                              size: 18.r, color: AppColors.ratingStar),
                          SizedBox(width: 4.w),
                          Text(_fmtRating(response.executorRating),
                              style: AppTextStyles.body),
                          SizedBox(width: 12.w),
                          Text(
                            '${response.executorReviewCount} ${reviewsWord(response.executorReviewCount)}',
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (response.serviceMachineryTitles.isNotEmpty) ...<Widget>[
              SizedBox(height: 12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: response.serviceMachineryTitles
                    .map((String e) => _Chip(label: e))
                    .toList(),
              ),
            ],
            if (response.agreedPricePerHour != null ||
                response.agreedPricePerDay != null) ...<Widget>[
              SizedBox(height: 12.h),
              Row(
                children: <Widget>[
                  if (response.agreedPricePerHour != null) ...<Widget>[
                    Text('${_fmtPrice(response.agreedPricePerHour!)} ₽/час',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                    SizedBox(width: 16.w),
                  ],
                  if (response.agreedPricePerDay != null)
                    Text('${_fmtPrice(response.agreedPricePerDay!)} ₽/день',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                ],
              ),
            ],
            SizedBox(height: 16.h),
            PrimaryButton(
              label: 'Выбрать исполнителя',
              enabled: enabled,
              onPressed: enabled ? onPick : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
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

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Не удалось загрузить отклики',
              style: AppTextStyles.bodyMRegular
                  .copyWith(color: AppColors.textPrimary)),
          SizedBox(height: 12.h),
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}
