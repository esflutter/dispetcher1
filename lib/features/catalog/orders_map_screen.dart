import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/features/catalog/catalog_filter_screen.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';

/// Плейсхолдер карты со списком заказов. Используется как контент таба
/// «На карте» внутри `OrderFeedScreen`. Реальная карта подключится позже.
class OrdersMapScreen extends StatefulWidget {
  const OrdersMapScreen({super.key, this.showSearchBar = false});

  /// Если true — рисует поверх собственный поиск+фильтр (когда экран
  /// открыт отдельным маршрутом, а не как таб).
  final bool showSearchBar;

  @override
  State<OrdersMapScreen> createState() => _OrdersMapScreenState();
}

class _OrdersMapScreenState extends State<OrdersMapScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.asset(
        'assets/images/map_placeholder.webp',
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),
    );
  }
}

/// Полноэкранный «Заказы на карте» — отдельный маршрут с собственным
/// тёмным AppBar и строкой поиска.
class OrdersMapFullScreen extends StatefulWidget {
  const OrdersMapFullScreen({super.key});

  @override
  State<OrdersMapFullScreen> createState() => _OrdersMapFullScreenState();
}

class _OrdersMapFullScreenState extends State<OrdersMapFullScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double searchTop = MediaQuery.of(context).padding.top + 48.h;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: OrdersMapScreen()),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8.w,
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 20.r),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            top: searchTop,
            left: 0,
            right: 0,
            child: CatalogSearchBar(
              controller: _searchCtrl,
              hintText: 'Поиск по адресу',
              onFilterTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CatalogFilterScreen(),
                ),
              ),
              onChanged: (String v) => setState(() => _query = v),
            ),
          ),
          if (_query.trim().isNotEmpty)
            Positioned(
              top: searchTop + 44.h + 3.h,
              left: 16.w,
              right: 16.w,
              child: _AddressSuggestions(
                onSelect: (String address) {
                  _searchCtrl.text = address;
                  setState(() => _query = address);
                  FocusScope.of(context).unfocus();
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Выпадающий список моковых адресов для карты (полноэкранный режим).
class _AddressSuggestions extends StatelessWidget {
  const _AddressSuggestions({required this.onSelect});

  final ValueChanged<String> onSelect;

  static const List<String> _all = <String>[
    'Московская область, Москва, ул. Ленина, д. 10',
    'Московская область, Москва, ул. Пушкина, д. 25',
    'Московская область, Москва, пр. Мира, д. 3',
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12.r),
      color: AppColors.surface,
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemCount: _all.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          thickness: 0.5,
          indent: 16.w,
          endIndent: 16.w,
          color: AppColors.divider,
        ),
        itemBuilder: (BuildContext context, int i) {
          return InkWell(
            onTap: () => onSelect(_all[i]),
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: <Widget>[
                  Icon(Icons.location_on_outlined,
                      size: 20.r, color: AppColors.textTertiary),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      _all[i],
                      style: AppTextStyles.bodyMRegular.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
