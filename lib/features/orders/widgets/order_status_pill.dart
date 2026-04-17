import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Состояния заказа заказчика — определяют цвет и текст пилюли статуса.
enum MyOrderStatus {
  /// Заказ на рассмотрении — ждём откликов от исполнителей.
  waiting,

  /// Пришли отклики — заказчик должен выбрать исполнителя.
  waitingChoose,

  /// Исполнитель выбран — можно связаться.
  accepted,

  /// Заказ выполнен.
  completed,

  /// Не нашёлся исполнитель.
  rejectedOther,

  /// Заказ был отменён.
  rejectedDeclined,

  /// Заказ был снят с публикации.
  rejectedRemoved,
}

extension MyOrderStatusX on MyOrderStatus {
  String get label {
    switch (this) {
      case MyOrderStatus.waiting:
        return 'Ждёт подтверждения от исполнителя';
      case MyOrderStatus.waitingChoose:
        return 'Выберите исполнителя';
      case MyOrderStatus.accepted:
        return 'Свяжитесь с исполнителем';
      case MyOrderStatus.completed:
        return 'Завершён';
      case MyOrderStatus.rejectedOther:
        return 'Исполнитель не найден';
      case MyOrderStatus.rejectedDeclined:
        return 'Заказ отменён';
      case MyOrderStatus.rejectedRemoved:
        return 'Заказ был снят с публикации';
    }
  }

  Color get bg {
    switch (this) {
      case MyOrderStatus.waiting:
        return const Color(0xFFE6F8EF);
      case MyOrderStatus.waitingChoose:
      case MyOrderStatus.accepted:
        // #1DAEDE @ 10%
        return const Color(0x1A1DAEDE);
      case MyOrderStatus.completed:
      case MyOrderStatus.rejectedRemoved:
        return const Color(0xFFF1F1F1);
      case MyOrderStatus.rejectedOther:
      case MyOrderStatus.rejectedDeclined:
        return const Color(0xFFFDECEC);
    }
  }

  Color get fg {
    switch (this) {
      case MyOrderStatus.waiting:
        return const Color(0xFF1FAE5C);
      case MyOrderStatus.waitingChoose:
      case MyOrderStatus.accepted:
        return const Color(0xFF1DAEDE);
      case MyOrderStatus.completed:
      case MyOrderStatus.rejectedRemoved:
        return const Color(0xFF7A7A7A);
      case MyOrderStatus.rejectedOther:
      case MyOrderStatus.rejectedDeclined:
        return const Color(0xFFE53935);
    }
  }
}

/// Полноразмерная пилюля статуса (на всю ширину контейнера).
/// Используется и в карточках списка, и в экране деталей.
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.status});

  final MyOrderStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 25.h,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Text(
        status.label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          height: 1.0,
          color: status.fg,
        ),
      ),
    );
  }
}
