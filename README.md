# Диспетчер №1 — приложение заказчика

Flutter-приложение для заказчика биржи спецтехники. Работает с общей Supabase-БД совместно с приложением исполнителя (`../claude`).

## Стек

- Flutter **3.41.7** / Dart 3.10+ (CI iOS собирается на этой версии — см. `codemagic.yaml`; локально собирать на ней же)
- Supabase (Auth, Storage, PostgREST) — self-hosted на Beget
- SMS-авторизация: GoTrue Send-SMS Hook → Edge Function → **RedSMS**
- Адреса: DaData Suggest API
- Навигация: go_router
- Адаптив: flutter_screenutil (целевой Pixel 9, 1080×2424)

В отличие от приложения исполнителя, здесь **нет** платежей (YooKassa), графика, подписок и виджетов карт — заказчику они по ТЗ не нужны.

## Запуск

Нужны ключи, передаются через `--dart-define` (Mapbox заказчику не нужен — карты у него нет):

| Переменная | Где взять | Обязательность |
|------------|-----------|----------------|
| `SUPABASE_URL` | URL self-hosted Supabase, например `https://jokaynapesbem.beget.app` | обязательна |
| `SUPABASE_ANON_KEY` | Публичный anon-JWT из Supabase Studio → Settings → API | обязательна |
| `DADATA_API_KEY` | Token (не Secret!) из dadata.ru → Профиль → API-ключи | опциональна (без неё подсказки адресов пустые) |

> ⚠️ **Firebase-конфиги (в `.gitignore`, в репозитории их нет):** перед сборкой Android положи `google-services.json` в `android/app/` — иначе Gradle упадёт на плагине google-services («File google-services.json is missing»). Для iOS — `GoogleService-Info.plist` в `ios/Runner/`. Оба файла берутся из передаваемой папки «4. Firebase» или из консоли Firebase (проект `dispetcher-8c871`).

### Debug-сборка

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://jokaynapesbem.beget.app \
  --dart-define=SUPABASE_ANON_KEY=<anon_jwt> \
  --dart-define=DADATA_API_KEY=<dadata_token>
```

### Release-сборка

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://jokaynapesbem.beget.app \
  --dart-define=SUPABASE_ANON_KEY=<anon_jwt> \
  --dart-define=DADATA_API_KEY=<dadata_token>
```

### VSCode launch.json

Удобно положить дев-ключи в `.vscode/launch.json`:

```json
{
  "configurations": [
    {
      "name": "customer (dev)",
      "request": "launch",
      "type": "dart",
      "toolArgs": [
        "--dart-define=SUPABASE_URL=https://jokaynapesbem.beget.app",
        "--dart-define=SUPABASE_ANON_KEY=<anon_jwt>",
        "--dart-define=DADATA_API_KEY=<dadata_token>"
      ]
    }
  ]
}
```

## Тестовые номера для SMS

См. README в приложении исполнителя — `GOTRUE_SMS_TEST_OTP` общий для обоих.

## Структура

- `lib/core/` — сервисы (Auth, Catalog, CustomerOrders, Profile, Storage, Settings, DaData)
- `lib/features/` — экраны (auth, onboarding, shell, catalog, orders, executor_card, profile, support)

## Полезные команды

```bash
flutter analyze
flutter pub outdated
flutter test
flutter clean && flutter pub get
```
