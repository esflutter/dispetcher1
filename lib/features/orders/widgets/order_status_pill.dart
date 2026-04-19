import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Состояния заказа заказчика — определяют цвет и текст пилюли статуса.
enum MyOrderStatus {
  /// Заказ опубликован, но ни один исполнитель ещё не откликнулся.
  /// Подсказываем заказчику поискать в каталоге самому.
  waiting,

  /// Заказчик уже предложил заказ конкретному исполнителю из каталога —
  /// ждём, пока тот подтвердит или откажется.
  awaitingExecutor,

  /// Пришли отклики — заказчик должен выбрать исполнителя.
  waitingChoose,

  /// Исполнитель выбран — можно связаться.
  accepted,

  /// Исполнитель отказался после подтверждения — заказчик должен
  /// выбрать нового из откликнувшихся.
  executorDeclined,

  /// Исполнитель отказался, но других откликов нет — заказчику
  /// подсказываем поискать в каталоге самому, как при обычном
  /// «ожидании откликов». Визуально — зелёная пилюля.
  executorDeclinedWaiting,

  /// Заказ выполнен.
  completed,

  /// Не нашёлся исполнитель (срок истёк, никто не откликнулся).
  rejectedOther,

  /// Заказ отменён заказчиком. Объединяет бывшие «отменён после выбора
  /// исполнителя» и «снят с публикации до выбора» — UI у них одинаковый,
  /// суть одна: заказчик сам прекратил заказ.
  rejectedDeclined,
}

extension MyOrderStatusX on MyOrderStatus {
  String get label {
    switch (this) {
      case MyOrderStatus.waiting:
        return 'Откликов пока нет';
      case MyOrderStatus.awaitingExecutor:
        return 'Ждёт подтверждения от исполнителя';
      case MyOrderStatus.waitingChoose:
        return 'Выберите исполнителя';
      case MyOrderStatus.accepted:
        return 'Свяжитесь с исполнителем';
      case MyOrderStatus.executorDeclined:
        return 'Исполнитель отказался. Выберите другого';
      case MyOrderStatus.executorDeclinedWaiting:
        return 'Исполнитель отказался. Откликов пока нет';
      case MyOrderStatus.completed:
        return 'Завершён';
      case MyOrderStatus.rejectedOther:
        return 'Исполнитель не найден';
      case MyOrderStatus.rejectedDeclined:
        return 'Отменён';
    }
  }

  Color get bg {
    switch (this) {
      case MyOrderStatus.waiting:
      case MyOrderStatus.awaitingExecutor:
      case MyOrderStatus.executorDeclinedWaiting:
        return const Color(0xFFE6F8EF);
      case MyOrderStatus.waitingChoose:
      case MyOrderStatus.accepted:
      case MyOrderStatus.executorDeclined:
        // #1DAEDE @ 10%
        return const Color(0x1A1DAEDE);
      case MyOrderStatus.completed:
      case MyOrderStatus.rejectedOther:
      case MyOrderStatus.rejectedDeclined:
        return const Color(0xFFF1F1F1);
    }
  }

  Color get fg {
    switch (this) {
      case MyOrderStatus.waiting:
      case MyOrderStatus.awaitingExecutor:
      case MyOrderStatus.executorDeclinedWaiting:
        return const Color(0xFF1FAE5C);
      case MyOrderStatus.waitingChoose:
      case MyOrderStatus.accepted:
      case MyOrderStatus.executorDeclined:
        return const Color(0xFF1DAEDE);
      case MyOrderStatus.completed:
      case MyOrderStatus.rejectedOther:
      case MyOrderStatus.rejectedDeclined:
        return const Color(0xFF7A7A7A);
    }
  }
}

/// Полноразмерная пилюля статуса (на всю ширину контейнера).
/// Используется и в карточках списка, и в экране деталей.
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({
    super.key,
    required this.status,
    this.count,
  });

  final MyOrderStatus status;

  /// Опциональный счётчик, приписывается к тексту статуса в скобках.
  /// Используется в статусе [MyOrderStatus.waitingChoose] для показа
  /// количества откликнувшихся исполнителей — «Выберите исполнителя (3)».
  final int? count;

  @override
  Widget build(BuildContext context) {
    final String label =
        count != null ? '${status.label} ($count)' : status.label;
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
        label,
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
