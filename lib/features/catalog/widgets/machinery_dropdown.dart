import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';

/// Выпадающий список выбора вида спецтехники (одиночный выбор). По тапу
/// открывает нижнюю шторку со списком; выбранный отмечается галочкой.
///
/// Используется и в фильтре каталога, и в форме создания заказа — там,
/// где раньше стояла сетка чипов с множественным выбором. Один и тот же
/// внешний вид, что у выбора техники в форме услуги исполнителя.
///
/// [clearable] добавляет в начало списка пункт [clearLabel], который
/// сбрасывает выбор (в фильтре — «искать любую технику»). В форме заказа
/// техника обязательна, поэтому сброса нет.
class MachineryDropdown extends StatelessWidget {
  const MachineryDropdown({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.placeholder = 'Выберите вид техники',
    this.clearable = false,
    this.clearLabel = 'Любая техника',
  });

  final List<String> items;
  final String? selected;

  /// `null` — выбор сброшен (только при [clearable]).
  final ValueChanged<String?> onChanged;
  final String placeholder;
  final bool clearable;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
    final bool empty = selected == null;
    return GestureDetector(
      onTap: items.isEmpty ? null : () => _openPicker(context),
      child: Container(
        height: 52.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                empty ? placeholder : selected!,
                style: AppTextStyles.body.copyWith(
                  color:
                      empty ? AppColors.textTertiary : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textTertiary, size: 24.r),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    // Сентинел для пункта «сбросить»: пустая строка отличима от любого
    // реального вида техники (у тех названия непустые).
    const String clearSentinel = '';
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(height: 12.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  if (clearable)
                    ListTile(
                      title: Text(clearLabel, style: AppTextStyles.body),
                      trailing: selected == null
                          ? Icon(Icons.check_rounded,
                              color: AppColors.primary, size: 22.r)
                          : null,
                      onTap: () => Navigator.of(ctx).pop(clearSentinel),
                    ),
                  for (final String m in items)
                    ListTile(
                      title: Text(m, style: AppTextStyles.body),
                      trailing: m == selected
                          ? Icon(Icons.check_rounded,
                              color: AppColors.primary, size: 22.r)
                          : null,
                      onTap: () => Navigator.of(ctx).pop(m),
                    ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
    if (picked == null) return; // шторку закрыли свайпом — выбор не менялся
    onChanged(picked == clearSentinel ? null : picked);
  }
}
