# Контракт вёрстки «Диспетчер №1» (для subagent-ов)

Любой код, написанный в `lib/features/**`, ОБЯЗАН следовать этому контракту.
Цель — единый стиль, точная передача Figma и адаптивность.

## Общее
- Базовый фрейм Figma: **375 × 812** (iPhone X). Скейл — через `flutter_screenutil` (`.w`, `.h`, `.r`, `.sp`).
- ScreenUtilInit уже инициализирован в `lib/app.dart` — НЕ оборачивать повторно.
- Material 3, theme — `AppTheme.light` (уже подключена).
- Только light-тема.
- Все строки на русском (UI текст из Figma).
- Иконки — SVG через `flutter_svg` если есть; иначе Material Icons как временный заместитель ТОЛЬКО если в макете системная иконка.

## Дизайн-система — ИМПОРТИРОВАТЬ ИЗ ЭТИХ ФАЙЛОВ
```dart
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';
```

### AppColors (НЕ создавать новые цвета — только если нет в палитре)
- `primary` `#FFAC26`, `primaryDark` `#C77E1F`, `primaryTint` `#FFF9F0`
- `background` / `surface` `#FFFFFF`, `surfaceVariant` `#F2F2F2`
- `textPrimary` `#1D1D1D`, `textSecondary` `#49454F`, `textTertiary` `#929292`
- `divider` `#EEEEEE`, `success` `#05BD0B`, `error` `#E53935`

### AppTextStyles (использовать готовые геттеры)
`h1`, `h1SemiBold`, `h1Phone`, `h2`, `h3`, `h3Tight`, `titleL`, `bodyL`,
`bodyMMedium`, `bodyMRegular`, `titleS`, `button`, `body`, `bodyMedium`,
`linkBold`, `tabActive`, `tabInactive`, `subBody`, `chip`, `caption`,
`captionBold`, `tiny`.
Все размеры уже в `.sp`. НЕ хардкодить TextStyle вручную — копировать из Figma в один из этих геттеров; если нужного нет — добавить геттер в `app_text_styles.dart`, а не создавать локально.

### AppSpacing (для отступов и радиусов)
`xxs(4) / xs(8) / sm(12) / md(16) / lg(20) / xl(24) / xxl(32) / xxxl(40)`,
`screenH(16)`, `radiusS/M/L/XL/Pill`. Все геттеры уже масштабированы.
Допустимо использовать `12.w`, `16.h` напрямую если значение из Figma не подпадает под токен.

### Виджеты
- `PrimaryButton(label, onPressed)` — оранжевая основная кнопка 56h.
- `SecondaryButton(label, onPressed)` — outline.
- Если нужен новый переиспользуемый виджет (chip, tag, listItem) — создать в `lib/core/widgets/` и переиспользовать.

## Структура файлов
- Группа верстается в `lib/features/<group>/` (например `lib/features/auth/`, `lib/features/catalog/`).
- Один файл = один экран. Имя: `<screen_name>_screen.dart`. Класс: `<ScreenName>Screen`.
- Локальные виджеты экрана — в `_<name>` (приватные классы) или в подпапке `widgets/`.
- НЕ трогать `lib/main.dart`, `lib/app.dart`, `lib/core/router.dart`. Маршруты добавит координатор после финиша.
- В конце своей работы subagent ВОЗВРАЩАЕТ список созданных экранов в формате:
  ```
  ROUTES:
  /onboarding -> OnboardingScreen (lib/features/onboarding/onboarding_screen.dart)
  ```

## Ассеты
- Папка для растровых: `assets/images/<group>/<name>.webp`
- Папка для SVG: `assets/icons/<group>/<name>.svg` (если экспортируешь как SVG из Figma — можно)
- Если ассет уже скачан — переиспользовать. Не дублировать.
- Скачивание: использовать готовый скрипт `tools/fetch_assets.py` (см. ниже).

### Скрипт скачивания ассетов
`python tools/fetch_assets.py <node_id> <out_dir> [--name NAME] [--scale 2] [--svg]`

Скрипт:
1. Дёргает Figma API `/images/{file_key}?ids=<node_id>&format=png&scale=2` (или svg).
2. Скачивает PNG, конвертирует в WebP через Pillow (lossless quality 90).
3. Сохраняет в `assets/images/<out_dir>/<name>.webp` (или `assets/icons/...`)
4. Печатает финальный путь — его использовать в `Image.asset(...)`.

## Точность вёрстки
- Перед написанием экрана subagent ОБЯЗАН вытащить иерархию узлов из Figma:
  `GET /v1/files/w8KXSwOOskaCLTdZU7ERa9/nodes?ids=<NODE_ID>&depth=6`
  Кэшировать в `.figma_cache/screens/<node_id>.json`.
- Брать оттуда: размеры контейнеров, отступы, цвета fills, текстовые значения, fontSize, fontWeight, layout (Auto Layout = Row/Column + spacing).
- НЕ угадывать. Если значение не находится — взять ближайший токен из дизайн-системы.
- OTP: на экране верификации **6 ячеек** (использовать pinput, длина 6).
- Не верстать системные экраны: **«Камера»** (системная), реальные карты внутри «Заказы на карте» / «Просмотр заказа на карте» — рисуем плейсхолдер карты (серый контейнер с центрованной иконкой), реальную карту подключим позже с API. Состояния «Алерт галерея» (системный picker) — тоже плейсхолдер/skip.
- На экранах, где аватарка по логике ТЗ должна быть, но в макете отсутствует — добавить.

## Качество
- `flutter analyze` должен пройти без ошибок и без warnings (info допустимы).
- Никаких `print`, `debugPrint`, TODO без обоснования.
- Никаких dummy-данных в верхнем уровне — допустимы только const-списки внутри экрана как mock-данные для отображения.
- Адаптивность: ничего не должно вылезать на узких экранах. Использовать `Expanded`, `Flexible`, `SingleChildScrollView` где список может не влезть.

## Имена групп и папок
| Группа | Папка | Префикс ассетов |
|---|---|---|
| Splash + Онбординг | `features/onboarding` | `images/onboarding/` |
| Авторизация | `features/auth` | `images/auth/` |
| Главный shell + нижняя навигация | `features/shell` | `icons/nav/` |
| Каталог + лента + фильтр + детали | `features/catalog` | `images/catalog/` |
| Заказы + отзывы | `features/orders` | `images/orders/` |
| Профиль + верификация | `features/profile` | `images/profile/` |
| Карточка исполнителя | `features/executor_card` | `images/executor_card/` |
| Мои услуги | `features/services` | `images/services/` |
| Мой график | `features/schedule` | `images/schedule/` |
| Подписка + оплата + карта | `features/subscription` | `images/subscription/` |
| Поддержка / чат | `features/support` | `images/support/` |
