import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Утилиты для работы с фото: пикер с устройства и универсальный
/// [ImageProvider] для путей, которые могут быть либо ассетом
/// (`assets/...`), либо реальным файлом на устройстве.

/// Единый инстанс пикера.
final ImagePicker _picker = ImagePicker();

/// Выбрать одно изображение из галереи. Ограничиваем размер и
/// качество — чтобы не таскать по памяти и сети оригиналы по
/// десяткам мегабайт.
Future<String?> pickImageFromGallery() async {
  final XFile? file = await _picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1920,
    maxHeight: 1920,
    imageQuality: 85,
  );
  return file?.path;
}

/// Выбрать несколько изображений из галереи. Нативный пикер покажет
/// мультивыбор. Возвращает все выбранные пути — вызывающий код сам
/// решает, что делать с лишними (лимит `[limit]` честно соблюдается
/// далеко не во всех галереях, например на Android <13 или в
/// вендорских).
Future<List<String>> pickMultipleImagesFromGallery({int? limit}) async {
  if (limit != null && limit <= 0) return const <String>[];
  final List<XFile> files = await _picker.pickMultiImage(
    maxWidth: 1920,
    maxHeight: 1920,
    imageQuality: 85,
    limit: limit,
  );
  return files.map((XFile f) => f.path).toList();
}

/// True, если путь указывает на ассет приложения, а не файл.
bool isAssetPath(String path) => path.startsWith('assets/');

/// Отдаёт нужный [ImageProvider] для картинки. Для ассетов —
/// [AssetImage], для файлов — [FileImage]. Используется в виджетах,
/// которые должны показывать и моковые ассеты, и реально
/// загруженные пользователем фото.
ImageProvider photoProvider(String path) =>
    isAssetPath(path) ? AssetImage(path) : FileImage(File(path));
