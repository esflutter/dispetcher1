import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/features/catalog/order_feed_screen.dart';

/// Карточка исполнителя в ленте каталога. Слева круглый аватар, справа —
/// имя со звездой и рейтингом. Ниже — секции «Спецтехника» и
/// «Категории услуг». Опыт работы и юридический статус показываются
/// только на экране деталей, чтобы не загромождать карточку поиска.
///
/// Если передан непустой [matchingServices] — вместо двух стандартных
/// блоков показываем список конкретных услуг (техника + цена/час +
/// мин. часы) по активному фильтру спецтехники.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.name,
    required this.rating,
    required this.equipment,
    required this.categories,
    this.matchingServices,
    this.highlightEquipment = const <String>{},
    this.highlightCategories = const <String>{},
    this.avatarAsset,
    this.onTap,
  });

  final String name;
  final double rating;
  final List<String> equipment;
  final List<String> categories;
  final List<ExecutorServiceOffer>? matchingServices;
  final Set<String> highlightEquipment;
  final Set<String> highlightCategories;
  final String? avatarAsset;
  final VoidCallback? onTap;

  static String _fmtThousands(int value) {
    final String s = value.toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final int rest = s.length - i;
      if (i > 0 && rest % 3 == 0) out.write(' ');
      out.write(s[i]);
    }
    return out.toString();
  }

  /// Словоформа «час» после предлога «от» (родительный падеж).
  /// «От 1 часа», «от 2/3/4/5 часов» — после «от» всегда родительный.
  static String _hoursWord(int n) {
    final int mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'часов';
    if (n % 10 == 1) return 'часа';
    return 'часов';
  }

  List<TextSpan> _buildSpans(List<String> items, Set<String> highlight) {
    final List<TextSpan> spans = <TextSpan>[];
    for (int i = 0; i < items.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '   '));
      spans.add(TextSpan(
        text: items[i],
        style: highlight.contains(items[i])
            ? const TextStyle(color: AppColors.primary)
            : null,
      ));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                ClipOval(
                  child: Image.asset(
                    avatarAsset ?? 'assets/images/catalog/avatar_placeholder.webp',
                    width: 48.r,
                    height: 48.r,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: <Widget>[
                          Image.asset(
                            'assets/images/catalog/star.webp',
                            width: 16.r,
                            height: 16.r,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            rating.toStringAsFixed(1).replaceAll('.', ','),
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            if (matchingServices != null && matchingServices!.isNotEmpty)
              _buildServicesBlock()
            else
              _buildDefaultBlocks(),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultBlocks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Спецтехника',
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 4.h),
        Text.rich(
          TextSpan(children: _buildSpans(equipment, highlightEquipment)),
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
            height: 1.78,
          ),
        ),
        SizedBox(height: 10.h),
        Text(
          'Категории услуг',
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 4.h),
        Text.rich(
          TextSpan(children: _buildSpans(categories, highlightCategories)),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToLastDescent: false,
          ),
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
            height: 1.78,
          ),
        ),
      ],
    );
  }

  Widget _buildServicesBlock() {
    final List<ExecutorServiceOffer> list = matchingServices!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < list.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: 6.h),
          Text.rich(
            TextSpan(
              children: <TextSpan>[
                TextSpan(text: '${list[i].equipment} — '),
                TextSpan(
                  text: '${_fmtThousands(list[i].pricePerHour)} ₽/час',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text:
                      ', от ${list[i].minHours} ${_hoursWord(list[i].minHours)}',
                ),
              ],
            ),
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
