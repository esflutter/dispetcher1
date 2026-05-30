// =====================================================================
// stt_recorder.dart — обёртка над `record` для голосовых сообщений.
//
// Запись идёт в OGG/Opus 16 kHz mono — сжатый формат, который без
// конвертации принимает Yandex SpeechKit STT v1 (sync). На 28 сек
// — примерно 30-60 КБ, влезает в лимит API 1 МБ с большим запасом.
//
// SpeechKit sync строго требует длительность <30 сек, иначе 400 Bad
// Request — поэтому автоматически останавливаем запись на 28 сек и
// дёргаем onAutoStop, чтобы клиент отправил то, что собрано.
// =====================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class SttRecorder {
  SttRecorder._();
  static final SttRecorder instance = SttRecorder._();

  /// Жёсткий лимит SpeechKit sync API — 30 секунд. Берём 28 с запасом
  /// на сетевую задержку и обработку.
  static const Duration maxDuration = Duration(seconds: 28);

  final AudioRecorder _rec = AudioRecorder();
  String? _currentPath;
  Timer? _maxDurationTimer;

  /// Формат последней записи для параметра `?format=` в stt-yandex:
  /// 'oggopus' (по умолчанию) либо 'lpcm' (фолбэк на устройствах без Opus).
  String _lastFormat = 'oggopus';
  String get lastFormat => _lastFormat;

  /// Callback срабатывает, когда auto-stop по maxDuration сработал.
  void Function()? onAutoStop;

  Future<bool> isRecording() => _rec.isRecording();

  Future<bool> ensurePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<void> openSettings() => openAppSettings();

  Future<bool> start() async {
    final granted = await ensurePermission();
    if (!granted) return false;
    try {
      // Выбираем кодек под устройство. Предпочитаем Opus (компактный). Если
      // нативного Opus-энкодера нет (часть Xiaomi/Huawei/MediaTek), раньше тут
      // был ЖЁСТКИЙ отказ — и голос на таких телефонах не работал. Теперь
      // фолбэк на сырой PCM (lpcm): он есть везде и его принимает SpeechKit.
      final AudioEncoder encoder;
      final String ext;
      if (await _rec.isEncoderSupported(AudioEncoder.opus)) {
        encoder = AudioEncoder.opus;       ext = 'ogg'; _lastFormat = 'oggopus';
      } else if (await _rec.isEncoderSupported(AudioEncoder.pcm16bits)) {
        encoder = AudioEncoder.pcm16bits;  ext = 'pcm'; _lastFormat = 'lpcm';
      } else {
        if (kDebugMode) debugPrint('[stt-recorder] no supported encoder (opus/pcm16)');
        return false;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.$ext';
      _currentPath = path;
      await _rec.start(
        RecordConfig(
          encoder:     encoder,
          sampleRate:  16000,
          numChannels: 1,
        ),
        path: path,
      );
      _maxDurationTimer?.cancel();
      _maxDurationTimer = Timer(maxDuration, () {
        try { onAutoStop?.call(); } catch (_) {}
      });
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[stt-recorder] start failed: $e');
      _currentPath = null;
      return false;
    }
  }

  Future<File?> stop() async {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    try {
      final path = await _rec.stop();
      _currentPath = null;
      if (path == null) return null;
      final f = File(path);
      if (!await f.exists()) return null;
      final len = await f.length();
      // Порог 200 байт — короткие «да», «нет», «ага» проходят.
      if (len < 200) {
        try { await f.delete(); } catch (_) {}
        return null;
      }
      return f;
    } catch (e) {
      if (kDebugMode) debugPrint('[stt-recorder] stop failed: $e');
      return null;
    }
  }

  Future<void> cancel() async {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    try {
      await _rec.cancel();
    } catch (_) {}
    final path = _currentPath;
    _currentPath = null;
    if (path != null) {
      try { await File(path).delete(); } catch (_) {}
    }
  }

  Future<void> dispose() => _rec.dispose();
}
