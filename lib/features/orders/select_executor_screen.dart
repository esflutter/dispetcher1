import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dispatcher_1/core/catalog/models.dart';
import 'package:dispatcher_1/core/customer_orders/customer_orders_service.dart';
import 'package:dispatcher_1/core/customer_orders/models.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/executor_card_view_screen.dart';
import 'package:dispatcher_1/features/catalog/widgets/order_card.dart';
import 'package:dispatcher_1/features/orders/orders_store.dart';
import 'package:dispatcher_1/features/orders/widgets/order_alerts.dart';
import 'package:dispatcher_1/features/orders/widgets/order_status_pill.dart';

/// Экран выбора исполнителя — открывается по тапу на заказ со статусом
/// «ожидает» с откликами. Источник откликов — таблица `order_matches`
/// через [CustomerOrdersService.listResponsesForOrder]. Каждая карточка —
/// `OrderCard` с превью прайса; тап на карточку открывает полную
/// [ExecutorCardViewScreen] в режиме `selectMode`, где кнопка снизу
/// меняется на «Выбрать исполнителя».
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
  /// передаются id мэтча, имя/аватарка и id исполнителя, чтобы
  /// родитель показал его в карточке заказа и впоследствии смог
  /// подтянуть контакты из `profiles_private` (RLS пускает только
  /// после `accepted`).
  final void Function(
    String matchId,
    String executorName,
    String executorId,
    String? executorAvatarUrl,
  ) onExecutorSelected;

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
      await CustomerOrdersService.instance.acceptResponse(r.matchId);
    } on MatchAlreadyTakenException {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('По этому заказу уже выбран другой исполнитель.'),
        ),
      );
      return;
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

    MyOrdersStore.acceptResponse(
      widget.order,
      name: r.executorName,
      phone: '',
      avatarUrl: r.executorAvatarUrl,
      matchId: r.matchId,
      executorId: r.executorId,
    );

    if (!mounted) return;
    await showExecutorSelectedDialog(context);
    if (!mounted) return;
    widget.onExecutorSelected(
      r.matchId,
      r.executorName,
      r.executorId,
      r.executorAvatarUrl,
    );
  }

  /// Открывает полную карточку исполнителя в режиме «выбор». Кнопка
  /// «Выбрать исполнителя» отрабатывает: закрывает карточку и
  /// выполняет [_pickExecutor] (UPDATE + диалог + callback родителю).
  Future<void> _openExecutorForSelection(IncomingResponse r) async {
    if (_busy) return;
    final NavigatorState nav = Navigator.of(context);
    await nav.push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext detailCtx) => ExecutorCardViewScreen(
          executorId: r.executorId,
          selectMode: true,
          onSelectExecutor: () async {
            if (!detailCtx.mounted) return;
            Navigator.of(detailCtx).pop();
            await _pickExecutor(r);
          },
        ),
      ),
    );
  }

  /// Превращает agreed-цену из отклика в строки `MatchingService` —
  /// по одной на каждую технику услуги, чтобы карточка показывала
  /// «Экскаватор — 3 500 ₽/час, от 4 часов» как в эталоне.
  List<MatchingService> _matchingServicesFor(IncomingResponse r) {
    if (r.serviceMachineryTitles.isEmpty) return const <MatchingService>[];
    return r.serviceMachineryTitles
        .map((String t) => MatchingService(
              machineryTitle: t,
              pricePerHour: r.agreedPricePerHour,
              pricePerDay: r.agreedPricePerDay,
              minHours: r.agreedMinHours,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final Set<String> orderEq = widget.order.equipment.toSet();
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
                                style: AppTextStyles.titleL
                                    .copyWith(height: 1.2)),
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
                        for (int i = 0; i < responses.length; i++) ...<Widget>[
                          SizedBox(height: i == 0 ? 0 : 16.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.fieldFill,
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: OrderCard(
                                name: responses[i].executorName,
                                rating: responses[i].executorRating,
                                avatarUrl: responses[i].executorAvatarUrl,
                                equipment: responses[i].serviceMachineryTitles,
                                categories: const <String>[],
                                matchingServices:
                                    _matchingServicesFor(responses[i]),
                                highlightEquipment: orderEq,
                                onTap: () => _openExecutorForSelection(
                                    responses[i]),
                              ),
                            ),
                          ),
                        ],
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
