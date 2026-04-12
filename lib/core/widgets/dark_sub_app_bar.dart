import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Канонический тёмный AppBar вложенных экранов (те, что пушатся поверх
/// MainShell). Совпадает с паттерном из `orders/order_detail_screen.dart`
/// и `catalog/order_detail_screen.dart`: высота 48, белая стрелка
/// `back_arrow.webp`, центрованный белый заголовок `titleS`.
class DarkSubAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DarkSubAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => Size.fromHeight(48.h);

  @override
  Widget build(BuildContext context) {
    return AppBar(
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
              errorBuilder: (_, _, _) => Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20.r,
                color: Colors.white,
              ),
            ),
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      title: Padding(
        padding: EdgeInsets.only(top: 2.h),
        child: Text(
          title,
          style: AppTextStyles.titleS.copyWith(color: Colors.white),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
      actions: actions,
    );
  }
}
