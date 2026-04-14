import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/customer_card_screen.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';
import 'package:dispatcher_1/features/catalog/widgets/respond_bottom_sheet.dart';
import 'package:dispatcher_1/features/profile/widgets/verification_badge.dart';

/// Карточка исполнителя (детали). По Figma — заголовок исполнителя сверху,
/// далее «техника → местоположение → категории → описание → стоимость».
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.multipleEquipment = false,
    this.price = '80 000 – 100 000 ₽',
  });

  final String orderId;
  final bool multipleEquipment;
  final String price;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  static const List<String> _multiEquipment = <String>[
    'Экскаватор',
    'Автокран',
    'Манипулятор',
    'Погрузчик',
    'Автовышка',
  ];

  bool get _verified => VerificationStatus.current.isVerified;

  // Моковый список техники из заказа.
  List<String> get _orderEquipment => widget.multipleEquipment
      ? _multiEquipment
      : const <String>['Экскаватор', 'Автокран', 'Манипулятор', 'Погрузчик', 'Автовышка'];

  Future<void> _onRespondTap() async {
    // 1. Проверка верификации — в процессе.
    if (VerificationStatus.current == VerificationStatus.inProgress) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (_) => _InProgressDialog(),
      );
      return;
    }

    // 2. Верификация не пройдена — предлагаем отправить документы.
    if (!_verified) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (_) => RespondModalDialog(verified: false),
      );
      if (mounted) setState(() {});
      return;
    }

    // 3. Выбор техники (если несколько).
    final List<String> eq = _orderEquipment;
    if (eq.length > 1) {
      final List<String>? picked = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _PickEquipmentSheet(options: eq),
      );
      if (picked == null || !mounted) {
        return;
      }
    }

    // 5. Отклик отправлен.
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => RespondModalDialog(verified: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> equipment = _orderEquipment;

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
            style: AppTextStyles.titleS.copyWith(color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: const <Widget>[],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 88.h),
        child: AiAssistantFab(
          onTap: () => context.push('/assistant/chat'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _CustomerHeader(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const CustomerCardScreen(customerId: '1'),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _Section(
                        title: 'Местоположение',
                        child: Text(
                            'Московская область, Москва',
                            style: AppTextStyles.subBody.copyWith(
                              fontWeight: FontWeight.w400,
                            )),
                      ),
                      Text('Заказы в радиусе 10 км',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                          )),
                      SizedBox(height: 12.h),
                      _Section(
                        title: 'Спецтехника',
                        child: Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: equipment
                              .map((String e) => _OutlinedChip(label: e))
                              .toList(),
                        ),
                      ),
                      _Section(
                        title: 'Категории услуг',
                        child: Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: const <Widget>[
                            _OutlinedChip(label: 'Земляные работы'),
                            _OutlinedChip(label: 'Погрузочно-разгрузочные работы'),
                          ],
                        ),
                      ),
                      _Section(
                        title: 'Опыт работы',
                        child: Text('5 лет',
                            style: AppTextStyles.subBody.copyWith(fontWeight: FontWeight.w400)),
                      ),
                      _Section(
                        title: 'Статус',
                        child: Text('Физ. лицо',
                            style: AppTextStyles.subBody.copyWith(fontWeight: FontWeight.w400)),
                      ),
                      _Section(
                        title: 'О себе',
                        child: Text(
                            'Опыт работы более 5 лет. Своя техника в хорошем состоянии, работаю без простоев. Готов выезжать в ближайшие районы.',
                            style: AppTextStyles.subBody.copyWith(fontWeight: FontWeight.w400)),
                      ),
                      _Section(
                        title: 'Занятость',
                        child: Text('С 9:00 до 18:00',
                            style: AppTextStyles.subBody.copyWith(fontWeight: FontWeight.w400)),
                      ),
                      _Section(
                        title: 'Услуги',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _ServiceItem(
                              title: 'Экскаватор для копки траншеи',
                              description: 'Экскаватор для земляных работ. Копка траншей, разработка котлованов, выравнивание участка. Работаю аккуратно, соблюдаю сроки. Возможен выезд в ближайшие районы.',
                              priceHour: '1 000 ₽',
                              priceDay: '14 000 ₽',
                            ),
                            SizedBox(height: 12.h),
                            _ServiceItem(
                              title: 'Самосвал для вывоза грунта',
                              description: 'Вывоз грунта, мусора и сыпучих материалов. Работаю быстро, без задержек. Возможен выезд в ближайшие районы.',
                              priceHour: '1 500 ₽',
                              priceDay: '18 000 ₽',
                            ),
                            SizedBox(height: 12.h),
                            _ServiceItem(
                              title: 'Работы на высоте',
                              description: 'Работы на высоте: монтаж, обслуживание, обрезка деревьев. Техника исправна, работаю аккуратно.',
                              priceHour: '2 000 ₽',
                              priceDay: '20 000 ₽',
                            ),
                          ],
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
                16.h + MediaQuery.of(context).padding.bottom),
            child: PrimaryButton(
              label: 'Предложить заказ',
              onPressed: _onRespondTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 28.r,
            backgroundColor: AppColors.primaryTint,
            backgroundImage:
                const AssetImage('assets/images/catalog/avatar_placeholder.webp'),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Александр Иванов',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    )),
                SizedBox(height: 2.h),
                Row(
                  children: <Widget>[
                    Image.asset('assets/images/catalog/star.webp',
                        width: 20.r, height: 20.r),
                    SizedBox(width: 4.w),
                    Text('4,5',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          color: AppColors.textPrimary,
                        )),
                    SizedBox(width: 16.w),
                    Text('15 отзывов',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          color: AppColors.textPrimary,
                        )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                height: 1.3,
              )),
          SizedBox(height: 4.h),
          child,
        ],
      ),
    );
  }
}

