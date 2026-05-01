import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/profile/profile_service.dart';
import 'package:dispatcher_1/core/storage/storage_service.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/utils/photo_source.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/avatar_circle.dart';
import 'package:dispatcher_1/core/widgets/cropped_avatar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/auth/photo_crop_screen.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';

import 'executor_card_screen.dart';

/// Форма создания / редактирования карточки заказчика.
/// Поля: ФИО, телефон, местоположение, статус, о себе.
class EditExecutorCardScreen extends StatefulWidget {
  const EditExecutorCardScreen({super.key, this.editing = true});

  final bool editing;

  @override
  State<EditExecutorCardScreen> createState() => _EditExecutorCardScreenState();
}

class _EditExecutorCardScreenState extends State<EditExecutorCardScreen> {
  static const int _nameMaxLen = 60;
  static const int _emailMaxLen = 50;

  /// Базовая проверка формата email: что-то@что-то.tld, без пробелов.
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
  );

  late final TextEditingController _about;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();

  /// Показывать ли красную подсказку под полем телефона (нельзя менять
  /// номер в карточке — только через регистрацию/техподдержку).
  bool _showPhoneHint = false;

  String? _selectedStatus;

  bool _statusExpanded = false;

  /// Ключ на контейнер с развёрнутым списком статусов — нужен, чтобы
  /// прокрутить экран к списку, когда пользователь его раскрывает
  /// (иначе список может быть ниже видимой области).
  final GlobalKey _statusDropdownKey = GlobalKey();

  /// Текст ошибки под полем email. Выставляется при потере фокуса,
  /// если введённое значение не проходит валидацию регуляркой. Сброс —
  /// при возврате фокуса в поле либо после корректного ввода.
  String? _emailError;

  /// Реальный рейтинг заказчика — `profiles.rating_as_customer` /
  /// `review_count_as_customer`. Грузится при открытии экрана; до
  /// первого ответа БД отображаем «—».
  double _ratingAsCustomer = 0;
  int _reviewCountAsCustomer = 0;

  static const _statusOptions = [
    'Физ. лицо',
    'Самозанятый',
    'ИП',
    'Юр. лицо',
  ];

  @override
  void initState() {
    super.initState();
    _about = TextEditingController(text: ExecutorCardData.about ?? '');
    // Имя/email — синхронизируются с профилем через [ExecutorCardData.name]
    // (геттер на [CropResult.userName]) и [CropResult.userEmail].
    _nameCtrl = TextEditingController(text: ExecutorCardData.name);
    _emailCtrl = TextEditingController(text: CropResult.userEmail);
    _selectedStatus = ExecutorCardData.status;

    _nameFocus.addListener(() async {
      if (!_nameFocus.hasFocus) {
        final String value = _nameCtrl.text.trim();
        if (value.isEmpty) {
          // Пустое имя не сохраняем — откатываем к последнему валидному.
          _nameCtrl.text = ExecutorCardData.name;
        } else if (value != ExecutorCardData.name) {
          // Оптимистично пишем в локальный кеш + UPDATE в БД. Раньше
          // изменение имени в этой форме не уходило в БД вовсе — после
          // Hot Restart новое имя пропадало.
          ExecutorCardData.name = value;
          try {
            await ProfileService.instance.update(name: value);
          } catch (_) {/* silent — UI не блокируем, при ошибке откатится при следующем loadMine */}
        }
      }
    });
    _emailFocus.addListener(() async {
      if (_emailFocus.hasFocus) {
        // Пользователь вернулся в поле редактировать — убираем подсказку
        // об ошибке, пока не оценим снова на следующем blur.
        if (_emailError != null) {
          setState(() => _emailError = null);
        }
      } else {
        // Нормализуем регистр для хранения — иначе один и тот же ящик
        // может оказаться в БД дважды («User@x.com» / «user@x.com»).
        // Контроллер не трогаем — пусть юзер видит вариант «как ввёл».
        final String value = _emailCtrl.text.trim().toLowerCase();
        final bool valid = value.isEmpty || _emailRegex.hasMatch(value);
        if (valid) {
          if (value != CropResult.userEmail) {
            CropResult.userEmail = value;
            try {
              await ProfileService.instance.updatePrivateEmail(value);
            } catch (_) {/* silent */}
          }
          if (_emailError != null) setState(() => _emailError = null);
        } else {
          // Невалидное значение не сохраняем в CropResult. Текст в поле
          // не откатываем — чтобы пользователь увидел ошибку и исправил.
          setState(() => _emailError = 'Некорректная электронная почта');
        }
      }
    });
    _loadRatingFromDb();
  }

  Future<void> _loadRatingFromDb() async {
    try {
      final MyProfile? p = await ProfileService.instance.loadMine();
      if (!mounted || p == null) return;
      setState(() {
        _ratingAsCustomer = p.ratingAsCustomer;
        _reviewCountAsCustomer = p.reviewCountAsCustomer;
      });
    } catch (_) {/* нет сети — оставим «—» */}
  }

  @override
  void dispose() {
    // Если пользователь ушёл с экрана не сняв фокус — listener не успел
    // ни сохранить локально, ни записать в БД. Дублируем оба действия
    // здесь с тем же rollback-паттерном, что в edit_profile_screen.
    final String name = _nameCtrl.text.trim();
    if (name.isNotEmpty && name != ExecutorCardData.name) {
      final String prev = ExecutorCardData.name;
      ExecutorCardData.name = name;
      // ignore: discarded_futures
      ProfileService.instance.update(name: name).catchError((Object _) {
        ExecutorCardData.name = prev;
      });
    }
    final String email = _emailCtrl.text.trim().toLowerCase();
    if ((email.isEmpty || _emailRegex.hasMatch(email)) &&
        email != CropResult.userEmail) {
      final String prev = CropResult.userEmail;
      CropResult.userEmail = email;
      // ignore: discarded_futures
      ProfileService.instance.updatePrivateEmail(email).catchError((Object _) {
        CropResult.userEmail = prev;
      });
    }
    _about.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
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
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md,
                    AppSpacing.screenH, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              ListenableBuilder(
                listenable: _nameCtrl,
                builder: (_, _) => _HeaderRow(
                  displayName: _nameCtrl.text,
                  rating: _ratingAsCustomer,
                  reviewCount: _reviewCountAsCustomer,
                ),
              ),
              SizedBox(height: 16.h),
              _PlainEditableField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                hint: 'Имя и фамилия',
                keyboardType: TextInputType.name,
                maxLength: _nameMaxLen,
              ),
              SizedBox(height: 8.h),
              _PlainEditableField(
                controller: _emailCtrl,
                focusNode: _emailFocus,
                hint: 'Электронная почта',
                keyboardType: TextInputType.emailAddress,
                maxLength: _emailMaxLen,
              ),
              if (_emailError != null) ...[
                SizedBox(height: 6.h),
                Text(
                  _emailError!,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.error),
                ),
              ],
              SizedBox(height: 8.h),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    setState(() => _showPhoneHint = !_showPhoneHint),
                child: Container(
                  height: 56.h,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(ExecutorCardData.phone, style: AppTextStyles.body),
                ),
              ),
              if (_showPhoneHint) ...[
                SizedBox(height: 6.h),
                Text(
                  'Можно использовать только номер телефона, '
                  'указанный при регистрации.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.error),
                ),
              ],
              SizedBox(height: AppSpacing.lg),
              _SectionTitle('О себе'),
              SizedBox(height: AppSpacing.xs),
              _TintField(
                controller: _about,
                hint: 'Расскажите о себе',
                minLines: 1,
                maxLength: 500,
                maxLines: 5,
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Информация о вас помогает другим лучше понять, '
                'с кем они будут работать.',
                style: AppTextStyles.caption
                    .copyWith(color: const Color(0xFF707070)),
              ),
              SizedBox(height: AppSpacing.lg),
              _SectionTitle('Статус'),
              SizedBox(height: AppSpacing.xs),
              GestureDetector(
                onTap: () {
                  setState(() => _statusExpanded = !_statusExpanded);
                  if (_statusExpanded) {
                    // После раскрытия списка прокручиваем экран так,
                    // чтобы полный список статусов был виден.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final BuildContext? ctx =
                          _statusDropdownKey.currentContext;
                      if (ctx != null) {
                        Scrollable.ensureVisible(
                          ctx,
                          duration: const Duration(milliseconds: 200),
                          alignment: 1.0,
                        );
                      }
                    });
                  }
                },
                child: Container(
                  height: 54.h,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: _statusExpanded
                        ? BorderRadius.vertical(top: Radius.circular(12.r))
                        : BorderRadius.circular(AppSpacing.radiusM),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedStatus ?? 'Укажите статус',
                          style: AppTextStyles.body.copyWith(
                            color: _selectedStatus == null
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Image.asset(
                        _statusExpanded
                            ? 'assets/icons/ui/arrow_up.webp'
                            : 'assets/icons/ui/arrow_down.webp',
                        width: 22.r,
                        height: 22.r,
                      ),
                    ],
                  ),
                ),
              ),
              if (_statusExpanded)
                Container(
                  key: _statusDropdownKey,
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(12.r)),
                  ),
                  child: Column(
                    children: [
                      Divider(height: 1, thickness: 0.5, color: Colors.grey.shade300),
                      for (final s in _statusOptions)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() {
                            _selectedStatus = s;
                            _statusExpanded = false;
                          }),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.md, vertical: 12.h),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(s, style: AppTextStyles.body),
                                ),
                                if (_selectedStatus == s)
                                  Image.asset('assets/icons/ui/check_black.webp',
                                      width: 22.r, height: 22.r),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                  SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    offset: const Offset(0, -1),
                    blurRadius: 8,
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
              child: PrimaryButton(
                label: 'Сохранить',
                onPressed: () async {
                  ExecutorCardData.status = _selectedStatus;
                  ExecutorCardData.about = _about.text;
                  ExecutorCardScreen.cardCreated = true;

                  // UPDATE profiles: about, legal_status. У заказчика
                  // отдельной таблицы карточки нет — всё в profiles.
                  final String? legalStatus = switch (_selectedStatus) {
                    'Физ. лицо' => 'individual',
                    'Самозанятый' => 'self_employed',
                    'ИП' => 'ip',
                    'Юр. лицо' => 'legal_entity',
                    _ => null,
                  };
                  try {
                    // Всегда выставляет customer_card_saved_at = now(),
                    // чтобы UI ушёл из empty-state даже когда оба поля
                    // (about/legal_status) пустые — они опциональные.
                    await ProfileService.instance.saveCustomerCard(
                      about: _about.text.trim().isEmpty
                          ? null
                          : _about.text.trim(),
                      legalStatus: legalStatus,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Не удалось сохранить: $e')),
                    );
                    return;
                  }
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatefulWidget {
  const _HeaderRow({
    required this.displayName,
    required this.rating,
    required this.reviewCount,
  });

  /// Имя пользователя, отображаемое рядом с аватаром. Родитель передаёт
  /// текущее значение из контроллера «Имя и фамилия», чтобы шапка
  /// обновлялась одновременно с тем, что вводит пользователь.
  final String displayName;
  final double rating;
  final int reviewCount;

  @override
  State<_HeaderRow> createState() => _HeaderRowState();
}

class _HeaderRowState extends State<_HeaderRow> {
  Future<void> _openCrop() async {
    final String? imagePath = await pickImageFromGallery(context: context);
    if (imagePath == null || !mounted) return;
    final result = await Navigator.of(context).push<CropResult>(
      MaterialPageRoute(
        builder: (_) => PhotoCropScreen(imagePath: imagePath),
      ),
    );
    if (result != null && mounted) {
      setState(() => CropResult.saved = result);
      // Аватар нужно реально залить в Storage и записать URL в БД,
      // иначе после Hot Restart загруженное фото исчезает: in-memory
      // CropResult.saved сбрасывается, а сетевая аватарка не была
      // обновлена. Раньше этот шаг отсутствовал в карточке заказчика
      // (в edit_profile_screen он есть — здесь зеркалим логику).
      final String? path = result.imagePath;
      if (path != null && !path.startsWith('assets/')) {
        // ignore: discarded_futures
        _uploadAvatar(path);
      }
    }
  }

  Future<void> _uploadAvatar(String path) async {
    try {
      final String url =
          await StorageService.instance.uploadAvatar(File(path));
      await ProfileService.instance.update(avatarUrl: url);
      if (mounted) setState(() => ExecutorCardData.avatarUrl = url);
    } catch (_) {/* silent */}
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _openCrop,
          child: SizedBox(
            width: 80.r,
            height: 80.r,
            child: Stack(
              children: [
                // Live-preview из памяти (если только что выбрали фото)
                // или сетевая аватарка из БД — иначе после рестарта
                // экран редактирования показывал серый плейсхолдер.
                if (CropResult.saved != null)
                  CroppedAvatar(size: 80.r)
                else
                  AvatarCircle(size: 80.r, avatarUrl: ExecutorCardData.avatarUrl),
                Positioned(
                  right: -1.w,
                  bottom: 0,
                  child: Image.asset(
                    'assets/icons/ui/edit.webp',
                    width: 21.r,
                    height: 21.r,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.displayName.trim().isEmpty
                    ? CropResult.namePlaceholder
                    : widget.displayName,
                style: AppTextStyles.titleS,
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  if (widget.reviewCount > 0) ...[
                    Image.asset('assets/images/catalog/star.webp',
                        width: 20.r, height: 20.r),
                    SizedBox(width: 4.w),
                    Text(
                      widget.rating
                          .toStringAsFixed(1)
                          .replaceAll('.', ','),
                      style: AppTextStyles.body,
                    ),
                    SizedBox(width: 16.w),
                  ],
                  GestureDetector(
                    onTap: () => context.push('/profile/reviews'),
                    child: Text(
                      '${widget.reviewCount} ${_reviewsWord(widget.reviewCount)}',
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

String _reviewsWord(int n) {
  final int mod100 = n % 100;
  final int mod10 = n % 10;
  if (mod100 >= 11 && mod100 <= 14) return 'отзывов';
  if (mod10 == 1) return 'отзыв';
  if (mod10 >= 2 && mod10 <= 4) return 'отзыва';
  return 'отзывов';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.bodyL.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

/// Поле в том же стиле, что и заглушенный `_TintField`, но с подключённым
/// контроллером и редактированием по тапу. Используется для «Имя и фамилия»
/// и «Электронная почта» в карточке заказчика — в отличие от экрана
/// редактирования профиля, здесь нет карандаша-бейджа.
class _PlainEditableField extends StatelessWidget {
  const _PlainEditableField({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.keyboardType,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(14.r),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          counterText: '',
          hintText: hint,
          hintStyle:
              AppTextStyles.body.copyWith(color: AppColors.textTertiary),
        ),
      ),
    );
  }
}

class _TintField extends StatelessWidget {
  const _TintField({
    required this.controller,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
  });
  final TextEditingController controller;
  final String? hint;
  final int minLines;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      buildCounter: maxLength != null ? (_, {required currentLength, required isFocused, required maxLength}) => null : null,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

