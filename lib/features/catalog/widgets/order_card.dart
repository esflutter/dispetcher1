import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/catalog/models.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/avatar_circle.dart';

/// Карточка исполнителя в ленте каталога. Слева круглый аватар, справа —
/// имя со звездой и рейтингом. Под шапкой — либо обобщённые блоки
/// «Спецтехника / Категории услуг», либо, если задан непустой
/// [matchingServices], построчные предложения по выбранной фильтром
/// технике (вид «Экскаватор — 3 500 ₽/час, от 4 часов»).
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.name,
    required this.rating,
    required this.equipment,
    required this.categories,
    this.matchingServices = const <MatchingService>[],
    this.highlightEquipment = const <String>{},
    this.highlightCategories = const <String>{},
    this.avatarUrl,
    this.onTap,
  });

  final String name;
  final double rating;
  final List<String> equipment;
  final List<String> categories;
  final List<MatchingService> matchingServices;
  final Set<String> highlightEquipment;
  final Set<String> highlightCategories;
  final String? avatarUrl;
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
                AvatarCircle(size: 48.r, avatarUrl: avatarUrl),
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
                            // У исполнителя без отзывов рейтинг 0,0
                            // выглядит как «плохой». В остальных местах
                            // в обоих приложениях такой рейтинг
                            // показывается как «—»; приводим к тому же.
                            rating > 0
                                ? rating
                                    .toStringAsFixed(1)
                                    .replaceAll('.', ',')
                                : '—',
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
            if (matchingServices.isNotEmpty)
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < matchingServices.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: 6.h),
          _ServiceLine(service: matchingServices[i]),
        ],
      ],
    );
  }
}

class _ServiceLine extends StatelessWidget {
  const _ServiceLine({required this.service});
  final MatchingService service;

  @override
  Widget build(BuildContext context) {
    final List<TextSpan> tail = <TextSpan>[];
    final double? hour = service.pricePerHour;
    final double? day = service.pricePerDay;
    // Если у услуги указана только дневная ставка (без часовой) —
    // показываем её, иначе строка превращается в «Экскаватор — » без
    // цены и выглядит сломанной.
    final TextStyle priceStyle = TextStyle(
      color: AppColors.primary,
      fontSize: 18.sp,
      fontWeight: FontWeight.w600,
    );
    if (hour != null) {
      tail.add(TextSpan(
        text: '${OrderCard._fmtThousands(hour.round())} ₽/час',
        style: priceStyle,
      ));
    } else if (day != null) {
      tail.add(TextSpan(
        text: '${OrderCard._fmtThousands(day.round())} ₽/день',
        style: priceStyle,
      ));
    }
    final int? mh = service.minHours;
    if (mh != null && mh > 0 && hour != null) {
      tail.add(TextSpan(text: ', от $mh ${OrderCard._hoursWord(mh)}'));
    }
    if (tail.isEmpty) {
      tail.add(const TextSpan(text: 'цена по запросу'));
    }
    return Text.rich(
      TextSpan(
        children: <TextSpan>[
          TextSpan(text: '${service.machineryTitle} — '),
          ...tail,
        ],
      ),
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 16.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
    );
  }
}
