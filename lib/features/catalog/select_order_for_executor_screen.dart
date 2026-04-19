import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';
import 'package:dispatcher_1/features/catalog/widgets/respond_bottom_sheet.dart';
import 'package:dispatcher_1/features/orders/orders_store.dart';

/// Трекер отправленных откликов по executor-order id. После отправки
/// отклика по конкретной карточке исполнителя кнопка «Предложить заказ»
/// на ней должна скрываться.
class OfferSubmissions {
  OfferSubmissions._();

  static final Set<String> _offered = <String>{};
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool isOffered(String executorOrderId) =>
      _offered.contains(executorOrderId);

  static void mark(String executorOrderId) {
    if (_offered.add(executorOrderId)) revision.value++;
  }
}

/// Экран «Выбор заказа для исполнителя».
/// Открывается при нажатии «Предложить заказ» в карточке исполнителя
/// (или в деталях услуги), если у заказчика уже есть созданные заказы.
class SelectOrderForExecutorScreen extends StatefulWidget {
  const SelectOrderForExecutorScreen({
    super.key,
    required this.executorOrderId,
  });

  final String executorOrderId;

  @override
  State<SelectOrderForExecutorScreen> createState() =>
      _SelectOrderForExecutorScreenState();
}

class _SelectOrderForExecutorScreenState
    extends State<SelectOrderForExecutorScreen> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    // Подписываемся на изменения списка: если пользователь прямо из
    // этого экрана уходит создавать новый заказ и возвращается — мы
    // должны увидеть его в списке сразу.
    MyOrdersStore.revision.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    MyOrdersStore.revision.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  /// Список заказов, которые заказчик может предложить этому
  /// исполнителю: опубликованные без выбранного исполнителя.
  /// Сортируем от новых к старым — единообразно с «Мои заказы».
  List<OrderMock> get _items {
    final List<OrderMock> list = List<OrderMock>.of(MyOrdersStore.offerable);
    list.sort(
        (OrderMock a, OrderMock b) => b.publishedAt.compareTo(a.publishedAt));
    return list;
  }

  Future<void> _onRespond() async {
    final OrderMock? selected = _selectedId == null
        ? null
        : _items.firstWhere(
            (OrderMock o) => o.id == _selectedId,
            orElse: () => _items.first,
          );
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => const RespondModalDialog(),
    );
    OfferSubmissions.mark(widget.executorOrderId);
    // После подтверждения переводим заказ в «Ждёт подтверждения от
    // исполнителя» (awaitingExecutor) — именно этот статус отражает
    // «предложил конкретному исполнителю, ждём его решения».
    if (selected != null) {
      MyOrdersStore.proposeToExecutor(selected);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final List<OrderMock> items = _items;
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
            'Выбор заказа для исполнителя',
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
        child: AiAssistantFab(onTap: () => context.push('/assistant/chat')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 1,
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              itemBuilder: (_, int i) {
                final OrderMock o = items[i];
                final bool selected = _selectedId == o.id;
                return _OrderOfferTile(
                  order: o,
                  selected: selected,
                  onTap: () => setState(() => _selectedId = o.id),
                );
              },
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
              16.h + MediaQuery.of(context).padding.bottom,
            ),
            child: PrimaryButton(
              label: 'Предложить заказ',
              enabled: _selectedId != null,
              onPressed: _selectedId == null ? null : _onRespond,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderOfferTile extends StatelessWidget {
  const _OrderOfferTile({
    required this.order,
    required this.selected,
    required this.onTap,
  });

  final OrderMock order;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected
            ? const Color(0xFFFFF4E3)
            : Colors.transparent,
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8.w,
              runSpacing: 4.h,
              children: order.equipment
                  .map((String e) => Text(
                        e,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ))
                  .toList(),
            ),
            SizedBox(height: 10.h),
            Text(
              order.title,
              style: AppTextStyles.body.copyWith(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 10.h),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: 'Дата аренды: ',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: order.rentDate,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 4.h),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: 'Адрес: ',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: order.address,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12.sp,
                      color: AppColors.textPrimary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Диалог «Вы ещё не создали заказ». Показывается при нажатии
/// «Предложить заказ», когда у заказчика нет созданных заказов.
class NoOrderDialog extends StatelessWidget {
  const NoOrderDialog({super.key, this.onCreateOrder});

  final VoidCallback? onCreateOrder;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.r, 18.r, 16.r, 16.r),
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
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(Icons.close_rounded,
                    size: 22.r, color: AppColors.textTertiary),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Вы ещё не создали заказ',
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.titleL.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 10.h),
            Text(
              'Создайте заказ, чтобы выбрать\nисполнителя',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMRegular
                  .copyWith(color: AppColors.textSecondary),
            ),
            SizedBox(height: 20.h),
            PrimaryButton(
              label: 'Создать заказ',
              onPressed: () {
                Navigator.of(context).pop();
                onCreateOrder?.call();
              },
            ),
            SizedBox(height: 8.h),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Вернуться',
                style: AppTextStyles.bodyL.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
