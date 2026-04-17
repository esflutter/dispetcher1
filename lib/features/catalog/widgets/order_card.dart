import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';

/// Карточка исполнителя в ленте каталога. Слева круглый аватар, справа —
/// имя со звездой и рейтингом, строка «Опыт работы» + статус (Юр. лицо
/// и т.п.), далее секции «Спецтехника» и «Категории услуг».
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.name,
    required this.rating,
    required this.experience,
    required this.legalStatus,
    required this.equipment,
    required this.categories,
    this.highlightEquipment = const <String>{},
    this.highlightCategories = const <String>{},
    this.avatarAsset,
    this.onTap,
  });

  final String name;
  final double rating;
  final String experience;
  final String legalStatus;
  final List<String> equipment;
  final List<String> categories;
  final Set<String> highlightEquipment;
  final Set<String> highlightCategories;
  final String? avatarAsset;
  final VoidCallback? onTap;

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
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                height: 1.25,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Image.asset(
                            'assets/images/catalog/star.webp',
                            width: 18.r,
                            height: 18.r,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            rating.toStringAsFixed(1).replaceAll('.', ','),
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Опыт работы  $experience',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textPrimary,
                                height: 1.3,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            legalStatus,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textTertiary,
                              height: 1.3,
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
            Text(
              'Спецтехника',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Text.rich(
              TextSpan(
                children: _buildSpans(equipment, highlightEquipment),
              ),
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
              TextSpan(
                children: _buildSpans(categories, highlightCategories),
              ),
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
        ),
      ),
    );
  }
}
