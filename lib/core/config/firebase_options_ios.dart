import 'package:firebase_core/firebase_core.dart';

/// Параметры Firebase для iOS, заданные ЯВНО в коде.
///
/// На Android Firebase поднимается сам: файл настроек `google-services.json`
/// лежит в проекте и подкладывается Gradle-плагином. На iOS файл
/// `GoogleService-Info.plist` создаётся скриптом сборки на диске, но НЕ
/// подключён к Xcode-проекту, а Xcode кладёт внутрь приложения только явно
/// добавленные файлы. Из-за этого запуск Firebase на iOS падал, ошибка
/// гасилась общим `catch`, и приложение работало без пушей вовсе.
///
/// Явные параметры снимают зависимость от того, попал файл в сборку или нет.
/// Значения взяты из `GoogleService-Info (заказчик iOS).plist` в папке
/// передачи проекта; это не секреты — они и так внутри любой опубликованной
/// сборки, доступ к данным ограничивают правила Firebase.
///
/// Android намеренно не трогаем — там всё работает через свой файл настроек.
const FirebaseOptions kFirebaseOptionsIos = FirebaseOptions(
  apiKey: 'AIzaSyBsex8A8gKVT-OZhT1-VfK4qJFbqBcKlNQ',
  appId: '1:389437917871:ios:7789120556fa9ec0d5a25a',
  messagingSenderId: '389437917871',
  projectId: 'dispetcher-8c871',
  storageBucket: 'dispetcher-8c871.firebasestorage.app',
  iosBundleId: 'com.dispatcher1.dispatcher1',
);
