import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dispatcher_1/core/ai/ai_client.dart';
import 'package:dispatcher_1/core/ai/chat_intent.dart';
import 'package:dispatcher_1/core/ai/stt_recorder.dart';
import 'package:dispatcher_1/core/auth/guest_gate.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/theme/system_bar_style.dart';
import 'package:dispatcher_1/core/user_location.dart';
import 'package:dispatcher_1/core/utils/photo_source.dart';
import 'package:dispatcher_1/features/support/widgets/chat_bubble.dart';
import 'package:dispatcher_1/features/support/widgets/chat_input_bar.dart';

/// Экран чата с ИИ-ассистентом «Поддержка».
///
/// Режимы:
///   - chat            — обычный FAQ
///   - slotFillOrder   — пошаговое создание заказа
///   - search          — поиск исполнителя по описанию
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.initialMessage});

  final String? initialMessage;

  static void resetHistory() {
    _ChatScreenState.resetHistory();
    AiClient.instance.resetSessions();
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static final List<ChatMessage> _messages = <ChatMessage>[
    const ChatMessage(
      id: 'm1',
      text: 'Здравствуйте! Я помогу создать заказ, найти исполнителя или '
            'ответить на вопрос по приложению. С чего начнём?',
      fromUser: false,
    ),
  ];

  static AiChatKind _mode = AiChatKind.chat;
  static int _idCounter = 0;

  static void resetHistory() {
    _messages
      ..clear()
      ..add(const ChatMessage(
        id: 'm1',
        text: 'Здравствуйте! Я помогу создать заказ, найти исполнителя или '
              'ответить на вопрос по приложению. С чего начнём?',
        fromUser: false,
      ));
    _mode = AiChatKind.chat;
    _idCounter = 0;
  }

  final List<String> _pendingImages = <String>[];
  // Все фото, прикреплённые в этой сессии (локальные пути). При создании
  // заказа уходят в черновик и заливаются в order-photos вместе с заказом.
  final List<String> _orderPhotos = <String>[];
  final ScrollController _scrollController = ScrollController();
  // Контроллер поля ввода держим в экране, чтобы класть в поле распознанный
  // голос — пользователь видит текст и отправляет/правит сам.
  final TextEditingController _inputController = TextEditingController();
  bool _isRecording = false;
  bool _isProcessing = false;
  /// Защёлка от двойного тапа по микрофону.
  bool _voiceBusy = false;

  /// id пузыря-плейсхолдера «идёт запись голоса» в ленте чата. Во время записи
  /// показываем его как сообщение пользователя; по завершении заменяем
  /// распознанным текстом и сразу отправляем ассистенту; при отмене/ошибке —
  /// убираем.
  static const String _kVoiceRecId = '__voice_rec__';

  bool get _showQuickActions =>
      _messages.length == 1 && !_messages.first.fromUser && _pendingImages.isEmpty && !_isProcessing;

  /// Отдельное облачко «печатает» показываем только пока ждём ПЕРВОЙ реакции
  /// (последнее сообщение — от пользователя). Когда появляется плейсхолдер
  /// ответа ассистента (стрим), точки рисуются уже внутри него — второе
  /// облачко не нужно.
  bool get _showStandaloneTyping =>
      _isProcessing && (_messages.isEmpty || _messages.last.fromUser);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Прогреваем геопозицию заранее (best-effort, не блокирует): к моменту
    // первого поиска координаты обычно уже готовы, и расстояние в карточках
    // показывается сразу.
    unawaited(UserLocation.ensure());
    _salvageOrphanPlaceholders();
    final initial = widget.initialMessage?.trim();
    if (initial == null || initial.isEmpty) {
      // Открытие чата без intent — это «обычный разговор». Сбрасываем
      // режим, иначе предыдущий slot-fill / search режим залипает.
      _mode = AiChatKind.chat;
      // История переживает закрытие экрана (static _messages). Если же
      // приложение перезапускали и в памяти только приветствие — подтянем
      // сохранённую переписку из БД, чтобы история не терялась.
      if (_messages.length <= 1) {
        unawaited(_restoreHistory());
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: true));
      return;
    }

    if (initial == 'create_order' || initial == 'Разместить заказ') {
      // Гость создать заказ не может — для этого нужен аккаунт. Остаёмся в чате
      // и зовём войти; поиск и вопросы доступны без входа.
      if (isGuest) {
        _mode = AiChatKind.chat;
        _addBotMessage('Чтобы создать и разместить заказ, нужно войти в аккаунт. '
            'Найти технику и задать вопрос можно и без входа.');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showGuestAuthPrompt(context,
                message: 'Войдите, чтобы создать и разместить заказ.');
          }
        });
        return;
      }
      _mode = AiChatKind.slotFillOrder;
      // Чистим прошлую слот-сессию — «Новый заказ» должен начинаться с пустого
      // черновика, а не продолжать предыдущий заказ этого же запуска.
      AiClient.instance.startFreshSlot(AiChatKind.slotFillOrder);
      _addBotMessage('Давайте оформлю заказ. Какая техника нужна и для каких работ? Можно ответить голосом.');
      return;
    }
    if (initial == 'find_executor' || initial == 'Найти исполнителя') {
      _mode = AiChatKind.search;
      _addBotMessage('Кого ищете? Назовите технику и город — например, «кран в Москве». Можно голосом.');
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mode = AiChatKind.chat;
      _handleSend(initial);
    });
  }

  /// Подчистка при открытии экрана: список сообщений статический и переживает
  /// уход/возврат и ремаунт (поворот экрана). Прерванный стрим мог оставить в
  /// нём пустой пузырь ассистента, который рисуется как вечные «печатает…».
  void _salvageOrphanPlaceholders() {
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (!m.fromUser &&
          m.type == ChatMessageType.text &&
          m.text.trim().isEmpty) {
        _messages[i] = ChatMessage(
          id: m.id,
          text: 'Ответ прервался — спросите, пожалуйста, ещё раз.',
          fromUser: false,
        );
      }
    }
  }

  void _addBotMessage(String text, {Map<String, dynamic>? data, ChatMessageType type = ChatMessageType.text}) {
    // Защита от вечных точек: пустой текст ассистента пузырь рисует как
    // индикатор «печатает». На неstreaming-пути (поиск/slot-fill) заменить
    // его нечем, поэтому пустой текстовый ответ подменяем понятным фолбэком.
    if (type == ChatMessageType.text && text.trim().isEmpty) {
      text = 'Не получилось сформировать ответ. Попробуйте переформулировать.';
    }
    // Если экран не активен — сохраняем сообщение в статичный список,
    // чтобы при возврате юзер его увидел. setState — только если mounted.
    final msg = ChatMessage(
      id:   _nextId(),
      text: text,
      fromUser: false,
      type: type,
      data: data,
    );
    if (!mounted) {
      _messages.add(msg);
      return;
    }
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  String _nextId() {
    _idCounter += 1;
    return 'm${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: jump));
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(pos);
      } else {
        _scrollController.animateTo(
          pos,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      // Высокие виджеты (handoff-карточка заказа, карточки результатов поиска)
      // доращивают высоту списка уже ПОСЛЕ первого кадра / во время анимации —
      // из-за этого одиночный скролл не достаёт до низа. Через короткую паузу
      // (после анимации) доводим список до фактического низа.
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    });
  }

  /// Синхронный шлюз: возвращает true, если отправка ПРИНЯТА (тогда поле ввода
  /// очищается). Если ассистент занят/идёт запись/пусто — false, и поле НЕ
  /// чистится, чтобы набранное сообщение не пропало молча.
  bool _trySend(String text) {
    if (text.isEmpty && _pendingImages.isEmpty) return false;
    if (_isProcessing || _isRecording) return false;
    unawaited(_handleSend(text));
    return true;
  }

  /// Дубль фото заказа? Сравниваем не только путь (галерея на повторном выборе
  /// даёт НОВЫЙ временный путь к тому же снимку), но и размер файла.
  bool _isDuplicatePhoto(String p) {
    if (_orderPhotos.contains(p)) return true;
    int len;
    try {
      len = File(p).lengthSync();
    } catch (_) {
      return false;
    }
    return _orderPhotos.any((e) {
      try {
        return File(e).lengthSync() == len;
      } catch (_) {
        return false;
      }
    });
  }

  Future<void> _handleSend(String text) async {
    final hasImages = _pendingImages.isNotEmpty;
    if (text.isEmpty && !hasImages) return;
    if (_isProcessing) return;
    // Идёт запись голоса — не отправляем текст параллельно (иначе два потока
    // правят список сообщений и _isProcessing). Голос завершит сам себя.
    if (_isRecording) return;

    setState(() {
      if (hasImages) {
        // Копим прикреплённые фото — при создании заказа уйдут в order-photos.
        for (final p in _pendingImages) {
          if (_orderPhotos.length < 8 && !_isDuplicatePhoto(p)) {
            _orderPhotos.add(p);
          }
        }
        _messages.add(ChatMessage(
          id:   _nextId(),
          text: '',
          fromUser: true,
          type: ChatMessageType.image,
          imageAssets: List<String>.from(_pendingImages),
        ));
        _pendingImages.clear();
      }
      if (text.isNotEmpty) {
        _messages.add(ChatMessage(id: _nextId(), text: text, fromUser: true));
      }
    });
    _scrollToBottom();
    if (text.isEmpty) {
      // Картинка без текста: сами изображения ассистент не читает, НО фото
      // прикрепятся к заказу при его создании. Подсказываем, что делать дальше.
      if (hasImages) {
        _addBotMessage(
          'Фото получил — сам я картинки не читаю, но прикреплю их к заказу, '
          'когда будем его оформлять. Опишите, что нужно: техника, даты, город '
          '(можно голосом).',
        );
      }
      return;
    }
    await _sendToAssistant(text);
  }

  Future<void> _sendToAssistant(String text) async {
    // Гость не может создавать заказ — для этого нужен аккаунт. Перехватываем
    // намерение «создай заказ» (и режим сбора, если в него как-то попали) до
    // обработки и зовём войти. Поиск и FAQ работают без входа.
    if (isGuest &&
        (_mode == AiChatKind.slotFillOrder ||
            ((_mode == AiChatKind.chat || _mode == AiChatKind.search) &&
                looksLikeCreateOrder(text)))) {
      if (_mode == AiChatKind.slotFillOrder) _mode = AiChatKind.chat;
      await showGuestAuthPrompt(context,
          message: 'Войдите, чтобы создать и разместить заказ.');
      return;
    }
    setState(() => _isProcessing = true);
    _scrollToBottom();

    // Поиск прямо из обычного чата: если пользователь в режиме болтовни явно
    // просит найти исполнителя/технику — уводим в поиск (карточки), а не в
    // FAQ-ответ. И наоборот: вопрос-FAQ в режиме поиска возвращает в чат.
    // Slot-fill (пошаговый сбор) не трогаем.
    // Явное «создай/оформи заказ» текстом — уводим в пошаговый сбор (проверяем
    // ДО поиска: «создай заказ на экскаватор» содержит и технику, но это
    // создание, а не поиск). Из режима сбора этот детектор не дёргаем.
    if ((_mode == AiChatKind.chat || _mode == AiChatKind.search) &&
        looksLikeCreateOrder(text)) {
      _mode = AiChatKind.slotFillOrder;
      AiClient.instance.startFreshSlot(AiChatKind.slotFillOrder);
    } else if (_mode == AiChatKind.chat && looksLikeCatalogSearch(text, isCustomer: true)) {
      _mode = AiChatKind.search;
    } else if (_mode == AiChatKind.search && looksLikeFaqQuestion(text)) {
      _mode = AiChatKind.chat;
    } else if (_mode == AiChatKind.slotFillOrder && looksLikeFaqInterruption(text)) {
      // Настоящий вопрос посреди пошагового создания заказа («как отменить?»,
      // «сколько стоит подписка») — выходим из сбора в обычный чат. А вот
      // притяжательные слова («моё местоположение», «у меня в Москве») — это
      // ОТВЕТЫ слот-филлу, на них из режима НЕ выходим (иначе терялись черновик
      // и геопозиция).
      _mode = AiChatKind.chat;
    }

    if (_mode == AiChatKind.search) {
      // Поиск: ЖДЁМ геопозицию, чтобы расстояние в карточках считалось от
      // пользователя уже с первого запроса (раньше на первом сообщении
      // координат ещё не было — расстояние то показывалось, то нет). После
      // первого раза ensure() возвращается мгновенно (координаты кэшируются),
      // плюс мы прогреваем их при открытии экрана.
      await UserLocation.ensure();
    } else if (_mode == AiChatKind.slotFillOrder) {
      // Создание заказа: ЖДЁМ геопозицию (если разрешит) — тогда сервер сам
      // определит город/адрес по координатам и не будет их спрашивать. После
      // первого раза координаты кэшируются, ожидание мгновенное.
      await UserLocation.ensure();
    }

    // 50 сек — ВЫШЕ серверного (~45 сек). Если клиент сдаётся раньше сервера,
    // юзер шлёт повтор в ту же беседу, и лимит ассистента списывается дважды.
    const Duration timeout = Duration(seconds: 50);
    try {
      // Для обычного chat-режима используем стрим. _streamChatReply сам
      // отрисовывает ошибку в placeholder и НЕ rethrow — иначе outer-catch
      // ниже добавил бы второй bubble с тем же текстом.
      if (_mode == AiChatKind.chat) {
        await _streamChatReply(text).timeout(timeout, onTimeout: () {
          // Внешний таймаут: помечаем стрим устаревшим, чтобы подвисший await
          // for внутри больше НЕ перезаписывал этот пузырь, и мягко завершаем
          // (сохранив накопленный текст и кнопку «Перейти»).
          _staleStreamIds.add(_lastStreamId);
          _finishStreamSoftly('__last_stream__', 'Не дождался ответа. Попробуйте ещё раз.');
        });
        return;
      }
      Future<AiReply> call() {
        switch (_mode) {
          case AiChatKind.search:
            return AiClient.instance.search(text);
          case AiChatKind.slotFillOrder:
            return AiClient.instance.slotFillOrder(text);
          case AiChatKind.chat:
            return AiClient.instance.chat(text);
        }
      }
      final reply = await call().timeout(timeout);
      _appendReply(reply);
    } on AiQuotaExceeded catch (e) {
      _addBotMessage(e.message);
    } on AiContentFilterError catch (e) {
      _addBotMessage(e.message);
    } on TimeoutException {
      _addBotMessage('Не дождался ответа. Попробуйте ещё раз.');
    } catch (_) {
      _addBotMessage(
        'Не удалось получить ответ. Проверьте интернет и попробуйте снова.',
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Стриминговый вариант chat. Все ошибки рисуются прямо в placeholder —
  /// НЕ rethrow, иначе outer-catch добавит дубликат-бабл.
  String _lastStreamId = '';
  // id стримов, помеченных устаревшими внешним таймаутом — их await for больше
  // не должен писать в пузырь (иначе мерцание «ошибка → кусок ответа»). Набор,
  // а не одна строка: при двух подряд протухших стримах одна переменная
  // «забывала» первый, и его поздний кусок протекал в свой пузырь поверх ошибки.
  final Set<String> _staleStreamIds = <String>{};
  Future<void> _streamChatReply(String text) async {
    _idCounter++;
    final id = 'stream_$_idCounter';
    _lastStreamId = id;
    _messages.add(ChatMessage(id: id, text: '', fromUser: false));
    if (mounted) setState(() {});
    _scrollToBottom();

    try {
      await for (final chunk
          in AiClient.instance.chatStream(text).timeout(
        // Таймаут МЕЖДУ чанками: если сервер завис и перестал слать данные,
        // прерываем await for → finally внутри chatStream закроет http-клиент.
        // Раньше .timeout() стоял на внешнем Future и подписку не отменял —
        // сокет висел до конца ответа сервера (до 45 сек). 50 сек — выше
        // серверного потолка, чтобы не оборвать медленный, но живой ответ.
        const Duration(seconds: 50),
      )) {
        // Экран закрыли посреди генерации — прекращаем читать поток.
        // Выход из await for отменяет подписку, и http-клиент закрывается
        // в finally внутри chatStream (иначе сокет висел бы до конца ответа).
        if (!mounted) return;
        // Стрим устарел (внешний таймаут уже завершил пузырь) — не пишем,
        // иначе пользователь увидел бы мерцание «ошибка → кусок ответа».
        if (_staleStreamIds.contains(id)) return;
        final idx = _messages.indexWhere((m) => m.id == id);
        if (idx < 0) return;
        _messages[idx] = ChatMessage(
          id: id,
          text: chunk.text,
          fromUser: false,
          // nav приходит только на финальном chunk'е — тогда под ответом
          // появляется кнопка «Перейти». На промежуточных он null.
          navAction: chunk.nav?.action,
          navLabel: chunk.nav?.label,
        );
        if (mounted) setState(() {});
        if (chunk.done) {
          _scrollToBottom();
          break;
        }
      }
      // Защита: если поток завершился с пустым текстом, плейсхолдер иначе
      // остался бы вечными точками (он рисуется как индикатор «печатает»).
      final idx = _messages.indexWhere((m) => m.id == id);
      if (idx >= 0 && _messages[idx].text.trim().isEmpty) {
        _replaceStreamMessage(
          id,
          'Не получилось сформировать ответ. Попробуйте переформулировать.',
        );
      }
    } on AiQuotaExceeded catch (e) {
      _replaceStreamMessage(id, e.message);
    } on AiContentFilterError catch (e) {
      _replaceStreamMessage(id, e.message);
    } catch (_) {
      if (_staleStreamIds.contains(id)) return;
      _finishStreamSoftly(
        id,
        'Не удалось получить ответ. Проверьте интернет и попробуйте снова.',
      );
    }
  }

  /// Мягкое завершение стрима: если часть ответа УЖЕ пришла — сохраняем её,
  /// дописываем пометку об обрыве и оставляем кнопку «Перейти» (nav). Иначе
  /// показываем фолбэк. Так почти готовый ответ не затирается генерик-ошибкой.
  void _finishStreamSoftly(String id, String fallback) {
    final String realId = (id == '__last_stream__') ? _lastStreamId : id;
    final int idx = _messages.indexWhere((m) => m.id == realId);
    if (idx < 0) {
      _addBotMessage(fallback);
      return;
    }
    final ChatMessage cur = _messages[idx];
    final bool hasText = cur.text.trim().isNotEmpty;
    _messages[idx] = ChatMessage(
      id: realId,
      text: hasText ? '${cur.text.trimRight()}\n\n(ответ оборвался)' : fallback,
      fromUser: false,
      navAction: cur.navAction,
      navLabel: cur.navLabel,
    );
    if (mounted) setState(() {});
  }

  void _replaceStreamMessage(String id, String text) {
    final realId = (id == '__last_stream__') ? _lastStreamId : id;
    final idx = _messages.indexWhere((m) => m.id == realId);
    if (idx < 0) {
      _addBotMessage(text);
      return;
    }
    _messages[idx] = ChatMessage(id: realId, text: text, fromUser: false);
    if (mounted) setState(() {});
  }

  /// Восстановление переписки из БД (последние сообщения сессии). Вызывается
  /// при первом открытии чата после перезапуска приложения. Заменяет
  /// стартовое приветствие реальной историей (текст + карточки заказов/
  /// исполнителей из сохранённого data).
  Future<void> _restoreHistory() async {
    await AiClient.instance.restoreChatSession();
    final List<Map<String, dynamic>> rows = await AiClient.instance.loadHistory();
    if (rows.isEmpty || !mounted) return;
    final List<ChatMessage> restored = <ChatMessage>[];
    for (final Map<String, dynamic> r in rows) {
      final String? role = r['role'] as String?;
      if (role != 'user' && role != 'assistant') continue;
      final bool fromUser = role == 'user';
      final String content = (r['content'] as String?) ?? '';
      final Map<String, dynamic>? data = r['data'] as Map<String, dynamic>?;
      final String? kind = data?['kind'] as String?;
      ChatMessageType type = ChatMessageType.text;
      if (!fromUser && data != null) {
        final dynamic items = data['items'];
        if (kind == 'order_cards' && items is List && items.isNotEmpty) {
          type = ChatMessageType.orderCards;
        } else if (kind == 'executor_cards' && items is List && items.isNotEmpty) {
          type = ChatMessageType.executorCards;
        }
      }
      // Пустые служебные строки без карточек не показываем.
      if (content.trim().isEmpty && type == ChatMessageType.text) continue;
      restored.add(ChatMessage(
        id: _nextId(),
        text: content,
        fromUser: fromUser,
        type: type,
        data: type == ChatMessageType.text ? null : data,
      ));
    }
    if (restored.isEmpty || !mounted) return;
    // За время загрузки истории (сеть) пользователь мог уже отправить
    // сообщение — тогда НЕ затираем его историей, иначе оно пропадёт.
    // Подставляем историю, только если на экране всё ещё одно приветствие.
    if (_messages.length > 1) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(restored);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: true));
  }

  void _appendReply(AiReply reply) {
    final kind = reply.dataKind;
    if (kind == 'executor_cards' && reply.items.isNotEmpty) {
      _addBotMessage(reply.text, type: ChatMessageType.executorCards, data: reply.data);
      return;
    }
    if (kind == 'order_cards' && reply.items.isNotEmpty) {
      _addBotMessage(reply.text, type: ChatMessageType.orderCards, data: reply.data);
      return;
    }
    if ((kind == 'order_draft' || kind == 'service_draft') && reply.isDraftReady) {
      Map<String, dynamic>? data = reply.data;
      // Прикрепляем накопленные в чате фото к черновику ЗАКАЗА — форма заберёт
      // их в _photos и зальёт в order-photos при публикации заказа.
      if (kind == 'order_draft' && _orderPhotos.isNotEmpty && data != null) {
        data = Map<String, dynamic>.from(data);
        final draft =
            Map<String, dynamic>.from((data['draft'] as Map?) ?? const <String, dynamic>{});
        draft['ai_photos'] = List<String>.from(_orderPhotos);
        data['draft'] = draft;
      }
      _addBotMessage(reply.text, type: ChatMessageType.draftReady, data: data);
      // Фото ушли в черновик заказа — очищаем накопитель, чтобы они не
      // прилипли к следующему заказу в этой же сессии.
      _orderPhotos.clear();
      // Slot-fill завершён черновиком. Возвращаем режим в обычный чат, иначе
      // следующий свободный вопрос ушёл бы снова в пошаговый сбор, а не в FAQ.
      _mode = AiChatKind.chat;
      return;
    }
    _addBotMessage(reply.text);
  }

  Future<void> _handleAttach() async {
    final int remaining = 8 - _pendingImages.length;
    if (remaining <= 0) return;
    final picked = await pickMultipleImagesFromGallery(limit: remaining, context: context);
    if (picked.isEmpty || !mounted) return;
    final kept = picked.length > remaining ? picked.sublist(0, remaining) : picked;
    setState(() => _pendingImages.addAll(kept));
    if (picked.length > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          'Можно добавить не более 8 фото. Добавлены первые ${kept.length}.',
        )),
      );
    }
  }

  void _removePendingImage(int index) {
    setState(() => _pendingImages.removeAt(index));
  }

  Future<void> _toggleRecording() async {
    if (_voiceBusy) return;
    // Пока ассистент отвечает — не начинаем новую запись (иначе два потока
    // правят индикатор и список). Отмену уже идущей записи разрешаем.
    if (_isProcessing && !_isRecording) return;
    _voiceBusy = true;
    try {
      if (_isRecording) {
        await _cancelRecording();
        return;
      }
      await _startRecording();
    } finally {
      _voiceBusy = false;
    }
  }

  Future<void> _startRecording() async {
    final granted = await SttRecorder.instance.ensurePermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Нет доступа к микрофону. Разрешите его в настройках, чтобы отправлять голосовые.'),
        action: SnackBarAction(
          label: 'Настройки',
          onPressed: () => SttRecorder.instance.openSettings(),
        ),
      ));
      return;
    }
    final started = await SttRecorder.instance.start();
    if (!started) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось начать запись — микрофон занят или недоступен. Напишите, пожалуйста, текстом.')),
        );
      }
      return;
    }
    SttRecorder.instance.onAutoStop = () {
      if (!mounted || !_isRecording) return;
      _sendVoice();
    };
    if (mounted) {
      setState(() {
        _isRecording = true;
        // Пузырь-индикатор записи прямо в ленте чата — чтобы было видно, что
        // голос пишется, а не молчаливое поле ввода.
        _messages.add(const ChatMessage(
          id: _kVoiceRecId, text: '🎤 Идёт запись…', fromUser: true,
        ));
      });
      _scrollToBottom();
    }
  }

  Future<void> _cancelRecording() async {
    SttRecorder.instance.onAutoStop = null;
    await SttRecorder.instance.cancel();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _messages.removeWhere((m) => m.id == _kVoiceRecId);
      });
    }
  }

  Future<void> _sendVoice() async {
    if (!_isRecording) return;
    SttRecorder.instance.onAutoStop = null;
    if (mounted) setState(() => _isRecording = false);

    final File? audio = await SttRecorder.instance.stop();
    // После await — экран мог закрыться. Без guard крах на setState().
    if (!mounted) {
      if (audio != null) {
        try { await audio.delete(); } catch (_) {}
      }
      return;
    }
    if (audio == null) {
      setState(() => _messages.removeWhere((m) => m.id == _kVoiceRecId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Слишком короткое сообщение — задержите кнопку микрофона')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      // Запись остановлена — меняем пузырь «идёт запись» на «распознаю».
      final i = _messages.indexWhere((m) => m.id == _kVoiceRecId);
      if (i >= 0) {
        _messages[i] = const ChatMessage(
          id: _kVoiceRecId, text: '🎤 Распознаю…', fromUser: true,
        );
      }
    });
    String? errorMsg;
    String? recognized;
    try {
      recognized = await AiClient.instance
          .transcribeAudio(audio, format: SttRecorder.instance.lastFormat);
    } on AiQuotaExceeded catch (e) {
      errorMsg = e.message;
    } on AiAudioTooLargeError {
      errorMsg = 'Слишком длинное сообщение — больше минуты.';
    } on AiAudioNoSpeechError {
      errorMsg = 'Не услышал речи — попробуйте ещё раз, поближе к микрофону.';
    } on AiAudioInvalidFormatError {
      errorMsg = 'Запись в неподдерживаемом формате. Напишите, пожалуйста, текстом.';
    } catch (_) {
      errorMsg = 'Не удалось распознать голос. Проверьте интернет.';
    }
    try { await audio.delete(); } catch (_) {}

    if (!mounted) return;
    if (errorMsg != null || recognized == null || recognized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg ?? 'Не удалось распознать речь')),
      );
      setState(() {
        _isProcessing = false;
        _messages.removeWhere((m) => m.id == _kVoiceRecId);
      });
      return;
    }
    // Распознанный текст уходит ПРЯМО В ЧАТ как сообщение пользователя и сразу
    // отправляется ассистенту — ответ приходит уже после завершения записи.
    final String capped =
        recognized.length > 1000 ? recognized.substring(0, 1000) : recognized;
    setState(() {
      _isProcessing = false;
      _messages.removeWhere((m) => m.id == _kVoiceRecId);
    });
    _handleSend(capped);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isRecording) {
      SttRecorder.instance.cancel();
      // Убираем пузырь «🎤 Идёт запись…» — иначе он остаётся в ленте навсегда.
      if (mounted) {
        setState(() {
          _isRecording = false;
          _messages.removeWhere((m) => m.id == _kVoiceRecId);
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isRecording) {
      SttRecorder.instance.cancel();
      // Снимаем пузырь «🎤 Идёт запись…» из статичной ленты, иначе при
      // следующем открытии чата он висит вечно.
      _messages.removeWhere((m) => m.id == _kVoiceRecId);
    }
    SttRecorder.instance.onAutoStop = null;
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        // Светлая шапка — тёмные иконки статус-бара (перебиваем светлый
        // дефолт темы, который рассчитан на тёмные шапки).
        systemOverlayStyle: dispatcherSystemBarStyle(),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: EdgeInsets.only(top: 4.h),
          child: Text(
            'Поддержка',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textBlack,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 4.w),
            child: IconButton(
              padding: EdgeInsets.only(top: 4.h),
              icon: Image.asset('assets/icons/support/close.webp', width: 26.r, height: 26.r),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/shell');
                }
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.h),
          child: Container(height: 1.h, color: AppColors.divider),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              itemCount: _messages.length + (_showStandaloneTyping ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox.shrink(),
              itemBuilder: (context, index) {
                if (index < _messages.length) {
                  final ChatMessage m = _messages[index];
                  // Ключ по id: при стриминге ответа и добавлении сообщений
                  // Flutter переиспользует уже отрисованные пузыри, а не
                  // путает их состояние при изменении списка.
                  return ChatBubble(key: ValueKey<String>(m.id), message: m);
                }
                return const TypingBubble();
              },
            ),
          ),
          if (_showQuickActions)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 54.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QuickActionChip(
                      label: 'Разместить заказ',
                      onTap: () {
                        // Гость заказ создать не может — нужен аккаунт.
                        if (isGuest) {
                          showGuestAuthPrompt(context,
                              message: 'Войдите, чтобы создать и разместить заказ.');
                          return;
                        }
                        _mode = AiChatKind.slotFillOrder;
                        AiClient.instance.startFreshSlot(AiChatKind.slotFillOrder);
                        _addBotMessage('Давайте оформлю заказ. Какая техника нужна, на какие даты и в каком городе? Можно голосом. При желании прикрепите фото объекта — добавлю их к заказу.');
                      },
                    ),
                    SizedBox(height: 8.h),
                    _QuickActionChip(
                      label: 'Найти исполнителя',
                      onTap: () {
                        _mode = AiChatKind.search;
                        _addBotMessage('Кого ищете? Назовите технику и город — например, «кран в Москве». Можно голосом.');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ChatInputBar(
            controller: _inputController,
            // Фото из чата теперь прикрепляются к ЗАКАЗУ при его создании
            // (накапливаются в _orderPhotos → уходят в черновик ai_photos →
            // форма create_order заливает их в order-photos). Кнопку показываем.
            showAttach: true,
            isRecording: _isRecording,
            pendingImages: _pendingImages,
            onRemovePendingImage: _removePendingImage,
            onSend: _trySend,
            onAttach: _handleAttach,
            onMicTap: _toggleRecording,
            onCancelRecording: _cancelRecording,
            onSendVoice: _sendVoice,
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            height: 36.h,
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
