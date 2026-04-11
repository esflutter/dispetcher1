import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Полосочка-индикатор для Bottom Sheet.
/// Цвет #929292, скругление 12.
class BottomSheetHandle extends StatelessWidget {
  const BottomSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36.w,
        height: 4.h,
        decoration: BoxDecoration(
          color: const Color(0xFF929292),
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }
}
