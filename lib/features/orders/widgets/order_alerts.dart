import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';

import 'package:dispatcher_1/core/widgets/dialog_close_button.dart';
/// Алерт «Вы уверены, что хотите переместить заказ в архив?»
/// Используется, когда заказчик хочет убрать заказ.
Future<void> showConfirmRefuseDialog(
  BuildContext context, {
  required VoidCallback onRefuse,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (BuildContext ctx) => _ConfirmDialog(
      title: 'Вы уверены, что хотите\nпереместить заказ в архив?',
      primaryLabel: 'Переместить в архив',
      onPrimary: () {
        Navigator.of(ctx).pop();
        onRefuse();
      },
    ),
  );
}

/// Алерт «Вы уверены, что хотите отменить заказ?» — для статуса
/// «Свяжитесь с исполнителем» (accepted). Функционально делает то же
/// самое, что `showConfirmRefuseDialog` (UPDATE заказа в `cancelled`),
/// но текст и кнопка другие — отмена принятого заказа звучит иначе,
/// чем простое «перемещение в архив».
Future<void> showConfirmCancelDialog(
  BuildContext context, {
  required VoidCallback onCancel,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (BuildContext ctx) => _ConfirmDialog(
      title: 'Вы уверены, что хотите\nотменить заказ?',
      primaryLabel: 'Отменить заказ',
      onPrimary: () {
        Navigator.of(ctx).pop();
        onCancel();
      },
    ),
  );
}

/// Алерт «Вы уверены, что хотите переместить заказ в архив?»
/// Используется, когда заказ ещё ожидает.
Future<void> showConfirmDeclineDialog(
  BuildContext context, {
  required VoidCallback onDecline,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (BuildContext ctx) => _ConfirmDialog(
      title: 'Вы уверены, что хотите\nпереместить заказ в архив?',
      primaryLabel: 'Переместить в архив',
      onPrimary: () {
        Navigator.of(ctx).pop();
        onDecline();
      },
    ),
  );
}

/// Подтверждение выбора исполнителя заказчиком.
Future<void> showConfirmAcceptDialog(
  BuildContext context, {
  required VoidCallback onConfirm,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (BuildContext ctx) => _ConfirmDialog(
      title: 'Вы уверены, что хотите\nвыбрать этого исполнителя?',
      primaryLabel: 'Подтвердить',
      onPrimary: () {
        Navigator.of(ctx).pop();
        onConfirm();
      },
    ),
  );
}

/// Алерт «Исполнитель выбран. Свяжитесь с ним по указанным на странице
/// данным.» — показывается заказчику после выбора исполнителя из
/// списка откликнувшихся. После закрытия заказ уходит в статус
/// «Свяжитесь с исполнителем».
Future<void> showExecutorSelectedDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (BuildContext ctx) => Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.r, 22.r, 16.r, 22.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Исполнитель выбран',
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
              'Свяжитесь с ним по указанным на странице данным.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                height: 1.3,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 18.h),
            PrimaryButton(
              label: 'Ок',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Алерт «Вы оставили отзыв» — показывается после успешной отправки отзыва.
/// Возвращает `true`, если пользователь нажал «Мои отзывы», иначе `null`.
Future<bool?> showReviewSentDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (BuildContext ctx) => Dialog(
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
              child: DialogCloseButton(
                onTap: () => Navigator.of(ctx).pop(),
                color: AppColors.textTertiary,
                iconSize: 22.r,
              ),
            ),
            SizedBox(height: 10.h),
            Center(
              child: Image.asset(
                'assets/images/orders/big_star.webp',
                width: 67.r,
                height: 67.r,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 30.h),
            Text(
              'Вы оставили отзыв',
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
              'Пользователь увидит вашу оценку',
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
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Диалог «Работа не завершена?» — заказчик не согласен с «работа
/// выполнена» от исполнителя и обязан описать причину: она уйдёт
/// модератору вместе с заказом. Возвращает введённый текст (обрезанный
/// по краям, до 300 символов) или `null`, если пользователь закрыл
/// диалог не отправив.
Future<String?> showDeclineCompletionReasonDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (BuildContext ctx) => const _DeclineCompletionReasonDialog(),
  );
}

/// Тело диалога отклонения завершения: тот же хаус-стайл, что у
/// [_ConfirmDialog] (голый Dialog + Container, крестик, оранжевая
/// кнопка, текстовая «Вернуться»), плюс обязательное поле причины.
/// Кнопка «Отправить модератору» неактивна, пока причина пустая —
/// сервер всё равно отверг бы её кодом `reason_required`.
class _DeclineCompletionReasonDialog extends StatefulWidget {
  const _DeclineCompletionReasonDialog();

  @override
  State<_DeclineCompletionReasonDialog> createState() =>
      _DeclineCompletionReasonDialogState();
}

class _DeclineCompletionReasonDialogState
    extends State<_DeclineCompletionReasonDialog> {
  final TextEditingController _reason = TextEditingController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _reason.addListener(() {
      final bool ok = _reason.text.trim().isNotEmpty;
      if (ok != _canSend) setState(() => _canSend = ok);
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

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
        // Скролл — на случай маленького экрана с открытой клавиатурой:
        // без него колонка с полем ввода переполняет диалог.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: DialogCloseButton(
                  onTap: () => Navigator.of(context).pop(),
                  color: AppColors.textTertiary,
                  iconSize: 22.r,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Работа не завершена?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Опишите, что именно не выполнено. Причина уйдёт '
                'модератору — он проверит заказ и примет решение.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 16.h),
              Container(
                constraints: BoxConstraints(minHeight: 56.h),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 12.h,
                ),
                child: TextField(
                  controller: _reason,
                  maxLines: 4,
                  minLines: 2,
                  maxLength: 300,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(300),
                  ],
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    // Счётчик «0/300» не показываем — лимит нужен только
                    // как валидация ввода (сервер режет ровно до 300).
                    counterText: '',
                    hintText: 'Опишите причину',
                    hintStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              PrimaryButton(
                label: 'Отправить модератору',
                enabled: _canSend,
                onPressed: () =>
                    Navigator.of(context).pop(_reason.text.trim()),
              ),
              SizedBox(height: 20.h),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Center(
                  child: Text(
                    'Вернуться',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }
}

/// Внутренний компонент: модалка-подтверждение с заголовком, кнопкой
/// и текстом «Вернуться» снизу.
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final String title;
  final String primaryLabel;
  final VoidCallback onPrimary;

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
              child: DialogCloseButton(
                onTap: () => Navigator.of(context).pop(),
                color: AppColors.textTertiary,
                iconSize: 22.r,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 20.h),
            PrimaryButton(label: primaryLabel, onPressed: onPrimary),
            SizedBox(height: 20.h),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Center(
                child: Text(
                  'Вернуться',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}
