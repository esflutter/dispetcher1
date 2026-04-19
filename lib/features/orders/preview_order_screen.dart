import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/dark_sub_app_bar.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
import 'package:dispatcher_1/features/catalog/widgets/catalog_search_bar.dart';
import 'package:dispatcher_1/features/orders/widgets/order_status_pill.dart';

/// Данные черновика заказа, которые передаются в предварительный
/// просмотр перед публикацией. Все поля отформатированы для показа.
/// Необязательные поля передаются в виде пустых коллекций/строк —
/// preview сам скроет блок, если он пуст.
class OrderDraft {
  const OrderDraft({
    required this.number,
    required this.title,
    required this.description,
    required this.budget,
    required this.rentDate,
    required this.address,
    required this.machinery,
    required this.categories,
    required this.works,
    required this.photos,
  });

  /// Номер заказа вида `№123456`.
  final String number;
  final String title;

  /// Текст описания. Может быть пустым — тогда блок не показывается.
  final String description;

  /// Отформатированная стоимость: «от 10 000 ₽», «до 50 000 ₽»,
  /// «10 000 – 50 000 ₽» либо пустая строка.
  final String budget;

  /// Готовая строка «15 июня · 09:00–18:00».
  final String rentDate;
  final String address;

  final List<String> machinery;
  final List<String> categories;

  /// Строки вида «Разработка грунта — 40 м³».
  final List<String> works;

  /// Пути ассетов к приложенным фото.
  final List<String> photos;
}

/// Экран предпросмотра заказа. Используется и перед публикацией
/// (`status == null`, режим создания с кнопками «Опубликовать /
/// Редактировать»), и при просмотре уже опубликованного заказа
/// (`status != null`, набор кнопок зависит от статуса).
///
/// Необязательные блоки (Описание, Стоимость, Характер работ, Фото)
/// показываются, только если заполнены.
class CreateOrderPreviewScreen extends StatelessWidget {
  const CreateOrderPreviewScreen({
    super.key,
    required this.draft,
    this.status,
    this.reviewLeft = false,
    this.onPickAnother,
    this.onMoveToArchive,
    this.onLeaveReview,
    this.onRepublish,
    this.onOpenCatalog,
  });

  final OrderDraft draft;

  /// Статус опубликованного заказа. `null` — режим создания заказа
  /// (до публикации), показываются кнопки «Опубликовать / Редактировать».
  final MyOrderStatus? status;

  /// Был ли уже оставлен отзыв по этому заказу. Если `true`, кнопка
  /// «Оставить отзыв» в статусе [MyOrderStatus.completed] не показывается.
  final bool reviewLeft;

  /// Колбэк «Выбрать другого исполнителя» — для waiting/waitingChoose/
  /// accepted.
  final VoidCallback? onPickAnother;

  /// Колбэк «Переместить в архив» — для waiting/waitingChoose/accepted.
  final VoidCallback? onMoveToArchive;

  /// Колбэк «Оставить отзыв» — для completed.
  final VoidCallback? onLeaveReview;

  /// Колбэк «Опубликовать заново» — для rejectedDeclined.
  final VoidCallback? onRepublish;

  /// Колбэк «Перейти в каталог» — для waiting, когда откликов ещё нет
  /// и заказчику предлагается поискать исполнителей самостоятельно.
  final VoidCallback? onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    final List<Widget> sections = <Widget>[];

    void addSection(String title, Widget child) {
      if (sections.isNotEmpty) sections.add(SizedBox(height: 16.h));
      sections.add(_Section(title: title, child: child));
    }

    addSection(
      'Дата и время аренды',
      Text(
        draft.rentDate,
        style: AppTextStyles.body.copyWith(fontSize: 14.sp, height: 1.4),
      ),
    );

    addSection(
      'Адрес',
      Text(
        draft.address,
        style: AppTextStyles.body.copyWith(
          fontSize: 14.sp,
          height: 1.4,
          decoration: TextDecoration.underline,
        ),
      ),
    );

    if (draft.description.trim().isNotEmpty) {
      addSection(
        'Описание заказа',
        Text(
          draft.description,
          style: AppTextStyles.body.copyWith(fontSize: 14.sp, height: 1.4),
        ),
      );
    }

