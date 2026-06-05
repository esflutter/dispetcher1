import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/ai/ai_navigation.dart';
import 'package:dispatcher_1/core/catalog/format.dart';
import 'package:dispatcher_1/core/utils/photo_source.dart';
import 'package:dispatcher_1/features/catalog/executor_card_view_screen.dart';
import 'package:dispatcher_1/features/orders/create_order_screen.dart';

enum ChatMessageType { text, image, orderCards, executorCards, draftReady }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.fromUser,
    this.type = ChatMessageType.text,
    this.imageAssets = const <String>[],
    this.data,
    this.navAction,
    this.navLabel,
  });

  final String id;
  final String text;
  final bool fromUser;
  final ChatMessageType type;
  final List<String> imageAssets;
  /// Для handoff-сообщений (см. enum ChatMessageType).
  final Map<String, dynamic>? data;
  /// Подсказка перехода в раздел (кнопка «Перейти» под ответом ассистента).
  final String? navAction;
  final String? navLabel;
}

/// Пузырь сообщения. Входящие — кремовый primaryTint слева,
/// исходящие — оранжевый primary справа.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    final bg = isUser ? AppColors.primary : AppColors.primaryTint;
    final fg = isUser ? Colors.white : AppColors.textBlack;

    if (message.type == ChatMessageType.executorCards) {
      return _ExecutorCardsHandoff(text: message.text, data: message.data ?? const {});
    }
    if (message.type == ChatMessageType.orderCards) {
      return _OrderCardsHandoff(text: message.text, data: message.data ?? const {});
    }
    if (message.type == ChatMessageType.draftReady) {
      return _DraftReadyHandoff(text: message.text, data: message.data ?? const {});
    }

    if (message.type == ChatMessageType.image) {
      return Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: 312.w), // 88*3 + 8*2 + 16*2
          margin: EdgeInsets.symmetric(vertical: 8.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final asset in message.imageAssets)
                GestureDetector(
                  onTap: () => _showFullscreenImage(context, asset),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: isAssetPath(asset)
                        ? Image.asset(
                            asset,
                            width: 88.r,
                            height: 88.r,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 88.r,
                              height: 88.r,
                              color: AppColors.surfaceMuted,
                              child: Icon(Icons.image_outlined,
                                  color: AppColors.textTertiary, size: 32.r),
                            ),
                          )
                        : Image.file(
                            File(asset),
                            width: 88.r,
                            height: 88.r,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 88.r,
                              height: 88.r,
                              color: AppColors.surfaceMuted,
                              child: Icon(Icons.image_outlined,
                                  color: AppColors.textTertiary, size: 32.r),
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Пустой текст ассистента = плейсхолдер стрима до прихода первого слова.
    // Показываем анимацию «печатает» прямо в этом облачке, чтобы рядом не
    // висело второе пустое облачко с точками.
    if (!isUser && message.type == ChatMessageType.text && message.text.isEmpty) {
      return const TypingBubble();
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 280.w),
        margin: EdgeInsets.symmetric(vertical: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: AppTextStyles.body.copyWith(
                color: fg,
                fontSize: 16.sp,
                height: 1.25,
              ),
            ),
            // Кнопка «Перейти» под ответом ассистента (если сервер прислал
            // подсказку раздела). На сообщениях пользователя её не бывает.
            if (!isUser && message.navAction != null && message.navLabel != null) ...[
              SizedBox(height: 10.h),
              _NavButton(action: message.navAction!, label: message.navLabel!),
            ],
          ],
        ),
      ),
    );
  }

  void _showFullscreenImage(BuildContext context, String asset) {
    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    child: isAssetPath(asset)
                        ? Image.asset(asset,
                            errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.broken_image,
                                    color: Colors.white38, size: 72)))
                        : Image.file(File(asset),
                            errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.broken_image,
                                    color: Colors.white38, size: 72))),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Кнопка «Перейти» под ответом ассистента — ведёт в нужный раздел.
