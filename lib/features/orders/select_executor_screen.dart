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

  static const List<_Responder> _mockResponders = <_Responder>[
    _Responder(
      id: 'resp_1',
      name: 'Александр Иванов',
      phone: '+7 999 111-22-33',
      rating: 4.5,
      experience: '8 лет',
      legalStatus: 'Юр. лицо',
      equipment: <String>['Экскаватор', 'Автокран', 'Эвакуатор', 'Автовышка'],
      categories: <String>[
        'Строительные работы',
        'Дорожные работы',
        'Буровые работы',
        'Высотные работы',
      ],
    ),
    _Responder(
      id: 'resp_2',
      name: 'Иван Петров',
      phone: '+7 999 222-33-44',
      rating: 4.8,
      experience: '5 лет',
      legalStatus: 'Юр. лицо',
      equipment: <String>['Экскаватор', 'Автокран', 'Эвакуатор', 'Автовышка'],
      categories: <String>[
        'Строительные работы',
        'Дорожные работы',
      ],
    ),
    _Responder(
      id: 'resp_3',
      name: 'Сергей Петров',
      phone: '+7 999 333-44-55',
      rating: 4.8,
      experience: '10 лет',
      legalStatus: 'ИП',
      equipment: <String>['Автокран', 'Экскаватор'],
      categories: <String>[
        'Строительные работы',
        'Погрузочно-разгрузочные работы',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final String title = order.title;
    // Для моков (у которых id вида 'n2', 'a1') — собираем номер только
    // из цифр, чтобы на экране не было букв из тех. id.
    final String digitsOnly = order.id.replaceAll(RegExp(r'\D'), '');
    final String number = order.number ??
        '№${digitsOnly.padLeft(6, '0').substring(0, 6)}';
    // Показываем столько карточек, сколько в заказе откликов. Если
    // счётчик не задан — берём весь моковый список. Клэмпим на всякий
    // случай, чтобы не вылезти за пределы массива.
    final int visibleCount =
        (order.respondersCount ?? _mockResponders.length)
            .clamp(0, _mockResponders.length);

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
                      ],
                    ),
                  ),
                  for (int i = 0; i < visibleCount; i++) ...<Widget>[
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
                          name: _mockResponders[i].name,
                          rating: _mockResponders[i].rating,
                          experience: _mockResponders[i].experience,
                          legalStatus: _mockResponders[i].legalStatus,
                          equipment: _mockResponders[i].equipment,
                          categories: _mockResponders[i].categories,
                          highlightEquipment: order.equipment.toSet(),
                          onTap: () {
                            final _Responder responder = _mockResponders[i];
                            // Запоминаем route самого SelectExecutorScreen,
                            // чтобы позже одним `popUntil` закрыть всю
                            // цепочку «карточка исполнителя → услуги» —
                            // даже если пользователь провалился в services.
                            final ModalRoute<dynamic>? selectRoute =
                                ModalRoute.of(context);
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (BuildContext detailCtx) =>
                                    OrderDetailScreen(
                                  orderId: responder.id,
                                  multipleEquipment: true,
                                  selectMode: true,
                                  executor: responder.toExecutor(),
                                  onSelectExecutor: () async {
                                    await showExecutorSelectedDialog(detailCtx);
                                    if (!detailCtx.mounted) return;
                                    // Сворачиваем всю вложенную цепочку
                                    // (services + executor card) до
                                    // SelectExecutorScreen. Дальше
                                    // onExecutorSelected закроет его и
                                    // откроет карточку заказа в статусе
                                    // accepted — в итоге «назад» с
                                    // этой карточки вернёт в список
                                    // заказов, без промежуточных слоёв.
                                    if (selectRoute != null) {
                                      Navigator.of(detailCtx).popUntil(
                                          (Route<dynamic> r) =>
                                              r == selectRoute);
                                    }
                                    onExecutorSelected(
                                      responder.id,
                                      responder.name,
                                      responder.phone,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
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

class _Responder {
  const _Responder({
    required this.id,
    required this.name,
    required this.phone,
    required this.rating,
    required this.experience,
    required this.legalStatus,
    required this.equipment,
    required this.categories,
  });

  final String id;
  final String name;
  final String phone;
  final double rating;
  final String experience;
  final String legalStatus;
  final List<String> equipment;
  final List<String> categories;

  /// Для передачи в `OrderDetailScreen(executor: ...)` — чтобы карточка
  /// исполнителя показывала данные ответчика, а не fallback-заглушку.
  ExecutorMock toExecutor() => ExecutorMock(
        id: id,
        name: name,
        rating: rating,
        experience: experience,
        legalStatus: legalStatus,
        equipment: equipment,
        categories: categories,
        pricePerHour: 0,
        pricePerDay: 0,
      );
}
