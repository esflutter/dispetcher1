import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/features/catalog/catalog_categories_screen.dart';
import 'package:dispatcher_1/features/orders/my_orders_screen.dart';
import 'package:dispatcher_1/features/profile/profile_screen.dart';
import 'package:dispatcher_1/features/support/support_home_screen.dart';

/// Главный shell приложения. Нижняя навигация на 3 таба
/// (Каталог / Заказы / Профиль) + плавающая оранжевая кнопка
/// поддержки в правом нижнем углу — как в Figma.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem('Каталог', 'assets/icons/nav/catalog.svg'),
    _NavItem('Заказы', 'assets/icons/nav/orders.svg'),
    _NavItem('Профиль', 'assets/icons/nav/profile.svg'),
  ];

  static const List<Widget> _screens = <Widget>[
    CatalogCategoriesScreen(),
    MyOrdersScreen(),
    ProfileScreen(),
  ];

  void _openSupport() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SupportHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: _SupportFab(onTap: _openSupport),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _BottomNavBar(
        items: _items,
        currentIndex: _index,
        onTap: (int i) => setState(() => _index = i),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.iconAsset);
  final String label;
  final String iconAsset;
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 64.h + bottomInset,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      padding: EdgeInsets.only(top: 6.h, bottom: bottomInset),
      child: Row(
        children: List<Widget>.generate(items.length, (int i) {
          final _NavItem it = items[i];
          final bool active = i == currentIndex;
          final Color color =
              active ? AppColors.primary : AppColors.textTertiary;
          return Expanded(
            child: InkWell(
              onTap: () => onTap(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SvgPicture.asset(
                    it.iconAsset,
                    width: 24.r,
                    height: 24.r,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    it.label,
                    style: AppTextStyles.tabActive.copyWith(color: color),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SupportFab extends StatelessWidget {
  const _SupportFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56.r,
      height: 56.r,
      child: FloatingActionButton(
        onPressed: onTap,
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: const CircleBorder(),
        child: Padding(
          padding: EdgeInsets.all(14.r),
          child: Image.asset(
            'assets/icons/nav/support_fab.webp',
            color: AppColors.surface,
            errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                Icon(Icons.support_agent,
                    color: AppColors.surface, size: 28.r),
          ),
        ),
      ),
    );
  }
}
