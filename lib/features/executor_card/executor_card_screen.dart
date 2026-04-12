import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';
import 'package:dispatcher_1/features/profile/widgets/verification_badge.dart';

import 'widgets/executor_card_alerts.dart';

/// Состояние верификации карточки исполнителя.
enum ExecutorCardStatus { empty, inReview, rejected, verified }

/// Экран «Моя карточка исполнителя» с разными состояниями верификации.
/// Кнопки и баннер меняются в зависимости от [status].
class ExecutorCardScreen extends StatefulWidget {
  const ExecutorCardScreen({super.key, this.status = ExecutorCardStatus.empty});

  final ExecutorCardStatus status;

  @override
  State<ExecutorCardScreen> createState() => _ExecutorCardScreenState();
}

class _ExecutorCardScreenState extends State<ExecutorCardScreen> {
  bool _alertShown = false;

  @override
  void initState() {
    super.initState();
    if (widget.status == ExecutorCardStatus.inReview ||
        widget.status == ExecutorCardStatus.rejected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_alertShown) {
          _alertShown = true;
          showExecutorCardStatusDialog(context, widget.status);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool filled = widget.status == ExecutorCardStatus.verified;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const DarkSubAppBar(title: 'Моя карточка исполнителя'),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 88.h),
        child: AiAssistantFab(onTap: () => context.push('/assistant/chat')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: filled ? const _FilledCard() : _EmptyContent(status: widget.status),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.md),
          child: filled
              ? PrimaryButton(
                  label: 'Редактировать',
                  onPressed: () => context.push('/executor-card/edit'),
                )
              : PrimaryButton(
                  label: 'Создать',
                  onPressed: () async {
                    final result = await showCreateExecutorCardAlert(context);
                    if (result == true && context.mounted) {
                      context.push('/assistant/chat',
                          extra: <String, Object?>{
                            'initial': 'verify_documents'
                          });
                    }
                  },
                ),
        ),
      ),
    );
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent({required this.status});
  final ExecutorCardStatus status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: AppSpacing.md),
          if (status == ExecutorCardStatus.verified)
            const FullWidthVerificationPill(
                status: VerificationStatus.verified),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/icons/profile/executor_card.webp',
                      width: 80.r, height: 80.r),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'Создайте карточку\nисполнителя',
                    style: AppTextStyles.h3
                        .copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Text(
                      'Заказчики смогут посмотреть информацию '
                      'о вас, услугах и связаться с вами.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilledCard extends StatelessWidget {
  const _FilledCard();

  static const _machinery = <String>[
    'Экскаватор-погрузчик',
    'Погрузчик',
    'Миниэкскаватор',
    'Минипогрузчик',
    'Буроям',
    'Самогруз',
    'Автокран',
    'Самосвалы (до 5тн, 15, 25)',
    'Бетононасос',
    'Эвакуатор',
    'Автовышка',
    'Манипулятор',
    'Минитрактор',
    'Экскаватор',
    'Инертные материалы',
  ];

  static const _categories = <String>[
    'Земляные работы',
    'Погрузочно-разгрузочные работы',
    'Перевозка материалов',
    'Строительные работы',
    'Дорожные работы',
    'Буровые работы',
    'Высотные работы',
    'Демонтажные работы',
    'Благоустройство территории',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderRow(),
          SizedBox(height: AppSpacing.lg),
          _SectionTitle('Номер телефона'),
          SizedBox(height: 4.h),
          Text('+7 999 123-45-67', style: AppTextStyles.body),
          SizedBox(height: AppSpacing.md),
          _SectionTitle('Местоположение'),
          SizedBox(height: 4.h),
          Text('Московская область, Москва', style: AppTextStyles.body),
          SizedBox(height: 2.h),
          Text('Заказы в радиусе 10 км',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary)),
          SizedBox(height: AppSpacing.md),
          _SectionTitle('Спецтехника'),
          SizedBox(height: AppSpacing.xs),
          _ChipWrap(items: _machinery),
          SizedBox(height: AppSpacing.md),
          _SectionTitle('Категории услуг'),
          SizedBox(height: AppSpacing.xs),
          _ChipWrap(items: _categories),
          SizedBox(height: AppSpacing.md),
          _SectionTitle('Опыт работы'),
          SizedBox(height: 4.h),
          Text('5 лет', style: AppTextStyles.body),
          SizedBox(height: AppSpacing.md),
          _SectionTitle('Статус'),
          SizedBox(height: 4.h),
          Text('Физ. лицо', style: AppTextStyles.body),
          SizedBox(height: AppSpacing.md),
          _SectionTitle('О себе'),
          SizedBox(height: 4.h),
          Text(
            'Опыт работы более 5 лет. Своя техника в хорошем состоянии, '
            'работаю без простоев. Готов выезжать в ближайшие районы.',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 64.r,
          height: 64.r,
          decoration: const BoxDecoration(
            color: AppColors.surfaceVariant,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(Icons.person, size: 36.r, color: AppColors.textTertiary),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Александр Иванов',
                  style:
                      AppTextStyles.h3.copyWith(fontWeight: FontWeight.w600)),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Icon(Icons.star_rounded,
                      color: AppColors.ratingStar, size: 18.r),
                  SizedBox(width: 4.w),
                  Text('4,5', style: AppTextStyles.bodyMedium),
                  SizedBox(width: 8.w),
                  Text(
                    '15 отзывов',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.bodyMedium
          .copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: items
          .map((label) => Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  label,
                  style: AppTextStyles.chip.copyWith(
                    fontSize: 13.sp,
                    color: Colors.white,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

/// Центрированный alert-dialog о статусе верификации карточки исполнителя.
Future<void> showExecutorCardStatusDialog(
    BuildContext context, ExecutorCardStatus status) {
  final String title;
  final String text;
  if (status == ExecutorCardStatus.inReview) {
    title = 'Ваши документы ещё\nна проверке';
    text = 'Вы получите уведомление, когда\nпроверка завершится';
  } else {
    title = 'Документы не прошли\nпроверку';
    text = 'Проверьте данные и отправьте\nдокументы ещё раз';
  }
  return showCupertinoDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Icon(Icons.close_rounded,
                    size: 22.r, color: AppColors.textSecondary),
              ),
            ),
            Text(
              title,
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              text,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Ок',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