    if (draft.budget.trim().isNotEmpty) {
      addSection(
        'Стоимость',
        Text(
          draft.budget,
          style: AppTextStyles.bodyMMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (draft.machinery.isNotEmpty) {
      addSection('Требуемая спецтехника', _ChipRow(items: draft.machinery));
    }

    if (draft.categories.isNotEmpty) {
      addSection('Категория работ', _ChipRow(items: draft.categories));
    }

    if (draft.works.isNotEmpty) {
      addSection(
        'Характер работ',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final String w in draft.works)
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Text(
                  w,
                  style: AppTextStyles.body
                      .copyWith(fontSize: 14.sp, height: 1.4),
                ),
              ),
          ],
        ),
      );
    }

    if (draft.photos.isNotEmpty) {
      addSection('Фото', _PhotosGrid(photos: draft.photos));
    }

    final List<Widget> bottomButtons = _buildBottomButtons(context);
    final bool hasBottomBar = bottomButtons.isNotEmpty;
    final double fabBottom = !hasBottomBar
        ? 24.h
        : (bottomButtons.length == 1 ? 88.h : 148.h);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: DarkSubAppBar(title: draft.title),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: fabBottom),
        child: AiAssistantFab(onTap: () => context.push('/assistant/chat')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (status != null) ...<Widget>[
                    Center(child: OrderStatusPill(status: status!)),
                    SizedBox(height: 12.h),
                  ],
                  Text(
                    draft.number,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    draft.title,
                    textAlign: TextAlign.left,
                    style: AppTextStyles.titleL.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  ...sections,
                ],
              ),
            ),
          ),
          if (hasBottomBar)
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                16.w,
                12.h,
                16.w,
                16.h + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: bottomButtons,
              ),
            ),
        ],
      ),
    );
  }

  /// Набор кнопок нижней панели в зависимости от статуса заказа.
  /// Пустой список означает, что нижней панели нет вообще.
  List<Widget> _buildBottomButtons(BuildContext context) {
    if (status == null) {
      return <Widget>[
        PrimaryButton(
          label: 'Опубликовать',
          onPressed: () => Navigator.of(context).pop(true),
        ),
        SizedBox(height: 8.h),
        SecondaryButton(
          label: 'Редактировать',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ];
    }
    switch (status!) {
      case MyOrderStatus.waiting:
      case MyOrderStatus.executorDeclinedWaiting:
        // Откликов (ещё) нет — предлагаем заказчику перейти в каталог
        // и самому поискать исполнителей. Второй кейс — когда ранее
        // выбранный исполнитель отказался и других откликов нет.
        return <Widget>[
          PrimaryButton(
            label: 'Перейти в каталог',
            onPressed: onOpenCatalog,
          ),
          SizedBox(height: 8.h),
          SecondaryButton(
            label: 'Переместить в архив',
            onPressed: onMoveToArchive,
          ),
        ];
      case MyOrderStatus.awaitingExecutor:
        // Заказ предложен конкретному исполнителю. Можно подождать
        // подтверждения — либо сразу выбрать другого. Логика «другого»:
        // если были другие отклики — переходим к списку, иначе — в
        // каталог, чтобы искать вручную (это решает родительский
        // колбэк [onPickAnother]).
        return <Widget>[
          PrimaryButton(
            label: 'Выбрать другого исполнителя',
            onPressed: onPickAnother,
          ),
          SizedBox(height: 8.h),
          SecondaryButton(
            label: 'Переместить в архив',
            onPressed: onMoveToArchive,
          ),
        ];
      case MyOrderStatus.waitingChoose:
      case MyOrderStatus.accepted:
      case MyOrderStatus.executorDeclined:
        return <Widget>[
          PrimaryButton(
            label: 'Выбрать другого исполнителя',
            onPressed: onPickAnother,
          ),
          SizedBox(height: 8.h),
          SecondaryButton(
            label: 'Переместить в архив',
            onPressed: onMoveToArchive,
          ),
        ];
      case MyOrderStatus.completed:
        // После оставленного отзыва кнопка скрывается — отзыв можно
        // оставить только один раз.
        if (reviewLeft) return const <Widget>[];
        return <Widget>[
          PrimaryButton(
            label: 'Оставить отзыв',
            onPressed: onLeaveReview,
          ),
        ];
      case MyOrderStatus.rejectedDeclined:
        return <Widget>[
          PrimaryButton(
            label: 'Опубликовать заново',
            onPressed: onRepublish,
          ),
        ];
      case MyOrderStatus.rejectedOther:
        return const <Widget>[];
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        child,
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: items
          .map(
            (String label) => Container(
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
            ),
          )
          .toList(),
    );
  }
}

class _PhotosGrid extends StatelessWidget {
  const _PhotosGrid({required this.photos});
  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: photos
          .map((String p) => ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: Image.asset(
                  p,
                  width: 72.r,
                  height: 72.r,
                  fit: BoxFit.cover,
                ),
              ))
          .toList(),
    );
  }
}
