# Диспетчер №1 — приложение заказчика

Flutter-приложение для заказчика биржи спецтехники. Работает с общей Supabase-БД совместно с приложением исполнителя (`../claude`).

## Стек

- Flutter 3.10+ / Dart 3.10+
- Supabase (Auth, Storage, PostgREST) — self-hosted на Beget
- SMS-авторизация: GoTrue Send-SMS Hook → Edge Function → sms.ru
- Адреса: DaData Suggest API
- Навигация: go_router
- Адаптив: flutter_screenutil (целевой Pixel 9, 1080×2424)

В отличие от приложения исполнителя, здесь **нет** платежей (YooKassa), графика, подписок и виджетов карт — заказчику они по ТЗ не нужны.

## Запуск

Нужны три ключа, передаются через `--dart-define`:

| Переменная | Где взять |
|------------|-----------|
| `SUPABASE_URL` | URL self-hosted Supabase, например `https://jokaynapesbem.beget.app` |
| `SUPABASE_ANON_KEY` | Публичный anon-JWT из Supabase Studio → Settings → API |
| `DADATA_API_KEY` | Token (не Secret!) из dadata.ru → Профиль → API-ключи |

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