class _NavButton extends StatelessWidget {
  const _NavButton({required this.action, required this.label});
  final String action;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => navigateAssistantAction(context, action),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: AppColors.primary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Handoff-виджеты — найденные карточки и готовые черновики.
// ============================================================

/// В приложении заказчика order_cards теоретически может прилететь (например,
/// «покажи мои заказы»). Раньше виджет был заглушкой с одним текстом —
/// карточки терялись. Сейчас рендерим список с тапом на детали заказа.
class _OrderCardsHandoff extends StatelessWidget {
  const _OrderCardsHandoff({required this.text, required this.data});
  final String text;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final items = (data['items'] is List ? data['items'] as List : const [])
        .whereType<Map<String, dynamic>>()
        .where((it) => (it['id'] as String? ?? '').isNotEmpty)
        .toList();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 312.w),
        margin: EdgeInsets.symmetric(vertical: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text.isNotEmpty) ...[
              Text(text,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textBlack, fontSize: 16.sp, height: 1.25,
                ),
              ),
              SizedBox(height: 12.h),
            ],
            ...items.take(5).map((it) => _CustomerOrderTile(item: it)),
            if (items.length > 5)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Text(
                  'И ещё ${items.length - 5} — уточните запрос, чтобы их сузить.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textTertiary, fontSize: 13.sp,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomerOrderTile extends StatelessWidget {
  const _CustomerOrderTile({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final id      = item['id'] as String? ?? '';
    final title   = (item['title']  as String? ?? '').trim();
    final address = (item['address']as String? ?? '').trim();
    final dateFrom = item['date_from'] as String?;
    return InkWell(
      // В приложении заказчика свои заказы открываются через /orders/:id.
      // Снимаем фокус перед уходом с чата — иначе при возврате клавиатура
      // снова всплывает (Navigator восстанавливает фокус поля ввода).
      onTap: id.isEmpty ? null : () {
        FocusManager.instance.primaryFocus?.unfocus();
        context.push('/orders/$id');
      },
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title.isEmpty ? 'Заказ' : title,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textBlack, fontSize: 14.sp, fontWeight: FontWeight.w600,
              ),
            ),
            if (address.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Text(address,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textTertiary, fontSize: 12.sp,
                ),
              ),
            ],
            if (dateFrom != null) ...[
              SizedBox(height: 4.h),
              Text('с ${formatIsoDayShort(dateFrom)}',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textTertiary, fontSize: 12.sp,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Карточки исполнителей — для заказчика.
class _ExecutorCardsHandoff extends StatelessWidget {
  const _ExecutorCardsHandoff({required this.text, required this.data});
  final String text;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final items = (data['items'] is List ? data['items'] as List : const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    // Карточки без user_id не кликабельны — фильтруем заранее, чтобы и срез
    // до 5, и счётчик «И ещё N» считались по реально показываемым.
    final visibleExec = items
        .where((it) => (it['user_id'] as String? ?? '').isNotEmpty)
        .toList();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 312.w),
        margin: EdgeInsets.symmetric(vertical: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text.isNotEmpty) ...[
              Text(text,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textBlack, fontSize: 16.sp, height: 1.25,
                ),
              ),
              SizedBox(height: 12.h),
            ],
            // Карточки без user_id не кликабельны — считаем по отфильтрованным.
            ...visibleExec
                .take(5)
                .map((it) => _ExecutorTile(item: it)),
            if (visibleExec.length > 5)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Text(
                  'И ещё ${visibleExec.length - 5} — уточните запрос, чтобы их сузить.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textTertiary, fontSize: 13.sp,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExecutorTile extends StatelessWidget {
  const _ExecutorTile({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final id      = item['user_id'] as String? ?? '';
    final name    = (item['name'] as String? ?? '').trim();
    final addr    = (item['location_address'] as String? ?? '').trim();
    final rating  = item['rating'];
    final reviews = item['review_count'];
    final priceH  = item['min_price_per_hour'];
    final dist    = item['distance_km'];
    return InkWell(
      onTap: id.isEmpty ? null : () {
        // Снимаем фокус перед уходом с чата — иначе при возврате всплывает
        // клавиатура (Navigator восстанавливает фокус поля ввода).
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ExecutorCardViewScreen(executorId: id),
        ));
      },
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name.isEmpty ? 'Исполнитель' : name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textBlack, fontSize: 14.sp, fontWeight: FontWeight.w600,
              ),
            ),
            if (rating != null) ...[
              SizedBox(height: 4.h),
              Text(
                [
                  '⭐ $rating',
                  if (reviews != null) '($reviews отзывов)',
                ].join(' '),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textTertiary, fontSize: 12.sp,
                ),
              ),
            ],
            if (priceH != null || dist != null) ...[
              SizedBox(height: 4.h),
              Text(
                [
                  if (priceH != null) 'от $priceH ₽/час',
                  if (dist   != null) '~ $dist км',
                ].join(' • '),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textTertiary, fontSize: 12.sp,
                ),
              ),
            ],
            if (addr.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Text(addr,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textTertiary, fontSize: 12.sp,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Реестр подписей уже опубликованных черновиков — чтобы повторными тапами
/// по карточке нельзя было создать дублей. Статический набор переживает
/// прокрутку чата. ВАЖНО: при выходе из аккаунта чистится в auth_reset,
/// иначе следующий пользователь на этом же устройстве увидел бы свой
/// идентичный черновик как «уже опубликовано».
class PublishedDraftRegistry {
  PublishedDraftRegistry._();
  static final Set<String> sigs = <String>{};
  static void clear() => sigs.clear();
}

/// Готовый черновик — кнопка «Открыть форму создания».
///
/// После публикации заказа кнопка становится неактивной («Заказ опубликован»),
/// чтобы повторными тапами нельзя было насоздавать дублей одного и того же
/// заказа. Подписи уже опубликованных черновиков держим в статическом наборе —
/// он переживает перестроение/прокрутку списка чата.
class _DraftReadyHandoff extends StatefulWidget {
  const _DraftReadyHandoff({required this.text, required this.data});
  final String text;
  final Map<String, dynamic> data;

  @override
  State<_DraftReadyHandoff> createState() => _DraftReadyHandoffState();
}

class _DraftReadyHandoffState extends State<_DraftReadyHandoff> {
  String get _sig {
    final d = widget.data['draft'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return '${widget.data['kind']}|${d['title']}|${d['description']}|'
        '${d['date_from']}|${d['machinery_ids']}|${d['city']}';
  }

  @override
  Widget build(BuildContext context) {
    final String text = widget.text;
    final kind  = widget.data['kind']  as String? ?? '';
    final draft = widget.data['draft'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final isOrder = kind == 'order_draft';
    final bool published = PublishedDraftRegistry.sigs.contains(_sig);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 312.w),
        margin: EdgeInsets.symmetric(vertical: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text.isNotEmpty) ...[
              Text(text,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textBlack, fontSize: 16.sp, height: 1.25,
                ),
              ),
              SizedBox(height: 12.h),
            ],
            Text(
              published
                  ? (isOrder ? 'Заказ опубликован' : 'Услуга опубликована')
                  : (isOrder ? 'Черновик заказа готов' : 'Черновик услуги готов'),
              style: AppTextStyles.body.copyWith(
                color: AppColors.textBlack, fontSize: 14.sp, fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              published
                  ? 'Готово. Чтобы создать ещё один — попросите ассистента собрать новый.'
                  : (isOrder
                      ? 'Откройте форму заказа — проверьте поля и опубликуйте.'
                      : 'Откройте форму услуги — проверьте поля и опубликуйте.'),
              style: AppTextStyles.body.copyWith(
                color: AppColors.textTertiary, fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // Неактивна, если этот черновик уже опубликован — защита от
                // повторного создания одного и того же заказа.
                onPressed: published
                    ? null
                    : () async {
                        if (draft.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Черновик пуст — расскажите подробнее ассистенту.')),
                          );
                          return;
                        }
                        // Снимаем фокус перед уходом на форму — чтобы при
                        // возврате в чат клавиатура не всплывала снова.
                        FocusManager.instance.primaryFocus?.unfocus();
                        if (isOrder) {
                          final Object? result = await Navigator.of(context).push<Object?>(
                            MaterialPageRoute<Object?>(
                              builder: (_) => CreateOrderScreen(aiDraft: draft),
                            ),
                          );
                          // Форма вернула true только при успешной публикации —
                          // помечаем черновик опубликованным и гасим кнопку.
                          if (result == true && mounted) {
                            setState(() => PublishedDraftRegistry.sigs.add(_sig));
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Этот тип черновика недоступен в приложении заказчика')),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.textTertiary.withValues(alpha: 0.25),
                  disabledForegroundColor: AppColors.textTertiary,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
                child: Text(
                  published
                      ? (isOrder ? 'Заказ опубликован' : 'Услуга опубликована')
                      : (isOrder ? 'Открыть форму заказа' : 'Открыть форму услуги'),
                  style: AppTextStyles.body.copyWith(
                    color: published ? AppColors.textTertiary : Colors.white,
                    fontSize: 15.sp, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Индикатор «печатает…» — три точки в кремовом пузыре.
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = ((_c.value * 3) - i).clamp(0.0, 1.0);
                final scale = 0.6 + 0.4 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3.w),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 8.r,
                      height: 8.r,
                      decoration: const BoxDecoration(
                        color: AppColors.textTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
