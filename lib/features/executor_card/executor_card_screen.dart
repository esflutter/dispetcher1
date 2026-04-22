import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/utils/plural.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';
import 'package:dispatcher_1/core/widgets/cropped_avatar.dart';
import 'package:dispatcher_1/features/auth/photo_crop_screen.dart';
import 'package:dispatcher_1/features/profile/account_block.dart';

/// Экран «Моя карточка заказчика». Два состояния:
///   empty   — карточка ещё не создана (показываем плейсхолдер + «Создать»)
///   filled  — карточка создана (показываем данные + «Редактировать»)
/// При активном блоке профиля ещё показываем соответствующий диалог
/// при попытке создать карточку.
class ExecutorCardScreen extends StatefulWidget {
  const ExecutorCardScreen({super.key});

  static bool cardCreated = false;

  @override
  State<ExecutorCardScreen> createState() => _ExecutorCardScreenState();
}

class _ExecutorCardScreenState extends State<ExecutorCardScreen> {
  @override
  void initState() {
    super.initState();
    AccountBlock.notifier.addListener(_refresh);
  }

  @override
  void dispose() {
    AccountBlock.notifier.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _onCreateTap() async {
    if (AccountBlock.isBlocked) {
      await showBlockedProfileDialog(context);
      return;
    }
    await context.push('/executor-card/edit');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool filled = ExecutorCardScreen.cardCreated;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const DarkSubAppBar(title: 'Моя карточка заказчика'),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 88.h),
        child: AiAssistantFab(onTap: () => context.push('/assistant/chat')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: filled ? _FilledCard() : const _EmptyContent(),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    offset: const Offset(0, -1),
                    blurRadius: 8,
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
              child: filled
                  ? PrimaryButton(
                      label: 'Редактировать',
                      onPressed: () async {
                        await context.push('/executor-card/edit');
                        if (mounted) setState(() {});
                      },
                    )
                  : PrimaryButton(
                      label: 'Создать',
                      onPressed: _onCreateTap,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(height: 22.h),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Создайте карточку\nзаказчика',
                    style: AppTextStyles.titleL,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Text(
                      'Создайте карточку, чтобы исполнители могли видеть информацию о вас и ваших заказах',
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

/// Данные карточки заказчика (до появления бэкенда). Имя и телефон
/// синхронизируются с профилем ([CropResult]) — это геттеры-обёртки.
/// Телефон менять нельзя (он задаётся только при регистрации).
class ExecutorCardData {
  /// Имя — всегда совпадает с именем профиля.
  static String get name => CropResult.userName;
  static set name(String value) => CropResult.userName = value;

  /// Телефон — всегда совпадает с номером профиля (поле регистрации).
  static String get phone => CropResult.userPhone;

  static String? location;
  static String? radius;
  static List<String> machinery = <String>[];
  static List<String> categories = <String>[];
  static String? experience;
  static String? status;
  static String? about;

  /// Сбросить все поля карточки — для logout.
  static void clear() {
    location = null;
    radius = null;
    machinery = <String>[];
    categories = <String>[];
    experience = null;
    status = null;
    about = null;
  }
}

class _FilledCard extends StatelessWidget {
  const _FilledCard();

  /// Для владельца карточки незаполненные поля «О себе» и «Статус»
  /// показываем прочерком — чтобы было видно, что блок есть и его
  /// можно заполнить. В публичном просмотре (экран со стороны
  /// исполнителя) такие пустые блоки скрываются.
  String _val(String? v) => (v != null && v.trim().isNotEmpty) ? v : '—';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _HeaderRow(),
          SizedBox(height: 20.h),
          _SectionTitle('Номер телефона'),
          SizedBox(height: 4.h),
          Text(ExecutorCardData.phone, style: AppTextStyles.body),
          SizedBox(height: 16.h),
          _SectionTitle('Электронная почта'),
          SizedBox(height: 4.h),
          Text(_val(CropResult.userEmail), style: AppTextStyles.body),
          SizedBox(height: 16.h),
          _SectionTitle('О себе'),
          SizedBox(height: 4.h),
          Text(_val(ExecutorCardData.about), style: AppTextStyles.body),
          SizedBox(height: 16.h),
          _SectionTitle('Статус'),
          SizedBox(height: 4.h),
          Text(_val(ExecutorCardData.status), style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final double rating = ReviewsData.aggregate;
    final int reviewsCount = ReviewsData.count;
    final String ratingText = reviewsCount == 0
        ? '0,0'
        : rating.toStringAsFixed(1).replaceAll('.', ',');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        CroppedAvatar(size: 72.r),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                ExecutorCardData.name.trim().isEmpty
                    ? CropResult.namePlaceholder
                    : ExecutorCardData.name,
                style: AppTextStyles.titleS,
              ),
              SizedBox(height: 4.h),
              Row(
                children: <Widget>[
                  Image.asset('assets/images/catalog/star.webp',
                      width: 20.r, height: 20.r),
                  SizedBox(width: 4.w),
                  Text(ratingText, style: AppTextStyles.body),
                  SizedBox(width: 16.w),
                  GestureDetector(
                    onTap: () => context.push('/profile/reviews'),
                    child: Text(
                      '$reviewsCount ${reviewsWord(reviewsCount)}',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                        decoration: TextDecoration.underline,
                      ),
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
      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

/// Диалог «Нет карточки заказчика» — показывается при попытке предложить
/// заказ исполнителю, пока у пользователя не создана своя карточка.
/// Кнопка «Создать карточку» ведёт на `/executor-card/edit`; если
/// карточка сохранена, флаг `ExecutorCardScreen.cardCreated` становится
/// `true`, и следующая попытка предложить заказ проходит без диалога.
Future<void> showCreateCustomerCardDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (BuildContext ctx) => Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 22.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Icon(Icons.close_rounded,
                    size: 22.r, color: AppColors.textTertiary),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Создайте карточку\nзаказчика',
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.titleL.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8.h),
            Text(
              'Чтобы предлагать заказы исполнителям, '
              'сначала заполните свою карточку — имя, '
              'контакты и краткое описание.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMRegular
                  .copyWith(color: AppColors.textSecondary),
            ),
            SizedBox(height: 18.h),
            PrimaryButton(
              label: 'Создать карточку',
              onPressed: () {
                Navigator.of(ctx).pop();
                ctx.push('/executor-card/edit');
              },
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    ),
  );
}

/// Диалог «Ваш профиль заблокирован на 30 дней» — показывается при попытке
/// создавать/редактировать/предлагать заказ при активной блокировке.
Future<void> showBlockedProfileDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (BuildContext ctx) => Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 22.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Icon(Icons.close_rounded,
                    size: 22.r, color: AppColors.textTertiary),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Ваш профиль заблокирован\nна 30 дней',
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.titleL.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8.h),
            Text(
              'Во избежание дальнейших блокировок избегайте отзывов с низкой оценкой',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMRegular
                  .copyWith(color: AppColors.textSecondary),
            ),
            SizedBox(height: 18.h),
            PrimaryButton(
              label: 'Ок',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    ),
  );
}
