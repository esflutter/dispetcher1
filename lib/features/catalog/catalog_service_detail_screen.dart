import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/photo_gallery_screen.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/select_order_for_executor_screen.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';
import 'package:dispatcher_1/features/orders/create_order_screen.dart';
import 'package:dispatcher_1/features/orders/orders_store.dart';

/// Склонение «час» после предлога «от» (род. падеж).
String _hoursWord(int n) {
  final int mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 14) return 'часов';
  if (n % 10 == 1) return 'часа';
  return 'часов';
}

/// Экран «Детали услуги» из карточки исполнителя в приложении заказчика.
/// Стиль идентичен такому же экрану в приложении исполнителя; отличается
/// только текст нижней кнопки — «Предложить заказ».
class CatalogServiceDetailScreen extends StatefulWidget {
  const CatalogServiceDetailScreen({
    super.key,
    required this.executorOrderId,
    required this.title,
    required this.description,
    required this.priceHour,
    required this.priceDay,
    required this.minOrderHours,
    required this.machinery,
    required this.categories,
    this.selectMode = false,
    this.onSelectExecutor,
  }) : assert(
          !selectMode || onSelectExecutor != null,
          'selectMode требует non-null onSelectExecutor: иначе кнопка '
          '«Выбрать исполнителя» будет показываться, но ничего не делать',
        );

  final String executorOrderId;
  final String title;
  final String description;
  final String priceHour;
  final String priceDay;
  final int minOrderHours;
  final List<String> machinery;
  final List<String> categories;

  /// true — экран открыт из потока «Выберите исполнителя»: вместо
  /// «Предложить заказ» внизу показываем «Выбрать исполнителя» и
  /// по нажатию вызываем [onSelectExecutor]. Нужно для согласованности
  /// с карточкой исполнителя (`catalog/order_detail_screen.dart`).
  final bool selectMode;

  /// Колбэк «Выбрать исполнителя» в `selectMode`. Родитель должен
  /// показать диалог подтверждения и перевести заказ в `accepted`.
  final VoidCallback? onSelectExecutor;

  @override
  State<CatalogServiceDetailScreen> createState() =>
      _CatalogServiceDetailScreenState();
}

class _CatalogServiceDetailScreenState
    extends State<CatalogServiceDetailScreen> {
  static const List<String> _photos = <String>[
    'assets/images/profile/photo_1.webp',
    'assets/images/profile/photo_2.webp',
    'assets/images/profile/photo_3.webp',
    'assets/images/profile/photo_4.webp',
    'assets/images/profile/photo_5.webp',
    'assets/images/profile/photo_6.webp',
  ];

  @override
  void initState() {
    super.initState();
    OfferSubmissions.revision.addListener(_onRevision);
  }

  @override
  void dispose() {
    OfferSubmissions.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    if (mounted) setState(() {});
  }

  /// В `selectMode` флаг «уже предложено» не применим — там показываем
  /// кнопку «Выбрать исполнителя» вне зависимости от прошлых
  /// предложений. «Уже предложено» имеет смысл только в каталоге.
  bool get _alreadyOffered =>
      !widget.selectMode &&
      OfferSubmissions.isOffered(widget.executorOrderId);

  Future<void> _onRespondTap() async {
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
          executorOrderId: widget.executorOrderId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const DarkSubAppBar(title: 'Детали услуги'),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 88.h),
        child: AiAssistantFab(onTap: () => context.push('/assistant/chat')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.title,
                    style: AppTextStyles.titleL.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: <Widget>[
                      Text('₽ / час',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                      SizedBox(width: 6.w),
                      Text(widget.priceHour,
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                      SizedBox(width: 24.w),
                      Text('₽ / день',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                      SizedBox(width: 6.w),
                      Text(widget.priceDay,
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: <Widget>[
                      Text('Минимальный заказ:',
                          style: AppTextStyles.body.copyWith(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          )),
                      SizedBox(width: 6.w),
                      Text(
                        'от ${widget.minOrderHours} ${_hoursWord(widget.minOrderHours)}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Text(widget.description,
                      style: AppTextStyles.body
                          .copyWith(fontSize: 14.sp, height: 1.4)),
                  SizedBox(height: 16.h),
                  _SectionTitle('Спецтехника'),
                  SizedBox(height: 8.h),
                  _ChipRow(items: widget.machinery),
                  SizedBox(height: 16.h),
                  _SectionTitle('Категория работ'),
                  SizedBox(height: 8.h),
                  _ChipRow(items: widget.categories),
                  SizedBox(height: 16.h),
                  _SectionTitle('Фото'),
                  SizedBox(height: 8.h),
                  const _PhotosGrid(photos: _photos),
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
              16.h + MediaQuery.of(context).padding.bottom,
            ),
            child: PrimaryButton(
              label: widget.selectMode
                  ? 'Выбрать исполнителя'
                  : (_alreadyOffered
                      ? 'Предложение уже отправлено'
                      : 'Предложить заказ'),
              enabled: widget.selectMode || !_alreadyOffered,
              onPressed: widget.selectMode
                  ? widget.onSelectExecutor
                  : (_alreadyOffered ? null : _onRespondTap),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(
        title,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      );
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: items
          .map(
            (String label) => Container(
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
            ),
          )
          .toList(),
    );
  }
}

class _PhotosGrid extends StatelessWidget {
  const _PhotosGrid({required this.photos});
  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 4.r,
        crossAxisSpacing: 4.r,
      ),
      itemCount: photos.length,
      itemBuilder: (BuildContext ctx, int i) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(ctx).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => PhotoGalleryScreen(
              photos: photos,
              initialIndex: i,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: Image.asset(photos[i], fit: BoxFit.cover),
        ),
      ),
    );
  }
}