class _OutlinedChip extends StatelessWidget {
  const _OutlinedChip({required this.label});
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
      child: Text(label,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13.sp,
            fontWeight: FontWeight.w400,
            height: 1.3,
            color: AppColors.textPrimary,
          )),
    );
  }
}

class _ServiceItem extends StatelessWidget {
  const _ServiceItem({
    required this.title,
    required this.description,
    this.priceHour,
    this.priceDay,
  });
  final String title;
  final String description;
  final String? priceHour;
  final String? priceDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            description,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (priceHour != null || priceDay != null) ...<Widget>[
            SizedBox(height: 8.h),
            Row(
              children: <Widget>[
                if (priceHour != null) ...<Widget>[
                  Text('₽ / час  ', style: TextStyle(
                    fontFamily: 'Roboto', fontSize: 12.sp,
                    color: AppColors.textTertiary,
                  )),
                  Text(priceHour!, style: TextStyle(
                    fontFamily: 'Roboto', fontSize: 14.sp,
                    fontWeight: FontWeight.w700, color: AppColors.primary,
                  )),
                ],
                if (priceHour != null && priceDay != null)
                  SizedBox(width: 16.w),
                if (priceDay != null) ...<Widget>[
                  Text('₽ / день  ', style: TextStyle(
                    fontFamily: 'Roboto', fontSize: 12.sp,
                    color: AppColors.textTertiary,
                  )),
                  Text(priceDay!, style: TextStyle(
                    fontFamily: 'Roboto', fontSize: 14.sp,
                    fontWeight: FontWeight.w700, color: AppColors.primary,
                  )),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PickEquipmentSheet extends StatefulWidget {
  const _PickEquipmentSheet({required this.options});
  final List<String> options;

  @override
  State<_PickEquipmentSheet> createState() => _PickEquipmentSheetState();
}

class _PickEquipmentSheetState extends State<_PickEquipmentSheet> {
  final Set<String> _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16.w,
        12.h,
        16.w,
        16.h + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(height: 16.h),
          Text(
            'Выберите технику, которая\nвам необходима',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          SizedBox(height: 16.h),
          for (final String e in widget.options)
            _CheckRow(
              label: e,
              checked: _picked.contains(e),
              onTap: () => setState(() {
                if (!_picked.add(e)) _picked.remove(e);
              }),
            ),
          SizedBox(height: 16.h),
          PrimaryButton(
            label: 'Предложить заказ',
            onPressed: _picked.isEmpty
                ? null
                : () => Navigator.of(context).pop(_picked.toList()),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
  });
  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Row(
          children: <Widget>[
            Container(
              width: 22.r,
              height: 22.r,
              decoration: BoxDecoration(
                color: checked ? AppColors.primary : AppColors.surface,
                border: Border.all(
                  color: checked ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: checked
                  ? Icon(Icons.check, size: 16.r, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 16.w),
            Text(label, style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }
}

class _InProgressDialog extends StatelessWidget {
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
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(Icons.close_rounded,
                    size: 22.r, color: AppColors.textTertiary),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Ваши документы ещё\nна проверке',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleL.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8.h),
            Text(
              'Вы получите уведомление, когда проверка завершится',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMRegular
                  .copyWith(color: AppColors.textSecondary),
            ),
            SizedBox(height: 18.h),
            PrimaryButton(
              label: 'Ок',
              onPressed: () => Navigator.of(context).pop(),
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }
}
