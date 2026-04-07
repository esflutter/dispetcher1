import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/features/catalog/catalog_filter_screen.dart';
import 'package:dispatcher_1/features/catalog/order_detail_screen.dart';
import 'package:dispatcher_1/features/catalog/orders_map_screen.dart';
import 'package:dispatcher_1/features/catalog/widgets/order_card.dart';

/// Лента заказов категории — табы «Список / Карта».
class OrderFeedScreen extends StatefulWidget {
  const OrderFeedScreen({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
  });

  final String categoryId;
  final String categoryTitle;

  @override
  State<OrderFeedScreen> createState() => _OrderFeedScreenState();
}

class _OrderFeedScreenState extends State<OrderFeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  static const List<_MockOrder> _orders = <_MockOrder>[
    _MockOrder(
      id: '1',
      title: 'Копка котлована под фундамент',
      price: '15 000 ₽',
      address: 'Москва, ул. Ленина, 10',
      dateTime: 'Сегодня, 14:00',
      equipment: 'Экскаватор-погрузчик',
    ),
    _MockOrder(
      id: '2',
      title: 'Планировка участка',
      price: '8 500 ₽',
      address: 'МО, г. Химки, ул. Заводская',
      dateTime: 'Завтра, 09:00',
      equipment: 'Бульдозер',
    ),
    _MockOrder(
      id: '3',
      title: 'Вывоз грунта',
      price: '22 000 ₽',
      address: 'Москва, Каширское шоссе, 88',
      dateTime: '12 апреля, 08:00',
      equipment: 'Самосвал, экскаватор',
    ),
  ];

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(widget.categoryTitle, style: AppTextStyles.titleL),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CatalogFilterScreen(),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.h),
          child: TabBar(
            controller: _tab,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textTertiary,
            labelStyle: AppTextStyles.tabActive,
            unselectedLabelStyle: AppTextStyles.tabInactive,
            tabs: const <Widget>[
              Tab(text: 'Списком'),
              Tab(text: 'На карте'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: <Widget>[
          ListView.separated(
            padding: EdgeInsets.all(AppSpacing.screenH),
            itemCount: _orders.length,
            separatorBuilder: (_, _) => SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int i) {
              final _MockOrder o = _orders[i];
              return OrderCard(
                title: o.title,
                price: o.price,
                address: o.address,
                dateTime: o.dateTime,
                equipment: o.equipment,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OrderDetailScreen(orderId: o.id),
                  ),
                ),
              );
            },
          ),
          const OrdersMapScreen(),
        ],
      ),
    );
  }
}

class _MockOrder {
  const _MockOrder({
    required this.id,
    required this.title,
    required this.price,
    required this.address,
    required this.dateTime,
    required this.equipment,
  });
  final String id;
  final String title;
  final String price;
  final String address;
  final String dateTime;
  final String equipment;
}
