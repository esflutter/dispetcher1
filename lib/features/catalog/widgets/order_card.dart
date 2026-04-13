import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';

/// Карточка исполнителя в ленте каталога. По Figma — без рамки, разделение
/// нижней линией, сверху строка тэгов техники + доп. инфо,
/// ниже жирный заголовок и две строки «Техника:» / «Местоположение:».
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.title,
    required this.address,
    required this.rentDate,
    required this.publishedAgo,
    required this.equipment,
    this.price,
    this.onTap,
  });

  final String title;
  final String address;
  final String rentDate;
  final String publishedAgo;
  final List<String> equipment;
  final String? price;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextStyle tagStyle = TextStyle(
      fontFamily: 'Roboto',
      fontSize: 12.sp,
      fontWeight: FontWeight.w400,
      color: AppColors.textTertiary,
      height: 1.78,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    equipment.join('   '),
                    style: tagStyle,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(publishedAgo, style: tagStyle),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              style: AppTextStyles.titleS.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8.h),
            _LabelLine(label: 'Техника:', value: rentDate),
            SizedBox(height: 5.h),
            _LabelLine(label: 'Местоположение:', value: address),
            if (price != null && price!.isNotEmpty) ...<Widget>[
              SizedBox(height: 10.h),
              Text(
                price!,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LabelLine extends StatelessWidget {
  const _LabelLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12.sp,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
        children: <TextSpan>[
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
