import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';

/// Выпадающий список выбора вида спецтехники. Два режима:
///
///  • ОДИНОЧНЫЙ (по умолчанию) — задаются [selected] + [onChanged]. По тапу
///    открывает нижнюю шторку со списком; выбор сразу отмечается галочкой и
///    закрывает шторку. Используется в форме создания заказа (техника
///    обязательна, поэтому ровно один вид).
///
///  • МНОЖЕСТВЕННЫЙ — задаются [multiSelected] + [onMultiChanged]. В шторке
///    можно отметить несколько видов (галочки-тогглы, применяются сразу); в
///    поле выбранные показываются через запятую одной строкой, длинный список —
///    с многоточием. Используется в фильтре каталога (поиск можно вести сразу
///    по нескольким видам техники — как было с прежней сеткой чипов).
///
/// [clearable] добавляет в начало списка пункт [clearLabel] («Любая техника»),
/// который сбрасывает выбор. В форме заказа техника обязательна — сброса нет.
class MachineryDropdown extends StatelessWidget {
  const MachineryDropdown({
    super.key,
    required this.items,
    this.selected,
    this.onChanged,
    this.multiSelected,
    this.onMultiChanged,
    this.placeholder = 'Выберите вид техники',
    this.clearable = false,
    this.clearLabel = 'Любая техника',
  }) : assert(
          (onChanged != null) != (onMultiChanged != null),
          'MachineryDropdown: задайте РОВНО один режим — '
          'одиночный (onChanged) или множественный (onMultiChanged).',
        );

  final List<String> items;

  // Одиночный режим.
  final String? selected;

  /// `null` — выбор сброшен (только при [clearable]).
  final ValueChanged<String?>? onChanged;

  // Множественный режим.
  final Set<String>? multiSelected;
  final ValueChanged<Set<String>>? onMultiChanged;

  final String placeholder;
  final bool clearable;
  final String clearLabel;

  bool get _multi => onMultiChanged != null;

  /// Текст в поле: в множественном режиме — выбранные через запятую (или null,
  /// если ничего не выбрано); в одиночном — выбранный вид (или null).
  String? get _fieldText {
    if (_multi) {
      final Set<String> s = multiSelected ?? const <String>{};
      return s.isEmpty ? null : s.join(', ');
    }
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    final String? text = _fieldText;
    final bool empty = text == null;
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
                empty ? placeholder : text,
                style: AppTextStyles.body.copyWith(
                  color:
                      empty ? AppColors.textTertiary : AppColors.textPrimary,
                ),
                // Одной строкой: несколько выбранных видов идут через запятую,
                // длинный список укорачивается многоточием, а не переносится.
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
    if (_multi) {
      await _openMultiPicker(context);
    } else {
      await _openSinglePicker(context);
    }
  }

  // --- Множественный выбор: тогглы применяются сразу, «Готово» не нужно. ---
  Future<void> _openMultiPicker(BuildContext context) async {
    // Локальная копия для галочек в шторке; на каждый тапа применяем выбор
    // сразу (onMultiChanged), поэтому поле под шторкой обновляется вживую.
    final Set<String> draft = <String>{...(multiSelected ?? const <String>{})};
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheet) => SafeArea(
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
                        trailing: draft.isEmpty
                            ? Icon(Icons.check_rounded,
                                color: AppColors.primary, size: 22.r)
                            : null,
                        onTap: () {
                          setSheet(draft.clear);
                          onMultiChanged!(<String>{});
                        },
                      ),
                    for (final String m in items)
                      ListTile(
                        title: Text(m, style: AppTextStyles.body),
                        trailing: draft.contains(m)
                            ? Icon(Icons.check_rounded,
                                color: AppColors.primary, size: 22.r)
                            : null,
                        onTap: () {
                          setSheet(() {
                            if (!draft.remove(m)) draft.add(m);
                          });
                          onMultiChanged!(<String>{...draft});
                        },
                      ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  // --- Одиночный выбор: тап по виду сразу закрывает шторку. ---
  Future<void> _openSinglePicker(BuildContext context) async {
    // Результат шторки: либо «сбросить выбор» (clear: true), либо конкретный
    // вид техники (value). Отдельные поля вместо «пустая строка как маркер» —
    // чтобы выбор техники с любым названием нельзя было спутать со сбросом.
    final ({bool clear, String? value})? picked =
        await showModalBottomSheet<({bool clear, String? value})>(
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
                      onTap: () =>
                          Navigator.of(ctx).pop((clear: true, value: null)),
                    ),
                  for (final String m in items)
                    ListTile(
                      title: Text(m, style: AppTextStyles.body),
                      trailing: m == selected
                          ? Icon(Icons.check_rounded,
                              color: AppColors.primary, size: 22.r)
                          : null,
                      onTap: () =>
                          Navigator.of(ctx).pop((clear: false, value: m)),
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
    onChanged!(picked.clear ? null : picked.value);
  }
}
