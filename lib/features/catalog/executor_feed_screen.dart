import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/catalog/catalog_service.dart';
import 'package:dispatcher_1/core/catalog/models.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/utils/plural.dart';
import 'package:dispatcher_1/features/catalog/catalog_filter_screen.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';

/// Лента исполнителей для заказчика. Источник — `executor_cards`
/// JOIN `profiles` + aggregate по `services` (техника/категории/мин.цена).
class ExecutorFeedScreen extends StatefulWidget {
  const ExecutorFeedScreen({
    super.key,
    required this.machineryTitle,
  });

  final String machineryTitle;

  @override
  State<ExecutorFeedScreen> createState() => _ExecutorFeedScreenState();
}

class _ExecutorFeedScreenState extends State<ExecutorFeedScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _debounce;
  late Future<List<ExecutorCardListItem>> _future;

  @override
  void initState() {
    super.initState();
    AppliedFilter.revision.addListener(_onFilterChanged);
    _future = _fetch();
  }

  @override
  void dispose() {
    AppliedFilter.revision.removeListener(_onFilterChanged);
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<ExecutorCardListItem>> _fetch() {
    return CatalogService.instance.listPublishedExecutors(
      machineryTitles: AppliedFilter.equipment,
      categoryTitles: AppliedFilter.categories,
      search: _query.trim().isEmpty ? null : _query,
    );
  }

  void _onFilterChanged() {
    if (mounted) setState(() => _future = _fetch());
  }

  void _onSearchChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _future = _fetch());
    });
  }

  bool get _hasActiveFilter =>
      AppliedFilter.equipment.isNotEmpty ||
      AppliedFilter.categories.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navBarDark,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 48.h,
        title: Text(widget.machineryTitle,
            style: AppTextStyles.titleS.copyWith(color: Colors.white)),
      ),
      body: Column(
        children: <Widget>[
          Container(
            color: AppColors.navBarDark,
            child: CatalogSearchBar(
              controller: _searchCtrl,
              hintText: 'Поиск по имени',
              onChanged: _onSearchChanged,
              onFilterTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CatalogFilterScreen(),
                ),
              ),
              showFilterBadge: _hasActiveFilter,
            ),
          ),
          SizedBox(height: 12.h),
          Expanded(
            child: FutureBuilder<List<ExecutorCardListItem>>(
              future: _future,
              builder: (BuildContext context,
                  AsyncSnapshot<List<ExecutorCardListItem>> snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _future = _fetch()),
                      child: const Text('Не удалось. Повторить'),
                    ),
                  );
                }
                final List<ExecutorCardListItem> list =
                    snap.data ?? const <ExecutorCardListItem>[];
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.w),
                      child: Text(
                        'Исполнители не найдены',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMRegular
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => SizedBox(height: 12.h),
                  itemBuilder: (BuildContext c, int i) =>
                      _ExecutorTile(item: list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutorTile extends StatelessWidget {
  const _ExecutorTile({required this.item});
  final ExecutorCardListItem item;

  String _fmt(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  String _fmtPrice(double v) {
    final int i = v.round();
    final String s = i.toString();
    final StringBuffer b = StringBuffer();
    for (int k = 0; k < s.length; k++) {
      if (k > 0 && (s.length - k) % 3 == 0) b.write(' ');
      b.write(s[k]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/catalog/executor/${item.userId}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(14.r),
        ),
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 24.r,
                  backgroundColor: AppColors.primaryTint,
                  backgroundImage: (item.avatarUrl != null &&
                          item.avatarUrl!.trim().isNotEmpty)
                      ? NetworkImage(item.avatarUrl!) as ImageProvider
                      : const AssetImage(
                          'assets/images/catalog/avatar_placeholder.webp'),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(item.name, style: AppTextStyles.titleS),
                      SizedBox(height: 4.h),
                      Row(
                        children: <Widget>[
                          Icon(Icons.star_rounded,
                              size: 18.r, color: AppColors.ratingStar),
                          SizedBox(width: 4.w),
                          Text(_fmt(item.ratingAsExecutor),
                              style: AppTextStyles.body),
                          SizedBox(width: 12.w),
                          Text(
                            '${item.reviewCountAsExecutor} ${reviewsWord(item.reviewCountAsExecutor)}',
                            style: AppTextStyles.body.copyWith(
                                color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item.machineryTitles.isNotEmpty) ...<Widget>[
              SizedBox(height: 12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: item.machineryTitles
                    .map((String t) => _Chip(label: t))
                    .toList(),
              ),
            ],
            if (item.minPricePerHour != null ||
                item.minPricePerDay != null) ...<Widget>[
              SizedBox(height: 12.h),
              Row(
                children: <Widget>[
                  if (item.minPricePerHour != null) ...<Widget>[
                    Text('от ${_fmtPrice(item.minPricePerHour!)} ₽/час',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                    SizedBox(width: 12.w),
                  ],
                  if (item.minPricePerDay != null)
                    Text('от ${_fmtPrice(item.minPricePerDay!)} ₽/день',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
