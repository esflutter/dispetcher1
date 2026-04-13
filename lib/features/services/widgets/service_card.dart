import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';

/// Карточка услуги в списке «Мои услуги».
class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.title,
    required this.machinery,
    required this.description,
    required this.pricePerHour,
    required this.pricePerDay,
    this.onTap,
  });

  final String title;
  final List<String> machinery;
  final String description;
  final String pricePerHour;
  final String pricePerDay;
  final VoidCallback? onTap;

  bool get _hasHour => pricePerHour.isNotEmpty && pricePerHour != '0';
  bool get _hasDay => pricePerDay.isNotEmpty && pricePerDay != '0';

  @override
  Widget build(BuildContext context) {
    final priceStyle = TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.primary,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              machinery.join('   '),
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textTertiary,
                height: 1.78,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 6.h),
            Text(
              description,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 9.w,
              runSpacing: 4.h,
              children: [
                if (_hasHour)
                  Text('₽ / час   $pricePerHour ₽', style: priceStyle),
                if (_hasDay)
                  Text('₽ / день   $pricePerDay ₽', style: priceStyle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
