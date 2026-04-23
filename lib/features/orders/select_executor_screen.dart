import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/order_detail_screen.dart';
import 'package:dispatcher_1/features/catalog/order_feed_screen.dart';
import 'package:dispatcher_1/features/catalog/widgets/order_card.dart';
import 'package:dispatcher_1/features/orders/orders_store.dart';
import 'package:dispatcher_1/features/orders/widgets/order_alerts.dart';
import 'package:dispatcher_1/features/orders/widgets/order_status_pill.dart';

/// Экран выбора исполнителя — открывается по тапу на заказ со статусом
/// [MyOrderStatus.waitingChoose]. Сверху — пилюля статуса и краткие данные
/// заказа, ниже — список откликнувшихся исполнителей (OrderCard). Внизу
/// кнопка «Переместить в архив».
class SelectExecutorScreen extends StatelessWidget {
  const SelectExecutorScreen({
    super.key,
    required this.order,
    required this.onMoveToArchive,
    required this.onExecutorSelected,
  });

  final OrderMock order;
  final VoidCallback onMoveToArchive;

  /// Вызывается, когда заказчик подтвердил выбор исполнителя из списка
  /// откликнувшихся (из карточки исполнителя → «Выбрать исполнителя»).
  /// Родитель должен перевести заказ в статус «accepted» и перейти
  /// на экран «Свяжитесь с исполнителем», подставив переданные имя
  /// и телефон исполнителя.
  final void Function(String id, String name, String phone)
      onExecutorSelected;


  @override
  Widget build(BuildContext context) {
    final String title = order.title;
    final String number = order.displayNumber;
    // Исполнители: только те, у кого есть хоть одна единица техники
    // из списка заказа. Берём не более чем respondersCount карточек —
    // чтобы счётчик в пилюле статуса совпадал с количеством карточек.
    final Set<String> orderEq = order.equipment.toSet();
    final List<ExecutorMock> allMatching = ExecutorMock.all
        .where((ExecutorMock e) =>
            e.equipment.any((String eq) => orderEq.contains(eq)))
        .toList();
    final int visibleCount =
        (order.respondersCount ?? allMatching.length)
            .clamp(0, allMatching.length);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: DarkSubAppBar(title: title),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                    child: OrderStatusPill(
                      status: order.status,
                      count: order.respondersCount,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          number,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textTertiary),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          title,
                          style:
                              AppTextStyles.titleL.copyWith(height: 1.2),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Дата и время аренды',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          order.rentDate,
                          style: AppTextStyles.subBody
                              .copyWith(fontWeight: FontWeight.w400),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Требуемая спецтехника',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: order.equipment
                              .map((String e) => Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12.w, vertical: 6.h),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      border: Border.all(
                                          color: AppColors.primary, width: 1),
                                      borderRadius:
                                          BorderRadius.circular(100.r),
                                    ),
                                    child: Text(
                                      e,
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w400,
                                        height: 1.3,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        SizedBox(height: 16.h),
                      ],
                    ),
                  ),
                  for (int i = 0; i < visibleCount; i++) ...<Widget>[
                    SizedBox(height: i == 0 ? 0 : 16.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Builder(
                        builder: (BuildContext _) {
                          final ExecutorMock executor = allMatching[i];
                          final List<ExecutorServiceOffer> matching =
                              executor.services
                                  .where((ExecutorServiceOffer s) =>
                                      orderEq.contains(s.equipment))
                                  .toList();
                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.fieldFill,
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: OrderCard(
                              name: executor.name,
                              rating: executor.rating,
                              equipment: executor.equipment,
                              categories: executor.categories,
                              matchingServices:
                                  matching.isEmpty ? null : matching,
                              highlightEquipment: orderEq,
                              onTap: () {
                                final ModalRoute<dynamic>? selectRoute =
                                    ModalRoute.of(context);
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext detailCtx) =>
                                        OrderDetailScreen(
                                      orderId: executor.id,
                                      multipleEquipment:
                                          order.equipment.length > 1,
                                      selectMode: true,
                                      executor: executor,
                                      onSelectExecutor: () async {
                                        await showExecutorSelectedDialog(
                                            detailCtx);
                                        if (!detailCtx.mounted) return;
                                        if (selectRoute != null) {
                                          Navigator.of(detailCtx).popUntil(
                                              (Route<dynamic> r) =>
                                                  r == selectRoute);
                                        }
                                        onExecutorSelected(
                                          executor.id,
                                          executor.name,
                                          executor.phone,
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  // Нижний отступ под последней карточкой — такой же, как
                  // между карточками, чтобы низ списка не прилипал к кнопке.
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
              // Bottom safe-area уже добавлен `SafeArea` у body — здесь
              // только собственные отступы под одну кнопку.
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
              child: SecondaryButton(
                label: 'Переместить в архив',
                onPressed: () => showConfirmRefuseDialog(
                  context,
                  onRefuse: onMoveToArchive,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

