import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/profile/profile_service.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/utils/plural.dart';
import 'package:dispatcher_1/core/widgets/avatar_circle.dart';
import 'package:dispatcher_1/core/widgets/cropped_avatar.dart';
import 'package:dispatcher_1/features/auth/photo_crop_screen.dart';
import 'account_block.dart';
import 'widgets/blocked_pill.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.fullName = '',
    this.photoUrl,
  });

  final String fullName;
  final String? photoUrl;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  double? _dbRating;
  int? _dbReviewCount;
  String? _dbAvatarUrl;

  @override
  void initState() {
    super.initState();
    AccountBlock.notifier.addListener(_refresh);
    // Любая правка профиля (аватар/имя/email/about/legal_status в дочерних
    // экранах) бьёт по этому маяку → ProfileScreen перетянет свежие
    // _dbAvatarUrl/_dbRating и т.п., не дожидаясь hot reload.
    ProfileService.changeBeacon.addListener(_onProfileChanged);
    _loadFromDb();
  }

  void _onProfileChanged() {
    if (!mounted) return;
    // Сбрасываем CropResult.userName/userEmail в пустое не нужно —
    // _loadFromDb с isEmpty-guard корректно мержит локальные правки
    // с серверными значениями, не клобя свежеотредактированные.
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    try {
      final MyProfile? p = await ProfileService.instance.loadMine();
      if (p == null || !mounted) return;
      // Не перезаписываем CropResult.userName/userEmail, если локально
      // уже есть значение. Иначе после возврата из EditProfileScreen
      // мы могли затереть только что введённое имя его старым значением
      // из БД (dispose-write оптимистичный, асинхронный — UPDATE долетит
      // позже, чем SELECT в loadMine). Проверяем именно «пустое»: cold
      // start → CropResult пуст → берём из БД; после редактирования →
      // CropResult свежий → доверяем локальному.
      if (CropResult.userName.isEmpty) {
        CropResult.userName = p.name;
      }
      // Синхронизируем мок-стор блокировки с БД. Без этой строки
      // плашка «Доступ ограничен» не появлялась даже при выставленном
      // в БД blocked_until — AccountBlock жил отдельной жизнью на
      // фронте, и на старте всегда считал юзера разблокированным.
      AccountBlock.setUntil(p.blockedUntil);
      setState(() {
        _dbRating = p.ratingAsCustomer;
        _dbReviewCount = p.reviewCountAsCustomer;
        _dbAvatarUrl = p.avatarUrl;
      });
      // Email живёт в profiles_private — отдельный SELECT. Без него
      // CropResult.userEmail никем не заполняется при cold start, и
      // после Hot Restart введённый ранее email пропадал из «Моя
      // карточка заказчика» и из формы редактирования.
      if (CropResult.userEmail.isEmpty) {
        final MyPrivate? priv = await ProfileService.instance.loadMyPrivate();
        if (!mounted) return;
        if (priv?.email != null && priv!.email!.isNotEmpty) {
          CropResult.userEmail = priv.email!;
          if (mounted) setState(() {});
        }
      }
    } catch (_) {/* silent */}
  }

  @override
  void dispose() {
    AccountBlock.notifier.removeListener(_refresh);
    ProfileService.changeBeacon.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _openEdit() async {
    await context.push('/profile/edit');
    if (!mounted) return;
    // Аватар/имя могли поменяться — перетягиваем из БД, чтобы UI
    // не остался с устаревшим _dbAvatarUrl.
    await _loadFromDb();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final String fullName = CropResult.displayName;
    final double rating = _dbRating ?? 0.0;
    final int reviewsCount = _dbReviewCount ?? 0;
    final bool isBlocked = AccountBlock.isBlocked;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navBarDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16.w,
        toolbarHeight: 64.h,
        title: Text(
          'Профиль',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 28.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        actions: <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: IconButton(
              icon: Image.asset('assets/icons/profile/pen.webp',
                  width: 24.r, height: 24.r),
              onPressed: _openEdit,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(height: AppSpacing.md),
            _Header(
              fullName: fullName,
              rating: rating,
              reviewsCount: reviewsCount,
              avatarUrl: _dbAvatarUrl ?? widget.photoUrl,
              onReviewsTap: () => context.push('/profile/reviews'),
            ),
            if (isBlocked) ...<Widget>[
              SizedBox(height: 16.h),
              const BlockedPill(),
              SizedBox(height: 8.h),
              Text(
                'Ваш рейтинг ниже 2 звёзд, поэтому доступ\nвременно ограничен ${AccountBlock.blockedUntilText ?? "на 30 дней"}',
                style: AppTextStyles.subBody.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
                textAlign: TextAlign.left,
              ),
              SizedBox(height: 16.h),
            ] else
              SizedBox(height: 20.h),
            _ProfileMenuItem(
              label: 'Моя карточка заказчика',
              onTap: () => context.push('/executor-card'),
            ),
            SizedBox(height: 20.h),
            const _SupportFooter(),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.fullName,
    required this.rating,
    required this.reviewsCount,
    required this.avatarUrl,
    required this.onReviewsTap,
  });

  final String fullName;
  final double rating;
  final int reviewsCount;
  final String? avatarUrl;
  final VoidCallback onReviewsTap;

  @override
  Widget build(BuildContext context) {
    final String ratingText = reviewsCount == 0
        ? '0,0'
        : rating.toStringAsFixed(1).replaceAll('.', ',');
    // Если только что выбрали новое фото в этой сессии и crop ещё в
    // памяти — показываем live-preview (cropped local file). Иначе —
    // сетевую аватарку из БД (или серый placeholder, если url пуст).
    final Widget avatar = CropResult.saved != null
        ? CroppedAvatar(size: 72.r)
        : AvatarCircle(size: 72.r, avatarUrl: avatarUrl);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        avatar,
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(fullName,
                  style: AppTextStyles.titleS),
              SizedBox(height: 4.h),
              GestureDetector(
                onTap: onReviewsTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: <Widget>[
                    // При нуле отзывов рейтинг бессмысленен — звезду и
                    // число прячем, оставляем только подчёркнутый счётчик.
                    if (reviewsCount > 0) ...<Widget>[
                      Image.asset('assets/images/catalog/star.webp',
                          width: 20.r, height: 20.r),
                      SizedBox(width: 4.w),
                      Text(ratingText, style: AppTextStyles.body),
                      SizedBox(width: 16.w),
                    ],
                    Text(
                      '$reviewsCount ${reviewsWord(reviewsCount)}',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.categoryCard,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          height: 56.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(label, style: AppTextStyles.body),
              ),
              Image.asset('assets/icons/profile/arrow_right.webp',
                  width: 16.r, height: 16.r),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportFooter extends StatelessWidget {
  const _SupportFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Возникли вопросы? Напишите нам!',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            )),
        SizedBox(height: 8.h),
        Row(
          children: <Widget>[
            Image.asset('assets/icons/profile/max.webp',
                width: 40.r, height: 40.r),
          ],
        ),
      ],
    );
  }
}

Future<bool?> showLogoutAlert(BuildContext context) {
  return _showProfileAlert(
    context,
    title: 'Вы уверены, что хотите выйти?',
    actionLabel: 'Выйти',
    isDestructive: true,
  );
}

Future<bool?> showDeleteAccountAlert(BuildContext context) {
  return _showProfileAlert(
    context,
    title: 'Вы уверены, что хотите удалить аккаунт?',
    actionLabel: 'Удалить',
    isDestructive: true,
  );
}

Future<bool?> _showProfileAlert(
  BuildContext context, {
  required String title,
  required String actionLabel,
  bool isDestructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => Dialog(
      backgroundColor: const Color(0xFFDFDFDF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: SizedBox(
        width: 270.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.titleS.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: Colors.grey.shade400),
            SizedBox(
              height: 44.h,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Center(
                        child: Text('Отмена',
                            style: AppTextStyles.titleS.copyWith(
                              color: AppColors.iosBlue,
                            )),
                      ),
                    ),
                  ),
                  Container(width: 0.5, color: Colors.grey.shade400),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Center(
                        child: Text(actionLabel,
                            style: AppTextStyles.bodyMRegular.copyWith(
                              color: isDestructive
                                  ? AppColors.error
                                  : AppColors.iosBlue,
                            )),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
